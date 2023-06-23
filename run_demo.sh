#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

script_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
tmp_dir=$(mktemp -d)
export KUBECONFIG="${script_dir}/kube.conf"

function cleanup(){
    trap - SIGTERM;
    echo "Cleaning up";
    if [[ -f "${script_dir}/kind" ]] && [[ -f "${KUBECONFIG}" ]]; then
        "${script_dir}/kind" delete cluster --name diracx-demo
    fi
    rm -rf "${tmp_dir}"
}

trap "cleanup" EXIT


if [[ ! -f "${script_dir}/helm" ]]; then
    # Inspect the current system
    system_name=$(uname -s | tr '[:upper:]' '[:lower:]')
    system_arch=$(uname -m)
    if [[ "${system_arch}" == "x86_64" ]]; then
        system_arch="amd64"
    fi

    # Download kind
    printf "\U1F984 Downloading kind\n"
    curl --no-progress-meter -L "https://kind.sigs.k8s.io/dl/v0.19.0/kind-${system_name}-${system_arch}" > "${script_dir}/kind"

    # Download kubectl
    printf "\U1F984 Downloading kubectl\n"
    latest_version=$(curl -L -s https://dl.k8s.io/release/stable.txt)
    curl --no-progress-meter -L "https://dl.k8s.io/release/${latest_version}/bin/${system_name}/${system_arch}/kubectl" > "${script_dir}/kubectl"

    # Download helm
    printf "\U1F984 Downloading helm\n"
    curl --no-progress-meter -L "https://get.helm.sh/helm-v3.12.0-${system_name}-${system_arch}.tar.gz" > "${tmp_dir}/helm.tar.gz"
    mkdir -p "${tmp_dir}/helm"
    tar xzf "${tmp_dir}/helm.tar.gz" -C "${tmp_dir}/helm"
    mv "${tmp_dir}/helm/${system_name}-${system_arch}/helm" "${script_dir}"

    # Make the binaries executable
    chmod +x "${script_dir}/kubectl" "${script_dir}/kind" "${script_dir}/helm"
fi
./kind create cluster \
    --kubeconfig "${KUBECONFIG}" \
    --wait "1m" \
    --config "${script_dir}/demo_cluster_conf.yaml" \
    --name diracx-demo

# run an Ingress
./kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml


until (./kubectl get nodes | grep -c Ready) &>/dev/null; do
    echo "Waiting for node to be ready";
    sleep 1;
done

./helm install diracx-demo "${script_dir}/diracx"

until (./kubectl get pods | grep diracx | grep -c Running) &>/dev/null; do
    echo "Waiting for pods to be Running";
    sleep 1;
done

echo "Pods are ready"
sleep 1000
