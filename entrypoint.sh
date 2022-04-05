#!/bin/ash -x

BASE_IMAGE_FILE=$(readlink -f "${1:-${VM_IMAGE:-""}}")
MEMORY=${2:-${VM_MEMORY:-512}}
CPU=${3:-${VM_CPU:-2}}
CLOUD_CONFIG=${4:-${VM_CLOUD_CONFIG:-""}}
SCRIPT=${5:-${VM_SCRIPT:-""}}
BRIDGE=${6:-${VM_BRIDGE:-""}}
BRIDGE_PXE=${7:-${VM_BRIDGE_PXE:-""}}
ASSIGN_PORTS=${8:-${VM_ASSIGN_PORTS:-""}}

main() {
  name=$(printf "%s" "$(hostname -s)")
  data_dir=${DATA_DIR_BASE:-$PWD/vms}/$name
  mkdir -p "$data_dir"

  prepare_cloud_config "$name" "$data_dir/cloud-config.iso" "$CLOUD_CONFIG" "$SCRIPT"

  if ! check_file_exists "$data_dir/instance.qcow2"; then
    prepare_image "$data_dir/instance.qcow2" "$BASE_IMAGE_FILE" "${VM_DISK_SIZE:-16G}"
  fi

  local vnc_port=":0"
  local ssh_port="22"
  if [ -n "$ASSIGN_PORTS" ]; then
    local number=$(get_hostname_number $name)
    vnc_port=":$(($number + 10000))"
    ssh_port="$(($number + 10022))"
  fi

  (
    echo \
      --enable-kvm \
      -m "$MEMORY" \
      -smp "$CPU" \
      -daemonize \
      -serial pty \
      -display vnc=$vnc_port
    echo \
      -object iothread,id=io1 \
      -device virtio-blk-pci,drive=disk0,iothread=io1 \
      -drive "if=none,id=disk0,cache=none,format=qcow2,aio=threads,file=$data_dir/instance.qcow2" \
      -cdrom "$data_dir/cloud-config.iso"
    echo \
      -netdev "user,id=net0,net=192.168.101.0/24,dhcpstart=192.168.101.100,hostname=$name,hostfwd=tcp::$ssh_port-:22,smb=$PWD" \
      -device "virtio-net-pci,netdev=net0"
    if [ -n "$BRIDGE" ]; then
      echo -netdev "bridge,id=net1,br=$BRIDGE"
      if [ -n "$BRIDGE_PXE" ]; then
        echo \
          -device "virtio-net-pci,netdev=net1,bootindex=1" \
          -boot n
      else
        echo -device "virtio-net-pci,netdev=net1"
      fi
    fi
  ) | xargs -t qemu-system-x86_64 2>&1 | tee "/tmp/qemu-$name-stdout.log"

  wait_with_picom "$name"
}

wait_with_picom() {
  local name=$1

  while true; do
    pty="$(grep -Eo '/dev/pts/[0-9]+' < "/tmp/qemu-$name-stdout.log")"
    if [ ! -e "$pty" ]; then
      break
    fi
    if picocom "$pty"; then
      break
    fi
  done
}

get_hostname_number() {
  local name=$1

  local n=$(echo $name | tr -cd 0-9)
  if [ -n "$n" ]; then
    echo $n
  else
    local t=$(printf "%d" "0x$(echo $name | sha1sum | cut -c1-2)")
    # avoid overlap direct specified number
    echo $(($t + 10))
  fi
}

check_file_exists() {
  local path=$1
  if [ -e "$path" ]; then
    true; return $?
  fi

  false; return $?
}

prepare_cloud_config() {
  local name=$1
  local path=$2
  local cloud_config=$3
  local script=$4
  local base_path
  base_path="$(dirname "$path")"

  cat > "$base_path/meta-data" <<EOF
local-hostname: $name
EOF

  if [ -n "$cloud_config" ]; then
    cp -f "$cloud_config" "$base_path/cloud-config"
  else
    cat > "$base_path/cloud-config" <<EOF
#cloud-config

password: Passw0rd1234
chpasswd: {expire: False}
ssh_pwauth: True
disable_root: True
EOF
  fi

  if [ -n "$script" ]; then
    cp -f "$script" "$base_path/script"
    python2 /usr/local/bin/write-mime-multipart \
      --output "$base_path/user-data" \
      "$base_path/cloud-config:text/cloud-config" \
      "$base_path/script:text/x-shellscript"
  else
    cp -f "$base_path/cloud-config" "$base_path/user-data"
  fi

  genisoimage \
    -output "$path" \
    -volid cidata -joliet -rock "$base_path/user-data" "$base_path/meta-data"
}

prepare_image() {
  local path=$1
  local image=$2
  local size=$3

  if [ -n "$image" ]; then
    qemu-img create \
      -f qcow2 \
      -F qcow2 \
      -o cluster_size=2M \
      -o "backing_file=$image" \
      "$path" \
      "$size"
  else
    qemu-img create \
      -f qcow2 \
      -o cluster_size=2M \
      "$path" \
      "$size"
  fi
}

main "$@"
