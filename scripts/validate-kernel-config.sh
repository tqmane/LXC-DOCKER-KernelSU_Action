#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <final-.config> <plain|containers>" >&2
  exit 2
fi

config="$1"
profile="$2"

if [[ ! -f "$config" ]]; then
  echo "final kernel config not found: $config" >&2
  exit 1
fi

failures=0

require_y() {
  local symbol="$1"
  if grep -qx "${symbol}=y" "$config"; then
    printf 'ok: %s=y\n' "$symbol"
  else
    printf 'error: expected %s=y\n' "$symbol" >&2
    grep -E "^${symbol}=|^# ${symbol} is not set$" "$config" >&2 || true
    failures=$((failures + 1))
  fi
}

require_n() {
  local symbol="$1"
  if grep -qx "# ${symbol} is not set" "$config"; then
    printf 'ok: %s is disabled\n' "$symbol"
  else
    printf 'error: expected %s to be disabled\n' "$symbol" >&2
    grep -E "^${symbol}=|^# ${symbol} is not set$" "$config" >&2 || true
    failures=$((failures + 1))
  fi
}

common_required=(
  CONFIG_BPF
  CONFIG_BPF_SYSCALL
  CONFIG_BPF_JIT
  CONFIG_BPF_JIT_ALWAYS_ON
  CONFIG_BPF_LSM
  CONFIG_DEBUG_INFO
  CONFIG_DEBUG_INFO_BTF
  CONFIG_CFI_CLANG
  CONFIG_SHADOW_CALL_STACK
)

for symbol in "${common_required[@]}"; do
  require_y "$symbol"
done

# The boot-tested Android 17 production profile intentionally keeps function
# tracing disabled. Re-enabling it also enables the unverified arm64 direct
# trampoline path and must not happen as a side effect of a container build.
require_n CONFIG_FUNCTION_TRACER

lsm_value="$(sed -n 's/^CONFIG_LSM="\(.*\)"$/\1/p' "$config")"
if [[ ",${lsm_value}," == *,bpf,* ]]; then
  echo "ok: CONFIG_LSM includes bpf"
else
  echo "error: CONFIG_LSM does not include bpf" >&2
  failures=$((failures + 1))
fi

case "$profile" in
  plain)
    ;;
  containers)
    container_required=(
      CONFIG_NAMESPACES
      CONFIG_UTS_NS
      CONFIG_IPC_NS
      CONFIG_PID_NS
      CONFIG_NET_NS
      CONFIG_USER_NS
      CONFIG_CGROUPS
      CONFIG_CGROUP_DEVICE
      CONFIG_CGROUP_PIDS
      CONFIG_CPUSETS
      CONFIG_MEMCG
      CONFIG_CGROUP_BPF
      CONFIG_SECCOMP
      CONFIG_SECCOMP_FILTER
      CONFIG_FHANDLE
      CONFIG_BRIDGE
      CONFIG_VETH
      CONFIG_TUN
      CONFIG_OVERLAY_FS
      CONFIG_VIRTUALIZATION
      CONFIG_KVM
      CONFIG_VHOST_NET
    )

    for symbol in "${container_required[@]}"; do
      require_y "$symbol"
    done

    require_n CONFIG_ANDROID_PARANOID_NETWORK
    ;;
  *)
    echo "unsupported build profile: $profile" >&2
    exit 2
    ;;
esac

if (( failures != 0 )); then
  echo "kernel config validation failed with ${failures} error(s)" >&2
  exit 1
fi

echo "kernel config validation passed for profile: $profile"
