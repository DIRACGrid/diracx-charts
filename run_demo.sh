#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

UNICORN_EMOJI='\xF0\x9F\xA6\x84'
SKULL_EMOJI='\xF0\x9F\x92\x80'
PARTY_EMOJI='\xF0\x9F\x8E\x89'
INFO_EMOJI='\xE2\x84\xB9\xEF\xB8\x8F'
WARN_EMOJI='\xE2\x9A\xA0\xEF\xB8\x8F'

if [ "$EUID" -eq 0 ]
  then printf "%b Do not run this script as root\n" "${SKULL_EMOJI}"
  exit 1
fi


script_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

tmp_dir=$(mktemp -d)
demo_dir="${script_dir}/.demo"
mkdir -p "${demo_dir}"
export KUBECONFIG="${demo_dir}/kube.conf"
export HELM_DATA_HOME="${demo_dir}/helm_data"
KINDEST_NODE_VERSION="v1.34.0"

function cleanup(){
  trap - SIGTERM;
  echo "Cleaning up";
  if [[ -n "${space_monitor_pid:-}" ]]; then
    kill $space_monitor_pid || true
  fi
  if [[ -f "${demo_dir}/kind" ]] && [[ -f "${KUBECONFIG}" ]]; then
      "${demo_dir}/kind" delete cluster --name diracx-demo
  fi
  rm -rf "${tmp_dir}"
  if [[ -n "${space_monitor_pid:-}" ]]; then
    wait $space_monitor_pid || true
  fi
}

function space_monitor(){
  # Check every 600 seconds if the cluster is low on space
  while true; do
    sleep 600
    # Check for the amount of free space on the cluster
    df_output=$(docker exec diracx-demo-control-plane df -BG / 2>/dev/null) || continue
    percent_free=$(echo "${df_output}" | awk 'NR == 2 { print substr($5, 1, length($5)-1) }')
    cluster_free_gb=$(echo "${df_output}" | awk 'NR == 2 { print substr($4, 1, length($4)-1) }')
    if [ "${cluster_free_gb}" -lt 50 ]; then
      printf "%b Cluster is low on space (%sGB free, %s%%)\n" "${WARN_EMOJI}" "${cluster_free_gb}" "${percent_free}"
    fi
    # Check the total size of the containerd volume
    if [ ${mount_containerd} -eq 1 ]; then
      containerd_volume_size="$(docker exec diracx-demo-control-plane du -s -BG /var/lib/containerd | cut -d 'G' -f 1)" || continue
      if [[ "${containerd_volume_size}" -gt 10 ]]; then
        printf "%b Volume for containerd is %s GB, if you want to save space " "${WARN_EMOJI}" "${containerd_volume_size}"
        printf "shutdown the demo and run \"docker volume rm diracx-demo-containerd\"\n"
      fi
    fi
  done
}

function check_hostname(){

  # Force the use of ipv4.

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
  if ! docker_ip_address=$(docker run --rm "${registry_proxy_dockerhub}/library/alpine:latest" ping -c 1 "$1" | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -n 1); then
    printf "%b ping command exited with a non-zero exit code from within docker\n" ${SKULL_EMOJI}
    return 1
  fi
  if [[ "${ip_address}" != "${docker_ip_address}" ]]; then
    printf "%b Hostname %s resolves to %s but within docker it resolves to %s\n" ${SKULL_EMOJI} "${1}" "${ip_address}" "${docker_ip_address}"
    return 1
  fi
}

function element_not_in_array() {
  local element=$1
  shift
  local elements=("$@")
  local found=0

  for existing_element in "${elements[@]}"; do
      if [[ "$existing_element" == "$element" ]]; then
          found=1
          break
      fi
  done

  return $found
}

usage="${0##*/} [-h|--help] [--exit-when-done] [--offline] [--enable-coverage] [--no-mount-containerd] [--set-value key=value] [--ci-values=values.yaml] [--load-docker-image=<image_name:tag>] [--chart-path=path] [--only-download-deps] [--registry-proxy=<url>] [--] [source directories]"
usage+="\n\n"
usage+="  -h|--help: Print this help message and exit\n"
usage+="  --extension-chart-path: Path to a custom Helm chart to install instead of the default diracx chart\n"
usage+="                          This is useful for installing umbrella charts that depend on diracx.\n"
usage+="  --ci-values: Path to a values.yaml file which contains diracx dev settings only enabled for CI\n"
usage+="  --exit-when-done: Exit after the demo has been started (it will be left running in the background)\n"
usage+="  --enable-coverage: Enable coverage reporting (used by diracx CI)\n"
usage+="  --enable-open-telemetry: lauches OpenTelemetry collection.\n"
usage+="                           WARNING: experimental and resource hungry.\n"
usage+="  --load-docker-image: Mount a local docker image into kind\n"
usage+="                      WARNING: the ImagePullPolicy MUST not be Always for this to work\n"
usage+="  --no-editable-python: Do not install Python source directories in editable mode\n"
usage+="  --no-mount-containerd: Mount a directory on the host for the kind containerd storage.\n"
usage+="                         This option avoids needing to pull container images every time the demo is started.\n"
usage+="                         WARNING: There is no garbage collection so the directory will grow without bound.\n"
usage+="  --offline: Run in a mode which is suitable for fully offline use.\n"
usage+="             WARNING: This may result in some weird behaviour, see the demo documentation for details.\n"
usage+="             Implies: --mount-containerd\n"
usage+="  --only-download-deps: Only download kind/kubectl/helm binaries and helm plugins, then exit\n"
usage+="                        Useful for preparing the environment before running other commands\n"
usage+="  --registry-proxy: Use a registry proxy for pulling container images.\n"
usage+="                    This is useful for restricted environments or to avoid rate limits.\n"
usage+="                    For example: --registry-proxy harbor.example.com\n"
usage+="                    This prefixes all image registries (DockerHub and GHCR) with the given URL.\n"
usage+="  --set-value: Set a value in the Helm values file. This can be used to override the default values.\n"
usage+="               For example, to enable coverage reporting pass: --set-value developer.enableCoverage=true\n"
usage+="  source directories: A list of directories containing Python packages to mount in the demo cluster.\n"

# Parse command-line switches
exit_when_done=0
mount_containerd=1
offline_mode=0
declare -a helm_arguments=()
enable_coverage=0
editable_python=1
open_telemetry=0
declare -a ci_values_files=()
declare -a docker_images_to_load=()
chart_path=""
only_download_deps=0
registry_proxy=""

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
    exit_when_done=1
    shift
    continue ;;

  --enable-coverage)
    enable_coverage=1
    shift
    continue ;;

  --no-editable-python)
    editable_python=0
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
    shift
    continue ;;

  --enable-open-telemetry)
    open_telemetry=1
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

  --load-docker-image)
    shift
    if [[ -z "${1:-}" ]]; then
      printf "%b Error: --load-docker-image requires an argument\n" ${SKULL_EMOJI}
      exit 1
    fi
    docker_images_to_load+=("${1}")
    shift
    continue ;;

  --prune-loaded-images)
    prune_loaded_images=1
    shift
    continue ;;

  --ci-values)
    shift
    if [[ -z "${1:-}" ]]; then
      printf "%b Error: --ci-values requires an argument\n" ${SKULL_EMOJI}
      exit 1
    fi
    ci_values_file=$(realpath "${1}")
    if [[ ! -f "${ci_values_file}" ]]; then
      printf "%b Error: --ci-values does not point to a file\n" ${SKULL_EMOJI}
      exit 1;
    fi
    ci_values_files+=("${ci_values_file}")
    shift
    continue ;;

  --extension-chart-path)
    shift
    if [[ -z "${1:-}" ]]; then
      printf "%b Error: --extension-chart-path requires an argument\n" ${SKULL_EMOJI}
      exit 1
    fi
    chart_path=$(realpath "${1}")
    if [[ ! -d "${chart_path}" ]]; then
      printf "%b Error: --extension-chart-path does not point to a directory\n" ${SKULL_EMOJI}
      exit 1;
    fi
    shift
    continue ;;

  --registry-proxy)
    shift
    if [[ -z "${1:-}" ]]; then
      printf "%b Error: --registry-proxy requires an argument\n" ${SKULL_EMOJI}
      exit 1
    fi
    registry_proxy="${1}"
    shift
    continue ;;

  --only-download-deps)
    only_download_deps=1
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

# Derive registry proxy URLs for DockerHub and GHCR
# When --registry-proxy is set, all image pulls go through the proxy
if [[ -n "${registry_proxy}" ]]; then
  registry_proxy_dockerhub="${registry_proxy}/docker.io"
  registry_proxy_github="${registry_proxy}/ghcr.io"
else
  registry_proxy_dockerhub="docker.io"
  registry_proxy_github="ghcr.io"
fi

# Remaining arguments are positional parameters that are used to specify which
# source directories to mount in the demo cluster
declare -a pkg_dirs=()
declare -a python_pkg_names=()
node_pkg_name=""
declare -a node_pkg_workspaces=()
declare -a diracx_and_extensions_pkgs=()

for src_dir in "$@"; do
  if [ ${#pkg_dirs[@]} -gt 0 ] && ! element_not_in_array "$src_dir" "${pkg_dirs[@]}"; then
    printf "%b Error: Source directory %s was given twice!\n" "${SKULL_EMOJI}" "${src_dir}"
    exit 1
  fi
  pkg_dirs+=("${src_dir}")


  # Does that look like a namespace package with the structure we expect ?
  # i.e. is it diracx itself or an extension ?
  if [ -f "${src_dir}/pyproject.toml" ]; then
      # Name of the package
      pkg_name="$(basename "${src_dir}")"

      # Do we find subdirectories called the same way as the package
      if [ -n "$(find "${src_dir}" -mindepth 3 -maxdepth 3 -type d  -path "*src/${pkg_name}")" ]; then
      # And are there multiple pyprojects
        if [ -n "$(find "${src_dir}" -mindepth 2 -maxdepth 2 -type f  -name "pyproject.toml")" ]; then
          # Then let's add all these
          while IFS= read -r  sub_pkg_dir
          do
            diracx_and_extensions_pkgs+=("$(basename "${src_dir}")/$(basename "${sub_pkg_dir}")");
          done < <(find "${src_dir}" -mindepth 1 -maxdepth 1 -type d -name "${pkg_name}-*" )

          continue
        fi
      fi

  fi


  # Python packages
  if [ -f "${src_dir}/pyproject.toml" ]; then
    while IFS='' read -r pkg_dir; do
      pkg_name="$(basename "$(dirname "${pkg_dir}")")"

      # Check for the presence of $pkg_name in pkg_names array
      if [ ${#python_pkg_names[@]} -gt 0 ] && ! element_not_in_array "$pkg_name" "${python_pkg_names[@]}"; then
        printf "%b Error: Source directory for %s was given twice!\n" "${SKULL_EMOJI}" "${pkg_name}"
        exit 1
      fi
      python_pkg_names+=("${pkg_name}")
    done < <(find "$src_dir/src" -mindepth 2 -maxdepth 2 -type f -name '__init__.py')

    if [ ${#python_pkg_names[@]} -gt 0 ]; then
      continue
    fi
  fi

  # Node packages: we keep a single package, the last one found
  node_pkg_path=""
  while IFS='' read -r pkg_json; do
    node_pkg_path=$src_dir
  done < <(find "$src_dir" -mindepth 1 -maxdepth 1 -type f -name 'package.json')
  node_pkg_name="$(basename "${node_pkg_path}")"

  pkg_json="${node_pkg_path}/package.json"

  # Check for workspaces in the package.json
  if [ "$(jq -e ".workspaces | type== \"array\"" "$pkg_json")" == "true" ]; then
    readarray -t node_pkg_workspaces < <(jq -r ".workspaces[]" "$pkg_json")
    node_pkg_workspaces=("${node_pkg_workspaces[@]}")
  fi

  # Ensure node_modules exist, else create them, as volumes will be mounted there
  mkdir -p "${node_pkg_path}"/node_modules
  for workspace in "${node_pkg_workspaces[@]}"; do
    mkdir -p "${node_pkg_path}/${workspace}"/node_modules
  done
done

if [ ${#diracx_and_extensions_pkgs[@]} -gt 0 ]; then
  printf "%b Found Diracx/Extensions package directories for: %s\n" ${UNICORN_EMOJI} "${diracx_and_extensions_pkgs[*]}"
fi
if [ ${#python_pkg_names[@]} -gt 0 ]; then
  printf "%b Found Python package directories for: %s\n" ${UNICORN_EMOJI} "${python_pkg_names[*]}"
fi
if [ "${node_pkg_name}" != "" ]; then
  printf "%b Found Node package directory for: %s\n" ${UNICORN_EMOJI} "${node_pkg_name}"
fi
if [ ${#node_pkg_workspaces[@]} -gt 0 ]; then
    printf "%b Found Node package workspaces for: %s\n" ${UNICORN_EMOJI} "$(IFS=' '; echo "${node_pkg_workspaces[*]}")"
fi

trap "cleanup" EXIT

# We use arkade to download kind/kubectl/helm into the .demo directory to avoid having any
# requirements on the user's machine
if [[ ! -f "${demo_dir}/helm" ]]; then
  # Check if arkade is available, download it if not
  if [[ ! -f "${demo_dir}/arkade" ]]; then
    printf "%b Downloading arkade\n" ${UNICORN_EMOJI}
    curl --no-progress-meter -sSLf https://get.arkade.dev | env BINLOCATION="${demo_dir}" sh
    chmod +x "${demo_dir}/arkade"
  fi

  # Use arkade to download the required tools with pinned versions
  # renovate: datasource=github-releases depName=kubernetes-sigs/kind
  KIND_VERSION="v0.31.0"
  # renovate: datasource=github-releases depName=kubernetes/kubernetes
  KUBECTL_VERSION="v1.35.0"
  # renovate: datasource=github-releases depName=helm/helm versioning=loose
  HELM_VERSION="v3.20.0"
  # renovate: datasource=github-releases depName=mikefarah/yq
  YQ_VERSION="v4.52.2"

  printf "%b Downloading kind, kubectl, helm and yq using arkade\n" ${UNICORN_EMOJI}
  "${demo_dir}/arkade" get \
    kind@${KIND_VERSION} \
    kubectl@${KUBECTL_VERSION} \
    helm@${HELM_VERSION} \
    yq@${YQ_VERSION} \
    --path "${demo_dir}"

  # Install helm plugins to ${HELM_DATA_HOME}
  # renovate: datasource=github-releases depName=databus23/helm-diff
  HELM_DIFF_VERSION="v3.15.0"
  "${demo_dir}/helm" plugin install https://github.com/databus23/helm-diff --version ${HELM_DIFF_VERSION}
fi

# Exit early if we're only downloading dependencies
if [ ${only_download_deps} -eq 1 ]; then
  printf "%b Dependencies downloaded successfully to %s\n" ${PARTY_EMOJI} "${demo_dir}"
  # Remove the EXIT trap so we don't clean up
  trap - EXIT
  exit 0
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
docker run --rm -v "${demo_dir}/cs-mount":/cs-mount busybox:latest rm -rf /cs-mount/initialRepo
rm -rf "${demo_dir}/cs-mount"
mkdir -p "${demo_dir}/cs-mount"
# Make sure the directory is writable by the container
chmod 777 "${demo_dir}/cs-mount"
mv "${demo_dir}/demo_cluster_conf.yaml" "${demo_dir}/demo_cluster_conf.yaml.bak"
sed "s@{{ csStorePath }}@${demo_dir}/cs-mount@g" "${demo_dir}/demo_cluster_conf.yaml.bak" > "${demo_dir}/demo_cluster_conf.yaml"
# If coverage is enabled mount .demo/coverage-reports into the cluster
if [[ ${enable_coverage} -eq 1 ]]; then
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
space_monitor_pid=$!

# Create the cluster itself
printf "%b Starting Kind cluster...\n" ${UNICORN_EMOJI}
"${demo_dir}/kind" create cluster \
  --image "${registry_proxy_dockerhub}/kindest/node:${KINDEST_NODE_VERSION}" \
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
    machine_ip=$(docker inspect --format '{{ .NetworkSettings.Networks.kind.Gateway }}' diracx-demo-control-plane)
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
    machine_hostname="${machine_ip}.nip.io"
    if ! check_hostname "${machine_hostname}"; then
      echo "Failed to find an appropriate hostname for the demo."
      exit 1
    fi
  fi
  printf "%b Using IP address %s instead \n" ${INFO_EMOJI} "${machine_hostname}"
fi

# Generate the Helm values file
printf "%b Generating Helm templates\n" ${UNICORN_EMOJI}
sed "s/{{ hostname }}/${machine_hostname}/g" "${script_dir}/demo/values.tpl.yaml" > "${demo_dir}/values.yaml"
mv "${demo_dir}/values.yaml" "${demo_dir}/values.yaml.bak"
sed "s@{{ demo_dir }}@${demo_dir}@g" "${demo_dir}/values.yaml.bak" > "${demo_dir}/values.yaml"
mv "${demo_dir}/values.yaml" "${demo_dir}/values.yaml.bak"

# Enable OpenTelemetry
if [[ ${open_telemetry} -eq 1 ]]; then
  sed "s/{{ open_telemetry }}/true/g" "${demo_dir}/values.yaml.bak" > "${demo_dir}/values.yaml"
  mv "${demo_dir}/values.yaml" "${demo_dir}/values.yaml.bak"
else
  sed "s/{{ open_telemetry }}/false/g" "${demo_dir}/values.yaml.bak" > "${demo_dir}/values.yaml"
  mv "${demo_dir}/values.yaml" "${demo_dir}/values.yaml.bak"
fi


# Add python packages
if [[ ${editable_python} -eq 1 ]]; then
  sed "s/{{ editable_mounted_modules }}/true/g" "${demo_dir}/values.yaml.bak" > "${demo_dir}/values.yaml"
  mv "${demo_dir}/values.yaml" "${demo_dir}/values.yaml.bak"
else
  sed "s/{{ editable_mounted_modules }}/false/g" "${demo_dir}/values.yaml.bak" > "${demo_dir}/values.yaml"
  mv "${demo_dir}/values.yaml" "${demo_dir}/values.yaml.bak"
fi
json="["
if [ ${#python_pkg_names[@]} -gt 0 ]; then
  for pkg_name in "${python_pkg_names[@]}"; do
      json+="\"$pkg_name\","
  done
fi

if [ ${#diracx_and_extensions_pkgs[@]} -gt 0 ]; then
  for diracx_compatible_pkg in "${diracx_and_extensions_pkgs[@]}"; do
    json+="\"$diracx_compatible_pkg\","
  done
fi

json="${json%,}]"
sed "s#{{ mounted_python_modules }}#${json}#g" "${demo_dir}/values.yaml.bak" > "${demo_dir}/values.yaml"
mv "${demo_dir}/values.yaml" "${demo_dir}/values.yaml.bak"

# Add the node package and its workspaces
sed "s#{{ node_module_to_mount }}#${node_pkg_name}#g" "${demo_dir}/values.yaml.bak" > "${demo_dir}/values.yaml"
mv "${demo_dir}/values.yaml" "${demo_dir}/values.yaml.bak"

json="["
if [ ${#node_pkg_workspaces[@]} -gt 0 ]; then
  for workspace in "${node_pkg_workspaces[@]}"; do
    json+="\"$workspace\","
  done
fi
json="${json%,}]"
printf "%b Node workspaces json: %s\n" ${UNICORN_EMOJI} "${json}"
sed "s#{{ node_module_workspaces }}#${json}#g" "${demo_dir}/values.yaml.bak" > "${demo_dir}/values.yaml"
mv "${demo_dir}/values.yaml" "${demo_dir}/values.yaml.bak"


# Generate the static client GUID for Dex
dex_client_uuid=$(uuidgen)
sed "s/{{ dex_client_uuid }}/${dex_client_uuid}/g" "${demo_dir}/values.yaml.bak" > "${demo_dir}/values.yaml"
mv "${demo_dir}/values.yaml" "${demo_dir}/values.yaml.bak"

# Generate the admin account for dex
dex_admin_uuid=$(uuidgen)
sed "s/{{ dex_admin_uuid }}/${dex_admin_uuid}/g" "${demo_dir}/values.yaml.bak" > "${demo_dir}/values.yaml"
# This is how dex generates the sub from a UserID
# https://github.com/dexidp/dex/issues/1719
dex_admin_sub=$(printf '\n$%s\x12\x05local' "${dex_admin_uuid}" | base64 -w 0)


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
  # Disable the strict validation of the path
  # https://github.com/kubernetes/ingress-nginx/issues/11176
  # https://github.com/kubernetes/ingress-nginx/issues/10200
  sed -E 's/^data: null/data:\n  strict-validate-path-type: "false"/g'  "${tmp_dir}/kind-ingress-deploy.yaml" > "${demo_dir}/kind-ingress-deploy.yaml"
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

if [ ${#ci_values_files[@]} -ne 0 ]; then
  printf "%b Adding extra values.yaml: ${ci_values_files[*]} \n" ${UNICORN_EMOJI}
  for ci_values_file in "${ci_values_files[@]}"
  do
    helm_arguments+=("--values" "${ci_values_file}")
  done
fi


# Load images into kind
if [ ${#docker_images_to_load[@]} -ne 0 ]; then
  printf "%b Loading docker images...\n" ${UNICORN_EMOJI}
  for img_name in "${docker_images_to_load[@]}"; do
    "${demo_dir}/kind" --name diracx-demo load docker-image "${img_name}"

    if [[ ${prune_loaded_images:-0} -eq 1 ]]; then
      printf "%b Pruning ${img_name} locally\n" ${UNICORN_EMOJI}
      # Delete the tag (will delete the layers if no other tag is using them)
      docker image rm -f "${img_name}"
    fi
done


fi;

# Set the chart path to use (default to the diracx chart in this repository)
helm_arg_prefix=""
if [[ -z "${chart_path}" ]]; then
  chart_path="${script_dir}/diracx"
else
  printf "%b Auto-indenting generated values into diracx section\n" ${UNICORN_EMOJI}
  # We need to indent all the file under a new "diracx" top section
  # shellcheck disable=SC2016
  "${demo_dir}/yq" eval -i '. as $item ireduce ({}; .diracx += $item )' "${demo_dir}/values.yaml"
  helm_arg_prefix="diracx."
fi

# Set the helm arguments which might need to be prefixed
if [ "${machine_ip}" ]; then
  helm_arguments+=("--set" "${helm_arg_prefix}developer.ipAlias=${machine_ip}")
fi
if [ ${offline_mode} -eq 1 ]; then
  helm_arguments+=("--set" "${helm_arg_prefix}developer.offline=true")
fi
if [ ${enable_coverage} -eq 1 ]; then
  helm_arguments+=("--set" "${helm_arg_prefix}developer.enableCoverage=true")
fi
if [[ -n "${registry_proxy}" ]]; then
  helm_arguments+=("--set" "${helm_arg_prefix}global.images.ghcr_registry=${registry_proxy_github}")
  helm_arguments+=("--set" "${helm_arg_prefix}global.images.dockerhub_registry=${registry_proxy_dockerhub}")
fi

if ! "${demo_dir}/helm" install --debug diracx-demo "${chart_path}" "${helm_arguments[@]}"; then
  printf "%b Error using helm DiracX\n" ${WARN_EMOJI}
  echo "Failed to run \"helm install\"" >> "${demo_dir}/.failed"
else
  printf "%b Waiting for installation to finish...\n" ${UNICORN_EMOJI}
  if "${demo_dir}/kubectl" wait --for=condition=ready pod --selector='app.kubernetes.io/name in (diracx, diracx-web)' --timeout=900s; then
    printf "%b %b %b Pods are ready! %b %b %b\n" "${PARTY_EMOJI}" "${PARTY_EMOJI}" "${PARTY_EMOJI}" "${PARTY_EMOJI}" "${PARTY_EMOJI}" "${PARTY_EMOJI}"

    # Dump the CA certificate to a file so that it can be used by the client
    "${demo_dir}/kubectl" get secret/root-secret -o template --template='{{ index .data "tls.crt" }}' | base64 -d > "${demo_dir}/demo-ca.pem"

    printf "%b Creating initial CS content ...\n" ${UNICORN_EMOJI}
    "${demo_dir}/kubectl" exec deployments/diracx-demo-cli -- bash /entrypoint.sh dirac internal add-vo /cs_store/initialRepo \
     --vo="diracAdmin" \
     --idp-url="http://${machine_hostname}:32002" \
     --idp-client-id="${dex_client_uuid}" \
     --default-group="admin" >> /tmp/init_cs.log

    "${demo_dir}/kubectl" exec deployments/diracx-demo-cli -- bash /entrypoint.sh  dirac internal add-user /cs_store/initialRepo \
     --vo="diracAdmin" \
     --sub="${dex_admin_sub}" \
     --preferred-username="admin" \
     --group="admin" >> /tmp/init_cs.log


    # This file is used by the various CI to test for success
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
