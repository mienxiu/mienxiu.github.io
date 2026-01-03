VERSION=8.19.7

# install docker
sudo apt-get update
sudo apt-get install -y ca-certificates curl
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

# Create a custom elasticsearch.yml
cat << 'EOF' > $HOME/elasticsearch.yml
discovery.type: single-node
xpack.security.enabled: true
network.host: 0.0.0.0
EOF

# Run Elasticsearch container
sudo docker run -d \
    --restart always \
    --group-add 0 \
    --volume $HOME/esdatadir:/usr/share/elasticsearch/data \
    --volume $HOME/eslogsdir:/usr/share/elasticsearch/logs \
    --ulimit nofile=65535:65535 \
    --env "bootstrap.memory_lock=true" --ulimit memlock=-1:-1 \
    --publish-all \
    --network host \
    --volume $HOME/elasticsearch.yml:/usr/share/elasticsearch/config/elasticsearch.yml \
    --env TZ=Asia/Seoul \
    --env ELASTIC_PASSWORD=elasticpassword \
    --name elasticsearch \
    docker.elastic.co/elasticsearch/elasticsearch:${VERSION}

echo "Waiting for Elasticsearch availability";
until curl -s http://localhost:9200 | grep -q "missing authentication credentials"; do sleep 5; done;
echo "All done!";

echo "Setting kibana_system password";
until curl -s -X POST -u "elastic:elasticpassword" -H "Content-Type: application/json" http://localhost:9200/_security/user/kibana_system/_password -d "{\"password\":\"kibanapassword\"}" | grep -q "{}"; do sleep 5; done;
echo "All done!";

# Create a custom elasticsearch.yml
cat << 'EOF' > $HOME/kibana.yml
server.host: "0.0.0.0"
server.shutdownTimeout: "5s"
elasticsearch.hosts: ["http://localhost:9200"]
elasticsearch.username: "kibana_system"
elasticsearch.password: "kibanapassword"
xpack.encryptedSavedObjects.encryptionKey: "d7x9s2k5v8y4b3m6n1q0w7e2r5t8y9u1"
server.name: kibana
EOF

# Run Kibana container
sudo docker run -d \
    --restart always \
    --network host \
    --env TZ=Asia/Seoul \
    --volume $HOME/kibana.yml:/usr/share/kibana/config/kibana.yml \
    --name kibana \
    docker.elastic.co/kibana/kibana:${VERSION}
