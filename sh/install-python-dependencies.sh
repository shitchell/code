#!/bin/bash
#
# Install python dependencies in an OS-intelligent way

DISTRIB_NAME=$(
        cat /etc/*-release \
            | grep ^ID= \
            | cut -d= -f2 \
            | tr -d '"' \
            | tr -d "'" \
            | tr '[:upper:]' '[:lower:]'
)
VERSION=$(
        cat /etc/*-release \
            | grep ^VERSION_ID= \
            | cut -d= -f2 \
            | tr -d '"' \
            | tr -d "'" \
            | tr '[:upper:]' '[:lower:]'
)

echo "Installing python dependencies for ${DISTRIB_NAME} ${VERSION}"

cmd=()
packages=()
case "${DISTRIB_NAME}" in
    ubuntu)
        cmd+=("apt" "install" "-y")
        packages+=(
            "build-essential"
            "libbz2-dev"
            "libc6-dev"
            "libffi-dev"
            "libgdbm-dev"
            "libgdbm-compat-dev"
            "libncurses5-dev"
            "libncursesw5-dev"
            "libreadline-dev"
            "libsqlite3-dev"
            "libssl-dev"
            "openssl"
            "tk-dev"
            "xz-utils"
            "zlib1g-dev"
        )
        case "${VERSION}" in
            18* | 20*)
                packages+=("python-dev" "python-smbus" "python-pip" "python-setuptools"
)
                ;;
            22*)
                packages+=("python3-dev" "python3-smbus" "python3-pip" "python3-setuptools")
                ;;
            *)
                echo "Unknown version: ${VERSION}"
                exit 1
                ;;
        esac
        ;;
    centos)
        cmd+=("yum" "install" "-y")
        packages+=(
            "tk-devel"
            "bzip2-devel"
            "db4-devel"
            "gdbm-devel"
            "libffi-devel"
            "libpcap-devel"
            "ncurses-devel"
            "openssl-devel"
            "readline-devel"
            "sqlite-devel"
            "xz-devel"
            "zlib-devel"
        )
        ;;
    *)
        echo "Unknown distribution: ${DISTRIB_NAME}"
        exit 1
        ;;
esac

printf ">" ; printf " %s" "${packages[@]}"
echo
sudo "${cmd[@]}" "${packages[@]}"
