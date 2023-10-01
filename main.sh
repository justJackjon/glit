#!/usr/bin/env bash

# --- Exit Codes ---

EXIT_MISSING_DEPS=1
EXIT_VOLUME_NOT_ACCESSIBLE=2
EXIT_NOT_WITHIN_GIT_REPO=3
EXIT_MISSING_VALUE_FOR_OPTION=4
EXIT_UNABLE_TO_LOCATE_GIT_REPO=5
EXIT_UNRECOGNIZED_OPTION=6
EXIT_ABORTED_BY_USER=7
EXIT_UNSUPPORTED_PLATFORM=8

# --- Dependency Checks ---

REQUIRED_DEPENDENCIES=("rsync" "git" "uname" "realpath")

for cmd in "${REQUIRED_DEPENDENCIES[@]}"; do
    if ! command -v "$cmd" &>/dev/null; then
        print error "$cmd is not installed or not in the PATH. Please install $cmd."

        exit $EXIT_MISSING_DEPS
    fi
done

# --- Modules ---

DIR="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" && pwd)"

source "$DIR/modules/variables.sh"
source "$DIR/modules/print_fn.sh"
source "$DIR/modules/arg_parsing.sh"
source "$DIR/modules/utils.sh"
source "$DIR/modules/sync_fns.sh"

# --- Usage Fn ---

display_help() {
    echo ""
    echo "Usage: glit <push|pull> [optional-local-path-to-repo] [OPTIONS]"
    echo ""
    echo "Synchronises the provided git repository with a mounted volume such as a networked"
    echo "drive or removable media. If no local path is provided, the root of the closest git"
    echo "repository will be used."
    echo ""
    echo "Options:"
    echo "  -e, --exclude   Comma-separated list of paths to exclude from syncing."
    echo "                  Default exclusions are: node_modules/, .git/, bin/, obj/"
    echo "                  Exclusion paths are relative to the root of the repo."
    echo ""
    echo "  -h, --help      Display this help message and exit."
    echo ""
    echo "  -t, --type      Specify the type of mounted volume: 'networked' or 'removable'."
    echo "                  Default is 'networked'."
    echo ""
    echo "  -V, --volume    Specify the name of the mounted volume. Default is '$DEFAULT_VOLUME_NAME'."
    echo "                  Ensure the volume is mounted and writable at the following"
    echo "                  locations: For macOS, under \`/Volumes\`. For Linux, use \`/mnt\`"
    echo "                  for networked volumes and \`/media\` for removable volumes."
    echo ""
    echo "  -y, --yes       Automatically answer 'yes' to the sync confirmation prompt."
    echo ""

    exit 0
}

# --- Main Logic ---

parse_args "$@"

determine_platform
check_volume_access
set_repo_path
generate_exclude_args

sync_repo "$REPO_PATH"
