VERSION=8.19.7

# Check if arguments are provided
if [ $# -lt 4 ]; then
    echo "Usage: $0 <CLUSTER_NAME> <NODE_NAME> <NODE_ROLES> <DISCOVERY_SEED_HOSTS> <CLUSTER_INITIAL_MASTER_NODES>"
    echo "- CLUSTER_NAME: a cluster name that describes the purpose of the cluster"
    echo "- NODE_NAME: a human-readable identifier for a particular instance of Elasticsearch"
    echo "- NODE_ROLES: node role (e.g., data, master, ingest). you must include master to have at least one master-eligible node."
    echo "- DISCOVERY_SEED_HOSTS: a list of other nodes in the cluster that are master-eligible"
    echo "- CLUSTER_INITIAL_MASTER_NODES: a list of node.name of the master-eligible nodes whose votes should be counted in the very first election"
    echo "Example: $0 my-elasticsearch-cluster master-1 master 10.0.0.1,10.0.0.2,10.0.0.3 master-1,master-2,master-3"
    exit 1
fi

CLUSTER_NAME=$1
NODE_NAME=$2
NODE_ROLES=$3
DISCOVERY_SEED_HOSTS=$4
CLUSTER_INITIAL_MASTER_NODES=$5

echo "CLUSTER_NAME: $CLUSTER_NAME"
echo "NODE_NAME: $NODE_NAME"
echo "DISCOVERY_SEED_HOSTS: $DISCOVERY_SEED_HOSTS"
echo "NODE_ROLES: $NODE_ROLES"
echo "CLUSTER_INITIAL_MASTER_NODES: $CLUSTER_INITIAL_MASTER_NODES"

# install docker
sudo apt-get update
sudo apt-get install -y ca-certificates curl unzip
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker ${USER}

# Set `vm.max_map_count` to at least 262144
sudo sysctl -w vm.max_map_count=262144
# Add vm.max_map_count to sysctl.conf only if it doesn't exist
if ! grep -q "vm.max_map_count=262144" /etc/sysctl.conf; then
    echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
fi

# Prepare a local directory for storing data and logs through a bind-mount
mkdir esdatadir && chmod g+rwx esdatadir && sudo chgrp 0 esdatadir
mkdir eslogsdir && chmod g+rwx eslogsdir && sudo chgrp 0 eslogsdir

# Prepare certificate directory
mkdir certs && chmod g+rwx certs && sudo chgrp 0 certs

# Generate CA (only if it doesn't exist - first node should create and share with others)
if [ ! -f certs/ca.crt ]; then
    echo "Creating Certificate Authority..."
    sudo docker run --rm \
        -v $HOME/certs:/usr/share/elasticsearch/config/certs \
        docker.elastic.co/elasticsearch/elasticsearch:${VERSION} \
        bin/elasticsearch-certutil ca --silent --pem --out /usr/share/elasticsearch/config/certs/ca.zip

    cd $HOME/certs && unzip -o ca.zip && mv ca/* . && rmdir ca && rm ca.zip
    echo "CA created. Copy ca.crt and ca.key to other nodes before running this script on them."
fi

ES_NETWORK_HOST=$(hostname -I | awk '{print $1}')

# Generate node certificate signed by CA
echo "Creating node certificate for ${NODE_NAME}..."
sudo docker run --rm \
    -v $HOME/certs:/usr/share/elasticsearch/config/certs \
    docker.elastic.co/elasticsearch/elasticsearch:${VERSION} \
    bin/elasticsearch-certutil cert --silent --pem \
    --ca-cert /usr/share/elasticsearch/config/certs/ca.crt \
    --ca-key /usr/share/elasticsearch/config/certs/ca.key \
    --dns ${NODE_NAME},localhost \
    --ip ${ES_NETWORK_HOST},127.0.0.1 \
    --out /usr/share/elasticsearch/config/certs/node.zip

cd $HOME/certs && unzip -o node.zip && mv instance/* . && rmdir instance && rm node.zip

# Create a custom elasticsearch.yml
cat << 'EOF' > $HOME/elasticsearch.yml
cluster.name: ${CLUSTER_NAME}
node.roles: ${NODE_ROLES}
node.name: ${NODE_NAME}
network.host: 0.0.0.0
discovery.seed_hosts: ${DISCOVERY_SEED_HOSTS}
cluster.initial_master_nodes: ${CLUSTER_INITIAL_MASTER_NODES}
xpack.security.enabled: true
xpack.security.transport.ssl.enabled: true
xpack.security.transport.ssl.verification_mode: certificate
xpack.security.transport.ssl.key: certs/instance.key
xpack.security.transport.ssl.certificate: certs/instance.crt
xpack.security.transport.ssl.certificate_authorities: certs/ca.crt
EOF

# Run Elasticsearch container
sudo docker run -d \
    --restart always \
    --group-add 0 \
    --volume $HOME/esdatadir:/usr/share/elasticsearch/data \
    --volume $HOME/eslogsdir:/usr/share/elasticsearch/logs \
    --volume $HOME/certs:/usr/share/elasticsearch/config/certs:ro \
    --ulimit nofile=65535:65535 \
    --env "bootstrap.memory_lock=true" --ulimit memlock=-1:-1 \
    --publish-all \
    --network host \
    --volume $HOME/elasticsearch.yml:/usr/share/elasticsearch/config/elasticsearch.yml \
    --env TZ=Asia/Seoul \
    --env CLUSTER_NAME=${CLUSTER_NAME} \
    --env NODE_ROLES=${NODE_ROLES} \
    --env NODE_NAME=${NODE_NAME} \
    --env DISCOVERY_SEED_HOSTS=${DISCOVERY_SEED_HOSTS} \
    --env CLUSTER_INITIAL_MASTER_NODES=${CLUSTER_INITIAL_MASTER_NODES} \
    --env ELASTIC_PASSWORD=elasticpassword \
    --name elasticsearch \
    docker.elastic.co/elasticsearch/elasticsearch:${VERSION}

echo "Waiting for Elasticsearch availability";
until curl -s http://127.0.0.1:9200 | grep -q "missing authentication credentials"; do sleep 5; done;
echo "All done!";

echo "You must now copy ca.crt and ca.key from this node to other nodes before running the join script on them."
echo "CA Certificate (ca.crt):"
cat $HOME/certs/ca.crt
echo ""
echo "CA Private Key (ca.key):"
cat $HOME/certs/ca.key
echo ""
