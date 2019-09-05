#!/bin/bash -x

BASE_IMAGE_FILE=$1
DATA_DIR_BASE=${DATA_DIR_BASE:-/data/libvirt}
DATA_DIR=$DATA_DIR_BASE/$HOSTNAME
IMAGE_FILE=$DATA_DIR/instance.qcow2
CONFIG_ISO_FILE=$DATA_DIR/config.iso

mkdir -p $DATA_DIR
qemu-img create \
  -f qcow2 \
  -o backing_file=$BASE_IMAGE_FILE \
  $IMAGE_FILE \
  5G

cat >$DATA_DIR/meta-data <<EOF
local-hostname: $HOSTNAME
EOF

cat >$DATA_DIR/user-data <<EOF
#cloud-config

password: Passw0rd1234
chpasswd: {expire: False}
ssh_pwauth: True
EOF
#disable_root: true

genisoimage \
  -output $CONFIG_ISO_FILE \
  -volid cidata -joliet -rock $DATA_DIR/user-data $DATA_DIR/meta-data

ip link add $LIBVIRTD_DEFAULT_NETWORK_DEVICE type bridge
virt-install \
  --connect qemu:///system \
  --virt-type kvm \
  --name $HOSTNAME \
  --ram 1024 \
  --vcpus=1 \
  --os-type linux \
  --os-variant ubuntu16.04 \
  --disk path=$IMAGE_FILE,format=qcow2 \
  --disk $CONFIG_ISO_FILE,device=cdrom \
  --import \
  --network network=default \
  --noautoconsole
