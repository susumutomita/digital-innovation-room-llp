#!/usr/bin/env bash
set -euo pipefail

# Local dev bootstrap for contracts.
# Installs common tools used by `make test`.

need() {
  command -v "$1" >/dev/null 2>&1
}

say() { printf "%s\n" "$*"; }

OS=$(uname -s)

say "== contracts bootstrap =="

missing=()
for cmd in forge cast anvil make python3; do
  need "$cmd" || missing+=("$cmd")
done

if (( ${#missing[@]} > 0 )); then
  say "Missing required tools: ${missing[*]}"
  say "Install Foundry first: https://book.getfoundry.sh/getting-started/installation"
  exit 1
fi

# Optional but needed for full `make test`.
need bats || MISSING_BATS=1 || true
need shellcheck || MISSING_SHELLCHECK=1 || true

if [[ -z "${MISSING_BATS:-}" && -z "${MISSING_SHELLCHECK:-}" ]]; then
  say "OK: bats + shellcheck already installed"
  exit 0
fi

case "$OS" in
  Darwin)
    if ! need brew; then
      say "Homebrew not found. Install: https://brew.sh/"
      exit 1
    fi
    pkgs=()
    [[ -n "${MISSING_BATS:-}" ]] && pkgs+=(bats-core)
    [[ -n "${MISSING_SHELLCHECK:-}" ]] && pkgs+=(shellcheck)
    say "Installing: ${pkgs[*]}"
    brew install "${pkgs[@]}"
    ;;

  Linux)
    if ! need sudo; then
      say "sudo not found; install bats/shellcheck manually."
      exit 1
    fi
    pkgs=()
    [[ -n "${MISSING_BATS:-}" ]] && pkgs+=(bats)
    [[ -n "${MISSING_SHELLCHECK:-}" ]] && pkgs+=(shellcheck)
    say "Installing via apt: ${pkgs[*]}"
    sudo apt-get update
    sudo apt-get install -y "${pkgs[@]}"
    ;;

  *)
    say "Unsupported OS: $OS"
    say "Install bats + shellcheck manually."
    exit 1
    ;;
 esac

say "OK: bootstrap complete"
