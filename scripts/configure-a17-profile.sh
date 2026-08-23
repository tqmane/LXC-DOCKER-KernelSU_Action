#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0
set -euo pipefail

PROFILE="${1:?usage: configure-a17-profile.sh <plain|containers> <kernel-dir> <config-fragment>}"
KERNEL_DIR="${2:?kernel source directory is required}"
CONFIG_FRAGMENT="${3:?config fragment path is required}"
CONFIG_TOOL="$KERNEL_DIR/scripts/config"

if [[ ! -x "$CONFIG_TOOL" ]]; then
  echo "error: kernel scripts/config is missing or not executable: $CONFIG_TOOL" >&2
  exit 1
fi
if [[ ! -f "$CONFIG_FRAGMENT" ]]; then
  echo "error: config fragment does not exist: $CONFIG_FRAGMENT" >&2
  exit 1
fi

case "$PROFILE" in
  plain)
    echo "Plain profile selected: leaving the kernel config unchanged."
    exit 0
    ;;
  containers)
    ;;
  *)
    echo "error: unsupported profile '$PROFILE' (expected plain or containers)" >&2
    exit 2
    ;;
esac

enable() {
  "$CONFIG_TOOL" --file "$CONFIG_FRAGMENT" --enable "$1"
}

# Rootful LXC/Docker namespace and IPC primitives. USER_NS is deliberately
# not forced on: it is not required for rootful containers and broadens the
# Android kernel attack surface.
for symbol in \
  NAMESPACES UTS_NS IPC_NS PID_NS NET_NS POSIX_MQUEUE \
  CGROUPS CGROUP_CPUACCT CGROUP_DEVICE CGROUP_FREEZER CGROUP_PIDS CPUSETS \
  MEMCG BLK_CGROUP CGROUP_BPF \
  SECCOMP SECCOMP_FILTER FHANDLE \
  DEVPTS_MULTIPLE_INSTANCES; do
  enable "$symbol"
done

# Container networking. Keep Android paranoid networking at its source value;
# this profile only adds kernel capabilities and does not weaken Android's
# existing socket policy.
for symbol in \
  VETH BRIDGE BRIDGE_NETFILTER TUN MACVLAN MACVTAP \
  NETFILTER NF_CONNTRACK NETFILTER_XTABLES \
  NETFILTER_XT_MATCH_ADDRTYPE NETFILTER_XT_MATCH_CONNTRACK \
  NETFILTER_XT_MATCH_COMMENT NETFILTER_XT_MATCH_MULTIPORT \
  NETFILTER_XT_TARGET_MASQUERADE \
  IP_NF_IPTABLES IP_NF_FILTER IP_NF_NAT IP_NF_TARGET_MASQUERADE \
  IP6_NF_IPTABLES IP6_NF_FILTER IP6_NF_NAT IP6_NF_TARGET_MASQUERADE; do
  enable "$symbol"
done

# OverlayFS is the supported Docker storage backend. Loop devices are useful
# for images and test guests; no AUFS/Btrfs source patches are downloaded.
for symbol in OVERLAY_FS BLK_DEV_LOOP; do
  enable "$symbol"
done

# arm64 KVM host and accelerated userspace I/O. This only builds host support;
# runtime availability still depends on EL2/firmware ownership on the device.
for symbol in \
  VIRTUALIZATION KVM VHOST VHOST_NET VHOST_VSOCK \
  VHOST_CROSS_ENDIAN_LEGACY; do
  enable "$symbol"
done

# Never re-enable the arm64 ftrace/direct-call path that caused early resets in
# the A17 BPF bring-up. The production branch intentionally keeps it disabled.
"$CONFIG_TOOL" --file "$CONFIG_FRAGMENT" --disable FUNCTION_TRACER

echo "Applied Android 17 containers profile to $CONFIG_FRAGMENT"
grep -E '^(CONFIG_(NAMESPACES|UTS_NS|IPC_NS|PID_NS|NET_NS|CGROUPS|CGROUP_DEVICE|CGROUP_PIDS|MEMCG|SECCOMP_FILTER|VETH|BRIDGE|OVERLAY_FS|VIRTUALIZATION|KVM|VHOST_NET)=|# CONFIG_FUNCTION_TRACER is not set)' \
  "$CONFIG_FRAGMENT" || true
