#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

script_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

tmp_dir="${script_dir}/.demo"
mkdir -p "${tmp_dir}"
export KUBECONFIG="${tmp_dir}/kube.conf"

function cleanup(){
    trap - SIGTERM;
    echo "Cleaning up";
    if [[ -f "${tmp_dir}/kind" ]] && [[ -f "${KUBECONFIG}" ]]; then
        "${tmp_dir}/kind" delete cluster --name diracx-demo
    fi
    #rm -rf "${tmp_dir}"
}

trap "cleanup" EXIT


if [[ ! -f "${tmp_dir}/helm" ]]; then
    # Inspect the current system
    system_name=$(uname -s | tr '[:upper:]' '[:lower:]')
    system_arch=$(uname -m)
    if [[ "${system_arch}" == "x86_64" ]]; then
        system_arch="amd64"
    fi

    # Download kind
    printf "\U1F984 Downloading kind\n"
    curl --no-progress-meter -L "https://kind.sigs.k8s.io/dl/v0.19.0/kind-${system_name}-${system_arch}" > "${tmp_dir}/kind"

    # Download kubectl
    printf "\U1F984 Downloading kubectl\n"
    latest_version=$(curl -L -s https://dl.k8s.io/release/stable.txt)
    curl --no-progress-meter -L "https://dl.k8s.io/release/${latest_version}/bin/${system_name}/${system_arch}/kubectl" > "${tmp_dir}/kubectl"

    # Download helm
    printf "\U1F984 Downloading helm\n"
    curl --no-progress-meter -L "https://get.helm.sh/helm-v3.12.0-${system_name}-${system_arch}.tar.gz" > "${tmp_dir}/helm.tar.gz"
    mkdir -p "${tmp_dir}/helm-tarball"
    tar xzf "${tmp_dir}/helm.tar.gz" -C "${tmp_dir}/helm-tarball"
    mv "${tmp_dir}/helm-tarball/${system_name}-${system_arch}/helm" "${tmp_dir}"

    # Make the binaries executable
    chmod +x "${tmp_dir}/kubectl" "${tmp_dir}/kind" "${tmp_dir}/helm"
fi

echo "Generating Kind cluster template..."

DIRACX_SRC_DIR=/home/chaen/dirac/diracx-project/diracx/src/diracx
sed "s@{{ diracx_src_dir }}@${DIRACX_SRC_DIR}@g"  "${script_dir}/demo/demo_cluster_conf.tpl.yaml"  > "${tmp_dir}/demo_cluster_conf.yaml"

if grep '{{' "${tmp_dir}/demo_cluster_conf.yaml"
then
  echo "Error generating Kind template. Found {{ in the template result"
  exit 1
fi


"${tmp_dir}/kind" create cluster \
    --kubeconfig "${KUBECONFIG}" \
    --wait "1m" \
    --config "${tmp_dir}/demo_cluster_conf.yaml" \
    --name diracx-demo

# run an Ingress
"${tmp_dir}/kubectl" apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

"${tmp_dir}/kubectl" wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s


echo "Generating Helm templates"

sed "s/{{ hostname }}/$(hostname)/g"  "${script_dir}/demo/values.tpl.yaml"  > "${tmp_dir}/values.yaml"

if grep '{{' "${tmp_dir}/values.yaml"
then
  echo "Error generating template. Found {{ in the template result"
  exit 1
fi


"${tmp_dir}/helm" install diracx-demo "${script_dir}/diracx" --values "${tmp_dir}/values.yaml"

echo "Waiting for Installation to finish..."

"${tmp_dir}/kubectl" wait \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/name=diracx \
  --timeout=300s


echo "Pods are ready"
echo ""
echo "To interact with the cluster:"
echo "export KUBECONFIG=${KUBECONFIG}"
echo "export PATH=${PATH}:${tmp_dir}"
echo ""
echo "You can access swagger at http://diracx-demo:8000/docs"
echo "Username: admin@example.com"
echo "Password: password"
echo ""
echo "Press Ctrl+C to exit"

while [[ true ]];
do
    sleep 1000;
done
