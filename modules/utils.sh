determine_platform() {
    case "$PLATFORM" in
        Darwin)
            BASE_PATH="/Volumes"
            ;;
        Linux)
            if [[ "$VOLUME_TYPE" == "removable" ]]; then
                BASE_PATH="/media/${SUDO_USER:-$USER}"
            else
                BASE_PATH="/mnt"
            fi
            ;;
        *)
            print error "Unsupported platform: $PLATFORM"
            exit $EXIT_UNSUPPORTED_PLATFORM
            ;;
    esac
}

# NOTE: Supply `1` or `0` for the second parameter, to either exit on error or continue without exiting, respectively.
#       Defaults to `1` (exit on error).
get_git_root() {
    local dir="$1"
    local exit_on_error="${2:-1}"
    local git_root=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)

    if [[ $? -ne 0 && $exit_on_error -eq 1 ]]; then
        print error "The provided directory ($dir) is not within a git repository."

        exit $EXIT_NOT_WITHIN_GIT_REPO
    fi

    echo "$git_root"
}

is_git_repo() {
    local git_root=$(get_git_root "$1" 0)

    test -n "$git_root"
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

prompt_user_and_create_dir() {
    local volume_dir="$1"

    if [[ $AUTO_CONFIRM -eq 0 ]]; then
        echo -en "\nWould you like to attempt to create the directory? [y/N]: "
        read -r user_input

        if [[ ! "$user_input" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
            print error "Aborting operation due to user input."

            exit $EXIT_ABORTED_BY_USER
        fi
    fi

    print info "Attempting to create directory '$volume_dir/'..."

    mkdir -p "$volume_dir"

    if [[ $? -eq 0 ]]; then
        print success "Successfully created directory '$volume_dir/'"
    fi
}

create_volume_dir_if_not_exists() {
    local dir_relpath="$1"
    local volume_root="$BASE_PATH/${VOLUME_NAME:-$DEFAULT_VOLUME_NAME}"
    local volume_dir="$volume_root/$dir_relpath"
    local mounted_volume=$(mount | grep "$volume_root")

    if [[ -z "$mounted_volume" ]]; then
        print error "Volume \`$volume_root\` is not mounted. Please ensure the volume is mounted before proceeding."

        exit $EXIT_VOLUME_NOT_MOUNTED
    fi

    local formatted_mounted_volume=$(echo "$mounted_volume" | sed -E 's/ \(.*\)//')

    echo -e "\nMounted Volume: $formatted_mounted_volume"

    if [[ ! -d "$volume_dir" ]]; then
        case "$ACTION" in
            push)
                print warning "Volume directory $volume_dir/ is non-existent or inaccessible."

                prompt_user_and_create_dir "$volume_dir"
                ;;
            pull)
                print error "Volume directory $volume_dir/ is non-existent or inaccessible. Please create the directory before proceeding."

                exit $EXIT_VOLUME_NOT_ACCESSIBLE
                ;;
        esac
    fi

    if [[ ! -w "$volume_dir" ]]; then
        print error "Write permission denied for user $USER on volume $volume_dir. Check and update permissions."

        exit $EXIT_VOLUME_NOT_ACCESSIBLE
    fi
}

generate_exclude_args() {
    for exclusion in "${EXCLUSIONS[@]:-${DEFAULT_EXCLUSIONS[@]}}"; do
        EXCLUDE_ARGS+=(--exclude="$exclusion")
    done
}

mk_autocleaned_tempfile() {
    local temp_file=$(mktemp)

    trap "rm -f '$temp_file' 2>/dev/null" EXIT ERR INT TERM
    echo "$temp_file"
}

# NOTE: Removes leading `./` or `/` and trailing `/`
strip_path() {
    echo "$1" | sed -E 's@^\./|/@@; s@/$@@'
}

create_comma_separated_list() {
    local input_array=("$@")

    echo "${input_array[@]}" | sed -E "s/([^ ]+)/'\1',/g; s/,\$//"
}
