#!/bin/bash

set -e

# 定义要检查的Skopeo版本和归档文件
SKOPEO_VERSION="v1.11.1"
SKOPEO_ARCHIVE="skopeo-${SKOPEO_VERSION}-linux-$(uname -m).tar.gz"
SKOPEO_TARGET_DIR="/usr/bin"

# 检查skopeo命令是否存在
if command -v skopeo &> /dev/null
then
    echo "skopeo is already installed."
else
    echo "skopeo is not installed. Checking for the archive file..."
    # 检查归档文件是否存在
    if [ -f "$SKOPEO_ARCHIVE" ]; then
        echo "Archive file $SKOPEO_ARCHIVE found. Extracting to $SKOPEO_TARGET_DIR..."
        # 解压归档文件到/usr/bin
        if sudo tar -zxf "$SKOPEO_ARCHIVE" -C "$SKOPEO_TARGET_DIR"
        then
            echo "skopeo has been installed successfully."
        else
            echo "Failed to install skopeo from archive."
            exit 1
        fi
    else
        echo "Archive file $SKOPEO_ARCHIVE does not exist. Cannot install skopeo."
        exit 1
    fi
fi

POSITIONAL=()

while [[ $# -gt 0 ]]
do
    key="$1"
    case $key in
        -s|--src)
            src="$2"
            shift
            shift
            ;;
        -su|--srcUser)
            srcUser="$2"
            shift
            shift
            ;;
        -d|--dst)
            dst="$2"
            shift
            shift
            ;;
        -du|--dstUser)
            dstUser="$2"
            shift
            shift
            ;;
        -a|--arch)
            arch="$2"
            shift
            shift
            ;;
        -f|--file)
            imageFile="$2"
            shift
            shift
            ;;
        -h|--help)
            echo "Usage: ./skopeoer.sh [flags [options]]..."
            echo
            echo "Available Flags:"
            echo "  -a, --arch: image architecture: arm64/amd64/all"
            echo "  -d, --dst: destination warehouse image name"
            echo "  -f, --file = true: push files to the repository"
            echo "  -du, --dst-user: use USERNAME[:PASSWORD] for accessing the registry"
            echo "  -s, --src: source warehouse image name"
            echo "  -su, --src-user: use USERNAME[:PASSWORD] for accessing the registry"
            echo "  -h, --help: print this help message"
            echo
            exit 0
            ;;
        *)
            POSITIONAL+=("$1")
            shift
            ;;
    esac
done

set -- "${POSITIONAL[@]}"

function image() {
    for image in "$@"
    do
        if echo "$image" | grep -q '/'; then
            if echo "${image%%/*}" | grep -q '\.'; then
                echo "$image"
            else
                echo "docker.io/$image"
            fi
        else
            echo "docker.io/library/$image"
        fi
    done
}

function images() {
    all_images=()

    if [[ "${file}" != "" ]] && [ -f "${file}" ]; then
        files=$(cat "$file")
        for image in $files; do
            all_images+=("$(image "$image" | sed 's/"//g')")
        done
    fi

    if [[ "${images}" != "" ]]; then
        for image in $images; do
            all_images+=("$(image "$image" | sed 's/"//g')")
        done
    fi

    echo "${all_images[@]}"
}

export IFS=$'\n\t, '

if [[ "$src" == "" ]]; then
    echo "Source warehouse image name is required:"
    echo "Use \"-h|--help\" for more information about this command."
    exit 1
fi

if [[ "$dst" == "" ]]; then
    echo "Destination warehouse image name is required:"
    echo "Use \"-h|--help\" for more information about this command."
    exit 1
fi

if [[ -n "$srcUser" ]]; then
    srcCreds="--screds $srcUser"
fi

if [[ -n "$dstUser" ]]; then
    dstCreds="--dcreds $dstUser"
fi

if [[ "${imageFile}" != "" ]];then
    if [[ "${arch}" != "" ]]; then
        if [[ "${arch}" != "all" ]]; then
            skopeo --override-arch $arch copy --src-tls-verify=false --dest-tls-verify=false --insecure-policy $srcCreds $dstCreds docker-archive:${imageFile}:$src docker://$dst
        else
            skopeo copy --multi-arch all --src-tls-verify=false --dest-tls-verify=false --insecure-policy $srcCreds $dstCreds docker-archive:${imageFile}:$src docker://$dst
        fi
    else
        skopeo copy --src-tls-verify=false --dest-tls-verify=false --insecure-policy $srcCreds $dstCreds docker://$src docker://$dst
    fi
else
    if [[ "${arch}" != "" ]]; then
        if [[ "${arch}" != "all" ]]; then
            skopeo --override-arch $arch copy --src-tls-verify=false --dest-tls-verify=false --insecure-policy $srcCreds $dstCreds docker://$src docker://$dst
        else
            skopeo copy --multi-arch all --src-tls-verify=false --dest-tls-verify=false --insecure-policy $srcCreds $dstCreds docker://$src docker://$dst
        fi
    else
        skopeo copy --src-tls-verify=false --dest-tls-verify=false --insecure-policy $srcCreds $dstCreds docker://$src docker://$dst
    fi
fi
