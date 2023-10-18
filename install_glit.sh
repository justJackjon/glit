#!/usr/bin/env bash

# --- Set Script Options ---

# NOTE: Due to exit on error, append '|| :' to add a no-op fallback to commands that might fail where we should continue.
set -o errexit
set -o nounset

# --- Declare Variables ---

# Set global variables
RED="\e[31m"
YELLOW="\e[33m"
GREEN="\e[32m"
BLUE="\e[34m"
RESET="\e[0m"
INSTALL_MODE="remote"
LOCAL_PATH="$(dirname "$(pwd)")"
VERSION="latest"
GH_API_ENDPOINT="https://api.github.com/repos/justJackjon/glit"
GLIT_REPO_URL="https://github.com/justJackjon/glit"
GLIT_DIR="/opt/glit"
SYMLINK_PATH="/usr/local/bin/glit"
PREFIX_COMMAND=""
IS_ROOT=false
UNATTENDED=false
IS_INPUT_INTERACTIVE=false
IS_OUTPUT_INTERACTIVE=false
OS_NAME="$(uname)"
MINIMUM_BASH_VERSION=4.2
INSTALLED_BASH_VERSION="${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}"
BASH_VERSION_ISSUE=false
MISSING_REQUIRED_PKGS=()
MISSING_RECCOMENDED_PKGS=()

declare -A DEPENDENCIES=(
    ["curl"]="required"
    ["git"]="required"
    ["rsync"]="required"
    ["uname"]="required"
    ["realpath"]="required"
    ["bc"]="required"
    ["tput"]="recommended"
)

declare -A DEP_TO_PKG_MAP=(
    ["curl"]="curl"
    ["git"]="git"
    ["rsync"]="rsync"
    ["uname"]="coreutils"
    ["realpath"]="coreutils"
    ["tput"]="ncurses"
    ["bash"]="bash"
    ["bc"]="bc"
)

# Set conditional values
(( $(id -u) == 0 )) && IS_ROOT=true || :
[[ -t 0 ]] && IS_INPUT_INTERACTIVE=true || :
[[ -t 1 ]] && IS_OUTPUT_INTERACTIVE=true || :
[[ ! $IS_ROOT ]] && PREFIX_COMMAND="sudo " || :
[[ "$OS_NAME" == "Linux" && -f "/etc/debian_version" ]] && DEP_TO_PKG_MAP["tput"]="ncurses-bin" || :
[[ "$INSTALL_MODE" == "remote" ]] && TEMP_DIR=$(mktemp -d) || :

cleanup() {
    echo -e "\nInstallation aborted. Cleaning up temporary files...\n"
    rm -rf "$TEMP_DIR"

    exit 1
}

# NOTE: Only trap on ERR, INT and TERM signals. TEMP_DIR is explicitly removed on successful EXIT.
trap cleanup ERR INT TERM

# Check Bash version
if (( $(echo "$INSTALLED_BASH_VERSION < $MINIMUM_BASH_VERSION" | bc -l) )); then
    BASH_VERSION_ISSUE=true
    MISSING_REQUIRED_PKGS+=("${DEP_TO_PKG_MAP["bash"]}")
fi

# Check for missing dependencies
for DEPENDENCY in "${!DEPENDENCIES[@]}"; do
    command -v "$DEPENDENCY" &> /dev/null && continue

    if [[ "${DEPENDENCIES[$DEPENDENCY]}" == "required" ]]; then
        MISSING_REQUIRED_PKGS+=("${DEP_TO_PKG_MAP["$DEPENDENCY"]}")
    else
        MISSING_RECCOMENDED_PKGS+=("${DEP_TO_PKG_MAP["$DEPENDENCY"]}")
    fi
done

# Quick sanity check on the following variables as we rm -rf them later.
# NOTE: This is just for belt and braces. The user is unable to set these variables.
if [[ "$GLIT_DIR" == "/" ]] || [[ "$TEMP_DIR" == "/" ]]; then
    echo -e "\nInvalid value for GLIT_DIR or TEMP_DIR. Aborting."

    exit 1
fi

# --- Argument Parsing ---

while (( "$#" )); do
  case "$1" in
    local)
      INSTALL_MODE="local"
      shift
      ;;
    remote)
      INSTALL_MODE="remote"
      shift
      ;;
    -v|--version)
      VERSION="$2"
      shift 2
      ;;
    -u|--unattended)
      UNATTENDED=true
      shift
      ;;
    *)
      LOCAL_PATH="$1"
      shift
      ;;
  esac
done

# --- Fn Declarations ---

print() {
    local message_type="$1"
    local message="$2"
    local color=""
    local prefix=""
    local suffix=""

    case "$message_type" in
        error) color="$RED"; prefix="Error: ";;
        warning) color="$YELLOW"; prefix="Warning: ";;
        success) color="$GREEN"; suffix=" ✔";;
        info) color="$BLUE";;
    esac

    if $IS_OUTPUT_INTERACTIVE; then
        echo -e "${color}\n${prefix}${message}${suffix}$RESET"
    else
        echo -e "\n${prefix}${message}${suffix}"
    fi
}

print_dependencies() {
    local message_type=$1; shift
    local message=$1; shift
    local dependencies=("$@")

    print "$message_type" "$message\n"

    for dependency in "${dependencies[@]}"; do
        echo " - $dependency"
    done
}

provide_os_advice() {
    local os_message=$1
    local command_prefix=$2
    local command_name=$3
    local install_command=$4
    local extra_command=$5
    local additional_info=$6
    local deps_space=""

    (( ${#MISSING_REQUIRED_PKGS[@]} > 0 && ${#MISSING_RECCOMENDED_PKGS[@]} > 0 )) && deps_space=" " || :

    print info "It seems you're using $os_message. You can install these dependencies using $command_name:\n"

    [[ ! -z "$extra_command" ]] && echo -e "  \`${command_prefix}${extra_command}\`" || :

    echo -e "  \`${command_prefix}${install_command} ${MISSING_REQUIRED_PKGS[*]-}${deps_space}${MISSING_RECCOMENDED_PKGS[*]-}\`\n"

    [[ ! -z "$additional_info" ]] && echo -e "$additional_info\n" || :
}

ask_should_force_install() {
    echo
    read -p "Do you want to install \`glit\` anyway? [y/N]: " response

    if [[ "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
        echo -e "\nInstalling \`glit\`..."
    else
        echo -e "\nInstallation aborted."

        exit 0
    fi
}

ask_should_reinstall() {
    print info "\`glit\` is already installed."

    if $UNATTENDED || ! $IS_INPUT_INTERACTIVE; then
        print info "Running in non-interactive mode. Assuming 'yes' for reinstall."

        return 0
    fi

    echo
    read -p "Do you want to reinstall it? [y/N]: " response

    if [[ "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
        return 0
    else
        return 1
    fi
}

# --- Dependency Checks ---

if
    $BASH_VERSION_ISSUE || \
    (( ${#MISSING_REQUIRED_PKGS[@]} > 0 )) || \
    (( ${#MISSING_RECCOMENDED_PKGS[@]} > 0 ))
then
    SHOULD_ABORT=false

    echo -e "\n!!!--------------------------------------------"

    if $BASH_VERSION_ISSUE; then
        print error "Bash verion $INSTALLED_BASH_VERSION.x is installed."
        echo
        echo "The minimum version requred by \`glit\` is $MINIMUM_BASH_VERSION.x."
        echo "Please upgrade Bash and try again."

        SHOULD_ABORT=true
    fi

    if (( ${#MISSING_REQUIRED_PKGS[@]} > 0 )); then
        print_dependencies "error" "Missing or unsupported dependencies:" "${MISSING_REQUIRED_PKGS[@]}"

        SHOULD_ABORT=true
    fi

    if (( ${#MISSING_RECCOMENDED_PKGS[@]} > 0 )); then
        print_dependencies "warning" "\`glit\` will work best if you install the following recommended dependencies:" "${MISSING_RECCOMENDED_PKGS[@]}"
    fi

    echo -e "\n--------------------------------------------!!!"

    case $OS_NAME in
        Darwin)
            provide_os_advice "macOS" "$PREFIX_COMMAND" "Homebrew" "brew install" "" \
            "If you don't have Homebrew yet, visit https://brew.sh to get started."
            ;;
        Linux)
            if [[ -f /etc/debian_version ]]; then
                provide_os_advice "a Debian-based system" "$PREFIX_COMMAND" "apt" "apt install" "apt update" ""
            elif [[ -f /etc/redhat-release ]]; then
                provide_os_advice "a RedHat-based system" "$PREFIX_COMMAND" "yum or dnf" "yum install" "" ""
            elif [[ -f /etc/alpine-release ]]; then
                provide_os_advice "Alpine Linux" "$PREFIX_COMMAND" "apk" "apk add" "" ""
            fi
            ;;
        *)
            echo -e "Please install these dependencies using your system's package manager."
            ;;
    esac

    ! $IS_ROOT && echo -e "INFO: Only use \`sudo\` when necessary and understand the risks.\n" || :

    echo -e "!!!--------------------------------------------"

    if $SHOULD_ABORT; then
        print error "Installation aborted due to unmet prerequisites."

        exit 1
    fi

    ! $UNATTENDED && $IS_INPUT_INTERACTIVE && ask_should_force_install || :
fi

# --- Installation ---

# Check if the user has write permissions for the install directories
if [[ ! -w "/opt" || ! -w "/usr/local/bin" ]]; then
    print error "You do not have write permissions for /opt or /usr/local/bin."
    print info "You can try running this script with sudo, but you should be certain that you can trust the content that you are installing."

    exit 1
fi

# Check if the `glit` dir and symlink already exist
if [[ -d "$GLIT_DIR" || -L "$SYMLINK_PATH" ]]; then
    if ask_should_reinstall; then
        rm -rf "$GLIT_DIR"
        rm -f "$SYMLINK_PATH"
    else
        echo -e "\nInstallation aborted."

        exit 0
    fi
fi

# Determine the installation mode and act accordingly
if [[ "$INSTALL_MODE" == "local" ]]; then
    if [[ ! -d "$LOCAL_PATH/glit" ]]; then
        print error "The \`glit\` directory was not found at the specified or default path ($LOCAL_PATH/glit). Please provide a valid path or check your current directory."

        exit 1
    fi

    cp -r "$LOCAL_PATH/glit" "$GLIT_DIR"
else
    # NOTE: Using grep and sed to parse JSON so we don't add a dependency on `jq`
    if [[ "$VERSION" == "latest" ]]; then
        RELEASE_URL=$(curl -s "$GH_API_ENDPOINT/releases/latest" | grep tarball_url | sed 's/.*: "\(.*\)",/\1/')
    else
        RELEASE_URL=$(curl -s "$GH_API_ENDPOINT/releases/tags/$VERSION" | grep tarball_url | sed 's/.*: "\(.*\)",/\1/')
    fi

    # Check if RELEASE_URL is empty, which might be due to an invalid or non-existent tag
    if [[ -z "$RELEASE_URL" ]]; then
        print error "Failed to retrieve the release URL for version '$VERSION'. Please ensure the provided version exists."

        exit 1
    fi

    print info "Downloading \`glit\` from $RELEASE_URL...\n"

    curl -L "$RELEASE_URL" -o "$TEMP_DIR/glit.tar.gz"
    tar -xzf "$TEMP_DIR/glit.tar.gz" -C "$TEMP_DIR"

    mv $TEMP_DIR/justJackjon-glit-* "$GLIT_DIR"

    # NOTE: The cleanup trap will remove temp files on ERR, INT and TERM signals, but not on [successful] EXIT.
    rm -rf "$TEMP_DIR"

    print success "Temporary files have been cleaned up"
fi

# Create a symlink to the main `glit` script
ln -s "$GLIT_DIR/main.sh" "$SYMLINK_PATH"

# Set permissions to make `glit` accessible to normal users
chmod -R 755 "$GLIT_DIR"
chmod 755 "$SYMLINK_PATH"

# Print success messages
print success "\`glit\` has been successfully installed to $GLIT_DIR"
print success "A symlink for \`glit\` has been created in $SYMLINK_PATH"

# Verify if the symlink directory is in the PATH and provide usage instructions
if echo "$PATH" | tr ':' '\n' | grep -qx "$(dirname "$SYMLINK_PATH")"; then
    glit --help
else
    print info "Since $(dirname "$SYMLINK_PATH") is not in your PATH, you might not be able to run \`glit\` directly. Please add $(dirname "$SYMLINK_PATH") to your PATH and then try running 'glit --help'."
fi
