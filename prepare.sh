#!/bin/bash -x

BASE_IMAGE_FILE=$(readlink -f $1)
NUM_OF_VM=${2:-1}

function main() {
  [[ ! -e $BASE_IMAGE_FILE ]] && ( echo "Image not found"; exit 1 )

  wait_libvirtd

  for ((num=1; num<$((NUM_OF_VM+1)); num++)); do
    name=$(printf "%s-%02d" $HOSTNAME $num)
    data_dir=${DATA_DIR_BASE:-$PWD/libvirtd}/$name
    mkdir -p $data_dir

    if ! check_file_exists $data_dir/cloud-config.iso; then
      prepare_cloud_config $data_dir/cloud-config.iso
    fi

    if ! check_file_exists $data_dir/instance.qcow2; then
      prepare_image $data_dir/instance.qcow2 $BASE_IMAGE_FILE
    fi

    # expect vm-definition not persisteed
    launch_vm \
      $name \
      $data_dir/instance.qcow2 \
      $data_dir/cloud-config.iso \
      $(printf "02:42:ac:11:00:%02d" $num) \
      $(printf "192.168.122.%s" $num)

  done
}

function wait_libvirtd() {
  cnt=0
  while [[ $cnt -lt 10 ]]; do
    virsh list
    [[ $? -eq 0 ]] && break
    sleep 3
    cnt=$((cnt + 1))
  done
}

function check_file_exists() {
  local path=$1
  if [[ -e $path ]]; then
    true; return $?
  fi

  false; return $?
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
  local mac=${4:-"02:42:ac:11:00:04"}
  local ip=${5:-"192.168.122.10"}
  local ram=${6:-1024}
  local cpu=${7:-1}

  virsh net-update default delete ip-dhcp-host "<host mac='$mac' ip='$ip'/>" --live --config || true
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
