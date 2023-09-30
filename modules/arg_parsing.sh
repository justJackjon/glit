is_missing_value() {
    [[ -z "$1" || "$1" =~ ^--?[A-Za-z0-9] ]]
}

parse_arg() {
    local current_arg="$1"
    local next_arg="$2"
    local original_ifs="$IFS"

    case "$current_arg" in
        -V|--volume)
            if is_missing_value "$next_arg"; then
                print error "The option $current_arg requires a value."

                exit $EXIT_MISSING_VALUE_FOR_OPTION
            fi

            VOLUME_NAME="$next_arg"

            return 1  # Indicate that two arguments have been consumed
            ;;
        -e|--exclude)
            if is_missing_value "$next_arg"; then
                print error "The option $current_arg requires a value."

                exit $EXIT_MISSING_VALUE_FOR_OPTION
            fi

            IFS=',' read -ra EXCLUSIONS <<< "$next_arg"
            IFS="$original_ifs"

            return 1  # Indicate that two arguments have been consumed
            ;;
        -y|--yes)
            AUTO_CONFIRM=1
            ;;
        -h|--help)
            display_help
            ;;
        push|pull)
            if [[ -z "$ACTION" ]]; then
                ACTION="$current_arg"
            fi
            ;;
        -*)
            print error "Unrecognised option: $current_arg"

            exit $EXIT_UNRECOGNIZED_OPTION
            ;;
        *)
            if [[ -z "$REPO_PATH" ]]; then
                REPO_PATH="$current_arg"
            fi
            ;;
    esac

    return 0  # Indicate that only one argument has been consumed
}

parse_args() {
    local arguments=("$@")
    local consume_next=0
    local total_arguments=${#arguments[@]}

    for (( i=0; i<total_arguments; i++ )); do
        local current_arg="${arguments[$i]}"
        local next_arg="${arguments[$((i+1))]:-}"

        if (( consume_next )); then
            consume_next=0
            continue
        fi

        if (( i+1 < total_arguments )); then
            parse_arg "$current_arg" "$next_arg"
            consume_next=$?  # 0 if only one argument was consumed, 1 if two arguments were consumed
        else
            parse_arg "$current_arg"
        fi
    done
}
