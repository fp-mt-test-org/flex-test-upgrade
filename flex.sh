#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

echo ""
echo "CURRENT DIR:"
pwd
echo ""

auto_update="${auto_update:-0}"
flex_install_path='./.flex'
flex_binary_path="${flex_install_path}/flex"
flex_version_command="${flex_binary_path} -version"
service_config_path='./service_config.yml'
should_install_flex="0"

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

    if [ "${auto_clean:=0}" == "1" ]; then
        echo "Cleaning up ${download_file_path}"
        rm -fdr "${download_file_path}"
    fi

    echo "Installation complete!"
    echo ""
}

if ! [[ -d "${flex_install_path}" ]]; then
    echo "${flex_install_path} not found, will install flex!"
    should_install_flex="1"
fi

if [[ "${should_install_flex}" == "1" ]]; then
    install_flex
fi

initial_flex_version=$(${flex_version_command})

# Check the service_config, if it exists (i.e. is not first run of flex)
if [[ "${auto_update}" == "1" ]] && [[ -f "${service_config_path}" ]]; then
    service_config=$(cat ${service_config_path})

    if [[ "${service_config}" =~ [0-9]+.[0-9]+.[0-9]+ ]]; then
        configured_flex_version="${BASH_REMATCH[0]}"
        echo "service_config: flex: version: ${configured_flex_version}"

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

echo "PARAMS:"
echo "$@"
echo ""

"${flex_binary_path}" "$@"
