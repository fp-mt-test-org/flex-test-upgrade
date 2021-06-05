#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

# echo ""
# echo "CURRENT DIR:"
# pwd
# echo ""
# echo "PARAMS:"
# echo "$@"
# echo ""

auto_update="${auto_update:-0}"
flex_install_path='./.flex'
flex_binary_path="${flex_install_path}/flex"
flex_version_command="${flex_binary_path} -version"
service_config_path='./service_config.yml'

install_flex() {
    version_to_install="${1:-latest}"
    skip_download=${skip_download:=0}
    download_folder_path="${download_folder_path:=$(realpath dist)}"
    install_folder_name='.flex'
    install_path="${install_path:=$(realpath ${install_folder_name})}"
    user_scripts_install_path="${install_path}/scripts/user"

    echo "Installing flex version $version_to_install!"

    # Generate the platform specific file name to download.
    os=$(uname | tr '[:upper:]' '[:lower:]')
    file_name="flex_${os}_amd64.tar.gz"
    base_url='https://github.com/fp-mt/flex/releases'
    if [[ "${version_to_install}" == "latest" ]]; then
        url="${base_url}/latest/download/${file_name}"
    else
        url="${base_url}/download/v${version_to_install}/${file_name}"
    fi

    mkdir -p "${install_path}"
    mkdir -p "${download_folder_path}"

    download_file_path="${download_folder_path}/${file_name}"

    if [ "${skip_download}" -ne "1" ]; then
        echo "Downloading ${url} to ${download_file_path}"
        curl -L "${url}" --output "${download_file_path}"
    fi

    echo "Extracting ${download_file_path} to ${install_path}"
    tar -xvf "${download_file_path}" -C "${install_path}"

    echo "Copying flex wrapper to repo root..."
    cp "${user_scripts_install_path}/flex.sh" .

    git_ignore_file='.gitignore'

    if ! grep -qs "${install_folder_name}" "${git_ignore_file}"; then
        echo "Updating ${git_ignore_file} to ignore the ${install_path} install_path..."
        echo "${install_folder_name}" >> "${git_ignore_file}"
    fi

    echo "Configuring the local host..."
    "${user_scripts_install_path}/configure-localhost.sh"

    if [ "${auto_clean:=1}" == "1" ]; then
        echo "Cleaning up ${download_file_path}"
        rm -fdr "${download_file_path}"
    fi

    echo "Installation complete!"
    echo ""
}

get_configured_version() {
    service_config_content=$(cat ${service_config_path})

    if [[ "${service_config_content}" =~ [0-9]+.[0-9]+.[0-9]+ ]]; then
        flex_version="${BASH_REMATCH[0]}"
        echo "${flex_version}"
    else
        echo "ERROR: Version not found!"
        exit 1
    fi
}

#echo "Checking if Flex needs to be installed, updated or initialized..."

if ! [[ -d "${flex_install_path}" ]]; then
    #echo "${flex_install_path} not found locally, Flex needs to be installed."
    should_install_flex="1"
fi

if [[ -f "${service_config_path}" ]]; then
    #echo "${service_config_path} exists!"
    #echo "Flex has been previously initialized for this repo, reading flex version..."
    version_to_install=$(get_configured_version)
    #echo "Configured version is ${version_to_install}"
else
    if [[ "$1" != "init" ]]; then
        echo "${service_config_path} doesn't exist, to initialize please run: flex init"
        exit 1
    fi
fi

if [[ "${should_install_flex:=0}" == "1" ]]; then
    install_flex "${version_to_install:=latest}"
fi

#echo "Getting current flex version with: ${flex_version_command}"

initial_flex_version=$(${flex_version_command})

#echo "initial_flex_version: ${initial_flex_version}"

# Check the service_config, if it exists (i.e. is not first run of flex)
if [[ "${auto_update}" == "1" ]] && [[ -f "${service_config_path}" ]]; then
    service_config=$(cat ${service_config_path})

    if [[ "${service_config}" =~ [0-9]+.[0-9]+.[0-9]+ ]]; then
        configured_flex_version="${BASH_REMATCH[0]}"
        #echo "service_config: flex: version: ${configured_flex_version}"

        # Regex for matching snapshot versions such as v0.8.3-SNAPSHOT-27afad4
        configured_flex_version_regex=".*${configured_flex_version}.*"

        if ! [[ "${initial_flex_version}" =~ ${configured_flex_version_regex} ]]; then
            echo "Current version is different than configured, upgrading..."
            install_flex "${configured_flex_version}"
            echo "Current version is now:"
            ${flex_version_command}
            echo "Upgrade complete."
        fi
    fi
fi

"${flex_binary_path}" "$@"
