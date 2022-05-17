#!/bin/sh

function exit_if_error() {
    if [ $? -ne 0 ]; then
        echo "Error: $1"
        exit 1
    fi
}

# parse command line arguments 
while [ "$1" != "" ]; do
    case $1 in
        --network )
            shift
            NET_NAME=$1
            ;;
        * )
            if [ -z "$VM_NAME" ]; then
                VM_NAME=$1
            else
                echo "Unknown argument: $1"
                exit 1
            fi
            VM_NAME=$1
            ;;
    esac
    shift
done

if [ -z "$VM_NAME" ]; then
    echo "usage: ./opener.sh [vm-name] --network=<network>"
    exit 1
fi

if [ -z "$NET_NAME" ]; then
    NET_NAME=default
fi

# check libvirtd status 
if [ `systemctl is-active libvirtd` != "active" ]; then
    printf "starting libvirtd service\n"
    systemctl start libvirtd
    exit_if_error "failed to start libvirtd service"
fi

# start net if not exist
if [ `virsh net-list | grep $NET_NAME | wc -l` -eq 0 ]; then
    printf "creating network $NET_NAME\n"
    virsh net-start $NET_NAME
    exit_if_error "failed to start network $NET_NAME"
fi

# start vm if not running
if [ -z "$(virsh list --state-running | grep $VM_NAME)" ]; then
    printf "Starting $VM_NAME...\n"
    virsh start $VM_NAME
    exit_if_error "failed to start $VM_NAME"
fi

# open virtual machine using virt-viewer
printf "Opening $VM_NAME...\n"
virt-viewer --full-screen -w -a $VM_NAME

zenity --question --title="Virt Opener" --text "Do you want to stop completely?" --ok-label="Yes" --cancel-label="No"
if [ $? -ne 0 ]; then
    exit 0
fi

# if vm is running then stop it
if [ -n "$(virsh list --state-running | grep $VM_NAME)" ]; then
    printf "Stopping $VM_NAME...\n"
    virsh shutdown $VM_NAME
    exit_if_error "failed to stop $VM_NAME"
    # wait for vm to stop
    start_time=$(date +%s)
    while [ -n "$(virsh list --state-running | grep $VM_NAME)" ]; do
        sleep 1
        if [ $(($(date +%s) - $start_time)) -gt 60 ]; then
            printf  "$VM_NAME is still running after 60 seconds,\n"
            zeity --question --title="Virt Opener" --text "Do you want to stop forcefully" --ok-label="Stop" --cancel-label="No"
            if [ $? -ne 0 ]; then
                exit 0
            fi
            printf "Stopping $VM_NAME forcefully...\n"
            virsh destroy $VM_NAME
            exit_if_error "failed to stop $VM_NAME"
            start_time=$(date +%s)
        fi
    done
fi

# if no other vm is running then stop net 
if [ `virsh list --state-running | grep $VM_NAME | wc -l` -eq 0 ]; then
    printf "Stopping network $NET_NAME\n"
    virsh net-destroy $NET_NAME
    exit_if_error "failed to stop network $NET_NAME"
fi

# if no other vm is running then stop libvirtd
if [ `virsh list --state-running | grep $VM_NAME | wc -l` -eq 0 ]; then
    printf "Stopping libvirtd service\n"
    systemctl stop libvirtd-admin.socket
    systemctl stop libvirtd.socket
    systemctl stop libvirtd-ro.socket
    systemctl stop libvirtd.service
fi

