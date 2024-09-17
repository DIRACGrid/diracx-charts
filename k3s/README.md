# diracx-k3s

Deploy diracx on a k3s cluster remotely


## Resources

kubectl: https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/

helm: https://helm.sh/docs/intro/install/

k3sup: https://github.com/alexellis/k3sup
k3s: https://docs.k3s.io/

loghorn: https://longhorn.io/

diracx: https://github.com/DIRACGrid/diracx
diracx-charts: https://github.com/DIRACGrid/diracx-charts


## Requirements

- Accessible cluster machines via ssh

- kubectl (client for managing kubernetes cluster)

- helm (tool for managing kubernetes deployments via charts)

- Clone this repo on your laptop

- Ports
    - 6443 (kubernetes)
    - 8001 (kubernetes dashboard)
    - 8080 (longhorn dashboard)
    - 9000 (traefik dashboard)

Check that you follow the recommendations https://docs.k3s.io/installation/requirements

Install kubectl (on laptop)
---------------------------

```bash
# kubectl
curl -LO https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl

# kubectl checksum file
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"

# validate binary
echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check

# install
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

```

Install helm (on laptop)
---------------------------

```bash
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
chmod 700 get_helm.sh
./get_helm.sh
```

Enable completion (optional but useful)
---------------------------------------

```bash
# kubectl
source <(kubectl completion bash)

# helm
source <(helm completion bash)
```


## Deploy K3S remotely (using k3sup)

Install k3sup (on laptop)
-------------------------

```bash
curl -sLS https://get.k3sup.dev | sh
sudo install k3sup /usr/local/bin/
```

Assuming your cluster is composed of 2 machines (main server and agent server)

```bash
# install k3s on main server

export SERVER_IP=xxx.xxx.xxx.xxx
export USER=root

k3sup install --ip $SERVER_IP --user $USER --k3s-extra-args '--flannel-backend=wireguard-native'


# join agent server

export AGENT_IP=xxx.xxx.xxx.xxx

k3sup join --ip $AGENT_IP --server-ip $SERVER_IP --user $USER
```


Test your cluster
-----------------

```bash
export KUBECONFIG=`pwd`/kubeconfig
kubectl config use-context default
kubectl get node

# k3s comes with pods already deployed
kubectl get pods -A
```

## Deploy Kubernetes Dashboard (optional but useful)

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml

kubectl apply -f ./manifest/dashboard/cluster-role.yaml
kubectl apply -f ./manifest/dashboard/secret.yaml
kubectl apply -f ./manifest/dashboard/service-account.yaml
```

```bash
# generate token
kubectl -n kubernetes-dashboard create token admin-user
```

```bash
# launch web server
kubectl proxy &
```

In a web browser, go to : http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/
Note: use token created just above for login

Choose `Token` as login method, paste the token just generated

## Get Traefik Dashboard

Traefik comes out of the box with k3s. In order to access Traefik Dashboard from your laptop:

```bash
kubectl --namespace kube-system port-forward deployments/traefik 9000:9000 &
```

In a web browser, go to : http://localhost:9000/dashboard/

Storage configuration (Longhorn)
--------------------------------

Deploy longhorn in your cluster:

```bash
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.5.3/deploy/prerequisite/longhorn-iscsi-installation.yaml

kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.5.3/deploy/prerequisite/longhorn-nfs-installation.yaml

```

**Single or two nodes cluster** (less than 3 nodes)

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

**Multi node cluster** (more than 2 nodes)

```bash
kubectl apply -f https://raw.githubusercontent.com/longhorn/longhorn/v1.5.3/deploy/longhorn.yaml
```

Check environnment
------------------

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


## What is your hostname ?

Single node: easy
Multi-node: todo

References to look at:
* loadbalancer [metallb](https://metallb.universe.tf/)
* [external dns ](https://github.com/kubernetes-sigs/external-dns)

Few tutorials:
* https://particule.io/en/blog/k8s-no-cloud/
* https://datavirke.dk/posts/bare-metal-kubernetes-part-4-ingress-dns-certificates/

## Deploy diracx

```bash
# Clone diracx repositories

git clone https://github.com/DIRACGrid/diracx-charts.git

# Update the config with your hostname
sed -i 's/<your_hostname>/thenameyouareacutally.using.com/g' ./diracx-charts/k3s/examples/*

# Deploy via provided helm charts

helm install --timeout 3600s diracx ./diracx-charts/diracx/ -f ./diracx-charts/k3s/examples/my.values.yaml --debug
```

## Configure DiracX

We need to configure DiracX. It could be done with `dirac` CLI tool if you have it available, but here we do it by editing the Configuration repository directly.

```bash
# Login to the diracx pod
kubectl exec -it deployments/diracx -- bash

# install an editor
micromamba install -c conda-forge vim

# Edit the content of the config file
# and replcate it with ./diracx-charts/k3s/examples/cs.yaml
cd /cs_store/initialRepo/
vim default.yml

# Commit
git config --global user.email "inspector@gadget.com"
git config --global user.name "Bond, James Bond"
git add default.yml
git commit -m 'Initial config'
```

## Post-install tips

In case you would like to make us of the services installed (e.g. MySQL or OpenSearch) from outisde the kubernetes cluster, there are different solutions and configurations to make. LoadBalancer, NodePort, or Ingress are the options. One of these would need to be set out.

Similar considerations apply for the use of certificates. See https://github.com/DIRACGrid/diracx-charts/issues/107


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

I used ``wireguard`` instead of ``flannel``
