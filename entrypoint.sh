#!/bin/ash -x

BASE_IMAGE_FILE=$(readlink -f $1)
MEMORY=${2:-512}
CPU=${3:-2}
shift 3;

function main() {
  name=$(printf "%s" $HOSTNAME)
  data_dir=${DATA_DIR_BASE:-$PWD/vms}/$name
  mkdir -p $data_dir

  prepare_cloud_config $data_dir/cloud-config.iso "$@"
  if ! check_file_exists $data_dir/cloud-config.iso; then
    prepare_cloud_config $data_dir/cloud-config.iso "$@"
  fi

  if ! check_file_exists $data_dir/instance.qcow2; then
    prepare_image $data_dir/instance.qcow2 $BASE_IMAGE_FILE
  fi

  qemu-system-x86_64 \
    --enable-kvm \
    -object iothread,id=io1 \
    -device virtio-blk-pci,drive=disk0,iothread=io1 \
    -drive if=none,id=disk0,cache=none,format=qcow2,aio=threads,file=$data_dir/instance.qcow2 \
    -cdrom $data_dir/cloud-config.iso \
    -nic user,hostfwd=tcp::22-:22,smb=$PWD \
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
  shift 1
  local base_path=$(dirname $path)

  cat >$base_path/meta-data <<EOF
local-hostname: $HOSTNAME
EOF

  if [[ ${#} -gt 0 ]]; then
    local FILE_LIST=""
    for f in "$@"; do
      case $f in
        *cloud-config*) FILE_LIST="$FILE_LIST $f:text/cloud-config";;
        *) FILE_LIST="$FILE_LIST $f:text/x-shellscript";;
      esac
    done

    write-mime-multipart \
      --output $base_path/user-data \
      $FILE_LIST
  else
    cat >$base_path/user-data <<EOF
#cloud-config

password: Passw0rd1234
chpasswd: {expire: False}
ssh_pwauth: True
disable_root: True
EOF
  fi

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

main "$@"
