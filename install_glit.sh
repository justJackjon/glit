#!/usr/bin/env bash

# Instruct bash to immediately exit if any command has a non-zero exit status
set -e

# Default values
INSTALL_MODE="remote"
LOCAL_PATH="$(dirname "$(pwd)")"
VERSION="latest"
UNATTENDED=false

# Argument parsing
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

GH_API_ENDPOINT="https://api.github.com/repos/justJackjon/glit"
GLIT_REPO_URL="https://github.com/justJackjon/glit"
GLIT_DIR="/opt/glit"
SYMLINK_PATH="/usr/local/bin/glit"
DEPENDENCIES=("curl" "git" "rsync" "uname" "realpath")

if [[ "$INSTALL_MODE" == "remote" ]]; then
    TEMP_DIR=$(mktemp -d)
fi

cleanup() {
    echo -e "\n\nInstallation aborted. Cleaning up temporary files..."
    rm -rf "$TEMP_DIR"

    exit 1
}

# NOTE: Only trap on ERR, INT and TERM signals. TEMP_DIR is explicitly removed on successful EXIT.
trap cleanup ERR INT TERM

HEAVY_CHECK_MARK="\u2714"
RED="\e[31m"
GREEN="\e[32m"
BLUE="\e[34m"
RESET="\e[0m"

print() {
    local message_type="$1"
    local message="$2"
    local color=""
    local prefix=""
    local suffix=""

    case "$message_type" in
        error) color="$RED"; prefix="Error: ";;
        success) color="$GREEN"; suffix=" $HEAVY_CHECK_MARK";;
        info) color="$BLUE";;
    esac

    if [[ -t 1 ]]; then
        echo -e "${color}\n${prefix}${message}${suffix}$RESET"
    else
        echo -e "\n${prefix}${message}${suffix}"
    fi
}

ask_should_reinstall() {
    print info "\`glit\` is already installed."

    if $UNATTENDED || [[ ! -t 0 ]]; then
        print info "Running in non-interactive mode. Assuming 'yes' for reinstall."

        return 0
    fi

    echo ""
    read -p "Do you want to reinstall it? [y/N]: " response

    if [[ "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
        return 0
    else
        return 1
    fi
}

# Check for dependencies
for dep in "${DEPENDENCIES[@]}"; do
    if ! command -v "$dep" &> /dev/null; then
        print error "$dep is not installed. Please install $dep and try again."

        exit 1
    fi
done

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
        print info "Installation aborted."

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
