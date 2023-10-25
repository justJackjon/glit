check_is_git_repo() {
    local path="$1"

    if [[ ! -d "$path/.git" ]]; then
        print error "Specified directory is not a git repository."

        exit $EXIT_NOT_WITHIN_GIT_REPO
    fi
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

generate_changes_output() {
    local dry_run_changelist="$1"
    local color="$2"
    local changes_symbol="$3"
    local target_path="$4"

    local changelist_prefix_regex="$5"
    local changelist_relative_path_regex='(([^\/]+\/)*)?'
    local changelist_filename_regex='([^\/]+(\.[A-Za-z0-9]+)?)?$'
    local changelist_record_regex="$changelist_prefix_regex$changelist_relative_path_regex$changelist_filename_regex"

    echo -e "$dry_run_changelist" | sed -n -E "s@$changelist_record_regex@${color} ${changes_symbol} ${target_path}\2\4${RESET}@p"
}

get_formatted_changelist() {
    local dry_run_changelist="$1"
    local target_path="$2"

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
    local deletions=$(generate_changes_output "$dry_run_changelist" "$RED" "-" "$target_path" "$del_prefix_regex")

    local add_prefix_regex="^([>c][fdLDS]\++ +)"
    local additions=$(generate_changes_output "$dry_run_changelist" "$GREEN" "+" "$target_path" "$add_prefix_regex")

    local mod_prefix_regex="^([>c][fdLDS][cstpogu\.]+ +)"
    local modifications=$(generate_changes_output "$dry_run_changelist" "$BLUE" "*" "$target_path" "$mod_prefix_regex")

    local combined_changes=""
    [[ -n "$deletions" ]] && combined_changes+="\nDeletions:\n$deletions\n"
    [[ -n "$additions" ]] && combined_changes+="\nAdditions:\n$additions\n"
    [[ -n "$modifications" ]] && combined_changes+="\nModifications:\n$modifications"

    echo -e "$combined_changes"
}

generate_change_summary() {
    local source_path="$1"
    local target_path="$2"

    shift 2; local -a rsync_common_options=("$@")
    local tempfile=$(mk_autocleaned_tempfile)

    rsync --dry-run --itemize-changes "${rsync_common_options[@]}" "$source_path" "$target_path" > "$tempfile" &

    show_spinner "$!" "Checking for changes..." "Finished checking for changes." > /dev/tty

    local dry_run_changelist=$(cat "$tempfile")
    local change_summary=$(get_formatted_changelist "$dry_run_changelist" "$target_path")

    echo -e "$change_summary"
}

output_change_summary_and_prompt() {
    local changelist="$1"

    if [[ $AUTO_CONFIRM == true ]]; then
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

sync_repo() {
    local local_path="$1"
    local -a rsync_common_options=(-vrtlDz --checksum --delete "${EXCLUDE_ARGS[@]}")

    check_is_git_repo "$local_path"

    IFS=$'\t' read -r source_path target_path < <(get_source_and_target_paths "$local_path")

    if [[ $FORCE_ACTION == false ]]; then
        local change_summary=$(generate_change_summary "$source_path" "$target_path" "${rsync_common_options[@]}")

        if [[ -z "$change_summary" ]]; then
            print success "No changes detected. Source and destination are in sync."

            exit 0
        fi

        output_change_summary_and_prompt "$change_summary"
    fi

    rsync --progress "${rsync_common_options[@]}" "$source_path" "$target_path"

    if [[ -n "$SUDO_USER" && "$ACTION" == "pull" ]]; then
        change_owner_and_group "$target_path"
    fi

    print success "Repository ${ACTION}ed successfully!"
}
