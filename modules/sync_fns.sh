check_git_repo() {
    local path="$1"

    if [[ ! -d "$path/.git" ]]; then
        print error "Specified directory is not a git repository."

        exit $EXIT_NOT_WITHIN_GIT_REPO
    fi
}

generate_changes_output() {
    local dry_run_changelist="$1"
    local color="$2"
    local changes_symbol="$3"
    local target_path="$4"

    local changelist_prefix_regex="$5"
    local changelist_relative_path_regex='(([^\/]+\/)*)?'
    local changelist_filename_regex='([^\/]+(\.[A-Za-z0-9]+)?)?$'
    local changelist_record_regex="$changelist_prefix_regex$changelist_relative_path_regex$changelist_filename_regex"

    echo -e "$dry_run_changelist" | sed -n -E "s@$changelist_record_regex@${color} ${changes_symbol} ${target_path}\2\4${reset}@p"
}

get_formatted_changelist() {
    local dry_run_changelist="$1"
    local target_path="$2"

    local red=$(tput setaf 1)
    local green=$(tput setaf 2)
    local blue=$(tput setaf 4)
    local reset=$(tput sgr0)

    # NOTE: `rsync` Output Prefix Characters:
    # >: The item is being transferred to the remote host (sent).
    # <: The item is being transferred to the local host (received).
    # c: The item is a change (for a file, it means the file’s data changed; for a directory, it means an item inside the directory changed).

    # NOTE: `rsync` Resource Type Indicators:
    # f: File
    # d: Directory
    # L: Symbolic Link
    # D: Device
    # S: Special file

    # NOTE: `rsync` Modification Flags:
    # s: The item’s size is changing.
    # t: The item’s modification time is changing.
    # p: The item’s permissions are changing.
    # o: The item’s owner is changing.
    # g: The item’s group is changing.
    # u: The item is being updated (implies one of the other flags is also present).
    # .: If a flag isn’t present, a dot (.) will take its place.

    local del_prefix_regex="^(\*deleting +)"
    local deletions=$(generate_changes_output "$dry_run_changelist" "$red" "-" "$target_path" "$del_prefix_regex")

    local add_prefix_regex="^([>c][fdLDS]\++ +)"
    local additions=$(generate_changes_output "$dry_run_changelist" "$green" "+" "$target_path" "$add_prefix_regex")

    local mod_prefix_regex="^([>c][fdLDS][cstpogu\.]+ +)"
    local modifications=$(generate_changes_output "$dry_run_changelist" "$blue" "*" "$target_path" "$mod_prefix_regex")

    local combined_changes=""
    [[ -n "$deletions" ]] && combined_changes+="\nDeletions:\n$deletions\n"
    [[ -n "$additions" ]] && combined_changes+="\nAdditions:\n$additions\n"
    [[ -n "$modifications" ]] && combined_changes+="\nModifications:\n$modifications"

    echo -e "$combined_changes"
}

prompt_user_for_confirmation() {
    local changelist="$1"

    if [[ $AUTO_CONFIRM -eq 1 ]]; then
        print info "Applying the following changes:"
        echo -e "$changelist"
        echo ""

        return 0
    fi

    print warning "Continuing this operation will make the following changes:"
    echo -e "$changelist"

    echo -en "\nDo you want to proceed with these changes in the target directory? [y/N]: "
    read -r user_input

    if [[ ! "$user_input" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
        print error "Aborting operation due to user input."

        exit $EXIT_ABORTED_BY_USER
    fi

    echo ""
}

change_owner_and_group() {
    local target_path="$1"
    local sudo_user_group=$(id -gn "$SUDO_USER")

    print info "Changing ownership of synced items to $SUDO_USER:$sudo_user_group..."

    chown -R "$SUDO_USER:$sudo_user_group" "$target_path"
}

get_source_and_target_paths() {
    local local_path="$1"
    local volume_path="$BASE_PATH/${VOLUME_NAME:-$DEFAULT_VOLUME_NAME}/$VOLUME_DIR/$(basename "$local_path")/"
    local source_path=""
    local target_path=""

    case "$ACTION" in
        push)
            source_path="$local_path/"
            target_path="$volume_path"
            ;;
        pull)
            source_path="$volume_path"
            target_path="$local_path/"
            ;;
        *)
            print error "No valid action provided (push or pull). Use -h or --help for usage."

            exit $EXIT_UNRECOGNIZED_OPTION
            ;;
    esac

    echo -e "$source_path\t$target_path"
}

sync_repo() {
    local local_path="$1"
    local tempfile=$(mk_autocleaned_tempfile)

    check_git_repo "$local_path"

    IFS=$'\t' read -r source_path target_path < <(get_source_and_target_paths "$local_path")

    rsync --dry-run --itemize-changes -vrtlDz --delete "${EXCLUDE_ARGS[@]}" "$source_path" "$target_path" > "$tempfile" &

    show_spinner "$!" "Checking for changes..." "Finished checking for changes."

    local dry_run_changelist=$(cat "$tempfile")
    local discovered_changes=$(get_formatted_changelist "$dry_run_changelist" "$target_path")

    if [[ -z "$discovered_changes" ]]; then
        print success "No changes detected. Source and destination are in sync."

        exit 0
    fi

    prompt_user_for_confirmation "$discovered_changes"

    rsync -vrtlDz --delete --progress "${EXCLUDE_ARGS[@]}" "$source_path" "$target_path"

    if [[ -n "$SUDO_USER" && "$ACTION" == "pull" ]]; then
        change_owner_and_group "$target_path"
    fi

    print success "Repository ${ACTION}ed successfully!"
}
