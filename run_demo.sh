#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

UNICORN_EMOJI='\xF0\x9F\xA6\x84'
SKULL_EMOJI='\xF0\x9F\x92\x80'
PARTY_EMOJI='\xF0\x9F\x8E\x89'
INFO_EMOJI='\xE2\x84\xB9\xEF\xB8\x8F'
WARN_EMOJI='\xE2\x9A\xA0\xEF\xB8\x8F'

script_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

tmp_dir=$(mktemp -d)
demo_dir="${script_dir}/.demo"
mkdir -p "${demo_dir}"
export KUBECONFIG="${demo_dir}/kube.conf"
export HELM_DATA_HOME="${demo_dir}/helm_data"

function cleanup(){
  trap - SIGTERM;
  echo "Cleaning up";
  if [[ -f "${demo_dir}/kind" ]] && [[ -f "${KUBECONFIG}" ]]; then
      "${demo_dir}/kind" delete cluster --name diracx-demo
  fi
  rm -rf "${tmp_dir}"
}

function space_monitor(){
  # Continiously monitor if the cluster is low on space
  # Wait for the container to be available
  while true; do
    if docker ps | grep diracx-demo-control-plane &> /dev/null; then
      break
    fi
    sleep 2
  done
  # Run the monitoring every 60 seconds
  while true; do
    # Check for the amount of free space on the cluster
    df_output=$(docker exec diracx-demo-control-plane df -BG 2>/dev/null)
    percent_free=$(echo "${df_output}" | awk 'NR == 2 { print substr($5, 1, length($5)-1) }')
    cluster_free_gb=$(echo "${df_output}" | awk 'NR == 2 { print substr($4, 1, length($4)-1) }')
    if [ "${cluster_free_gb}" -lt 50 ]; then
      printf "%b Cluster is low on space (%sGB free, %s%%)\n" "${WARN_EMOJI}" "${cluster_free_gb}" "${percent_free}"
    fi
    # Check the total size of the containerd volume
    if [ ${mount_containerd} -eq 1 ]; then
      containerd_volume_size="$(docker exec diracx-demo-control-plane du -s -BG /var/lib/containerd | cut -d 'G' -f 1)"
      if [[ "${containerd_volume_size}" -gt 10 ]]; then
        printf "%b Volume for containerd is %s GB, if you want to save space " "${WARN_EMOJI}" "${containerd_volume_size}"
        printf "shutdown the demo and run \"docker volume rm diracx-demo-containerd\"\n"
      fi
    fi
    sleep 60
  done
}

function check_hostname(){
  # Check that the hostname resolves to an IP address
  # dig doesn't consider the effect of /etc/hosts so we use ping instead
  if ! ip_address=$(ping -c 1 "$1" | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -n 1); then
    printf "%b ping command exited with a non-zero exit code\n" ${SKULL_EMOJI}
    return 1
  fi
  if [[ -z "${ip_address}" ]]; then
    printf "%b No IP address found hostname %s\n" ${SKULL_EMOJI} "${1}"
    return 1
  fi
  if [[ "${ip_address}" == 127.* ]]; then
    printf "%b Hostname %s resolves to 127.0.0.1 but this is not supported\n" ${SKULL_EMOJI} "${1}"
    return 1
  fi
}

usage="${0##*/} [-h|--help] [--exit-when-done] [--offline] [--enable-coverage] [--no-mount-containerd] [--set-value key=value] [--] [source directories]"
usage+="\n\n"
usage+="  -h|--help: Print this help message and exit\n"
usage+="  --exit-when-done: Exit after the demo has been started (it will be left running in the background)\n"
usage+="  --enable-coverage: Enable coverage reporting\n"
usage+="  --offline: Run in a mode which is suitable for fully offline use.\n"
usage+="             WARNING: This may result in some weird behaviour, see the demo documentation for details.\n"
usage+="             Implies: --mount-containerd\n"
usage+="  --no-mount-containerd: Mount a directory on the host for the kind containerd storage.\n"
usage+="                         This option avoids needing to pull container images every time the demo is started.\n"
usage+="                         WARNING: There is no garbage collection so the directory will grow without bound.\n"
usage+="  --set-value: Set a value in the Helm values file. This can be used to override the default values.\n"
usage+="               For example, to enable coverage reporting pass: --set-value developer.enableCoverage=true\n"
usage+="  source directories: A list of directories containing Python packages to mount in the demo cluster.\n"

# Parse command-line switches
exit_when_done=0
mount_containerd=1
offline_mode=0
declare -a helm_arguments=()
enable_coverage=0
while [ -n "${1:-}" ]; do case $1 in
	# Print a brief usage summary and exit
	-h|--help|-\?)
		printf 'Usage: %b\n' "$usage"
		exit ;;

	# # Unbundle short options
	# -[niladic-short-opts]?*)
	# 	tail="${1#??}"
	# 	head=${1%"$tail"}
	# 	shift
	# 	set -- "$head" "-$tail" "$@"
	# 	continue ;;

	# # Expand parametric values
	# -[monadic-short-opts]?*|--[!=]*=*)
	# 	case $1 in
	# 		--*) tail=${1#*=}; head=${1%%=*} ;;
	# 		*)   tail=${1#??}; head=${1%"$tail"} ;;
	# 	esac
	# 	shift
	# 	set -- "$head" "$tail" "$@"
	# 	continue ;;

	# Add new switch checks here
	--exit-when-done)
    exit_when_done=1;
		shift
		continue ;;

	--enable-coverage)
    helm_arguments+=("--set")
    helm_arguments+=("developer.enableCoverage=true")
    enable_coverage=1
		shift
		continue ;;

	--no-mount-containerd)
    mount_containerd=0
		shift
		continue ;;

	--offline)
    mount_containerd=1
    offline_mode=1
    helm_arguments+=("--set" "global.imagePullPolicy=IfNotPresent")
    helm_arguments+=("--set" "developer.offline=true")
		shift
		continue ;;

	--set-value)
		shift
    if [[ -z "${1:-}" ]]; then
      printf "%b Error: --set-value requires an argument\n" ${SKULL_EMOJI}
      exit 1
    fi
    helm_arguments+=("--set")
    helm_arguments+=("${1}")
		shift
		continue ;;

	# Double-dash: Terminate option parsing
	--)
		shift
		break ;;

	# Invalid option: abort
	--*|-?*)
		>&2 printf '%b %s: Invalid option: "%s"\n' ${SKULL_EMOJI} "${0##*/}" "$1"
		>&2 printf 'Usage: %b\n' "$usage"
		exit 1 ;;

	# Argument not prefixed with a dash
	*) break ;;

esac; shift
done

# Remaining arguments are positional parameters that are used to specify which
# source directories to mount in the demo cluster
declare -a pkg_dirs=()
declare -a python_pkg_names=()
node_pkg_name=""

for src_dir in "$@"; do
  pkg_dirs+=("${src_dir}")
  # Python packages
  # shellcheck disable=SC2044
  for pkg_dir in $(find "$src_dir/src" -mindepth 2 -maxdepth 2 -type f -name '__init__.py'); do
    pkg_name="$(basename "$(dirname "${pkg_dir}")")"

    # Check for the presence of $pkg_name in pkg_names array
    found=0
    if [ ${#python_pkg_names[@]} -gt 0 ]; then
      for existing_pkg_name in "${python_pkg_names[@]}"; do
        if [[ "$existing_pkg_name" == "$pkg_name" ]]; then
          found=1
          break
        fi
      done
    fi

    if [[ $found -eq 1 ]]; then
      printf "%b Error: Source directory for %s was given twice!\n" "${SKULL_EMOJI}" "${pkg_name}"
      exit 1
    fi
    python_pkg_names+=("${pkg_name}")
  done

  # Node packages: we keep a single package, the last one found
  # shellcheck disable=SC2044
  for pkg_json in $(find "$src_dir" -mindepth 1 -maxdepth 1 -type f -name 'package.json'); do
    node_pkg_name="$(basename "$(dirname "${pkg_json}")")"
  done
done

if [ ${#python_pkg_names[@]} -gt 0 ] || [ ${#node_pkg_name} != "" ]; then
  pkg_names_joined=$(IFS=' '; echo "${python_pkg_names[*]} ${node_pkg_name}")
  printf "%b Found package directories for: %s\n" ${UNICORN_EMOJI} "${pkg_names_joined}"
else
  printf "%b No source directories were specified\n" ${UNICORN_EMOJI}
fi

trap "cleanup" EXIT

# We download kind/kubectl/helm into the .demo directory to avoid having any
# requirements on the user's machine
if [[ ! -f "${demo_dir}/helm" ]]; then
  # Inspect the current system
  system_name=$(uname -s | tr '[:upper:]' '[:lower:]')
  system_arch=$(uname -m)
  if [[ "${system_arch}" == "x86_64" ]]; then
      system_arch="amd64"
  fi

  # Download kind
  printf "%b Downloading kind\n" ${UNICORN_EMOJI}
  curl --no-progress-meter -L "https://kind.sigs.k8s.io/dl/v0.19.0/kind-${system_name}-${system_arch}" > "${demo_dir}/kind"

  # Download kubectl
  printf "%b Downloading kubectl\n" ${UNICORN_EMOJI}
  latest_version=$(curl -L -s https://dl.k8s.io/release/stable.txt)
  curl --no-progress-meter -L "https://dl.k8s.io/release/${latest_version}/bin/${system_name}/${system_arch}/kubectl" > "${demo_dir}/kubectl"

  # Download helm
  printf "%b Downloading helm\n" ${UNICORN_EMOJI}
  curl --no-progress-meter -L "https://get.helm.sh/helm-v3.12.0-${system_name}-${system_arch}.tar.gz" > "${tmp_dir}/helm.tar.gz"
  mkdir -p "${tmp_dir}/helm-tarball"
  tar xzf "${tmp_dir}/helm.tar.gz" -C "${tmp_dir}/helm-tarball"
  mv "${tmp_dir}/helm-tarball/${system_name}-${system_arch}/helm" "${demo_dir}"

  # Make the binaries executable
  chmod +x "${demo_dir}/kubectl" "${demo_dir}/kind" "${demo_dir}/helm"

  # Install helm plugins to ${HELM_DATA_HOME}
  "${demo_dir}/helm" plugin install https://github.com/databus23/helm-diff
fi

# Generate the cluster template for kind which includes the source directories
printf "%b Generating Kind cluster template...\n" ${UNICORN_EMOJI}
cp "${script_dir}/demo/demo_cluster_conf.tpl.yaml" "${demo_dir}/demo_cluster_conf.yaml"
if [ ${#pkg_dirs[@]} -gt 0 ]; then
  for pkg_dir in "${pkg_dirs[@]}"; do
    mv "${demo_dir}/demo_cluster_conf.yaml" "${demo_dir}/demo_cluster_conf.yaml.bak"
    sed "s@{{ extraMounts }}@  - hostPath: ${pkg_dir}\n    containerPath: /diracx_source/$(basename "${pkg_dir}")\n{{ extraMounts }}@g" "${demo_dir}/demo_cluster_conf.yaml.bak" > "${demo_dir}/demo_cluster_conf.yaml"
  done
fi
# If requested, mount the containerd storage from the host
if [ ${mount_containerd} -eq 1 ]; then
  # We use a docker volume for the containerd mount rather than a directory on
  # the host as it needs to support overlayfs. This isn't the case for some
  # host file systems or when Docker Desktop is used (e.g. macOS)
  if docker volume inspect diracx-demo-containerd -f '{{ .Mountpoint }}' > /dev/null 2>&1; then
    printf "%b Using existing containerd storage\n" ${UNICORN_EMOJI}
  else
    printf "%b Creating containerd storage\n" ${UNICORN_EMOJI}
    docker volume create diracx-demo-containerd
  fi
  containerd_mount=$(docker volume inspect diracx-demo-containerd -f '{{ .Mountpoint }}')
  mv "${demo_dir}/demo_cluster_conf.yaml" "${demo_dir}/demo_cluster_conf.yaml.bak"
  sed "s@{{ extraMounts }}@  - hostPath: ${containerd_mount}\n    containerPath: /var/lib/containerd\n{{ extraMounts }}@g" "${demo_dir}/demo_cluster_conf.yaml.bak" > "${demo_dir}/demo_cluster_conf.yaml"
fi
# Add the mount for the CS
# hack to cleanup the cs-mount content owned by somebody else
# (long term solution is proper security policy in the cluster)
docker run -v "${demo_dir}/cs-mount":/cs-mount busybox:latest rm -rf /cs-mount/initialRepo
rm -rf "${demo_dir}/cs-mount"
mkdir -p "${demo_dir}/cs-mount"
# Make sure the directory is writable by the container
chmod 777 "${demo_dir}/cs-mount"
mv "${demo_dir}/demo_cluster_conf.yaml" "${demo_dir}/demo_cluster_conf.yaml.bak"
sed "s@{{ csStorePath }}@${demo_dir}/cs-mount@g" "${demo_dir}/demo_cluster_conf.yaml.bak" > "${demo_dir}/demo_cluster_conf.yaml"
# If coverage is enabled mount .demo/coverage-reports into the cluster
if [[ ${enable_coverage} ]]; then
  rm -rf "${demo_dir}/coverage-reports"
  mkdir -p "${demo_dir}/coverage-reports"
  # Make sure the directory is writable by the container
  chmod 777 "${demo_dir}/coverage-reports"
  mv "${demo_dir}/demo_cluster_conf.yaml" "${demo_dir}/demo_cluster_conf.yaml.bak"
  sed "s@{{ extraMounts }}@  - hostPath: ${demo_dir}/coverage-reports\n    containerPath: /coverage-reports\n{{ extraMounts }}@g" "${demo_dir}/demo_cluster_conf.yaml.bak" > "${demo_dir}/demo_cluster_conf.yaml"
fi
# Cleanup the "{{ extraMounts }}" part of the template and make sure things look reasonable
mv "${demo_dir}/demo_cluster_conf.yaml" "${demo_dir}/demo_cluster_conf.yaml.bak"
sed "s@{{ extraMounts }}@@g" "${demo_dir}/demo_cluster_conf.yaml.bak" > "${demo_dir}/demo_cluster_conf.yaml"
if grep '{{' "${demo_dir}/demo_cluster_conf.yaml"; then
  printf "%b Error generating Kind template. Found {{ in the template result\n" ${UNICORN_EMOJI}
  exit 1
fi

# Start background task to monitor the cluster space
space_monitor &

# Create the cluster itself
printf "%b Starting Kind cluster...\n" ${UNICORN_EMOJI}
"${demo_dir}/kind" create cluster \
  --kubeconfig "${KUBECONFIG}" \
  --wait "1m" \
  --config "${demo_dir}/demo_cluster_conf.yaml" \
  --name diracx-demo

# Try to find a suitable hostname/IP-address for the demo. This must be not
# resolve to a loopback address as pods need to be able to communicate with
# each other via this address. For example, the DiracX service pod needs to be
# able to communicate with dex via this while users also use the same
# address/IP-address.
machine_ip=""
machine_hostname=$(hostname | tr '[:upper:]' '[:lower:]')
if ! check_hostname "${machine_hostname}"; then
  if [[ "$(uname -s)" = "Linux" ]]; then
    machine_ip=$(docker inspect --format '{{ .NetworkSettings.Networks.kind.IPAddress }}' diracx-demo-control-plane)
    if [[ -z "${machine_ip}" ]]; then
      printf "%b Error: Failed to find IP address from docker\n" ${SKULL_EMOJI}
      exit 1
    fi
    machine_hostname="${machine_ip}.nip.io"
  fi
  if ! check_hostname "${machine_hostname}"; then
    machine_ip=$(ifconfig | grep 'inet ' | awk '{ print $2 }' | grep -v '^127' | head -n 1 | cut -d '/' -f 1)
    # We use nip.io to have an actual DNS name and be allowed to specify this in
    # the ingress host
    machine_hostname="${machine_hostname}.nip.io"
    if ! check_hostname "${machine_hostname}"; then
      echo "Failed to find an appropriate hostname for the demo."
      exit 1
    fi
  fi
  printf "%b Using IP address %s instead \n" ${INFO_EMOJI} "${machine_hostname}"
fi
if [ "${machine_ip}" ]; then
  helm_arguments+=("--set" "developer.ipAlias=${machine_ip}")
fi

# Generate the Helm values file
printf "%b Generating Helm templates\n" ${UNICORN_EMOJI}
sed "s/{{ hostname }}/${machine_hostname}/g" "${script_dir}/demo/values.tpl.yaml" > "${demo_dir}/values.yaml"
mv "${demo_dir}/values.yaml" "${demo_dir}/values.yaml.bak"
sed "s@{{ demo_dir }}@${demo_dir}@g" "${demo_dir}/values.yaml.bak" > "${demo_dir}/values.yaml"
mv "${demo_dir}/values.yaml" "${demo_dir}/values.yaml.bak"

# Add python packages
json="["
if [ ${#python_pkg_names[@]} -gt 0 ]; then
  for pkg_name in "${python_pkg_names[@]}"; do
      json+="\"$pkg_name\","
  done
fi
json="${json%,}]"
sed "s/{{ python_modules_to_mount }}/${json}/g" "${demo_dir}/values.yaml.bak" > "${demo_dir}/values.yaml"
mv "${demo_dir}/values.yaml" "${demo_dir}/values.yaml.bak"

# Add the node package
sed "s/{{ node_module_to_mount }}/${node_pkg_name}/g" "${demo_dir}/values.yaml.bak" > "${demo_dir}/values.yaml"

# Final check
if grep '{{' "${demo_dir}/values.yaml"; then
  printf "%b Error generating template. Found {{ in the template result\n" ${SKULL_EMOJI}
  exit 1
fi

# Add an ingress to the cluster
printf "%b Creating an ingress...\n" ${UNICORN_EMOJI}
# TODO: This should move to the chart itself
if [ ${offline_mode} -eq 0 ]; then
  curl -L https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml > "${tmp_dir}/kind-ingress-deploy.yaml"
  mv "${tmp_dir}/kind-ingress-deploy.yaml" "${demo_dir}/kind-ingress-deploy.yaml"
fi
"${demo_dir}/kubectl" apply -f "${demo_dir}/kind-ingress-deploy.yaml"
printf "%b Waiting for ingress controller to be created...\n" ${UNICORN_EMOJI}
"${demo_dir}/kubectl" wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=300s

# Install the DiracX chart
printf "%b Installing DiracX...\n" ${UNICORN_EMOJI}
helm_arguments+=("--values" "${demo_dir}/values.yaml")
if ! "${demo_dir}/helm" install diracx-demo "${script_dir}/diracx" "${helm_arguments[@]}"; then
  printf "%b Error using helm DiracX\n" ${WARN_EMOJI}
  echo "Failed to run \"helm install\"" >> "${demo_dir}/.failed"
else
  printf "%b Waiting for installation to finish...\n" ${UNICORN_EMOJI}
  if "${demo_dir}/kubectl" wait --for=condition=ready pod --selector=app.kubernetes.io/name=diracx --timeout=900s; then
    printf "%b %b %b Pods are ready! %b %b %b\n" "${PARTY_EMOJI}" "${PARTY_EMOJI}" "${PARTY_EMOJI}" "${PARTY_EMOJI}" "${PARTY_EMOJI}" "${PARTY_EMOJI}"

    # Dump the CA certificate to a file so that it can be used by the client
    "${demo_dir}/kubectl" get secret/root-secret -o json | jq -r '.data."tls.crt"' | base64 -d > "${demo_dir}/demo-ca.pem"

    touch "${demo_dir}/.success"
  else
    printf "%b Installation did not start sucessfully!\n" ${WARN_EMOJI}
    echo "Installation did not start sucessfully!" >> "${demo_dir}/.failed"
  fi
fi

# Exit if --exit-when-done was passed
if [ ${exit_when_done} -eq 1 ]; then
  # Remove the EXIT trap so we don't clean up
  trap - EXIT
  exit 0
fi

echo ""
printf "%b  Press Ctrl+C to clean up and exit\n" "${INFO_EMOJI}"

machine_hostname_has_changed=0
while true; do
  sleep 60;
  # If the machine hostname changes then the demo will need to be restarted.
  # See the original machine_hostname detection description above.
  if ! check_hostname "${machine_hostname}"; then
    echo "The demo will likely need to be restarted."
    machine_hostname_has_changed=1
  elif [ ${machine_hostname_has_changed} -eq 1 ]; then
    printf "%b The machine hostnamae seems to have been fixed. %b\n" "${PARTY_EMOJI}" "${PARTY_EMOJI}"
    printf "%b No need to restart! %b\n" "${PARTY_EMOJI}" "${PARTY_EMOJI}"
    machine_hostname_has_changed=0
  fi
done
