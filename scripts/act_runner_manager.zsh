#!/usr/bin/env zsh
set -eo pipefail

if [[ -n "$ZSH_VERSION" ]]; then
  setopt ERR_EXIT PIPE_FAIL
  trap '__err_handler ${LINENO} ${(%):-%x} ${(%):-%I}' ERR
else
  set -o errtrace
  trap '__err_handler ${LINENO} "${BASH_COMMAND}"' ERR
fi

SCRIPT_NAME="$(basename "$0")"
SCRIPT_VERSION="2.7.0"
DEFAULT_INSTALL_DIR="/opt/gitea-act-runner"
DEFAULT_DATA_DIR="/var/lib/gitea-act-runner"
DEFAULT_SERVICE_USER="git-runner"
DEFAULT_SERVICE_GROUP="git-runner"
DEFAULT_SERVICE_NAME="gitea-act-runner"
DEFAULT_LABELS="ubuntu-latest:docker://node:20-bookworm,ubuntu-22.04:docker://node:20-bookworm"
LATEST_VERSION="0.3.0"
DOWNLOAD_BASE="https://gitea.com/gitea/act_runner/releases/download"
CONFIG_FILE=".runner"
BACKUP_TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOCK_FILE="/tmp/.gitea-act-runner.lock"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

__err_handler() {
  local line=$1
  local file=$2
  local func=$3
  local exit_code=$?
  echo -e "${RED}❌ Error at ${file}:${line} | func: ${func:-main} | code: ${exit_code}${NC}" >&2
  [[ -f "$LOCK_FILE" ]] && rm -f "$LOCK_FILE"
  exit "${exit_code}"
}

log() {
  local level=$1
  local color=$2
  shift 2
  echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] [${level}] ${color}$*${NC}"
}

info()    { log "INFO"  "${GREEN}" "$*"; }
warn()    { log "WARN"  "${YELLOW}" "$*"; }
error()   { log "ERROR" "${RED}" "$*"; exit 1; }
step()    { log "STEP"  "${BLUE}" "$*"; }
success() { log "OK"    "${GREEN}" "✅ $*"; }

cleanup() {
  [[ -f "$LOCK_FILE" ]] && rm -f "$LOCK_FILE"
}
trap cleanup EXIT

check_root() {
  [[ $EUID -ne 0 ]] && {
    warn "This script is recommended to run as root"
    return 1
  }
  return 0
}

check_deps() {
  step "Checking dependencies"
  local missing=()
  for cmd in curl tar docker systemctl; do
    command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
  done
  [[ ${#missing[@]} -gt 0 ]] && error "Missing: ${missing[*]}"

  if ! systemctl is-active --quiet docker; then
    warn "Docker not running: systemctl start docker"
  fi
  success "Dependencies OK"
}

detect_arch() {
  local arch=$(uname -m)
  case "$arch" in
    x86_64|amd64) echo "amd64" ;;
    aarch64|arm64) echo "arm64" ;;
    armv7l|armhf) echo "armv7" ;;
    *) error "Unsupported arch: $arch" ;;
  esac
}

backup_config() {
  local dir=$1
  local backup_dir="${dir}/backups"
  mkdir -p "$backup_dir"
  [[ -f "${dir}/${CONFIG_FILE}" ]] && {
    cp "${dir}/${CONFIG_FILE}" "${backup_dir}/${CONFIG_FILE}.${BACKUP_TIMESTAMP}"
    info "Backup: ${backup_dir}/${CONFIG_FILE}.${BACKUP_TIMESTAMP}"
  }
}

usage() {
cat << EOF
Usage: sudo $SCRIPT_NAME [COMMAND] [OPTIONS]
Gitea Act Runner | v$SCRIPT_VERSION

Commands:
  deploy      Install/upgrade runner
  uninstall   Remove service + files
  status      Show runner status
  logs        View logs
  backup      Backup config

Required (deploy):
  --url URL     Gitea root URL
  --token TOKEN Runner registration token

Optional:
  --version VER  Version (default $LATEST_VERSION)
  --name NAME    Runner name
  --labels LABELS
  --dir DIR      Install dir
  --data-dir DIR Data dir
  --user USER    Service user
  --service NAME Systemd service
  --force        Force re-register
  -h --help      Show help
EOF
}

show_status() {
  step "Status: $SERVICE_NAME"
  systemctl is-active --quiet "$SERVICE_NAME" && {
    info "Active: $(systemctl is-active "$SERVICE_NAME")"
    info "Enabled: $(systemctl is-enabled "$SERVICE_NAME" 2>/dev/null || echo disabled)"
    info "Config: ${INSTALL_DIR}/${CONFIG_FILE}"
  } || {
    warn "Service not running"
  }
  docker info >/dev/null 2>&1 && info "Docker: running" || warn "Docker: down"
}

view_logs() {
  local follow="" lines=50
  for arg in "$@"; do
    case "$arg" in
      -f|--follow) follow="-f" ;;
      -n) lines="$2"; shift ;;
    esac
  done
  journalctl -u "$SERVICE_NAME" $follow -n "$lines" ${follow:+--no-pager}
}

do_uninstall() {
  step "Uninstalling $SERVICE_NAME"
  warn "This will remove service & install dir"
  [[ -z "$FORCE" ]] && {
    echo -n "Continue? (y/N) "
    read -q REPLY && echo || exit 0
    [[ ! "$REPLY" =~ [Yy] ]] && error "Cancelled"
  }

  systemctl stop "$SERVICE_NAME" 2>/dev/null || true
  systemctl disable "$SERVICE_NAME" 2>/dev/null || true
  rm -f "/etc/systemd/system/${SERVICE_NAME}.service"
  rm -f "/etc/logrotate.d/${SERVICE_NAME}"
  systemctl daemon-reload

  [[ -d "$INSTALL_DIR" ]] && {
    backup_config "$INSTALL_DIR"
    rm -rf "$INSTALL_DIR"
  }

  success "Uninstall done"
  warn "Data dir preserved: $DATA_DIR"
  warn "User preserved: $SERVICE_USER"
}

pre_check() {
  check_root
  [[ -z "$GITEA_URL" ]] && error "Missing --url"
  [[ -z "$RUNNER_TOKEN" ]] && error "Missing --token"
  check_deps
  success "Pre-check passed"
}

create_user() {
  step "Create service user: $SERVICE_USER"
  if ! id "$SERVICE_USER" >/dev/null 2>&1; then
    useradd -r -s /usr/sbin/nologin -d "$DATA_DIR" -m "$SERVICE_USER"
  fi
  mkdir -p "$INSTALL_DIR" "$DATA_DIR"
  chown -R "${SERVICE_USER}:${SERVICE_GROUP}" "$INSTALL_DIR" "$DATA_DIR"
  usermod -aG docker "$SERVICE_USER" 2>/dev/null || true
}

download_binary() {
  step "Download act_runner v$RUNNER_VERSION"
  local arch=$(detect_arch)
  local bin="act_runner-${RUNNER_VERSION}-linux-${arch}"
  local url="${DOWNLOAD_BASE}/v${RUNNER_VERSION}/${bin}"

  local tmp=$(mktemp -d)
  curl -SL --fail --retry 3 -o "${tmp}/act_runner" "$url"
  chmod 0755 "${tmp}/act_runner"
  mv "${tmp}/act_runner" "${INSTALL_DIR}/act_runner"
  chown "${SERVICE_USER}:${SERVICE_GROUP}" "${INSTALL_DIR}/act_runner"
  rm -rf "$tmp"
  success "Download OK"
}

register_runner() {
  step "Register runner"
  cd "$INSTALL_DIR"
  [[ -f "$CONFIG_FILE" && -z "$FORCE" ]] && {
    info "Using existing config"
    return 0
  }
  backup_config "$INSTALL_DIR"

  sudo -u "$SERVICE_USER" ./act_runner register \
    --instance "$GITEA_URL" \
    --token "$RUNNER_TOKEN" \
    --labels "$RUNNER_LABELS" \
    ${RUNNER_NAME:+--name "$RUNNER_NAME"} \
    --no-interactive

  [[ ! -f "$CONFIG_FILE" ]] && error "Register failed"
  chmod 600 "$CONFIG_FILE"
  success "Registered"
}

setup_systemd() {
  step "Setup systemd: $SERVICE_NAME"
  local svc="/etc/systemd/system/${SERVICE_NAME}.service"
  cat > "$svc" << EOF
[Unit]
Description=Gitea Act Runner
After=network.target docker.service
Requires=docker.service

[Service]
Type=simple
User=$SERVICE_USER
Group=$SERVICE_GROUP
WorkingDirectory=$INSTALL_DIR
ExecStart=$INSTALL_DIR/act_runner daemon
Restart=on-failure
RestartSec=5
LimitNOFILE=65536
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ReadWritePaths=$INSTALL_DIR $DATA_DIR /var/run/docker.sock

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable --now "$SERVICE_NAME"
  sleep 3
  systemctl is-active --quiet "$SERVICE_NAME" || error "Start failed"
  success "Systemd OK"
}

deploy() {
  pre_check
  create_user
  download_binary
  register_runner
  setup_systemd
  success "Deployment complete!"
  echo "Logs: journalctl -u $SERVICE_NAME -f"
}

main() {
  [[ $# -eq 0 ]] && { usage; exit 1; }

  local COMMAND="$1"
  shift

  GITEA_URL=""
  RUNNER_TOKEN=""
  RUNNER_NAME=""
  RUNNER_VERSION="$LATEST_VERSION"
  RUNNER_LABELS="$DEFAULT_LABELS"
  INSTALL_DIR="$DEFAULT_INSTALL_DIR"
  DATA_DIR="$DEFAULT_DATA_DIR"
  SERVICE_USER="$DEFAULT_SERVICE_USER"
  SERVICE_GROUP="$DEFAULT_SERVICE_GROUP"
  SERVICE_NAME="$DEFAULT_SERVICE_NAME"
  FORCE=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --url) GITEA_URL="$2"; shift 2 ;;
      --token) RUNNER_TOKEN="$2"; shift 2 ;;
      --version) RUNNER_VERSION="$2"; shift 2 ;;
      --name) RUNNER_NAME="$2"; shift 2 ;;
      --labels) RUNNER_LABELS="$2"; shift 2 ;;
      --dir) INSTALL_DIR="$2"; shift 2 ;;
      --data-dir) DATA_DIR="$2"; shift 2 ;;
      --user) SERVICE_USER="$2"; shift 2 ;;
      --service) SERVICE_NAME="$2"; shift 2 ;;
      --force) FORCE=1; shift ;;
      -h|--help) usage; exit 0 ;;
      *) error "Unknown option: $1" ;;
    esac
  done

  case "$COMMAND" in
    deploy) deploy ;;
    uninstall) do_uninstall ;;
    status) show_status ;;
    logs) view_logs "$@" ;;
    backup) backup_config "$INSTALL_DIR"; success "Backup done" ;;
    *) error "Unknown command: $COMMAND" ;;
  esac
}

main "$@"