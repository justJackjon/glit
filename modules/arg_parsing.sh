TWO_ARGS_CONSUMED=1
ONE_ARG_CONSUMED=0

is_missing_value() {
    [[ -z "$1" || "$1" =~ ^--?[A-Za-z0-9] ]]
}

check_opt_missing_value() {
    local current_option="$1"
    local arg_value="$2"

    if is_missing_value "$arg_value"; then
        print error "The option $current_option requires a value."

        exit $EXIT_MISSING_VALUE_FOR_OPTION
    fi
}

parse_arg() {
    local current_arg="$1"
    local next_arg="$2"

    case "$current_arg" in
        -d|--dir)
            check_opt_missing_value "$current_arg" "$next_arg"

            VOLUME_DIR=$(strip_path "$next_arg")

            return $TWO_ARGS_CONSUMED
            ;;
        -e|--exclude)
            check_opt_missing_value "$current_arg" "$next_arg"

            IFS=',' read -ra EXCLUSIONS < <(echo "$next_arg")

            return $TWO_ARGS_CONSUMED
            ;;
        -f|--force)
            FORCE_ACTION=1

            return $ONE_ARG_CONSUMED
            ;;
        -h|--help)
            display_help
            ;;
        -t|--type)
            check_opt_missing_value "$current_arg" "$next_arg"

            if ! [[ " ${ACCEPTABLE_TYPE_ARGS[*]} " =~ " $next_arg " ]]; then
                # NOTE: Formats the array of acceptable arguments into a comma-separated list
                local formatted_arg_list=$(echo "${ACCEPTABLE_TYPE_ARGS[@]}" | sed -E "s/([^ ]+)/'\1',/g; s/,\$//")

                print error "Invalid argument for --type option. Acceptable arguments are: $formatted_arg_list."

                exit $EXIT_UNRECOGNIZED_OPTION
            fi

            VOLUME_TYPE="$next_arg"

            return $TWO_ARGS_CONSUMED
            ;;
        -V|--volume)
            check_opt_missing_value "$current_arg" "$next_arg"

            VOLUME_NAME=$(strip_path "$next_arg")

            return $TWO_ARGS_CONSUMED
            ;;
        -y|--yes)
            AUTO_CONFIRM=1
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

    return $ONE_ARG_CONSUMED
}

parse_args() {
    local arguments=("$@")
    local skip_current_arg=0
    local total_arguments=${#arguments[@]}

    if (( total_arguments == 0 )); then
        display_help

        exit $EXIT_NO_ARGS
    fi

    for (( i=0; i<total_arguments; i++ )); do

        if (( skip_current_arg )); then
            skip_current_arg=0
            continue
        fi

        local current_arg="${arguments[$i]}"
        local next_arg="${arguments[$((i+1))]:-}"

        if (( i+1 < total_arguments )); then
            parse_arg "$current_arg" "$next_arg"
            skip_current_arg=$?  # 0 if only one argument was consumed, 1 if two arguments were consumed
        else
            parse_arg "$current_arg"
        fi

    done
}
