determine_platform() {
    case "$PLATFORM" in
        Darwin)
            BASE_PATH="/Volumes"
            ;;
        Linux)
            BASE_PATH="/mnt"
            ;;
        *)
            print error "Unsupported platform: $PLATFORM"

            exit $EXIT_UNSUPPORTED_PLATFORM
            ;;
    esac
}

get_git_root() {
    local dir="$1"
    local git_root=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)

    if [[ $? -ne 0 ]]; then
        print error "The provided directory ($dir) is not within a git repository."

        exit $EXIT_NOT_WITHIN_GIT_REPO
    fi

    echo "$git_root"
}

set_repo_path() {
    if [[ -n "$REPO_PATH" ]]; then
        return
    fi

    local git_root=$(get_git_root "$(pwd)")

    if [[ -z "$git_root" ]]; then
        print error "Unable to locate a git repository. Provide a valid path or run this command inside a git repository."

        exit $EXIT_UNABLE_TO_LOCATE_GIT_REPO
    fi

    REPO_PATH="$git_root"
}

check_volume_access() {
    local volume_dir="$BASE_PATH/${VOLUME_NAME:-$DEFAULT_VOLUME_NAME}/SharedRepos/"
    
    if [[ ! -d "$volume_dir" ]]; then
        print error "Volume $volume_dir is non-existent or inaccessible by user $USER. Verify path and user permissions."

        exit $EXIT_VOLUME_NOT_ACCESSIBLE
    elif [[ ! -w "$volume_dir" ]]; then
        print error "Write permission denied for user $USER on volume $volume_dir. Check and update permissions."

        exit $EXIT_VOLUME_NOT_ACCESSIBLE
    fi
}

generate_exclude_args() {
    for exclusion in "${EXCLUSIONS[@]:-${DEFAULT_EXCLUSIONS[@]}}"; do
        EXCLUDE_ARGS+=(--exclude="$exclusion")
    done
}
