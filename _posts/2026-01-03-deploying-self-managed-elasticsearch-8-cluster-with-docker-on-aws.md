---
title: "Deploying Self-managed Elasticsearch 8 Cluster with Docker on AWS"
tags: [aws, docker, elasticsearch]
toc: true
toc_sticky: true
post_no: 39
---

Deploying a self-managed Elasticsearch cluster for production is a bit of pain.
It's not just about understanding the core components.
You also have to manually configure availability and security.
To do that, you end up jumping between many pages in the official documentation to piece everything together.

This post is a comprehensive walkthrough of deploying a self-managed Elasticsearch cluster using one of [the supported installation methods](https://www.elastic.co/guide/en/elasticsearch/reference/8.19/install-elasticsearch.html#elasticsearch-deployment-options): Docker.
It also aims to follow production best practices and recommendations.

## Planning Elasticsearch Cluster

By the end of this tutorial, you'll have the following setup in place:

![Production cluster and monitoring node](/assets/posts/39/production_cluster_and_monitoring_node.png)

We will deploy:

- A production cluster with:
    - Three master nodes, as [there should normally be an odd number of master-eligible nodes in a cluster](https://www.elastic.co/guide/en/elasticsearch/reference/8.19/modules-discovery-voting.html#_even_numbers_of_master_eligible_nodes).
    - Three data nodes
- A dedicated monitoring cluster with Kibana and Elastic Agent
- An optional load balancer in front of the production cluster.

### About Node Roles

Here's a quick note on node roles in this setup:

- `master`: Responsible for lightweight cluster-wide actions such as creating or deleting an index, tracking which nodes are part of the cluster, and deciding which shards to allocate to which nodes.
- `data`: Responsible for holding data and performing data related operations such as CRUD, search, and aggregations.

We won't use [coordinating only nodes](https://www.elastic.co/guide/en/elasticsearch/reference/8.19/node-roles-overview.html#coordinating-only-node-role) in this setup, since data nodes can happily serve the same purpose.
For more details on node roles, refer to [Node roles](https://www.elastic.co/guide/en/elasticsearch/reference/8.19/node-roles-overview.html).

### Why Use a Dedicated Monitoring Cluster?

Using a dedicated monitoring cluster is the [recommended configuration](https://www.elastic.co/guide/en/elasticsearch/reference/8.19/monitoring-overview.html) for two key reasons:
- Production outages do not impact access to monitoring data.
- Monitoring workloads are isolated and cannot degrade production cluster performance.

Elastic also recommends using [a separate Kibana instance](https://www.elastic.co/guide/en/kibana/8.19/monitoring-data.html) to view a separate monitoring cluster.

For the sake of operational simplicity, this setup uses a single-node monitoring cluster.
When operating at scale, however, you can also configure a more resilient multi-node monitoring cluster by following this tutorial.

## Infrastructure Setup

You can skip this part if you already have servers ready to host the Elasticsearch cluster.

This tutorial has been demonstrated using the following setup:

- Elastic Stack version: 8.19.7.
- VPN access: A VPN for secure configuration and access to the Elasticsearch cluster, using the CIDR block `10.0.0.0/8`

### Create a Security Group

Log in to the AWS Management Console and navigate to EC2 -> Security Groups -> Create security group.

Create a security group named `my-elasticsearch-node` for the Elasticsearch nodes, and configure the following inbound rules:

| Type       | Protocol | Port range | Source     | Description - optional                                       |
| :---       | :---     | :---       | :---       | :---                                                         |
| SSH        | TCP      | 22         | 10.0.0.0/8 |                                                              |
| Custom TCP | TCP      | 5601       | 10.0.0.0/8 | Kibana                                                       |
| Custom TCP | TCP      | 9200       | 10.0.0.0/8 | HTTP port for REST clients to communicate with Elasticsearch |
| Custom TCP | TCP      | 9300       | 10.0.0.0/8 | Transport port for nodes to communicate with one another     |

### Create a Launch Template

Create a Launch Template to make it easier to add multiple nodes to the cluster.

Go to EC2 → Launch Templates → Create launch template, then configure the following:

- Launch template name: `my-elasticsearch-node`
- Launch template contents:
    - Amazon Machine Image (AMI): `Ubuntu Server 24.04 LTS (HVM), SSD Volume Type`
    - Architecture: `64-bit (Arm)`
- Network settings:
    - Security groups: `my-elasticsearch-node`
- Storage:
    - Size: 100 GiB

This configuration is just an example.
You can adjust the values to match your own requirements.
Just make sure to select the security group created in the previous step, that is `my-elasticsearch-node`.

### Launch Instances

1. Go to EC2 -> Instances -> Launch instance from template and configure the following:
    - Source template: `my-elasticsearch-node`
    - Instance type: (Your choice. For this tutorial, the monitoring node requires at least 8 GiB of RAM.)
    - Key pair (login): Select your key pair.
    - Resource tags:
        - Key: `Name` (for identifying instances)
        - Value: `my-elasticsearch-node`
    - Number of instances: `7` (6 for the production cluster and 1 for the monitoring node)
2. Click `Launch instance`
2. Go to EC2 -> Instances -> Search `my-elasticsearch-node` and update the `Name` tags as follows:
    - `my-elasticsearch-node-master-1`
    - `my-elasticsearch-node-master-2`
    - `my-elasticsearch-node-master-3`
    - `my-elasticsearch-node-data-1`
    - `my-elasticsearch-node-data-2`
    - `my-elasticsearch-node-data-3`
    - `my-elasticsearch-node-monitoring`
3. Retrieve the private IP addresses of all EC2 instances using the AWS CLI:
    ```sh
    aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=my-elasticsearch-node-*" \
        --query "Reservations[].Instances[].[Tags[?Key=='Name'].Value | [0], PrivateIpAddress]" \
        --output text \
        --no-cli-pager
    ```
    Output:
    ```
    my-elasticsearch-node-master-1   10.0.0.1
    my-elasticsearch-node-master-2   10.0.0.2
    my-elasticsearch-node-master-3   10.0.0.3
    my-elasticsearch-node-data-1     10.0.1.1
    my-elasticsearch-node-data-2     10.0.1.2
    my-elasticsearch-node-data-3     10.0.1.3
    my-elasticsearch-node-monitoring        10.0.2.1
    ```
4. Update SSH config file (usually `~/.ssh/config`) to connect to the instances from your local environment:
    ```
    Host my-elasticsearch-node-*
        User ubuntu
        IdentityFile your_key.pem
    Host my-elasticsearch-node-master-1
        HostName 10.0.0.1
    Host my-elasticsearch-node-master-2
        HostName 10.0.0.2
    Host my-elasticsearch-node-master-3
        HostName 10.0.0.3
    Host my-elasticsearch-node-data-1
        HostName 10.0.1.1
    Host my-elasticsearch-node-data-2
        HostName 10.0.1.2
    Host my-elasticsearch-node-data-3
        HostName 10.0.1.3
    Host my-elasticsearch-node-monitoring
        HostName 10.0.2.1
    ```

The IP addresses used in this tutorial are simplified for clarity.
Your IP addresses will differ depending on your VPC and subnet configuration.

## Deploying an Elasticsearch cluster

### Initializing the Cluster with Master Nodes

1. Connect to `my-elasticsearch-node-master-1`:
    ```sh
    ssh my-elasticsearch-node-master-1
    ```
2. Install Docker [7](https://docs.docker.com/engine/install/ubuntu/):
    ```sh
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
    ```
3. [Set `vm.max_map_count` to at least `262144`](https://www.elastic.co/guide/en/elasticsearch/reference/8.19/vm-max-map-count.html):
    ```sh
    sudo sysctl -w vm.max_map_count=262144
    # Add `vm.max_map_count` to `sysctl.conf`
    echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
    ```
    - This is to increase the limits on `mmap` counts to avoid out of memory exceptions:
5. [Prepare local directories for storing data and logs through a bind-mount](https://www.elastic.co/docs/deploy-manage/deploy/self-managed/install-elasticsearch-docker-prod#_configuration_files_must_be_readable_by_the_elasticsearch_user):
    ```sh
    mkdir esdatadir && chmod g+rwx esdatadir && sudo chgrp 0 esdatadir
    mkdir eslogsdir && chmod g+rwx eslogsdir && sudo chgrp 0 eslogsdir
    ```
6. Prepare a certificate directory:
    ```sh
    mkdir certs && chmod g+rwx certs && sudo chgrp 0 certs
    ```
7. Generate CA (only if it doesn't exist - first node should create and share with others):
    ```sh
    sudo apt-get install -y unzip
    sudo docker run --rm \
        -v $HOME/certs:/usr/share/elasticsearch/config/certs \
        docker.elastic.co/elasticsearch/elasticsearch:8.19.7 \
        bin/elasticsearch-certutil ca --silent --pem --out /usr/share/elasticsearch/config/certs/ca.zip
    cd $HOME/certs && unzip -o ca.zip && mv ca/* . && rmdir ca && rm ca.zip
    ```
8. Generate node certificate signed by CA:
    ```sh
    ES_NETWORK_HOST=$(hostname -I | awk '{print $1}')
    sudo docker run --rm \
        -v $HOME/certs:/usr/share/elasticsearch/config/certs \
        docker.elastic.co/elasticsearch/elasticsearch:8.19.7 \
        bin/elasticsearch-certutil cert --silent --pem \
        --ca-cert /usr/share/elasticsearch/config/certs/ca.crt \
        --ca-key /usr/share/elasticsearch/config/certs/ca.key \
        --dns master-1,localhost \
        --ip ${ES_NETWORK_HOST},127.0.0.1 \
        --out /usr/share/elasticsearch/config/certs/node.zip
    cd $HOME/certs && unzip -o node.zip && mv instance/* . && rmdir instance && rm node.zip
    ```
9. Create a custom `elasticsearch.yml` in your home directory with [important settings](https://www.elastic.co/guide/en/elasticsearch/reference/8.19/important-settings.html):
    ```yaml
    cluster.name: my-elasticsearch-cluster
    node.roles: master
    node.name: master-1
    network.host: 0.0.0.0
    discovery.seed_hosts: 10.0.0.1,10.0.0.2,10.0.0.3
    cluster.initial_master_nodes: master-1,master-2,master-3
    xpack.security.enabled: true
    xpack.security.transport.ssl.enabled: true
    xpack.security.transport.ssl.verification_mode: certificate
    xpack.security.transport.ssl.key: certs/instance.key
    xpack.security.transport.ssl.certificate: certs/instance.crt
    xpack.security.transport.ssl.certificate_authorities: certs/ca.crt
    ```
    - The configuration files should contain settings which are node-specific (such as `node.name` and paths), or settings which a node requires in order to be able to join a cluster (such as `cluster.name` and `network.host`), as [most settings can be changed on a running cluster using the Cluster update settings API](https://www.elastic.co/guide/en/elasticsearch/reference/8.19/settings.html).
    - `cluster.name`: A node can only join a cluster when it shares its `cluster.name` with all the other nodes in the cluster. The default name is `elasticsearch`, but you should change it to an appropriate name that describes the purpose of the cluster.
    - `node.roles`: We set the role to `master` to create a [dedicated master-eligible node](https://www.elastic.co/guide/en/elasticsearch/reference/8.19/node-roles-overview.html#dedicated-master-node). This is the most reliable way to avoid overloading the master with other tasks.
    - `node.name`: Elasticsearch uses `node.name` as a human-readable identifier for a particular instance of Elasticsearch. The node name defaults to the hostname of the machine when Elasticsearch starts.
    - `network.host`: Sets the address of this node for both HTTP and transport traffic.
    - `discovery.seed_hosts`: When you want to form a cluster with nodes on other hosts, this setting provides a list of other nodes in the cluster that are master-eligible and likely to be live and contactable to seed the discovery process.
    - `cluster.initial_master_nodes`: A list of node names of master-eligible nodes whose votes are counted in the first election. Do not configure this setting on master-ineligible nodes or nodes joining an existing cluster.
    - `xpack.security.enabled`: Set `true` to install Elastic Agent for stack monitoring.
    - `xpack.security.transport.ssl.enabled`: Set `true` as [transport SSL must be enabled if security is enabled](https://www.elastic.co/guide/en/elasticsearch/reference/8.19/bootstrap-checks-xpack.html#bootstrap-checks-tls).
    - For a full list of configuration options, refer to [Elasticsearch configuration reference](https://www.elastic.co/docs/reference/elasticsearch/configuration-reference).
10. Run Elasticsearch container:
    ```sh
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
        --env ELASTIC_PASSWORD=elasticpassword \
        --name elasticsearch \
        docker.elastic.co/elasticsearch/elasticsearch:8.19.7
    ```
    - `--restart always`: to automatically restarts the container if it stops.
    - [`--group-add 0`](https://www.elastic.co/docs/deploy-manage/deploy/self-managed/install-elasticsearch-docker-prod#_configuration_files_must_be_readable_by_the_elasticsearch_user): to ensure that the user under which Elasticsearch is running has file permissions to `esdatadir`.
    - `--volume $HOME/...`: to persist data, logs, and certificates across container restarts.
    - [`--ulimit nofile=65535:65535`](https://www.elastic.co/docs/deploy-manage/deploy/self-managed/install-elasticsearch-docker-prod#_increase_ulimits_for_nofile_and_nproc): to increase the file descriptor limit required for production workloads.
    - `--publish-all`: to randomize published ports, which is [recommended for production clusters](https://www.elastic.co/docs/deploy-manage/deploy/self-managed/install-elasticsearch-docker-prod#_randomize_published_ports).
    - `--network host`: to [optimize performance](https://docs.docker.com/engine/network/drivers/host/). The `host` network only works on Linux hosts and `--publish-all` option is ignored when it is enabled.
    - `--volume $HOME/...`: to bind-mount custom `elasticsearch.yml`, [the preferred approach for production setups](https://www.elastic.co/docs/deploy-manage/deploy/self-managed/install-elasticsearch-docker-configure).
    - [`--env "bootstrap.memory_lock=true" --ulimit memlock=-1:-1`](https://www.elastic.co/docs/deploy-manage/deploy/self-managed/install-elasticsearch-docker-prod#_disable_swapping): to disable swapping for performance and node stability.
    - `--env TZ=Asia/Seoul`: Sets the container timezone (adjust as needed).
    - `ELASTIC_PASSWORD`: Replace it with a password for your production Elasticsearch cluster.
    - Some setups use `ES_JAVA_OPTS`,  but this is [not recommended for production](https://www.elastic.co/guide/en/elasticsearch/reference/8.19/advanced-configuration.html). [Use the default Elasticsearch memory settings instead](https://www.elastic.co/docs/deploy-manage/deploy/self-managed/install-elasticsearch-docker-prod#docker-set-heap-size).

At this stage, the cluster isn't fully formed yet, so you'll see a warning in the container logs like:
```log
master not discovered yet, this node has not previously joined a bootstrapped cluster, and this node must discover master-eligible nodes [master-1, master-2, master-3] to bootstrap a cluster: ...
```

You won't see this error if you're using only a single master-eligible node.
{: .notice--info}

This happens because we configured three initial master nodes—`master-1`, `master-2`, and `master-3`—but only `master-1` has joined the cluster so far. Elasticsearch is still waiting for the remaining master-eligible nodes before it can complete the bootstrap process.
To finish forming the cluster, you need to bring up and join the other master-eligible nodes (`master-2` and `master-3`) as well.

#### Joining Master Nodes to the Cluster

1. Copy `certs/ca.crt` and `certs/ca.key` files to your local machine or another secure location. These will be reused when setting up the remaining nodes.
2. Connect to `my-elasticsearch-node-master-2`:
    ```sh
    ssh my-elasticsearch-node-master-2
    ```
3. Copy `ca.crt` and `ca.key` into the home directory on this node.
4. Install docker, set `vm.max_map_count`, prepare local directories, and generate node certificate:
    ```sh
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
    echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf

    # Prepare a local directory for storing data and logs through a bind-mount
    mkdir esdatadir && chmod g+rwx esdatadir && sudo chgrp 0 esdatadir
    mkdir eslogsdir && chmod g+rwx eslogsdir && sudo chgrp 0 eslogsdir

    # Prepare certificate directory
    mkdir certs && chmod g+rwx certs && sudo chgrp 0 certs

    mv ca.crt certs/
    mv ca.key certs/

    # Generate node certificate signed by CA
    ES_NETWORK_HOST=$(hostname -I | awk '{print $1}')
    sudo docker run --rm \
        -v $HOME/certs:/usr/share/elasticsearch/config/certs \
        docker.elastic.co/elasticsearch/elasticsearch:8.19.7 \
        bin/elasticsearch-certutil cert --silent --pem \
        --ca-cert /usr/share/elasticsearch/config/certs/ca.crt \
        --ca-key /usr/share/elasticsearch/config/certs/ca.key \
        --dns master-2,localhost \
        --ip ${ES_NETWORK_HOST},127.0.0.1 \
        --out /usr/share/elasticsearch/config/certs/node.zip

    cd $HOME/certs && unzip -o node.zip && mv instance/* . && rmdir instance && rm node.zip
    ```
5. Create a custom `elasticsearch.yml` in your home directory:
    ```yaml
    cluster.name: my-elasticsearch-cluster
    node.roles: master
    node.name: master-2
    network.host: 0.0.0.0
    discovery.seed_hosts: 10.0.0.1,10.0.0.2,10.0.0.3
    xpack.security.enabled: true
    xpack.security.transport.ssl.enabled: true
    xpack.security.transport.ssl.verification_mode: certificate
    xpack.security.transport.ssl.key: certs/instance.key
    xpack.security.transport.ssl.certificate: certs/instance.crt
    xpack.security.transport.ssl.certificate_authorities: certs/ca.crt
    ```
    - `node.name`: now set to `master-2`
6. Run Elasticsearch container:
    ```sh
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
        --env ELASTIC_PASSWORD=elasticpassword \
        --name elasticsearch \
        docker.elastic.co/elasticsearch/elasticsearch:8.19.7
    ```
    - `--env TZ=Asia/Seoul`: Sets the container timezone (adjust as needed).
    - `ELASTIC_PASSWORD`: Replace it with a password for your production Elasticsearch cluster.
7. Connect to `my-elasticsearch-node-master-3` and repeat steps 13-16, making sure to set `node.name` to `master-3` in the `elasticsearch.yml` file.
8. Verify that the master nodes have formed a cluster:
    ```sh
    curl -u elastic:elasticpassword "http://localhost:9200/_cat/nodes?v&s=name"
    ```
    Output:
    ```
    ip             heap.percent ram.percent cpu load_1m load_5m load_15m node.role master name
    10.0.0.1                 40          98   0    0.00    0.05     0.07 m         *      master-1
    10.0.0.2                 26          98   0    0.07    0.17     0.10 m         -      master-2
    10.0.0.3                 24          98   0    0.39    0.31     0.13 m         -      master-3
    ```

Since there are no data nodes to host shards yet, the cluster health will show up as `red`:
```sh
curl http://elastic:elasticpassword@localhost:9200/_cluster/health
```
Output:
```json
{
    "cluster_name": "my-elasticsearch-cluster",
    "status": "red",
    "timed_out": false,
    "number_of_nodes": 3,
    "number_of_data_nodes": 0,
    "active_primary_shards": 0,
    "active_shards": 0,
    "relocating_shards": 0,
    "initializing_shards": 0,
    "unassigned_shards": 2,
    "unassigned_primary_shards": 2,
    "delayed_unassigned_shards": 0,
    "number_of_pending_tasks": 0,
    "number_of_in_flight_fetch": 0,
    "task_max_waiting_in_queue_millis": 0,
    "active_shards_percent_as_number": 0.0
}
```

This is expected.
Once the data nodes join the cluster, Elasticsearch will be able to allocate shards and the status should move to `yellow` or `green` depending on replica allocation.

### Joining Data Nodes to the Cluster

The process for adding a data node is very similar to adding a master node, with a few small changes in the `elasticsearch.yml` configuration.

1. Connect to `my-elasticsearch-node-data-1`:
    ```sh
    ssh my-elasticsearch-node-data-1
    ```
2. Copy `ca.crt` and `ca.key` into the home directory on this node.
3. Install docker, set `vm.max_map_count`, prepare local directories, and generate node certificate:
    ```sh
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
    echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf

    # Prepare a local directory for storing data and logs through a bind-mount
    mkdir esdatadir && chmod g+rwx esdatadir && sudo chgrp 0 esdatadir
    mkdir eslogsdir && chmod g+rwx eslogsdir && sudo chgrp 0 eslogsdir

    # Prepare certificate directory
    mkdir certs && chmod g+rwx certs && sudo chgrp 0 certs

    mv ca.crt certs/
    mv ca.key certs/

    # Generate node certificate signed by CA
    ES_NETWORK_HOST=$(hostname -I | awk '{print $1}')
    sudo docker run --rm \
        -v $HOME/certs:/usr/share/elasticsearch/config/certs \
        docker.elastic.co/elasticsearch/elasticsearch:8.19.7 \
        bin/elasticsearch-certutil cert --silent --pem \
        --ca-cert /usr/share/elasticsearch/config/certs/ca.crt \
        --ca-key /usr/share/elasticsearch/config/certs/ca.key \
        --dns data-1,localhost \
        --ip ${ES_NETWORK_HOST},127.0.0.1 \
        --out /usr/share/elasticsearch/config/certs/node.zip

    cd $HOME/certs && unzip -o node.zip && mv instance/* . && rmdir instance && rm node.zip
    ```
4. Create a custom `elasticsearch.yml` in your home directory:
    ```yaml
    cluster.name: my-elasticsearch-cluster
    node.roles: data
    node.name: data-1
    network.host: 0.0.0.0
    discovery.seed_hosts: 10.0.0.1,10.0.0.2,10.0.0.3
    xpack.security.enabled: true
    xpack.security.transport.ssl.enabled: true
    xpack.security.transport.ssl.verification_mode: certificate
    xpack.security.transport.ssl.key: certs/instance.key
    xpack.security.transport.ssl.certificate: certs/instance.crt
    xpack.security.transport.ssl.certificate_authorities: certs/ca.crt
    ```
    - `node.roles`: now set to `data`.
    - `node.name`: now set to `data-1`
5. Run Elasticsearch container:
    ```sh
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
        --env ELASTIC_PASSWORD=elasticpassword \
        --name elasticsearch \
        docker.elastic.co/elasticsearch/elasticsearch:8.19.7
    ```
    - `--env TZ=Asia/Seoul`: Sets the container timezone (adjust as needed).
    - `ELASTIC_PASSWORD`: Replace it with a password for your production Elasticsearch cluster.
    - Joining the cluster can take a little time. Once a data node joins the cluster, the health status transitions from `red` to `green`:
        ```json
        {
            "cluster_name": "my-elasticsearch-cluster",
            "status": "green",
            "timed_out": false,
            "number_of_nodes": 4,
            "number_of_data_nodes": 1,
            "active_primary_shards": 3,
            "active_shards": 3,
            "relocating_shards": 0,
            "initializing_shards": 0,
            "unassigned_shards": 0,
            "unassigned_primary_shards": 0,
            "delayed_unassigned_shards": 0,
            "number_of_pending_tasks": 0,
            "number_of_in_flight_fetch": 0,
            "task_max_waiting_in_queue_millis": 0,
            "active_shards_percent_as_number": 100.0
        }
        ```
6. Repeat steps 1-5 for `my-elasticsearch-node-data-2` and `my-elasticsearch-node-data-3`, updating `node.name` to match each node.
7. From any node, verify that all nodes have successfully joined the cluster:
    ```sh
    curl -u elastic:elasticpassword "http://localhost:9200/_cat/nodes?v&s=name"
    ```
    Output:
    ```
    ip             heap.percent ram.percent cpu load_1m load_5m load_15m node.role master name
    10.0.1.1                 41          97   0    0.00    0.06     0.08 d         -      data-1
    10.0.1.2                 36          98   0    0.22    0.33     0.16 d         -      data-2
    10.0.1.3                 33          98   0    0.14    0.24     0.11 d         -      data-3
    10.0.0.1                  8          98   0    0.00    0.00     0.00 m         *      master-1
    10.0.0.2                 44          97   0    0.00    0.00     0.00 m         -      master-2
    10.0.0.3                 42          97   0    0.00    0.00     0.00 m         -      master-3
    ```

At this point, all master and data nodes should be present, and the cluster should be fully formed and healthy.

### Updating custom `elasticsearch.yml`

Updating a custom `elasticsearch.yml` in a Docker-based setup is straightforward:
1. Make your changes in `elasticsearch.yml` in your home directory.
2. Restart the container:
    ```sh
    docker restart elasticsearch.yml
    ```

Be aware that restarting the container will cause downtime.
For production clusters, plan configuration changes carefully and apply them during a maintenance window, especially if the setting you're changing affects cluster behavior or node roles.

## Stack Monitoring

Stack Monitoring lets you collect logs and metrics from Elastic products, most importantly your production Elasticsearch nodes, and also things like Kibana.
At a minimum, you need monitoring data for the production Elasticsearch cluster.
[Once that's in place, Kibana can show monitoring data for other products in the Stack Monitoring page](https://www.elastic.co/guide/en/kibana/8.19/monitoring-data.html).

The legacy Elasticsearch Monitoring plugin approach (enabled via `xpack.monitoring.collection.enabled`) was deprecated in 7.16.
These days, Elastic recommends using Elastic Agent or Metricbeat to collect and ship monitoring data to a monitoring cluster.
{: .notice--info}

Next, we'll deploy a single-node monitoring cluster and use Elastic Agent to monitor our production cluster.

### Deploying Elasticsearch

1. Connect to `my-elasticsearch-monitoring`
    ```sh
    ssh my-elasticsearch-node-monitoring
    ```
2. Install docker, set `vm.max_map_count`, and prepare local directories for data persistency:
    ```sh
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
    echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf

    # Prepare a local directory for storing data and logs through a bind-mount
    mkdir esdatadir && chmod g+rwx esdatadir && sudo chgrp 0 esdatadir
    mkdir eslogsdir && chmod g+rwx eslogsdir && sudo chgrp 0 eslogsdir
    ```
3. Create a custom `elasticsearch.yml` in your home directory:
    ```yaml
    discovery.type: single-node
    xpack.security.enabled: true
    network.host: 0.0.0.0
    ```
4. Run Elasticsearch container:
    ```sh
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
        docker.elastic.co/elasticsearch/elasticsearch:8.19.7
    ```
    - `--env TZ=Asia/Seoul`: Sets the container timezone (adjust as needed).
    - `ELASTIC_PASSWORD`: Replace it with a password for your monitoring Elasticsearch node.
5. Verify:
    ```sh
    curl -u elastic:elasticpassword "http://localhost:9200/_cat/nodes?v&s=name"
    ```
    Output
    ```
    ip             heap.percent ram.percent cpu load_1m load_5m load_15m node.role   master name
    10.0.2.1                 22          97  44    0.92    0.31     0.11 cdfhilmrstw *      ip-10-0-2-1
    ```
    - Note that the node is assigned [every role as it must do everything](https://www.elastic.co/guide/en/elasticsearch/reference/8.19/high-availability-cluster-small-clusters.html#high-availability-cluster-design-one-node).

### Deploying Kibana

1. Set a password for `kibana_system` user:
    ```sh
    curl -s -X POST -u "elastic:elasticpassword" -H "Content-Type: application/json" http://localhost:9200/_security/user/kibana_system/_password -d "{\"password\":\"kibanapassword\"}"
    ```
    - `kibanapassword`: Replace it with your password.
2. Create custom `kibana.yml`:
    ```yaml
    server.host: "0.0.0.0"
    server.shutdownTimeout: "5s"
    elasticsearch.hosts: ["http://localhost:9200"]
    elasticsearch.username: "kibana_system"
    elasticsearch.password: "kibanapassword"
    xpack.encryptedSavedObjects.encryptionKey: "d7x9s2k5v8y4b3m6n1q0w7e2r5t8y9u1" # Replace this with your own key. You can generate one using `./kibana-encryption-keys generate`.
    server.name: kibana
    ```
    - `elasticsearch.hosts`: Use `http://localhost:9200` since Elasticsearch is running on the same machine.
3. Run Kibana container:
    ```sh
    sudo docker run -d \
        --restart always \
        --network host \
        --env TZ=Asia/Seoul \
        --volume $HOME/kibana.yml:/usr/share/kibana/config/kibana.yml \
        --name kibana \
        docker.elastic.co/kibana/kibana:8.19.7
    ```
4. Verify the deployment by opening Kibana (`http://10.0.2.1:5601` in this case) in your browser:

    ![Kibana login page](/assets/posts/39/kibana_login_page.png)

### Installing Elasticsearch Integration

1. [Create a user on the production cluster that has the `remote_monitoring_collector` built-in role](https://www.elastic.co/guide/en/elasticsearch/reference/8.19/configuring-elastic-agent.html#_prerequisites_11).
    ```sh
    curl -X POST "http://localhost:9200/_security/user/elastic_agent?pretty" \
        -u elastic:elasticpassword \
        -H "Content-Type: application/json" \
        -d '{
            "password" : "changeme",
            "roles" : [ "remote_monitoring_collector"]
        }'
    ```
    - `elastic_agent`: This is just a username for Elastic Agent. Feel free to use a different one.
    - `password`: Choose a secure password for this user.
2. Go to Kibana in your browser.
3. Login with:
    - Username: `elastic`
    - Password: Your `ELASTIC_PASSWORD`
4. Click `Add integrations`.
5. In the query bar, search for and select the `Elasticsearch` integration for Elastic Agent:

    ![Integrations](/assets/posts/39/integrations.png)

6. Click `Add Elasticsearch`.
7. Configure the integration name and optionally add a description. Make sure you configure all required settings:
    - Go to Metrics (Stack monitoring) -> Change defaults:
        - Hosts: Specify data nodes, or [a load balancer that routes to master-ineligible nodes](https://www.elastic.co/guide/en/elasticsearch/reference/8.19/configuring-elastic-agent.html#_add_elasticsearch_monitoring_data):
            - `http://10.0.1.1:9200`
            - `http://10.0.1.2:9200`
            - `http://10.0.1.3:9200`
        - Advanced options:
            - Username: `elastic_agent`
            - Password: `changeme`
            - Scope: `cluster` (If set to `node`, Elastic Agent only collects metrics from the specified hosts.)
6. Click `Save and continue`. This may take a minute or two. When it finishes, an agent policy with the Elasticsearch monitoring integration will be created.
7. Click `Add Elastic Agent later`.

### Deploying Elastic Agent

There are two ways to run Elastic Agent:

- Fleet-managed: Elastic Agent is centrally managed through Fleet in Kibana.
- Standalone: Elastic Agent is configured locally using YAML files.

In this tutorial, we'll use the standalone approach to avoid the extra dependency on Fleet.

1. Go to Kibana for the monitoring cluster in your browser.
2. Go to `Fleet` -> `Agents` -> `Add Agent` -> `Run standalone`
3. Select `Agent Policy 1`.
4. Click `Create API key` to generate an API key for Elastic Agent.
    - By default, the output host is set to `http://localhost:9200`, which is where Elastic Agent will send monitoring data.
5. Click `Copy to clipboard` or `Download policy`
6. Connect to monitoring node:
    ```sh
    ssh my-elasticsearch-node-monitoring
    ```
7. Create an `elastic-agent.yml` file and paste the configuration from the clipboard, or copy the downloaded policy from step 5.
8. Run Elastic Agent container:
    ```sh
    docker run \
        -d \
        --restart always \
        --name elastic-agent \
        --network host \
        --user root \
        --volume $HOME/elastic-agent.yml:/usr/share/elastic-agent/elastic-agent.yml \
        docker.elastic.co/beats/elastic-agent:8.19.7
    ```
    - `--network host`: Allows the agent to connect to Elasticsearch via `http://localhost:9200`.
    - Startup usually takes a few seconds.
9. Go to Kibana for the monitoring cluster in your browser.
10. Click `Stack Monitoring` in the left menu, then select `Remind me later` when prompted.

Once everything is set up successfully, Elastic Agent will start collecting and shipping monitoring data from the production Elasticsearch cluster.
With this data in place, Kibana can display monitoring information for Elasticsearch and other Elastic Stack components:

![Stack Monitoring](/assets/posts/39/stack_monitoring.png)

Click `Nodes` for node monitoring:

![Nodes monitoring](/assets/posts/39/nodes_monitoring.png)

Click specific node for detailed metrics:

![Node monitoring](/assets/posts/39/node_monitoring.png)

So far, Elastic Agent runs on the same node as the monitoring Elasticsearch and Kibana, but it can be deployed on any other node as well.
To do that, update the `Outputs` in the agent policy:

1. Go to `Fleet` -> `Settings` -> `Outputs` -> `Add output`
2. Set the monitoring Elasticsearch host to `http://10.0.2.1:9200`.

Updating the output will result in an `elastic-agent.yml` similar to the following:
```yaml
...
outputs:
  default:
    type: elasticsearch
    hosts:
      - http://10.0.2.1:9200
...
```

When new nodes are added to the production cluster, Elastic Agent will automatically start collecting their metrics without requiring any output changes.

In practice, however, it's advisable to place [a load-balancing proxy in front of master-ineligible nodes](https://www.elastic.co/guide/en/elasticsearch/reference/8.19/configuring-elastic-agent.html#_add_elasticsearch_monitoring_data).
This distributes monitoring traffic evenly and prevents overloading master nodes, which [must remain stable](https://www.elastic.co/guide/en/elasticsearch/reference/8.19/node-roles-overview.html#master-node-role).

## Creating a Load Balancer

Below is an example of setting up a load balancer with a TLS listener that forwards traffic only to master-ineligible data nodes in your Elasticsearch cluster:
1. Create a target group:
    - Target type: `Instances`
    - Target group name: `my-elasticsearch`
    - Protocol: `TCP`
    - Port: `9200`
    - Health check protocol: `TCP`
    - Health check port: `Trafic port` (9200 in this case)
    - Targets:
        - `my-elasticsearch-node-data-1`
        - `my-elasticsearch-node-data-2`
        - `my-elasticsearch-node-data-3`
2. Create a networkd load balancer. This is a good choice for Elasticsearch because it has low latency and works well with TCP/TLS passthrough:
    - Load balancer name: `my-elasticsearch`
    - Scheme: `Internal` (recommended for private networks)
    - VPC: (Use the same VPC as your Elasticsearch nodes)
    - Security group: (Allow inbound traffic on TCP 443 from trusted sources)
    - Listeners:
        - Protocol: `TLS`
        - Port: `443`
        - Target group: `my-elasticsearch`
        - Default SSL/TLS server certificate: (Your ACM or imported certificate)
    - With this setup, clients connect over HTTPS on port 443, and the NLB forwards traffic directly to port 9200 on the data nodes.
3. Create a DNS record (for example, in Route 53):
    - Use the hostname covered by your TLS certificate
    - Route to the network load balancer

After this, clients can reach Elasticsearch using a simple HTTPS URL.
You can use this URL as the Elasticsearch hosts for Elastic Agent instead of listing the IP addresses of individual data nodes.
When you add or remove data nodes, the only thing you need to update is the target group.
The client configuration stays the same, and the load balancer automatically handles routing traffic to the available data nodes.

## Shell Scripts for Easier Deployment

Often, we need to scale out the cluster to handle more traffic.
Manually repeating every step in this guide is daunting.

To make life easier, here are complete scripts you can use:

- For initializing a fresh Elasticsearch cluster: [`init_cluster.sh`](/assets/posts/39/init_cluster.sh)
- For joining nodes to an exisiting Elasticsearch cluster: [`join_cluster.sh`](/assets/posts/39/join_cluster.sh)
- For initializing a single-node monitoring cluster: [`init_monitoring_stack.sh`](/assets/posts/39/init_monitoring_stack.sh)

Before running them, make sure you update these values to match your environment:

- `VERSION`
- `Timezone`
- `ELASTIC_PASSWORD`
- `ca.crt` and `ca.key` files (refer to `REPLACE IT` in the `join_cluster.sh` file)

## Conclusion

Running a self-managed cluster means you own everything.
You operate it, you watch it, and you fix it when it breaks.
Scaling, monitoring, and compliance are all on you.
That work costs time and money, and there's no way around that.

The upside is what you don't have.
No extra control planes, no operators, no Kubernetes glue code deciding things on your behalf.
Systems like ECK (Elastic Cloud on Kubernetes) add layers, and layers add complexity.
Complexity creates edge cases, and edge cases could fail in unexpected ways.

If your environment can handle the operational load and you care about clarity, predictability, and knowing exactly how your system behaves, a self-managed cluster can be a good choice.
