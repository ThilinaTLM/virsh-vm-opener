#!/bin/bash

SOURCE="./virt-opener.sh"
DESTINATION="/usr/local/bin/virt-opener"

function install() {
    printf "Copying virt-opener to $DESTINATION\n"
    sudo cp $SOURCE $DESTINATION
    sudo chmod +x $DESTINATION
}

function uninstall() {
    printf "Removing virt-opener from $DESTINATION\n"
    sudo rm $DESTINATION
}

function create_desktop_entry() {
    printf "Creating desktop entry\n"
    sudo tee "/usr/share/applications/virt-opener-$1.desktop" <<EOF
[Desktop Entry]
Encoding=UTF-8
Version=1.0
Type=Application
Terminal=false
Exec=pkexec env DISPLAY=\$DISPLAY XAUTHORITY=\$XAUTHORITY /usr/bin/virt-opener $1 --network $2
Name=Open Virtual Machine $1
Icon=windows
EOF
}

# Check if virt-opener is already installed
if [ -f "$DESTINATION" ]; then
    echo "virt-opener is already installed"
    printf "Do you want to reinstall it? [y/N] "
    read -r answer
    if [ "$answer" != "${answer#[Yy]}" ]; then
        install
    fi
else
    install
fi

printf "Do you want to create a desktop entry for virt-opener? [y/N] "
read -r answer
if [ "$answer" != "${answer#[Yy]}" ]; then
    printf "Enter the name of the virtual machine: "
    read -r vm
    printf "Enter the network name [default]: "
    read -r network
    if [ -z "$network" ]; then
        network="default"
    fi
    create_desktop_entry $vm $network
fi

