# Install Kubernetes


[Kubernetes](https://kubernetes.io/docs/tutorials/kubernetes-basics/) (k8s) allows you to deploy containerized applications while letting you abstract the underlying infrastructure. Talking about `Kubernetes`  is like talking about `Linux`: you need to pick a distribution (Rancher, Azure AKS, OpenShift, K3s, Amazon EKS, etc).


!!! danger "Use anything that is readily available"

    Running a Kubernetes cluster is a non trivial task, involving system, storage and network administration. If you have any possibility to use an existing cluster, either provided by your institute or even commercial, by all mean, do it.


!!! warning "Shared storage is hard"

    It is notably more difficult to manage a shared storage in a kubernetes cluster than it is to run stateless compute tasks. This is why if you have no experience you should run your databases and your object store outside of the cluster.

!!! tip "Your cluster is disposable"

    Think of your kubernes cluster as something that you should be able to recreate quickly on a whim.

## K3S

[K3s](https://docs.k3s.io/) is a lightweight Kubernetes cluster easy to deploy. We are going to cover its installation such that `DiracX` can be deployed on it.

### Requirements

You need to have a certain number of machine (VM or bare metal) accessible via `ssh`.  The [upstream documentation](https://docs.k3s.io/installation/requirements) specifies requirements for these servers.

Smaller VO should run on a single machine. Larger VO can expands on how many nodes they want, however you will run into challenges with DNS, certificates, etc (see below).



### Installation

We will perform the installation using [k3sup](https://github.com/alexellis/k3sup), a utility to deploy k3s easily, and illustrate it for a single node.

You can run the following on any UI you use to manage your cluster.

```bash
curl -sLS https://get.k3sup.dev | sh

# install k3s on main server

export SERVER_IP=xxx.xxx.xxx.xxx
export USER=root

k3sup install --ip $SERVER_IP --user $USER --k3s-extra-args '--flannel-backend=wireguard-native'

```
This will create a `kubeconfig` in your current directory. You want to keep that config file in a safe place.

### Test your cluster

In case you do not have it already, install `kubectl`

```bash
# kubectl
curl -LO https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl
```

You can then test your configuration

```bash
export KUBECONFIG=`pwd`/kubeconfig
kubectl config use-context default
kubectl get node

# k3s comes with pods already deployed
kubectl get pods -A
```


### Deploy Kubernetes Dashboard (optional but useful)

Installing the [Kubernetes dashboard](https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard/) requires `helm`. If you haven't installed it

```bash
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
```

Now install the dashboard

```bash
# Add kubernetes-dashboard repository
helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/

# Deploy a Helm Release named "kubernetes-dashboard" using the kubernetes-dashboard chart
helm upgrade --install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard --create-namespace --namespace kubernetes-dashboard
```

```bash
# generate token
kubectl -n kubernetes-dashboard create token admin-user
```

```bash
# launch web server
kubectl -n kubernetes-dashboard port-forward svc/kubernetes-dashboard-kong-proxy 8443:443
```

Using your browser, visit the dashboard ([http://localhost:8443/](http://localhost:8443/)) and login using the token created above.

### Get Traefik Dashboard

Traefik comes out of the box with k3s. In order to access Traefik Dashboard from your laptop:

```bash
kubectl --namespace kube-system port-forward deployments/traefik 9000:9000 &
```

In a web browser, go to : [http://localhost:9000/dashboard/](http://localhost:9000/dashboard/)

### Get a certificate

The certificates are managed by [cert-manager](https://cert-manager.io/). If your institute certificate issuer does not support the `ACME` protocol, we recommend using [Let's Encrypt](https://letsencrypt.org/).

The upstream documentation of [traefik](https://doc.traefik.io/traefik/https/acme/), the default `ingress` of k3s, explains how to do that. See the [DiracX installation instruction](./installing.md#ingress-configuration) for an example.


## Running on more than one node

### Growing up the cluster

We defer you to the [k3sup](https://github.com/alexellis/k3sup?tab=readme-ov-file#-setup-a-kubernetes-server-with-k3sup) documentation for detailed instruction, but the gist of it is that you are just expanding your existing cluster by adding agent to it.

```bash

# join agent server

export AGENT_IP=xxx.xxx.xxx.xxx
export USER=root

k3sup join --ip $AGENT_IP --server-ip $SERVER_IP --user $USER
```

### New challenges

Having multiple machines means that you don't have a single DNS entry point, and that your infrastructure needs to support load balancer. This is way out of scope, and very infrastructure dependent. See [this issue](https://github.com/DIRACGrid/diracx-charts/issues/107) for pointers.


## Shared storage: Longhorn

!!! danger "Do this at your own risk"

    As stated before, we recommend you do not deploy storage on your cluster. The instructions below were tested as exercise, but no guarantee whatsoever are given. The version used here is maybe not even supported anymore

In order to have a shared storage across your cluster, you can use [Longhorn](https://longhorn.io/)


Deploy longhorn in your cluster:

```bash
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.5.3/deploy/prerequisite/longhorn-iscsi-installation.yaml

kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.5.3/deploy/prerequisite/longhorn-nfs-installation.yaml

```

### Single or two nodes cluster

```bash
wget https://raw.githubusercontent.com/longhorn/longhorn/v1.5.3/deploy/longhorn.yaml
```

edit `longhorn.yaml` and
- modify `numberOfReplicas: <number of nodes>` (i.e 1 or 2)
- OPTIONAL: look for the `longhorn-default-setting` section. At this point, depending on the configuration you applied on your (Virtual) machine(s), modify its `data` part as following:
```
  data:
  default-setting.yaml: |-
    default-data-path: /mnt/longhorn  # reflect what is the config you'd like to apply. Without, the default is /var/lib/longhorn
```

```bash
kubectl apply -f longhorn.yaml
```

### Starting from 3 nodes

```bash
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.5.3/deploy/longhorn.yaml
```

### Check environnment

```bash
curl -sSfL https://raw.githubusercontent.com/longhorn/longhorn/v1.5.3/scripts/environment_check.sh | bash

```

On master Node:
```bash
cp /var/lib/rancher/k3s/server/manifests/local-storage.yaml /var/lib/rancher/k3s/server/manifests/custom-local-storage.yaml

sed -i -e "s/storageclass.kubernetes.io\/is-default-class: \"true\"/storageclass.kubernetes.io\/is-default-class: \"false\"/g" /var/lib/rancher/k3s/server/manifests/custom-local-storage.yaml
```


Now, on your client, start the longhorn UI with
```bash
kubectl port-forward -n longhorn-system svc/longhorn-frontend 8080:80 &
```

and then visualize it by visiting http://localhost:8080



## Uninstall k3s on main server
https://docs.k3s.io/installation/uninstall

On master node:
```bash
/usr/local/bin/k3s-uninstall.sh
```

On agent nodes
```bash
/usr/local/bin/k3s-agent-uninstall.sh
```


## Troubleshoot

### `Nameserver limits were exceeded`

This is due to `glibc` limitation on the number of entry in `/etc/resolv.conf`. Do not have more than 3.


### `Longorn-ui` failure

`longhorn-ui` fails with

```bash
host not found in upstream "longhorn-backend" in /etc/nginx/nginx.conf:32
nginx: [emerg] host not found in upstream "longhorn-backend" in /etc/nginx/nginx.conf:32
```

Use ``wireguard`` instead of ``flannel``
