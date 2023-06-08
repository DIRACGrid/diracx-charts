#!/usr/bin/bash
set -euo pipefail


function cleanup(){
    trap - SIGTERM;
    echo cleaning up;
    ./kind delete cluster --name diracx-demo

}

trap "cleanup" EXIT

# if [[ ! -f "k3s" ]];
# then
#     curl -LO https://github.com/k3s-io/k3s/releases/latest/download/k3s
#     chmod a+x k3s
# fi
# sudo ./k3s server\
#      --write-kubeconfig $(pwd)/k3s.yaml\
#      --write-kubeconfig-mode 644\
#      --data-dir $(pwd)/k3sData/ &>server.log &

# K3S_PID=$!
# echo "K3S_PID ${K3S_PID}"

if [[ ! -f "kind" ]]
then
    [ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.19.0/kind-linux-amd64
    chmod +x kind
fi
./kind create cluster \
    --kubeconfig $(pwd)/kube.conf \
    --wait 1m \
    --config /home/chaen/dirac/diracx-chart/demo_cluster_conf.yaml \
    --name diracx-demo

./kind load docker-image -n diracx-demo gitlab-registry.cern.ch/chaen/chrissquare-hack-a-ton/diracx

# run an Ingress

kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

if [[ ! -f "kubectl" ]];
then
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
fi

export KUBECONFIG=$(pwd)/kube.conf

until (./kubectl get nodes | grep -c Ready) &>/dev/null
do
    echo "Waiting for node to be ready";
    sleep 1;
done





if [[ ! -f "helm" ]];
then
    curl -LO https://get.helm.sh/helm-v3.12.0-linux-amd64.tar.gz
    tar xvzf helm-v3.12.0-linux-amd64.tar.gz
    mv linux-amd64/helm .
    rm -rf linux-amd64 xvzf helm-v3.12.0-linux-amd64.tar.gz
fi
./helm install /home/chaen/dirac/diracx-chart/diracx --generate-name &> helm.log



until (./kubectl get pods | grep diracx | grep -c Running) &>/dev/null
do
    echo "Waiting for pods to be Running";
    sleep 1;
done

sed '1,/Get the application URL by running these commands/d' helm.log | sed 's@kubectl@./kubectl@g' | sed 's/8080:/8000:/g' > expose_pod.sh
chmod +x expose_pod.sh
./expose_pod.sh


# export POD_NAME=$(./k3s kubectl get pods --namespace {{ .Release.Namespace }} -l "app.kubernetes.io/name={{ include "diracx.name" . }},app.kubernetes.io/instance={{ .Release.Name }}" -o jsonpath="{.items[0].metadata.name}")
# export CONTAINER_PORT=$(./3s kubectl get pod --namespace {{ .Release.Namespace }} $POD_NAME -o jsonpath="{.spec.containers[0].ports[0].containerPort}")
#   kubectl --namespace {{ .Release.Namespace }} port-forward $POD_NAME 8080:$CONTAINER_PORT