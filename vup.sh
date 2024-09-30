#!/usr/bin/env bash

set -euo pipefail

if [[ "${NO_COLOR-}" = "" && ( -t 1 || "${FORCE_COLOR-}" != "" ) ]]; then
    C_RESET='\033[0m'
    C_RED='\033[0;31m'
    C_GREEN='\033[0;32m'
    C_YELLOW='\033[0;33m'
    C_DIM='\033[0;37m'
    C_BOLD='\033[1m'
    PROGRESS=-#
else
    C_RESET=
    C_RED=
    C_GREEN=
    C_YELLOW=
    C_DIM=
    C_BOLD=
    PROGRESS=-Ss
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

readonly INST_NAME=vup
readonly LANG_NAME=V
readonly TOOL_NAME=v
readonly VERSION=0.1.2

readonly INST_DIR="${INST_DIR-$HOME/.$INST_NAME}"
readonly TOOL_DIR=${TOOL_DIR-$HOME/.$TOOL_NAME}

print_usage_instructions() {
    echo -e "${C_BOLD}$INST_NAME $VERSION${C_RESET} - upgrade to the latest or manage more versions of $LANG_NAME

${C_BOLD}Usage${C_RESET}: $INST_NAME <task> [version]
${C_BOLD}Tasks${C_RESET}:
  current              print the currently selected version of $LANG_NAME
  latest               print the latest version of $LANG_NAME for download
  local                print versions of $LANG_NAME ready to be selected
  remote               print versions of $LANG_NAME available for download
  update               update this tool to the latest version
  upgrade              upgrade $LANG_NAME to the latest and remove the current version
  up                   perform both update and upgrade tasks
  install <version>    add the specified or the latest version of $LANG_NAME
  uninstall <version>  remove the specified version of $LANG_NAME
  use <version>        use the specified or the latest version of $LANG_NAME
  help                 print usage instructions for this tool
  version              print the version of this tool"
}

print_installer_version() {
    echo "$VERSION"
}

if [ $# -eq 0 ]; then
    print_usage_instructions
    exit 1
elif [ $# -gt 2 ]; then
    fail 'command failed' 'because of too many arguments'
fi
TASK=$1
if ! [[ ' current help install latest local remote uninstall up update upgrade use version ' =~ [[:space:]]${TASK}[[:space:]] ]]; then
    fail 'unrecognised task' "$TASK"
fi
if [ $# -eq 1 ]; then
    if [[ ' install uninstall use ' =~ [[:space:]]${TASK}[[:space:]] ]]; then
        fail 'missing version argument' "for task $TASK"
    fi
    ARG=
else
    if [[ ' current help latest local remote up update upgrade version ' =~ [[:space:]]${TASK}[[:space:]] ]]; then
        fail 'unexpected argument' "for task $TASK"
    fi
    ARG=$2
fi
if [[ "$ARG" != "" ]] && ! [[ "$ARG" =~ ^[.[:digit:][:alpha:]]+$ ]] && [[ "$ARG" != "latest" ]]; then
    fail 'invalid version argument' "$ARG"
fi

exists_tool_directory() {
    # TOOL_EXISTS=$(command -v $TOOL_NAME)
    if [ -e "$TOOL_DIR" ]; then
        TOOL_EXISTS=1
    else
        TOOL_EXISTS=
    fi
}

check_tool_directory_exists() {
    exists_tool_directory
    if [ -z "$TOOL_EXISTS" ]; then
        fail missing "$TOOL_DIR"
    fi
}

try_current_tool_version() {
    # TOOL_CUR_VER=$(command $TOOL_NAME tool dist version) ||
    #     fail 'failed getting' 'the current version of $LANG_NAME"
    if [ -e "$TOOL_DIR" ]; then
        cd "$TOOL_DIR" ||
            fail 'failed entering' "$TOOL_DIR"
        TOOL_CUR_VER=$(pwd -P) ||
            fail 'failed reading' "real path of $TOOL_DIR"
        if ! [[ "$TOOL_CUR_VER" =~ /([^/]+)$ ]]; then
            failed 'failed recognising' "version in $TOOL_CUR_VER"
        fi
        TOOL_CUR_VER=${BASH_REMATCH[1]}
    else
        TOOL_CUR_VER=
    fi
}

get_current_tool_version() {
    try_current_tool_version
    if [ -z "$TOOL_CUR_VER" ]; then
        fail 'not found' "any version in $TOOL_DIR"
    fi
}

print_tool_version() {
    check_tool_directory_exists
    get_current_tool_version
    echo "$TOOL_CUR_VER"
}

check_command_exists() {
    local CMD=$1
    local WHY=$2
    command -v "$CMD" >/dev/null ||
        fail missing "${C_BOLD}$CMD${C_RESET} for $WHY"
}

check_uname_exists() {
    check_command_exists uname 'detecting the current platform'
}

check_rm_exists() {
    check_command_exists rm 'removing files and directories'
}

check_ln_exists() {
    check_command_exists ln 'creating links'
}

check_curl_exists() {
    check_command_exists curl 'downloading from the Internet'
}

check_tar_exists() {
    check_command_exists tar 'unpacking tar archives'
}

check_unzip_exists() {
    check_command_exists unzip 'unpacking zip archives'
}

check_jq_exists() {
    check_command_exists jq 'extracting data from JSON'
}

check_sort_exists() {
    check_command_exists sort 'sorting version numbers'
}

detect_platform() {
    local UNAME
    PLATFORM=${PLATFORM-}
    if [ -z "$PLATFORM" ]; then
        check_uname_exists

        OS=${OS-}
        ARCH=${ARCH-}
        if [ -z "$OS" ] || [ -z "$ARCH" ]; then
            local UNAME
            read -ra UNAME < <(command uname -ms)
            if [ -z "$OS" ]; then
                OS=${UNAME[0],,}
            fi
            if [ -z "$ARCH" ]; then
                ARCH=${UNAME[1],,}
            fi
        fi

        if ! [[ ' darwin linux windows ' =~ [[:space:]]${OS}[[:space:]] ]]; then
            fail unsupported "operating system $OS"
        fi

        case $ARCH in
        aarch64 | armv8 | armv8l)
            ARCH=arm64
            ;;
        x86_64 | amd64)
            ARCH=x64
            ;;
        esac

        if ! [[ " x64 arm64 riscv64 " =~ [[:space:]]${ARCH}[[:space:]] ]]; then
            fail unsupported "architecture $ARCH"
        fi

        PLATFORM=$OS-$ARCH

        if [[ $PLATFORM = darwin-x64 ]]; then
            if [[ $(sysctl -n sysctl.proc_translated 2>/dev/null) = 1 ]]; then
                PLATFORM=darwin-arm64
                pass 'changing platform' "to $PLATFORM because Rosetta 2 was detected"
            fi
        fi

        if ! [[ " darwin-x64 darwin-arm64 linux-x64 linux-arm64 linux-riscv64 windows-x64 " =~ [[:space:]]${PLATFORM}[[:space:]] ]]; then
            fail unsupported "platform $PLATFORM"
        fi
    else
        IFS='-' read -ra UNAME <<< "$PLATFORM"
        OS=${UNAME[0],,}
        if [ -z "$OS" ]; then
            fail unrecognised "operating system in $PLATFORM"
        fi
        ARCH=${UNAME[1],,}
        if [ -z "$OS" ]; then
            fail unrecognised "architecture in $PLATFORM"
        fi
    fi

    local REPO_NAME
    local FILE_EXT=.zip

    case $OS in
    darwin)
        REPO_NAME=vlang/v
        FILE_NAME=v_macos_
        if [[ $ARCH = x64 ]]; then
            FILE_NAME="${FILE_NAME}x86_64"
        elif [[ $ARCH = arm64 ]]; then
            FILE_NAME="${FILE_NAME}arm64"
        fi
        ;;
    linux)
        REPO_NAME=prantlf/docker-vlang
        FILE_NAME=v-linux-
        if [[ $ARCH = x64 ]]; then
            FILE_NAME="${FILE_NAME}x64"
        elif [[ $ARCH = arm64 ]]; then
            FILE_NAME="${FILE_NAME}arm64"
        elif [[ $ARCH = riscv64 ]]; then
            FILE_NAME="${FILE_NAME}riscv64"
        fi
        ;;
    windows)
        REPO_NAME=vlang/v
        FILE_NAME=v_windows
        ;;
    esac

    REPO_URL=${REPO_URL-https://github.com/$REPO_NAME}
    API_URL=${API_URL-https://api.github.com/repos/$REPO_NAME}
    PKG_NAME=${PKG_NAME-$FILE_NAME$FILE_EXT}

    pass 'detected' "platform $PLATFORM"
}

check_remote_tool_version_exists() {
    local VER=$1
    TOOL_URL_PKG="$REPO_URL/releases/download/$VER/$PKG_NAME"
    start_debug "checking $TOOL_URL_PKG"
    TOOL_EXISTS=$(command curl -LfI "$PROGRESS" "$TOOL_URL_PKG") ||
        fail 'failed accessing' "$TOOL_URL_PKG"
    end_debug
    if ! [[ "$TOOL_EXISTS" =~ [[:space:]]200 ]]; then
        fail 'not found' "archive $TOOL_URL_PKG in the response:\n$TOOL_EXISTS"
    fi
    pass 'confirmed' "$VER"
}

download_tool_version() {
    local VER=$1
    if [[ " ${INST_LOCAL[*]} " =~ [[:space:]]${VER}[[:space:]] ]]; then
        command rm -r "$INST_DIR/$VER" ||
            fail 'failed deleting' "directory $INST_DIR/$VER"
    fi
    command mkdir "$INST_DIR/$VER" ||
        fail 'failed creating' "directory $INST_DIR/$VER"
    start_debug "downloading $TOOL_URL_PKG"
    command curl -Lf "$PROGRESS" -o "$PKG_NAME" "$TOOL_URL_PKG" ||
        fail 'failed downloading' "$TOOL_URL_PKG to $PKG_NAME"
    end_debug
    command unzip -q -d "$INST_DIR/$VER" "$PKG_NAME" ||
        fail 'failed unzipping' "$PKG_NAME to $INST_DIR/$VER"
    command rm "$PKG_NAME" ||
        fail 'failed deleting' "$PKG_NAME"
    command mv "$INST_DIR/$VER/v" "$INST_DIR/$VER/dist" ||
        fail 'failed moving' "$INST_DIR/$VER/v to $INST_DIR/$VER/dist"
    readonly RETAIN=(cmd thirdparty vlib v v.mod)
    local FILE
    for FILE in "${RETAIN[@]}"; do
        command mv "$INST_DIR/$VER/dist/$FILE" "$INST_DIR/$VER/$FILE" ||
            fail 'failed moving' "$INST_DIR/$VER/dist/$FILE to $INST_DIR/$VER/$FILE"
    done
    command rm -r "$INST_DIR/$VER/dist" ||
        fail 'failed deleting' "$INST_DIR/$VER/dist"
    pass 'downloaded and upacked' "$INST_DIR/$VER"
}

exists_installer_directory() {
    if [[ -d "$INST_DIR" ]]; then
        INST_EXISTS=1
    else
        INST_EXISTS=
    fi
}

check_installer_directory_exists() {
    exists_installer_directory
    if [[ "$INST_EXISTS" = "" ]]; then
        fail 'not found' "$INST_DIR"
    fi
}

get_local_tool_versions() {
    local VER_DIR
    local INST_LEN=${#INST_DIR}
    INST_LOCAL=()
    for VER_DIR in "$INST_DIR"/*/; do
        VER_DIR="${VER_DIR:$INST_LEN+1}"
        if [[ "$VER_DIR" != "*/" ]]; then
            INST_LOCAL+=("${VER_DIR%/}")
        fi
    done
}

link_tool_version_directory() {
    local VER=$1
    if [ -L "$TOOL_DIR" ]; then
        command rm "$TOOL_DIR" ||
            fail 'failed deleting' "link $TOOL_DIR"
    fi
    command ln -s "$INST_DIR/$VER" "$TOOL_DIR" ||
        fail 'failed creating' "link $TOOL_DIR to $INST_DIR/$VER"
    pass created "link $TOOL_DIR to $INST_DIR/$VER"
}

get_latest_remote_version() {
    readonly TOOL_URL_LATEST=${TOOL_URL_LATEST-$API_URL/releases/latest}
    start_debug "downloading $TOOL_URL_LATEST"
    TOOL_LATEST_VER=$(command curl -f "$PROGRESS" "$TOOL_URL_LATEST") ||
        fail 'failed downloading' "from $TOOL_URL_LATEST"
    end_debug
    if ! [[ "$TOOL_LATEST_VER" =~ \"tag_name\":.?\"([.[:alpha:][:digit:]]+)\" ]]; then
        fail 'failed recognising' "version in $TOOL_LATEST_VER"
    fi
    TOOL_LATEST_VER=${BASH_REMATCH[1]}
    TOOL_URL_PKG=${TOOL_URL_PKG-$REPO_URL/releases/download/$TOOL_LATEST_VER/$PKG_NAME}
}

remove_version_arg_from_local_tool_versions() {
    local OLD_LOCAL=("${INST_LOCAL[@]}")
    INST_LOCAL=()
    for DIR in "${OLD_LOCAL[@]}"; do
        if [[ "$DIR" != "$ARG" ]]; then
            INST_LOCAL+=("$DIR")
        fi
    done
}

get_latest_local_tool_version() {
    check_sort_exists

    if [[ "${INST_LOCAL[*]}" != "" ]]; then
        local SORTED
        SORTED=$(printf '%s\n' "${INST_LOCAL[@]}" | command sort -Vr) ||
            fail 'failed sorting' "versions: ${INST_LOCAL[*]}"
        read -r TOOL_VER < <(echo "${SORTED[@]}")
    else
        TOOL_VER=
    fi
}

get_local_tool_version_by_arg() {
    if [[ "$ARG" = "latest" ]]; then
        get_latest_local_tool_version
    else
        TOOL_VER=$ARG
    fi
}

exists_local_tool_version() {
    local VER=$1
    if [ -n "$VER" ] && [[ " ${INST_LOCAL[*]} " =~ [[:space:]]${VER}[[:space:]] ]]; then
        VER_EXISTS=1
    else
        VER_EXISTS=
    fi
}

check_local_tool_version_exists() {
    exists_local_tool_version "$TOOL_VER"
    if [[ "$VER_EXISTS" = "" ]]; then
        if [[ "$TOOL_VER" = "" ]]; then
            fail 'not found' "any version in $INST_DIR"
        else
            fail 'not found' "$INST_DIR/$TOOL_VER"
        fi
    fi
}

ensure_tool_directory_link() {
    local VER=$1
    exists_tool_directory
    if [[ "$TOOL_EXISTS" = "" ]]; then
        link_tool_version_directory "$VER"
    else
        try_current_tool_version
        if [[ "$TOOL_CUR_VER" != "$VER" ]]; then
            link_tool_version_directory "$VER"
        fi
    fi
}

install_tool_version() {
    check_curl_exists
    check_rm_exists
    check_ln_exists
    check_unzip_exists
    check_installer_directory_exists

    detect_platform

    local VER
    if [[ "$ARG" = "latest" ]]; then
        get_latest_remote_version
        VER=$TOOL_LATEST_VER
    else
        VER=$ARG
        check_remote_tool_version_exists "$VER"
    fi

    get_local_tool_versions
    exists_local_tool_version "$VER"
    if [[ "$VER_EXISTS" = "" ]]; then
        download_tool_version "$VER"
    else
        ignore 'already installed' "$VER"
    fi

    ensure_tool_directory_link "$VER"
}

delete_tool_version() {
    local VER=$1
    command rm -r "$INST_DIR/$VER" ||
        fail 'failed deleting' "$INST_DIR/$VER"
    pass deleted "$VER"
}

upgrade_tool_version() {
    check_curl_exists
    check_rm_exists
    check_ln_exists
    check_unzip_exists
    check_installer_directory_exists

    detect_platform

    get_latest_remote_version
    get_local_tool_versions
    exists_local_tool_version "$TOOL_LATEST_VER"
    if [[ "$VER_EXISTS" = "" ]]; then
        pass discovered "$TOOL_LATEST_VER"
        download_tool_version "$TOOL_LATEST_VER"
        get_latest_local_tool_version
        if [ -n "$TOOL_VER" ]; then
            delete_tool_version "$TOOL_VER"
        fi
    else
        ignore 'up to date' "language $TOOL_LATEST_VER"
    fi

    ensure_tool_directory_link "$TOOL_LATEST_VER"
}

update_installer() {
    local LATEST_VER
    local TRACE
    readonly INST_ROOT_URL="${INST_VER_URL-https://raw.githubusercontent.com/prantlf/$INST_NAME/master}"
    readonly INST_VER_URL="${INST_VER_URL-$INST_ROOT_URL/VERSION}"
    start_debug "downloading $INST_VER_URL"
    LATEST_VER=$(command curl -f "$PROGRESS" "$INST_VER_URL") ||
        fail 'failed downloading' "from $INST_VER_URL"
    if [[ "$LATEST_VER" != "$VERSION" ]]; then
        if [[ $- == *x* ]]; then
            TRACE=-x
        else
            TRACE=
        fi
        readonly INST_URL="${INST_URL-$INST_ROOT_URL/install.sh}"
        start_debug "downloading $INST_URL"
        command curl -f "$PROGRESS" "$INST_URL" | NO_INSTRUCTIONS=1 bash $TRACE ||
            fail 'failed downloading and executing' "$INST_URL"
        end_debug
    else
        ignore 'up to date' "installer $LATEST_VER"
    fi
}

update_installer_and_upgrade_tool_version() {
    update_installer
    upgrade_tool_version
}

print_local_tool_versions() {
    check_installer_directory_exists
    get_local_tool_versions
    printf '%s\n' "${INST_LOCAL[@]}" 
}

print_remote_tool_versions() {
    local LIST

    check_curl_exists
    check_jq_exists

    detect_platform

    readonly TOOL_URL_LIST="$API_URL/tags?per_page=100"
    start_debug "downloading $TOOL_URL_LIST"
    LIST=$(command curl -f "$PROGRESS" "$TOOL_URL_LIST" | command jq -r '.[].name') ||
        fail 'failed downloading and processing' "the output from $TOOL_URL_LIST"
        end_debug
    echo "$LIST"
}

uninstall_tool_version() {
    check_rm_exists
    check_ln_exists

    check_installer_directory_exists
    get_local_tool_versions
    get_local_tool_version_by_arg
    exists_local_tool_version "$TOOL_VER"
    if [[ "$VER_EXISTS" = "" ]]; then
        if [[ "$TOOL_VER" = "" ]]; then
            fail 'not found' "any version in $INST_DIR"
        else
            fail 'not found' "$INST_DIR/$TOOL_VER"
        fi
    else
        delete_tool_version "$TOOL_VER"
    fi

    try_current_tool_version
    if [ -n "$TOOL_CUR_VER" ] && [[ "$TOOL_CUR_VER" = "$TOOL_VER" ]]; then
        command rm "$TOOL_DIR" ||
            fail 'failed deleting' "$TOOL_DIR"
        get_local_tool_versions
        if [[ "${INST_LOCAL[*]}" != "" ]]; then
            get_latest_local_tool_version
            link_tool_version_directory "$TOOL_VER"
        else
            announce deleted "the latest $LANG_NAME version"
        fi
    fi
}

print_latest_remote_version() {
    check_curl_exists
    detect_platform
    get_latest_remote_version
    echo "$TOOL_LATEST_VER"
}

use_tool_version() {
    check_rm_exists
    check_ln_exists

    check_installer_directory_exists
    get_local_tool_versions
    get_local_tool_version_by_arg
    check_local_tool_version_exists

    get_current_tool_version
    if [[ "$TOOL_CUR_VER" != "$TOOL_VER" ]]; then
        link_tool_version_directory "$TOOL_VER"
        pass activated "$TOOL_VER"
    else
        ignore 'already active' "$TOOL_VER"
    fi
}

case $TASK in
current)
    print_tool_version
    ;;
help)
    print_usage_instructions
    ;;
install)
    install_tool_version
    ;;
latest)
    print_latest_remote_version
    ;;
local)
    print_local_tool_versions
    ;;
remote)
    print_remote_tool_versions
    ;;
up)
    update_installer_and_upgrade_tool_version
    ;;
update)
    update_installer
    ;;
upgrade)
    upgrade_tool_version
    ;;
uninstall)
    uninstall_tool_version
    ;;
use)
    use_tool_version
    ;;
version)
    print_installer_version
    ;;
esac
