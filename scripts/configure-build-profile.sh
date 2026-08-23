#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <config-fragment> <plain|containers>" >&2
  exit 2
fi

fragment="$1"
profile="$2"

if [[ ! -f "$fragment" ]]; then
  echo "config fragment not found: $fragment" >&2
  exit 1
fi

set_y() {
  local symbol="$1"
  sed -i -E "/^${symbol}=|^# ${symbol} is not set$/d" "$fragment"
  printf '%s=y\n' "$symbol" >> "$fragment"
}

set_n() {
  local symbol="$1"
  sed -i -E "/^${symbol}=|^# ${symbol} is not set$/d" "$fragment"
  printf '# %s is not set\n' "$symbol" >> "$fragment"
}

case "$profile" in
  plain)
    echo "plain profile: leaving the kernel config fragment unchanged"
    exit 0
    ;;
  containers)
    ;;
  *)
    echo "unsupported build profile: $profile" >&2
    exit 2
    ;;
esac

# Android-safe LXC/Docker baseline. Deliberately do not enable
# FAIR_GROUP_SCHED, RT_GROUP_SCHED or SCHED_AUTOGROUP and do not disable WALT:
# those scheduler changes are not required for basic containers and previously
# made this vendor kernel unstable.
container_symbols=(
  CONFIG_NAMESPACES
  CONFIG_UTS_NS
  CONFIG_IPC_NS
  CONFIG_PID_NS
  CONFIG_NET_NS
  CONFIG_USER_NS
  CONFIG_CHECKPOINT_RESTORE
  CONFIG_SYSVIPC
  CONFIG_POSIX_MQUEUE
  CONFIG_CGROUPS
  CONFIG_CGROUP_CPUACCT
  CONFIG_CGROUP_DEVICE
  CONFIG_CGROUP_FREEZER
  CONFIG_CGROUP_SCHED
  CONFIG_CGROUP_PIDS
  CONFIG_CPUSETS
  CONFIG_MEMCG
  CONFIG_MEMCG_SWAP
  CONFIG_BLK_CGROUP
  CONFIG_CGROUP_BPF
  CONFIG_CGROUP_NET_CLASSID
  CONFIG_CGROUP_NET_PRIO
  CONFIG_NET_CLS_CGROUP
  CONFIG_BPF
  CONFIG_BPF_SYSCALL
  CONFIG_SECCOMP
  CONFIG_SECCOMP_FILTER
  CONFIG_FHANDLE
  CONFIG_KEYS
  CONFIG_DEVTMPFS
  CONFIG_DEVTMPFS_MOUNT
  CONFIG_PACKET
  CONFIG_PACKET_DIAG
  CONFIG_UNIX
  CONFIG_UNIX_DIAG
  CONFIG_NETLINK_DIAG
  CONFIG_INET_DIAG
  CONFIG_NETFILTER
  CONFIG_NF_CONNTRACK
  CONFIG_NF_NAT
  CONFIG_NETFILTER_XTABLES
  CONFIG_NETFILTER_XT_MATCH_ADDRTYPE
  CONFIG_NETFILTER_XT_MATCH_CONNTRACK
  CONFIG_NETFILTER_XT_MATCH_BPF
  CONFIG_NETFILTER_XT_MATCH_MULTIPORT
  CONFIG_NETFILTER_XT_TARGET_CHECKSUM
  CONFIG_IP_NF_IPTABLES
  CONFIG_IP_NF_FILTER
  CONFIG_IP_NF_NAT
  CONFIG_IP_NF_TARGET_MASQUERADE
  CONFIG_IP6_NF_IPTABLES
  CONFIG_IP6_NF_FILTER
  CONFIG_IP6_NF_NAT
  CONFIG_IP6_NF_TARGET_MASQUERADE
  CONFIG_BRIDGE
  CONFIG_BRIDGE_NETFILTER
  CONFIG_BRIDGE_VLAN_FILTERING
  CONFIG_VETH
  CONFIG_TUN
  CONFIG_DUMMY
  CONFIG_MACVLAN
  CONFIG_IPVLAN
  CONFIG_VXLAN
  CONFIG_NET_L3_MASTER_DEV
  CONFIG_OVERLAY_FS
  CONFIG_VIRTUALIZATION
  CONFIG_KVM
  CONFIG_VHOST_NET
)

for symbol in "${container_symbols[@]}"; do
  set_y "$symbol"
done

# Rootful containers create sockets outside Android's AID group model.
set_n CONFIG_ANDROID_PARANOID_NETWORK

# OverlayFS is the supported Docker storage driver for this profile. Avoid
# forcing large optional filesystems that have caused build/boot regressions.
set_n CONFIG_AUFS_FS
set_n CONFIG_BTRFS_FS

cat <<EOF
containers profile applied to: $fragment
  - LXC namespaces/cgroup v1 support
  - Docker bridge/NAT/veth/OverlayFS support
  - arm64 KVM and vhost-net support
  - Android paranoid-network restriction disabled
  - vendor WALT scheduler configuration preserved
EOF
