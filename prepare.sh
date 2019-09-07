#!/bin/bash -x

BASE_IMAGE_FILE=$(readlink -f $1)

function main() {
  DATA_DIR=${DATA_DIR_BASE:-$PWD}/$HOSTNAME
  mkdir -p $DATA_DIR

  prepare_cloud_config $DATA_DIR/cloud-config.iso
  prepare_image $DATA_DIR/instance.qcow2 $BASE_IMAGE_FILE
  launch_vm $HOSTNAME $DATA_DIR/instance.qcow2 $DATA_DIR/cloud-config.iso
}

function prepare_cloud_config() {
  local path=$1
  local base_path=$(dirname $path)

  cat >$base_path/meta-data <<EOF
local-hostname: $HOSTNAME
EOF

  cat >$base_path/user-data <<EOF
#cloud-config

password: Passw0rd1234
chpasswd: {expire: False}
ssh_pwauth: True
disable_root: True
EOF

  genisoimage \
    -output $path \
    -volid cidata -joliet -rock $base_path/user-data $base_path/meta-data
}

function prepare_image() {
  local path=$1
  local image=$2
  local size=${3:-5G}

  qemu-img create \
    -f qcow2 \
    -o backing_file=$image \
    $path \
    $size
}

function launch_vm() {
  local name=$1
  local image=$2
  local config_image=$3
  local ram=${4:-1024}
  local cpu=${5:-1}
  local mac=${6:-"02:42:ac:11:00:04"}
  local ip=${7:-"192.168.122.10"}

  virsh net-update default add-last ip-dhcp-host "<host mac='$mac' ip='$ip'/>" --live --config

  virt-install \
    --connect qemu:///system \
    --virt-type kvm \
    --name $name \
    --ram $ram \
    --vcpus=$cpu \
    --os-type linux \
    --disk path=$image,format=qcow2 \
    --disk $config_image,device=cdrom \
    --import \
    --network network=default,mac=$mac \
    --noautoconsole
}

main
