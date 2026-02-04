#!/usr/bin/env bash
set -euo pipefail

VERSION="1.0"
REBOOT_REQUIRED=0

DEFAULT_MIN="512M"
DEFAULT_MAX="16G"
DEFAULT_LOWER="20"
DEFAULT_UPPER="80"

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() {
  echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $*" >&2
}

usage() {
  cat <<'EOF'
swapboost — keep Ubuntu desktops smooth with dynamic swapspace (zswap optional).

Usage: swapboost [apply|status|rollback|set|preset|--help|--version]
  apply [--enable-zswap]    Enable swapspace (and optionally zswap) using default tuning
  status                    Show current zswap/swapspace state
  rollback                  Remove zswap flags, drop tuning block, try to re-enable /swapfile
  set --min X --max Y --lower P --upper Q   Update swapspace tuning values
  preset balanced|aggressive|conservative   Apply a predefined tuning set
  --help              Show this help
  --version           Show script version

The script must run as root; it will re-exec with sudo when available.

Options for 'apply':
  --enable-zswap       Also enable zswap (disabled by default due to CPU overhead)
EOF
}

reexec_as_root() {
  if [[ $EUID -eq 0 ]]; then
    return
  fi

  if command -v sudo >/dev/null 2>&1; then
    log_info "Elevating privileges with sudo..."
    exec sudo -E SWAPBOOST_ALREADY_ROOT=1 "$0" "$@"
  fi

  log_error "This script must run as root. Re-run with sudo."
  exit 1
}

require_ubuntu_like() {
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    if [[ "${ID:-}" == "ubuntu" || "${ID_LIKE:-}" == *"ubuntu"* ]]; then
      return 0
    fi
  fi

  log_error "This package targets Ubuntu-based distributions."
  exit 1
}

validate_size() {
  local value=$1
  if [[ "$value" =~ ^[0-9]+[MG]?$ ]]; then
    return 0
  fi
  log_error "Invalid size: $value (use integers with optional M/G suffix)"
  return 1
}

validate_percent() {
  local value=$1
  if [[ "$value" =~ ^[0-9]+$ && "$value" -ge 1 && "$value" -le 100 ]]; then
    return 0
  fi
  log_error "Invalid percent: $value (1-100)"
  return 1
}

disable_default_swapfile() {
  local fstab="/etc/fstab"

  if [[ ! -f "$fstab" ]]; then
    log_warn "Missing $fstab, skipping swapfile removal."
    return
  fi

  if grep -Eq '^[[:space:]]*/swapfile[[:space:]]' "$fstab"; then
    log_info "Commenting /swapfile entry in $fstab..."
    sed -i 's|^[[:space:]]*/swapfile[[:space:]].*|#&|' "$fstab"
  fi

  if swapon --noheadings --show=NAME 2>/dev/null | grep -xq '/swapfile'; then
    log_info "swapoff /swapfile..."
    swapoff /swapfile || log_warn "swapoff /swapfile failed, please check manually."
  fi
}

ensure_zswap() {
  local grub_file="/etc/default/grub"
  if [[ ! -f "$grub_file" ]]; then
    log_error "Missing $grub_file; cannot configure zswap."
    return 1
  fi

  if ! command -v update-grub >/dev/null 2>&1; then
    log_error "update-grub not found (install grub-common) to enable zswap."
    return 1
  fi

  local current_args=""
  current_args=$(grep '^GRUB_CMDLINE_LINUX_DEFAULT=' "$grub_file" | tail -n1 | sed -E 's/^GRUB_CMDLINE_LINUX_DEFAULT="?([^"]*)"?/\1/')
  [[ -z "$current_args" ]] && current_args="quiet splash"

  local -a required_opts=(
    "zswap.enabled=1"
    "zswap.compressor=lz4"
    "zswap.max_pool_percent=20"
    "zswap.zpool=z3fold"
  )

  local changed=0
  local opt
  for opt in "${required_opts[@]}"; do
    if [[ " $current_args " != *" $opt "* ]]; then
      current_args="$current_args $opt"
      changed=1
    fi
  done

  # trim whitespace
  current_args=$(printf '%s\n' "$current_args" | awk '{$1=$1; print}')
  local new_line="GRUB_CMDLINE_LINUX_DEFAULT=\"${current_args}\""

  if ! grep -q '^GRUB_CMDLINE_LINUX_DEFAULT=' "$grub_file"; then
    log_info "Writing GRUB_CMDLINE_LINUX_DEFAULT to $grub_file..."
    printf '%s\n' "$new_line" >> "$grub_file"
    changed=1
  elif ! grep -Fxq "$new_line" "$grub_file"; then
    log_info "Updating GRUB_CMDLINE_LINUX_DEFAULT to enable zswap..."
    sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|$new_line|" "$grub_file"
    changed=1
  else
    log_info "GRUB already includes expected zswap options."
  fi

  if (( changed )); then
    log_info "Running update-grub..."
    if update-grub; then
      REBOOT_REQUIRED=1
    else
      log_warn "update-grub failed; please run it manually to apply zswap options."
    fi
  fi
}

remove_zswap_options() {
  local grub_file="/etc/default/grub"
  if [[ ! -f "$grub_file" ]]; then
    log_warn "Missing $grub_file; skip zswap removal."
    return 0
  fi

  if ! command -v update-grub >/dev/null 2>&1; then
    log_warn "update-grub not found; cannot remove zswap flags automatically."
    return 1
  fi

  local current_args=""
  current_args=$(grep '^GRUB_CMDLINE_LINUX_DEFAULT=' "$grub_file" | tail -n1 | sed -E 's/^GRUB_CMDLINE_LINUX_DEFAULT="?([^"]*)"?/\1/')

  local -a required_opts=(
    "zswap.enabled=1"
    "zswap.compressor=lz4"
    "zswap.max_pool_percent=20"
    "zswap.zpool=z3fold"
  )

  local padded=" $current_args "
  local changed=0
  local opt
  for opt in "${required_opts[@]}"; do
    if [[ "$padded" == *" $opt "* ]]; then
      padded=${padded// $opt / }
      changed=1
    fi
  done

  local cleaned
  cleaned=$(printf '%s\n' "$padded" | awk '{$1=$1; print}')
  [[ -z "$cleaned" ]] && cleaned="quiet splash"
  local new_line="GRUB_CMDLINE_LINUX_DEFAULT=\"${cleaned}\""

  if (( changed )); then
    log_info "Removing zswap flags from GRUB_CMDLINE_LINUX_DEFAULT..."
    if grep -q '^GRUB_CMDLINE_LINUX_DEFAULT=' "$grub_file"; then
      sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|$new_line|" "$grub_file"
    else
      printf '%s\n' "$new_line" >> "$grub_file"
    fi

    log_info "Running update-grub..."
    if update-grub; then
      REBOOT_REQUIRED=1
    else
      log_warn "update-grub failed; please run it manually to drop zswap flags."
    fi
  else
    log_info "No zswap flags found in GRUB_CMDLINE_LINUX_DEFAULT."
  fi
}

ensure_swapspace_package() {
  if dpkg -s swapspace >/dev/null 2>&1; then
    log_info "swapspace already installed."
    return
  fi

  log_info "Installing swapspace..."
  if ! command -v apt-get >/dev/null 2>&1; then
    log_error "apt-get not found; install swapspace manually."
    return 1
  fi

  if ! apt-get update; then
    log_error "apt-get update failed; cannot install swapspace automatically."
    return 1
  fi
  if ! DEBIAN_FRONTEND=noninteractive apt-get install -y swapspace; then
    log_error "swapspace installation failed."
    return 1
  fi
}

configure_swapspace_conf() {
  local conf="/etc/swapspace.conf"
  local marker_begin="# swapboost tuning begin"
  local marker_end="# swapboost tuning end"
  local min_size=$1
  local max_size=$2
  local lower=$3
  local upper=$4

  touch "$conf"

  local tmp
  tmp=$(mktemp)
  if ! sed "/${marker_begin}/,/${marker_end}/d" "$conf" > "$tmp"; then
    log_error "Failed to prepare $conf"
    rm -f "$tmp"
    return 1
  fi

  {
    echo
    echo "$marker_begin"
    echo "min_swapsize = ${min_size}"
    echo "max_swapsize = ${max_size}"
    echo "lower_freelimit=${lower}"
    echo "upper_freelimit=${upper}"
    echo "$marker_end"
  } >> "$tmp"

  if ! mv "$tmp" "$conf"; then
    log_error "Failed to write $conf"
    rm -f "$tmp"
    return 1
  fi
  log_info "swapspace.conf updated with swapboost tuning."
}

remove_swapspace_block() {
  local conf="/etc/swapspace.conf"
  local marker_begin="# swapboost tuning begin"
  local marker_end="# swapboost tuning end"

  if [[ ! -f "$conf" ]]; then
    log_info "No swapspace.conf found; skip removing tuning block."
    return
  fi

  if ! grep -Fq "$marker_begin" "$conf" 2>/dev/null; then
    log_info "swapspace.conf has no swapboost block."
    return
  fi

  log_info "Removing swapboost block from $conf..."
  local tmp
  tmp=$(mktemp)
  if sed "/${marker_begin}/,/${marker_end}/d" "$conf" > "$tmp"; then
    mv "$tmp" "$conf"
  else
    log_warn "Failed to remove tuning block from $conf; please clean manually."
    rm -f "$tmp"
  fi
}

restart_swapspace_service() {
  if ! command -v systemctl >/dev/null 2>&1; then
    log_warn "systemctl not available; please restart swapspace manually."
    return
  fi

  systemctl enable --now swapspace >/dev/null 2>&1 || true
  if systemctl restart swapspace; then
    if systemctl is-active --quiet swapspace; then
      log_info "swapspace service is active."
    else
      log_warn "swapspace service not active after restart; please inspect logs."
    fi
  else
    log_warn "swapspace service restart failed; please check manually."
  fi
}

set_swapspace_tuning() {
  local min_size=$1
  local max_size=$2
  local lower=$3
  local upper=$4

  validate_size "$min_size" || return 1
  validate_size "$max_size" || return 1
  validate_percent "$lower" || return 1
  validate_percent "$upper" || return 1

  configure_swapspace_conf "$min_size" "$max_size" "$lower" "$upper"
  restart_swapspace_service
}

restore_swapfile() {
  local fstab="/etc/fstab"

  if [[ ! -f "$fstab" ]]; then
    log_warn "Missing $fstab; cannot restore /swapfile entry."
  else
    if grep -Eq '^[[:space:]]*#[[:space:]]*/swapfile[[:space:]]' "$fstab"; then
      log_info "Uncommenting /swapfile entry in $fstab..."
      sed -i 's|^[[:space:]]*#[[:space:]]*/swapfile[[:space:]]\+|/swapfile |' "$fstab"
    else
      log_info "No commented /swapfile entry found in $fstab."
    fi
  fi

  if swapon --noheadings --show=NAME 2>/dev/null | grep -xq '/swapfile'; then
    log_info "/swapfile swap already active."
    return
  fi

  if [[ -f /swapfile ]]; then
    log_info "Enabling /swapfile swap..."
    if ! swapon /swapfile; then
      log_warn "swapon /swapfile failed; run 'sudo mkswap /swapfile && sudo swapon /swapfile' manually if needed."
    fi
  else
    log_warn "/swapfile is missing; create it manually if you want swapfile back (e.g., fallocate/mkswap/swapon)."
  fi
}

show_status() {
  echo "== zswap =="
  if [[ -r /sys/module/zswap/parameters/enabled ]]; then
    echo "enabled: $(cat /sys/module/zswap/parameters/enabled)"
    [[ -r /sys/module/zswap/parameters/max_pool_percent ]] && echo "max_pool_percent: $(cat /sys/module/zswap/parameters/max_pool_percent)"
    [[ -r /sys/module/zswap/parameters/compressor ]] && echo "compressor: $(cat /sys/module/zswap/parameters/compressor)"
    [[ -r /sys/module/zswap/parameters/zpool ]] && echo "zpool: $(cat /sys/module/zswap/parameters/zpool)"
  else
    echo "zswap parameters not exposed (reboot may be required)."
  fi

  echo
  echo "== swap devices =="
  if command -v swapon >/dev/null 2>&1; then
    swapon --noheadings --show=NAME,SIZE,USED,PRIO || true
  else
    echo "swapon not found."
  fi

  echo
  echo "== swapspace service =="
  if command -v systemctl >/dev/null 2>&1; then
    systemctl is-active swapspace && systemctl status --no-pager --lines=3 swapspace || true
  else
    echo "systemctl not available."
  fi

  echo
  echo "== swapspace.conf (swapboost block) =="
  local conf="/etc/swapspace.conf"
  if [[ -f "$conf" ]] && grep -Fq "# swapboost tuning begin" "$conf"; then
    sed -n '/# swapboost tuning begin/,/# swapboost tuning end/p' "$conf"
  else
    echo "No swapboost tuning block found."
  fi
}

apply_all() {
  reexec_as_root apply "$@"
  local enable_zswap=0
  local arg
  for arg in "$@"; do
    case "$arg" in
      --from-package)
        ;;
      --enable-zswap)
        enable_zswap=1
        ;;
      *)
        log_warn "Ignoring unknown apply option: $arg"
        ;;
    esac
  done
  require_ubuntu_like
  disable_default_swapfile
  if (( enable_zswap )); then
    ensure_zswap
    log_info "zswap enabled via GRUB (requires reboot to take effect)."
  else
    log_info "zswap not enabled (use --enable-zswap to enable it)."
    log_info "Note: zswap can increase CPU usage, especially when running many applications."
  fi
  ensure_swapspace_package
  set_swapspace_tuning "$DEFAULT_MIN" "$DEFAULT_MAX" "$DEFAULT_LOWER" "$DEFAULT_UPPER"
  log_info "Swapboost tuning applied."
  if (( REBOOT_REQUIRED )); then
    log_warn "A reboot is recommended to activate zswap parameters."
  fi
}

run_set_command() {
  reexec_as_root set "$@"
  require_ubuntu_like

  local min=""
  local max=""
  local lower=""
  local upper=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --min)
        min="${2:-}"
        shift 2
        ;;
      --max)
        max="${2:-}"
        shift 2
        ;;
      --lower)
        lower="${2:-}"
        shift 2
        ;;
      --upper)
        upper="${2:-}"
        shift 2
        ;;
      *)
        log_error "Unknown option for set: $1"
        exit 1
        ;;
    esac
  done

  if [[ -z "$min" || -z "$max" || -z "$lower" || -z "$upper" ]]; then
    log_error "set requires --min <size> --max <size> --lower <percent> --upper <percent>"
    exit 1
  fi

  ensure_swapspace_package
  set_swapspace_tuning "$min" "$max" "$lower" "$upper"
  log_info "Swapspace tuning updated."
}

preset_values() {
  local preset=$1
  case "$preset" in
    balanced)
      echo "$DEFAULT_MIN $DEFAULT_MAX $DEFAULT_LOWER $DEFAULT_UPPER"
      ;;
    aggressive)
      echo "1G 24G 15 70"
      ;;
    conservative)
      echo "256M 8G 25 85"
      ;;
    *)
      return 1
      ;;
  esac
}

run_preset_command() {
  reexec_as_root preset "$@"
  require_ubuntu_like
  local preset="${1:-}"
  if [[ -z "$preset" ]]; then
    log_error "preset requires a name: balanced|aggressive|conservative"
    exit 1
  fi

  local values
  if ! values=$(preset_values "$preset"); then
    log_error "Unknown preset: $preset (use balanced|aggressive|conservative)"
    exit 1
  fi

  ensure_swapspace_package
  # shellcheck disable=SC2086
  set_swapspace_tuning $values
  log_info "Applied preset '$preset'."
}

rollback_all() {
  reexec_as_root rollback "$@"
  require_ubuntu_like
  remove_zswap_options
  remove_swapspace_block
  restart_swapspace_service
  restore_swapfile
  log_info "Rollback completed."
  if (( REBOOT_REQUIRED )); then
    log_warn "A reboot is recommended to drop zswap parameters."
  fi
}

main() {
  local cmd="${1:-apply}"
  case "$cmd" in
    apply)
      shift
      apply_all "$@"
      ;;
    status)
      shift
      show_status
      ;;
    rollback)
      shift
      rollback_all "$@"
      ;;
    set)
      shift
      run_set_command "$@"
      ;;
    preset)
      shift
      run_preset_command "$@"
      ;;
    --help|-h)
      usage
      ;;
    --version)
      echo "$VERSION"
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
