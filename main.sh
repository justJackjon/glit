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
EXIT_VOLUME_NOT_MOUNTED=9
EXIT_MANDATORY_ARGUMENT_MISSING=10
EXIT_UNRECOGNIZED_ARGUMENT=11
EXIT_CONFIG_CREATION_FAILED=12
EXIT_CONFIG_MODIFICATION_FAILED=13

# --- Modules ---

DIR="$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")" && pwd)"

source "$DIR/modules/variables.sh"
source "$DIR/modules/print_fn.sh"
source "$DIR/modules/config_parsing.sh"
source "$DIR/modules/dependency_checking.sh"
source "$DIR/modules/arg_parsing.sh"
source "$DIR/modules/utils.sh"
source "$DIR/modules/sync_fns.sh"
source "$DIR/modules/loading_spinner.sh"

# --- Display Info Fns ---

display_help() {
    echo
    echo "Usage: glit <push|pull> [optional-local-path-to-repo] [OPTIONS]"
    echo
    echo "Synchronises the provided git repository with a mounted volume such as a networked"
    echo "drive or removable media. If no local path is provided, the root of the closest git"
    echo "repository will be used."
    echo
    echo "Options:"
    echo "  -d, --dir       Specify the path to the mounted volume directory. Default is"
    echo "                  '$VOLUME_DIR'. The path is relative to the root of the mounted"
    echo "                  volume."
    echo
    echo "  -e, --exclude   Comma-separated list of paths to exclude from syncing. Default"
    echo "                  exclusions are: node_modules/, .git/, bin/, obj/ - exclusion"
    echo "                  paths are relative to the root of the repo."
    echo
    echo "  -f, --force     Similar to \`-y\`/\`--yes\`, but instead of outputting the formatted"
    echo "                  change summary, the sync will be performed immediately."
    echo
    echo "  -h, --help      Display this help message and exit."
    echo
    echo "  -t, --type      Specify the type of mounted volume: 'networked' or 'removable'."
    echo "                  Default is 'networked'."
    echo
    echo "  -v, --version   Display version information and exit."
    echo
    echo "  -V, --volume    Specify the name of the mounted volume. Default is '$DEFAULT_VOLUME_NAME'."
    echo "                  Ensure the volume is mounted and writable at the following"
    echo "                  locations: For macOS, under \`/Volumes\`. For Linux, use \`/mnt\`"
    echo "                  for networked volumes and \`/media\` for removable volumes."
    echo
    echo "  -y, --yes       Automatically answer 'yes' to the sync confirmation prompt. Note"
    echo "                  that this option is ignored if \`-f\`/\`--force\` is also specified."
    echo "                  This is useful if you still want to see the formtted change"
    echo "                  summary, but wish to skip the confirmation prompt. This option is"
    echo "                  slower than \`-f\`/\`--force\` as it requires a dry run to generate"
    echo "                  the change summary."
    echo

    exit 0
}

display_version() {
    echo -e "\n\e[1m\`glit\` $VERSION\e[0m"
    echo
    echo "Release Date: $RELEASE_DATE"
    echo
    echo "License: MIT"
    echo -e "Website: \e]8;;https://github.com/justJackjon/glit\ahttps://github.com/justJackjon/glit\e]8;;\a"
    echo -e "Contact: \e]8;;https://github.com/justJackjon/glit/issues\ahttps://github.com/justJackjon/glit/issues\e]8;;\a"
    echo
    echo "About:"
    echo "\`glit\` is a user-friendly wrapper around \`rsync\`, designed to assist in synchronising"
    echo "git repositories with mounted volumes such as networked drives or removable media."
    echo

    exit 0
}

# --- Main Logic ---

parse_config
parse_args_and_options "$@"

determine_platform
check_dependencies
create_volume_dir_if_not_exists "$VOLUME_DIR"
set_repo_path
generate_exclude_args

sync_repo "$REPO_PATH"
