---
title: How Kubelet Garbage Collection Fails
category: kubernetes
classes: wide
post_no: 3
---
Since I've bootstrapped a K8s cluster and been administrating all by myself, I've encountered many problems and I have had to solve them on my own.
One challenging problem is that even though the garbage collector is enabled by default, sometimes the node won't come back to normal state ever.
I wanted to find out what went wrong and managed to reproduce the problem. [More on this later](#the-worst-case-scenario).

## Kubelet Garbage Collection
Whenever creating or updating a pod to a node, a new image is pulled to the node and it takes up some disk space of that node.
But no matter how many times the pods are udpated, the disk usage does not easily hit the limit.
This is because of **kubelet garbage collection**.

The garbage collector is enabled by default with `--enable-garbage-collector` flag set to True for `kube-controller-manager`.
{: .notice--info}

Kubelet periodically performs garbage collection to ensure long-term operational readiness by cleaning up unused images or containers.

The garbage collector for images uses **LRU** algorithm and considers two variables:
* `HighThresholdPercent`: Default is 85%.
* `LowThresholdPercent`: Default is 80%.

Thresholds are the minimum amount of the resource that should be available on the node.
This post is mainly focused on these variables.

The garbage collector for containers considers three variables:
* `MinAge`: Default is 0 minute.
* `MaxPerPodContainer`: Default is 1.
* `MaxContainers`: Default is -1.

For the detailed explanation of each variable, refer to [this document](https://kubernetes.io/docs/concepts/cluster-administration/kubelet-garbage-collection/).

## How garbage collection works
Basically, kubelet triggers garbage collection when the disk space usage passes `HighThresholdPercent` and attempts to free it to `LowThresholdPercent`.

I'm going to simply demonstrate how it works in different cases.

The worker node for this demonstration has 9.7G storage and the following examples will be tested with the default configuration which would be equivalent to:
```yaml
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
evictionHard:
  imagefs.available: "15%"
```
The thresholds can be adjusted with `--eviction-hard` and `--eviction-minimum-reclaim` kubelet flags. `--image-gc-high-threshold` and `--image-gc-low-threshold` kubelet flags works the same but are scheduled to be deprecated.
{: .notice--info}
And every pod in the examples here runs a single a container.

### The Best Case Scenario
The default configuration for garbage collection may be enough for most cases. Here's an example.

The disk space usage are:
```
Filesystem      Size  Used Avail Use% Mounted on
/dev/root       9.7G  7.9G  1.8G  82% /
```
The pulled images are:
```
IMAGE                         TAG        IMAGE ID         SIZE
myregistry/myapp              v1         4421d5054cbbd    349MB
docker.io/library/mysql       8.0        c0cdc95609f1f    162MB
docker.io/library/postgres    11         f977a7cc785ef    107MB
k8s.gcr.io/kube-proxy         v1.21.1    4359e752b5961    52.5MB
quay.io/coreos/flannel        v0.14.0    8522d622299ca    21.1MB
```
(`myapp` is just a custom image that I built for this test.)

The running containers are:
```
CONTAINER ID     IMAGE            STATE      NAME            POD ID
5ac6ca064945c    4421d5054cbbd    Running    myapp           ac7db35530fdd
96653a1b1fb07    8522d622299ca    Running    kube-flannel    0d2f563c82b8a
a854dc07c3748    4359e752b5961    Running    kube-proxy      33d194bd7679e
```
Note that both `mysql` and `postgres` images are not being used.

As the current disk usage is only 3% less than the default threshold which is 85%, creating a file larger than about 300MB will trigger the garbage collection.
I'm going to create a 500MB file by running `fallocate -l 500M somefile`. `fallocate` is just a command to manipulate file space.

As soon as a new file is created, the disk usage went up to 87% that is 2% over the high threshold:
```
Filesystem      Size  Used Avail Use% Mounted on
/dev/root       9.7G  8.4G  1.3G  87% /
```
A few seconds later, the disk usage went down below 80%:
```
Filesystem      Size  Used Avail Use% Mounted on
/dev/root       9.7G  7.3G  2.4G  76% /
```
The running containers are the same as before:
```
CONTAINER ID     IMAGE            STATE      NAME            POD ID
5ac6ca064945c    4421d5054cbbd    Running    myapp           ac7db35530fdd
96653a1b1fb07    8522d622299ca    Running    kube-flannel    0d2f563c82b8a
a854dc07c3748    4359e752b5961    Running    kube-proxy      33d194bd7679e
```
But the unused images, `mysql` and `postgres` have now been deleted:
```
IMAGE                     TAG        IMAGE ID         SIZE
myregistry/myapp          v1         4421d5054cbbd    349MB
k8s.gcr.io/kube-proxy     v1.21.1    4359e752b5961    52.5MB
quay.io/coreos/flannel    v0.14.0    8522d622299ca    21.1MB
```
Note that `kube-proxy` and `flannel` are the system pods that configured with **tolerations** so they didn't get deleted.

To see what happened, look into the kubelet's log by running `journalctl -xeu kubelet`:
```
... eviction_manager.go:339] "Eviction manager: attempting to reclaim" resourceName="ephemeral-storage"
... container_gc.go:85] "Attempting to delete unused containers"
... image_gc_manager.go:321] "Attempting to delete unused images"
... image_gc_manager.go:375] "Removing image to free bytes" imageID="sha256:c0cd..." size=162019241
... image_gc_manager.go:375] "Removing image to free bytes" imageID="sha256:80d2..." size=299513
... image_gc_manager.go:375] "Removing image to free bytes" imageID="sha256:f977..." size=106563200
... eviction_manager.go:346] "Eviction manager: able to reduce resource pressure without evicting pods." resourceName="ephemeral-storage"
```
We can see that `Eviction manager` is responsible to reclaim resource and reduce resource pressure.
It removed all the unused and unreferenced images but **did not evict any pods**.

Meanwhile, the node got tainted with `node.kubernetes.io/disk-pressure:NoSchedule`:
```
Taints:    node.kubernetes.io/disk-pressure:NoSchedule
Events:
  ...
  Warning  EvictionThresholdMet    5m24s    kubelet    Attempting to reclaim ephemeral-storage
  Normal   NodeHasDiskPressure     5m21s    kubelet    Node test2 status is now: NodeHasDiskPressure
```
If either the garbage collector reduces resource pressure or you manually clean up the disk space, a few minutes later, the taint is deleted.
And if pods are managed by a workload resource such as `Deployment` or `ReplicaSet`, new pods are created to replace evicted pods to meet the number of desired `replicas`.

**Untagged images are also considered as unused images**.
So, for example, if you evenly deploy your pods to certain nodes with `nodeSelector` and `tolerations`, as long as you don't add new pods to existing nodes and always use the same tag for pulling images, then the untagged images are automatically garbage-collected by kubelets after all.

I'd say this is the best case scenario.

### Pod Eviction
What if the resource reaches the high threshold and there's no unused images to delete? **The pods are evicted**.

Pod eviction is carried out with the following variables:
* Eviction signals
* Eviction thresholds
* Monitoring intervals

For the detailed explanation of each variable, refer to [this document](https://kubernetes.io/docs/concepts/scheduling-eviction/node-pressure-eviction/).

A takeaway is that when the garbage collection is triggered, **kubelet firsts attempts to delete container images and then evict the pods**.

Let's see how it's done. Here's a new node:
```sh
# Pods
NAMESPACE    NAME        READY    STATUS     RESTARTS    AGE
default      myapp       1/1      Running    0           5m56s
default      mysql       1/1      Running    0           3m36s
default      postgres    1/1      Running    0           119s

# Disk space usage
Filesystem      Size  Used Avail Use% Mounted on
/dev/root       9.7G  5.2G  4.5G  54% /

# Images
IMAGE                         TAG        IMAGE ID         SIZE
myregistry/myapp              v1         4421d5054cbbd    349MB
docker.io/library/mysql       8          c0cdc95609f1f    162MB
docker.io/library/postgres    11         f977a7cc785ef    107MB
k8s.gcr.io/kube-proxy         v1.21.1    4359e752b5961    52.5MB
k8s.gcr.io/pause              3.2        80d28bedfe5de    300kB
quay.io/coreos/flannel        v0.14.0    8522d622299ca    21.1MB

# Containers
CONTAINER ID     IMAGE            CREATED           STATE      NAME            ATTEMPT    POD ID
b6287d396be2e    f977a7cc785ef    3 minutes ago     Running    postgres        0          ee504005fcb8e
6287c50b4ef68    c0cdc95609f1f    4 minutes ago     Running    mysql           0          29a550e34ed75
3a9206f0513b1    4421d5054cbbd    7 minutes ago     Running    myapp           0          0de10398b97fc
43c95b15f4b95    8522d622299ca    10 minutes ago    Running    kube-flannel    0          40b83edb42eab
556ea3147f7b7    4359e752b5961    10 minutes ago    Running    kube-proxy      0          a62d76fa6ccfb
```
Then I created a 3GB size file to hit the threshold and watched the kubelet log:
```
... eviction_manager.go:339] "Eviction manager: attempting to reclaim" resourceName="ephemeral-storage"
... container_gc.go:85] "Attempting to delete unused containers"
... image_gc_manager.go:321] "Attempting to delete unused images"
... image_gc_manager.go:375] "Removing image to free bytes" imageID="sha256:80d2..." size=299513
... eviction_manager.go:350] "Eviction manager: must evict pod(s) to reclaim" resourceName="ephemeral-storage"
... eviction_manager.go:368] "Eviction manager: pods ranked for eviction" pods=[default/mysql default/postgres default/myapp kube-system/kube-proxy-f94hx kube-system/kube-flannel-ds-z447z]
... eviction_manager.go:575] "Eviction manager: pod is evicted successfully" pod="default/mysql"
... eviction_manager.go:199] "Eviction manager: pods evicted, waiting for pod to be cleaned up" pods=[default/mysql]
... scope.go:111] "RemoveContainer" containerID="6287..."
... scope.go:111] "RemoveContainer" containerID="6287..."
... eviction_manager.go:411] "Eviction manager: pods successfully cleaned up" pods=[default/mysql]
```
While I truncated some lines that are out of the scope of this topic, here's what happened:
1. Eviction manager attempts to reclaim resource.
2. It comes to conclusion that evicting pod(s) is unavoidable.
3. It prioritizes the pods to evict - `[mysql, postgres, myapp, ... (system pods)]`
4. `mysql` is evicted as it's the first priority.

Beside a lost pod, taint is added too.

This unpleasant outcome might be acceptable in certain cases, however, this is something that any cluster developers would encounter if they have not configured their cluster with careful planning.

At this point, I created a large file to hit the `HighThresholdPercent` again:
```
... eviction_manager.go:339] "Eviction manager: attempting to reclaim" resourceName="ephemeral-storage"
... container_gc.go:85] "Attempting to delete unused containers"
... image_gc_manager.go:321] "Attempting to delete unused images"
... image_gc_manager.go:375] "Removing image to free bytes" imageID="sha256:c0cdc95609f1fc1daf2c7cae05ebd6adcf7b5c614b4f424949554a24012e3c09" size=162019241
... eviction_manager.go:346] "Eviction manager: able to reduce resource pressure without evicting pods." resourceName="ephemeral-storage"
```
The garbage collector was triggered again and `mysql` image was deleted as it wasn't being used since 'mysql' pod had been evicted.
The node's disk space usage is now 79%.

I once again created a large file to see what's next to be deleted. This time, `postgres` pod was first evicted and then its image was deleted:
```
... eviction_manager.go:339] "Eviction manager: attempting to reclaim" resourceName="ephemeral-storage"
... container_gc.go:85] "Attempting to delete unused containers"
... image_gc_manager.go:321] "Attempting to delete unused images"
... eviction_manager.go:350] "Eviction manager: must evict pod(s) to reclaim" resourceName="ephemeral-storage"
... eviction_manager.go:368] "Eviction manager: pods ranked for eviction" pods=[default/postgres default/myapp kube-system/kube-proxy-f94hx kube-system/kube-flannel-ds-z447z]
... scope.go:111] "RemoveContainer" containerID="b628..."
... eviction_manager.go:575] "Eviction manager: pod is evicted successfully" pod="default/postgres"
... eviction_manager.go:199] "Eviction manager: pods evicted, waiting for pod to be cleaned up" pods=[default/postgres]
... scope.go:111] "RemoveContainer" containerID="b628..."
... eviction_manager.go:411] "Eviction manager: pods successfully cleaned up" pods=[default/postgres]
... eviction_manager.go:339] "Eviction manager: attempting to reclaim" resourceName="ephemeral-storage"
... container_gc.go:85] "Attempting to delete unused containers"
... image_gc_manager.go:321] "Attempting to delete unused images"
... image_gc_manager.go:375] "Removing image to free bytes" imageID="sha256:f977..." size=106563200
... eviction_manager.go:346] "Eviction manager: able to reduce resource pressure without evicting pods." resourceName="ephemeral-storage"
```
With the concept of kubelet garbage collection mechanism, I could reproduce the problem.

### The Worst Case Scenario
Kubelet garbage collection may fail in some particular cases, and here's one example:
1. Create a `Deployment`, `kube-controller-manager` attempts to create a new pod.
2. The worker node pulls a new image.
3. The disk usage goes beyond the high threshold.
4. The new pods are evicted and the node gets tainted with `NoSchedule`.
5. The newly pulled image is deleted too to meet the low threshold.
6. After a while, the taint is deleted.
7. `kube-controller-manager` reattempts to create a new pod in place of the evicted nodes, **go back to step 2**.

This eventually falls in **an infinite loop**.
As a result, you can see a bunch of bewildered pods.
```
NAMESPACE     NAME         READY   STATUS    RESTARTS   AGE
default       myapp        0/1     Evicted   0          17m
default       myapp        0/1     Evicted   0          9m42s
default       myapp        0/1     Evicted   0          17m
default       myapp        0/1     Evicted   0          22m
default       myapp        0/1     Evicted   0          17m
default       myapp        0/1     Error     1          19m
default       myapp        0/1     Evicted   0          9m44s
default       myapp        0/1     Evicted   0          9m38s
default       myapp        0/1     Evicted   0          17m
default       myapp        0/1     Evicted   0          9m40s
default       myapp        0/1     Pending   0          2m2s
default       myapp        0/1     Evicted   0          2m4s
default       myapp        0/1     Evicted   0          9m41s
default       myapp        0/1     Evicted   0          22m
```
A `Pending` pod indicates that it's waiting for the node to be untainted from `node.kubernetes.io/disk-pressure:NoSchedule`.

While this problem should be better prevented in the first place, here's a few workarounds:
* Dynamically adjust the thresholds.
* Manually clean up the disk space to ensure that the deployment does not hit `HighThresholdPercent`.

## Lessons Learned
Kubernetes provides many options to configure garbage collection features.
These features help to keep clusters more robust and fault-tolerant. With that in mind,
* Assigning pods to nodes requires thorough planning with resource consideration.
* Provide enough resource to avoid any unexpected failure from resource pressure.
* Configure your own garbage collection features rather than relying on default configurations: [Best practices for eviction configuration](https://kubernetes.io/docs/concepts/scheduling-eviction/node-pressure-eviction/#node-pressure-eviction-good-practices)
