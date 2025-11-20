#!/usr/bin/env bash

if [ -z "${HAVEN_ROOT-}" ]; then
  HAVEN_ROOT=${HOME}/.haven
fi

if [ -z "${HAVEN_VERSION-}" ]; then
  HAVEN_VERSION="main"
fi

HAVEN_BIN="$HAVEN_ROOT/bin"
HAVEN_EXE="$HAVEN_BIN/haven.new"

is_sourced() {
  if [ -n "$ZSH_VERSION" ]; then
    case $ZSH_EVAL_CONTEXT in *:file:*) return 0;; esac
  else  # Add additional POSIX-compatible shell names here, if needed.
    case ${0##*/} in dash|-dash|bash|-bash|ksh|-ksh|sh|-sh) return 0;; esac
  fi
  return 1  # NOT sourced.
}

if is_sourced; then
    # shellcheck disable=SC2209
    ret=return
else
    # shellcheck disable=SC2209
    # shellcheck disable=SC2034
    ret=exit
fi

OS="$(uname -s)"
if [ "$OS" = 'Darwin' ]; then
  # Check if we're running on Apple Silicon
  if [ "$(uname -m)" = 'arm64' ]; then
    # Make sure rosetta is installed
    if ! command -v arch > /dev/null 2>&1; then
      softwareupdate --install-rosetta
    fi
  fi
  DOWNLOAD_URL="https://puro.dev/builds/${HAVEN_VERSION}/darwin-x64/puro"
elif [ "$OS" = 'Linux' ]; then
  DOWNLOAD_URL="https://puro.dev/builds/${HAVEN_VERSION}/linux-x64/puro"
else
  >&2 echo "Error: Unknown OS: $OS"
  $ret 1
fi

command -v curl > /dev/null 2>&1 || {
  >&2 echo 'Error: could not find curl command'
  case "$OS" in
    Darwin)
      >&2 echo 'Consider running "brew install curl".'
      ;;
    Linux)
      >&2 echo 'Consider running "sudo apt-get install curl".'
      ;;
  esac
  $ret 1
}

mkdir -p "$HAVEN_BIN"
curl -f --retry 3 --output "$HAVEN_EXE" "$DOWNLOAD_URL" || {
  >&2 echo "Error downloading $DOWNLOAD_URL"
  $ret $?
}
chmod +x "$HAVEN_EXE" || $ret $?

"$HAVEN_EXE" install-haven --promote
