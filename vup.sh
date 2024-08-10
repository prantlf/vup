#!/usr/bin/env bash

set -euo pipefail

if [[ "${NO_COLOR-}" = "" && ( -t 1 || "${FORCE_COLOR-}" != "" ) ]]; then
    C_RESET='\033[0m'
    C_RED='\033[0;31m'
    C_GREEN='\033[0;32m'
    C_YELLOW='\033[0;33m'
    C_DIM='\033[0;37m'
    C_BOLD='\033[1m'
else
    C_RESET=
    C_RED=
    C_GREEN=
    C_YELLOW=
    C_DIM=
    C_BOLD=
fi

announce() {
    echo -e "${C_BOLD}$1${C_RESET}" "$2" >&2
}

fail() {
    echo -e "${C_RED}$1${C_RESET}" "$2" >&2
    exit 1
}

pass() {
    echo -e "${C_GREEN}$1${C_RESET}" "$2" >&2
}

ignore() {
    echo -e "${C_YELLOW}$1${C_RESET}" "$2" >&2
}

start_debug() {
    echo -e "${C_DIM}$1" >&2
}

end_debug() {
    echo -en "${C_RESET}" >&2
}

readonly VERSION=0.0.1

print_usage_description() {
    echo -e "${C_BOLD}vup $VERSION${C_RESET} - upgrade to the latest or manage more versions of V

${C_BOLD}Usage${C_RESET}: vup <task> [version]
${C_BOLD}Tasks${C_RESET}:
  current              print the currently selected version of V
  latest               print the latest version of V for download
  local                print versions of V ready to be selected
  remote               print versions of V available for download
  update               update this tool to the latest version
  upgrade              upgrade V to the latest and remove the current version
  up                   perform both update and upgrade tasks
  install <version>    add the specified or the latest version of V
  uninstall <version>  remove the specified version of V
  use <version>        use the specified or the latest version of V
  help                 print usage instructions for this tool
  version              print the version of this tool"
}

print_vup_version() {
    echo "$VERSION"
}

if [ $# -eq 0 ]; then
    print_usage_description
    exit 1
elif [ $# -gt 2 ]; then
    fail 'command failed' 'because of too many arguments'
fi
TASK=$1
if ! [[ ' current help install latest local remote uninstall up update upgrade use version ' =~ [[:space:]]${TASK}[[:space:]] ]]; then
    fail 'unrecognised task' "'$TASK'"
fi
if [ $# -eq 1 ]; then
    if [[ ' install uninstall use ' =~ [[:space:]]${TASK}[[:space:]] ]]; then
        fail 'missing version argument' "for task '$TASK'"
    fi
    ARG=
else
    if [[ ' current help latest local remote up update upgrade version ' =~ [[:space:]]${TASK}[[:space:]] ]]; then
        fail 'unexpected argument' "for task '$TASK'"
    fi
    ARG=$2
fi
if [[ "$ARG" != "" ]] && ! [[ "$ARG" =~ ^[.[:digit:]rcbeta]+$ ]] && [[ "$ARG" != "latest" ]]; then
    fail 'invalid version argument' "'$ARG'"
fi

case $TASK in
help)
    print_usage_description
    ;;
version)
    print_vup_version
    ;;
esac
