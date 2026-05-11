#!/usr/bin/env bash
# update-system.sh — update an existing student VM lab system in place.
#
# Usage:
#   ./update-system.sh
#   ./update-system.sh --skip-docker
#
# This updates student-facing scripts, libraries, labs, services, compose files,
# and course materials while preserving local progress and submissions.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

REPO_URL="${REPO_URL:-https://github.com/ZolaNUAA/cyber-practice.git}"
BRANCH="${BRANCH:-main}"
SKIP_DOCKER=false
ACTUAL_USER="${SUDO_USER:-${USER:-}}"

for arg in "$@"; do
  case "$arg" in
    --skip-docker) SKIP_DOCKER=true ;;
    --help|-h)
      echo "Usage: ./update-system.sh [--skip-docker]"
      echo "  --skip-docker   update files only; do not pull/rebuild Docker images"
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg"
      echo "Run ./update-system.sh --help for usage."
      exit 1
      ;;
  esac
done

UPDATE_PATHS=(
  "student.sh"
  "start-lab.sh"
  "stop-lab.sh"
  "reset-lab.sh"
  "check-env.sh"
  "install-kali.sh"
  "prepare-lab-data.sh"
  "verify-lab-env.sh"
  "update-system.sh"
  "docker-compose.yml"
  "README.md"
  "TEACHER_GUIDE.md"
  "lib"
  "labs"
  "services"
  "slides"
)

KEEP_PATHS=(
  ".progress"
  "submit"
  "reports"
  "pcaps"
  "logs"
  "evidence"
  "lab-passwords.txt"
  ".teacher-config"
  ".teacher-data"
)

msg() { printf '\n[*] %s\n' "$1"; }
ok() { printf '    ok: %s\n' "$1"; }
warn() { printf '    warn: %s\n' "$1"; }
die() { printf '    error: %s\n' "$1" >&2; exit 1; }

need_git() {
  command -v git >/dev/null 2>&1 || die "git is required. Install it first: sudo apt-get install git"
}

backup_runtime_state() {
  BACKUP_DIR="$(mktemp -d /tmp/cyber-practice-state.XXXXXX)"
  for path in "${KEEP_PATHS[@]}"; do
    if [[ -e "$path" ]]; then
      mkdir -p "$BACKUP_DIR/$(dirname "$path")"
      cp -a "$path" "$BACKUP_DIR/$path"
    fi
  done
  ok "runtime state backed up to $BACKUP_DIR"
}

restore_runtime_state() {
  [[ -n "${BACKUP_DIR:-}" && -d "$BACKUP_DIR" ]] || return 0
  for path in "${KEEP_PATHS[@]}"; do
    if [[ -e "$BACKUP_DIR/$path" ]]; then
      rm -rf "$path"
      mkdir -p "$(dirname "$path")"
      cp -a "$BACKUP_DIR/$path" "$path"
    fi
  done
}

update_with_git_checkout() {
  msg "Fetching latest lab system from $REPO_URL ($BRANCH)"

  if ! git remote get-url origin >/dev/null 2>&1; then
    git remote add origin "$REPO_URL"
  fi
  git remote set-url origin "$REPO_URL"
  git fetch --depth=1 origin "$BRANCH"

  msg "Updating tracked lab files"
  git checkout "origin/$BRANCH" -- "${UPDATE_PATHS[@]}"
}

update_with_temp_clone() {
  local tmp_dir
  tmp_dir="$(mktemp -d /tmp/cyber-practice-update.XXXXXX)"

  msg "No usable .git directory found; cloning latest lab system"
  git clone --depth=1 --branch "$BRANCH" "$REPO_URL" "$tmp_dir"

  msg "Replacing lab files from fresh clone"
  for path in "${UPDATE_PATHS[@]}"; do
    if [[ -e "$tmp_dir/$path" ]]; then
      rm -rf "$path"
      mkdir -p "$(dirname "$path")"
      cp -a "$tmp_dir/$path" "$path"
    fi
  done

  rm -rf "$tmp_dir"
}

set_permissions() {
  chmod +x student.sh start-lab.sh stop-lab.sh reset-lab.sh check-env.sh install-kali.sh \
    prepare-lab-data.sh verify-lab-env.sh update-system.sh 2>/dev/null || true
  chmod +x lib/*.sh 2>/dev/null || true
  find labs -name "guide.sh" -exec chmod +x {} \; 2>/dev/null || true
  ok "script permissions refreshed"
}

fix_ownership() {
  if [[ "$(id -u)" -eq 0 && -n "$ACTUAL_USER" && "$ACTUAL_USER" != "root" ]]; then
    chown -R "$ACTUAL_USER:$ACTUAL_USER" "$ROOT_DIR" 2>/dev/null || true
    ok "ownership restored to $ACTUAL_USER"
  fi
}

prepare_data() {
  if [[ -x ./prepare-lab-data.sh ]]; then
    ./prepare-lab-data.sh >/dev/null
    ok "lab evidence and runtime directories prepared"
  else
    warn "prepare-lab-data.sh is missing"
  fi
}

refresh_docker() {
  $SKIP_DOCKER && { warn "Docker refresh skipped"; return 0; }
  command -v docker >/dev/null 2>&1 || { warn "Docker is not installed; file update completed only"; return 0; }

  msg "Refreshing Docker services"
  docker compose down --remove-orphans >/dev/null 2>&1 || true
  docker compose pull || true
  docker compose build
}

main() {
  need_git
  backup_runtime_state

  if [[ -d .git ]]; then
    update_with_git_checkout
  else
    update_with_temp_clone
  fi

  restore_runtime_state
  set_permissions
  prepare_data
  refresh_docker
  fix_ownership

  msg "Update complete"
  echo "Run ./check-env.sh, then ./student.sh."
}

main "$@"
