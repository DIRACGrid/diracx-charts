#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

if [ -z "${1:-}" ]; then
  echo "Usage: $0 <diracx_src_dir>"
  exit 1
fi
diracx_repo_dir="$(readlink -f "${1}")"
diracx_src_dir="${diracx_repo_dir}/src/diracx"
if [[ ! -d "${diracx_src_dir}" ]]; then
  printf "\U26A0\UFE0F Error: %s is not a clone of DiracX!" "${diracx_repo_dir}"
  exit 1
fi

script_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

tmp_dir=$(mktemp -d)
demo_dir="${script_dir}/.demo"
mkdir -p "${demo_dir}"
export KUBECONFIG="${demo_dir}/kube.conf"

function cleanup(){
  trap - SIGTERM;
  echo "Cleaning up";
  if [[ -f "${demo_dir}/kind" ]] && [[ -f "${KUBECONFIG}" ]]; then
      "${demo_dir}/kind" delete cluster --name diracx-demo
  fi
  rm -rf "${tmp_dir}"
}

trap "cleanup" EXIT

if [[ ! -f "${demo_dir}/helm" ]]; then
  # Inspect the current system
  system_name=$(uname -s | tr '[:upper:]' '[:lower:]')
  system_arch=$(uname -m)
  if [[ "${system_arch}" == "x86_64" ]]; then
      system_arch="amd64"
  fi

  # Download kind
  printf "\U1F984 Downloading kind\n"
  curl --no-progress-meter -L "https://kind.sigs.k8s.io/dl/v0.19.0/kind-${system_name}-${system_arch}" > "${demo_dir}/kind"

  # Download kubectl
  printf "\U1F984 Downloading kubectl\n"
  latest_version=$(curl -L -s https://dl.k8s.io/release/stable.txt)
  curl --no-progress-meter -L "https://dl.k8s.io/release/${latest_version}/bin/${system_name}/${system_arch}/kubectl" > "${demo_dir}/kubectl"

  # Download helm
  printf "\U1F984 Downloading helm\n"
  curl --no-progress-meter -L "https://get.helm.sh/helm-v3.12.0-${system_name}-${system_arch}.tar.gz" > "${tmp_dir}/helm.tar.gz"
  mkdir -p "${tmp_dir}/helm-tarball"
  tar xzf "${tmp_dir}/helm.tar.gz" -C "${tmp_dir}/helm-tarball"
  mv "${tmp_dir}/helm-tarball/${system_name}-${system_arch}/helm" "${demo_dir}"

  # Make the binaries executable
  chmod +x "${demo_dir}/kubectl" "${demo_dir}/kind" "${demo_dir}/helm"
fi

printf "\U1F984 Generating Kind cluster template...\n"
sed "s@{{ diracx_src_dir }}@${diracx_src_dir}@g" "${script_dir}/demo/demo_cluster_conf.tpl.yaml" > "${demo_dir}/demo_cluster_conf.yaml"
if grep '{{' "${demo_dir}/demo_cluster_conf.yaml"; then
  echo "Error generating Kind template. Found {{ in the template result"
  exit 1
fi

printf "\U1F984 Starting Kind cluster...\n"
"${demo_dir}/kind" create cluster \
  --kubeconfig "${KUBECONFIG}" \
  --wait "1m" \
  --config "${demo_dir}/demo_cluster_conf.yaml" \
  --name diracx-demo

printf "\U1F984 Creating an ingress...\n"
"${demo_dir}/kubectl" apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
printf "\U1F984 Waiting for ingress controller to be created...\n"
"${demo_dir}/kubectl" wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s

printf "\U1F984 Generating Helm templates\n"
machine_hostname=$(hostname | tr '[:upper:]' '[:lower:]')
sed "s/{{ hostname }}/${machine_hostname}/g" "${script_dir}/demo/values.tpl.yaml" > "${demo_dir}/values.yaml"
if grep '{{' "${demo_dir}/values.yaml"; then
  printf "\U1F984 Error generating template. Found {{ in the template result\n"
  exit 1
fi

printf "\U1F984 Installing DiracX...\n"
"${demo_dir}/helm" install diracx-demo "${script_dir}/diracx" --values "${demo_dir}/values.yaml"
printf "\U1F984 Waiting for installation to finish...\n"
"${demo_dir}/kubectl" wait \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/name=diracx \
  --timeout=300s

printf "\U1F389 \U1F389 \U1F389 Pods are ready! \U1F389 \U1F389 \U1F389\n"
echo ""
printf "\U2139 \UFE0F To interact with the cluster:\n"
echo "export KUBECONFIG=${KUBECONFIG}"
echo "export PATH=${PATH}:${demo_dir}"
echo ""
printf "\U2139 \UFE0F You can access swagger at http://%s:8000/docs\n" "${machine_hostname}"
echo "Username: admin@example.com"
echo "Password: password"
echo ""
printf "\U2139 \UFE0F Press Ctrl+C to clean up and exit\n"

while true; do
  sleep 1000;
done
