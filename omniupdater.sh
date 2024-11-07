#!/bin/bash

# Function to check for root privileges
function check_root() {
    if [[ "$EUID" -ne 0 ]]; then
        echo "This script requires root privileges. Please run it as root or with sudo."
        exit 1
    fi
}

function snap_install() {
    if ! command -v snap &> /dev/null; then
        echo "Snap is not installed. Installing Snap..."
        git clone https://aur.archlinux.org/snapd.git
        cd snapd || exit 1
        makepkg -si
        systemctl enable --now snapd.socket
        systemctl enable --now snapd.apparmor.service
        ln -s /var/lib/snapd/snap /snap
        cd .. || exit 1
        rm -rf snapd
    fi

    if snap install "$1"; then
        echo "$1 has been installed successfully with Snapcraft."
    else
        echo "$1 has FAILED to get installed with Snapcraft."
        return 1
    fi
}

function pacman_install() {
    if pacman -S --noconfirm "$1"; then
        echo "$1 has been installed successfully with Pacman."
    else
        echo "$1 has FAILED to get installed with Pacman."
        return 1
    fi
}

function yay_install() {
    if ! command -v yay &> /dev/null; then
        echo "Yay is not installed. Installing Yay..."
        git clone https://aur.archlinux.org/yay.git
        cd yay || exit 1
        makepkg -si
        cd .. || exit 1
        rm -rf yay
    fi

    if yay -S --noconfirm "$1"; then
        echo "$1 has been installed successfully with Yay."
    else
        echo "$1 has FAILED to get installed with Yay."
        return 1
    fi
}

function apt_install() {
    if ! command -v apt &> /dev/null; then
        echo "Apt is not available on this system. Skipping..."
        return 1
    fi

    if apt-get install -y "$1"; then
        echo "$1 has been installed successfully with Apt."
    else
        echo "$1 has FAILED to get installed with Apt."
        return 1
    fi
}

function global_installation() {
    echo "Attempting to install $1 with Snap..."
    if snap_install "$1"; then return 0; fi

    echo "Attempting to install $1 with Pacman..."
    if pacman_install "$1"; then return 0; fi

    echo "Attempting to install $1 with Yay..."
    if yay_install "$1"; then return 0; fi

    echo "Attempting to install $1 with Apt..."
    if apt_install "$1"; then return 0; fi

    echo "Installation of $1 FAILED with all package managers."
    return 1
}

# Function to check for and perform an upgrade if a newer version exists
function upgrade() {
    TEMP_DIR=$(mktemp -d)
    CURRENT_VER=$(cat /usr/local/bin/omnipkg/version.txt)
    
    # Fetch the latest version.txt from the raw GitHub URL
    wget -O "$TEMP_DIR/version.txt" https://raw.githubusercontent.com/devtracer/Omnipkg/main/version.txt
    
    LATEST_VER=$(cat "$TEMP_DIR/version.txt")
    if [[ "$CURRENT_VER" != "$LATEST_VER" ]]; then
        echo "New version detected. Upgrading Omnipkg..."
        git clone https://github.com/devtracer/Omnipkg.git "$TEMP_DIR/Omnipkg"
        cd "$TEMP_DIR/Omnipkg" || exit 1
        chmod +x omniupdater.sh
        ./omniupdater.sh
        echo "Omnipkg has been updated to version $LATEST_VER."
    else
        echo "You're using the latest version of Omnipkg."
    fi
    
    # Cleanup
    rm -rf "$TEMP_DIR"
}

function update_all() {
    echo "Updating all packages with Snap, Pacman, Yay, and Apt..."

    if command -v snap &> /dev/null; then
        echo "Updating Snap packages..."
        snap refresh
    fi

    echo "Updating Pacman packages..."
    pacman -Syu --noconfirm

    if command -v yay &> /dev/null; then
        echo "Updating Yay packages..."
        yay -Syu --noconfirm
    fi

    if command -v apt &> /dev/null; then
        echo "Updating Apt packages..."
        apt-get update && apt-get upgrade -y
    fi

    echo "All packages have been updated successfully."
}

function Omnipkg() {
    case "$1" in
        "-a")
            global_installation "$2" && echo "Installation of $2 completed successfully!"
            ;;
        "-u")
            update_all
            ;;
        "-ug")
            upgrade
            ;;
        *)
            echo "Usage: $0 -a <package_name> | -u (to update all packages) | -ug (to upgrade Omnipkg)"
            ;;
    esac
}

check_root
Omnipkg "$@"
