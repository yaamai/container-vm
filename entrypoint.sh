#!/bin/ash -x

BASE_IMAGE_FILE=$(readlink -f $1)
MEMORY=${2:-512}
CPU=${3:-2}

function main() {
  name=$(printf "%s" $HOSTNAME)
  data_dir=${DATA_DIR_BASE:-$PWD/libvirtd}/$name
  mkdir -p $data_dir

  if ! check_file_exists $data_dir/cloud-config.iso; then
    prepare_cloud_config $data_dir/cloud-config.iso
  fi

  if ! check_file_exists $data_dir/instance.qcow2; then
    prepare_image $data_dir/instance.qcow2 $BASE_IMAGE_FILE
  fi

  qemu-system-x86_64 \
    --enable-kvm \
    -drive file=$data_dir/instance.qcow2,format=qcow2 \
    -cdrom $data_dir/cloud-config.iso \
    -display vnc=:0 \
    -m $MEMORY \
    -smp $CPU \
    -daemonize \
    -serial pty 2>&1 | tee /tmp/qemu-$name-stdout.log

  while true; do
    minicom -p $(cat /tmp/qemu-$name-stdout.log | grep -Eo "/dev/pts/[0-9]+")
    if [[ $? -ne 0 ]]; then
      break
    fi
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
  local size=${3:-${VM_DISK_SIZE:-16G}}

  qemu-img create \
    -f qcow2 \
    -o cluster_size=2M \
    -o backing_file=$image \
    $path \
    $size
}

main