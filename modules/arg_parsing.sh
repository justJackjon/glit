TWO_VALUES_CONSUMED=1
ONE_VALUE_CONSUMED=0

is_early_exit_option() {
    local args_and_options=("$@")
    local early_return_options=("-h" "--help" "-v" "--version")

    if [[ " ${early_return_options[*]} " =~ " ${args_and_options[0]} " ]]; then
        return 0
    fi

    return 1
}

# NOTE: Usage: glit <push|pull> [optional-local-path-to-repo] [OPTIONS]
parse_positional_args() {
    local positional_args=("$@")
    local total_positional_args=${#positional_args[@]}

    # 1st position
    ACTION="${positional_args[0]}"

    # 2nd position
    if (( total_positional_args > 1 )); then
        REPO_PATH="${positional_args[1]}"
    fi
}

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

validate_volume_type() {
    local volume_type="$1"
    local formatted_volume_types=$(create_comma_separated_list "${ACCEPTABLE_TYPE_ARGS[@]}")

    if ! [[ " ${ACCEPTABLE_TYPE_ARGS[*]} " =~ " ${volume_type} " ]]; then
        print error "Invalid argument for --type option. Acceptable volume types are: $formatted_volume_types."

        exit $EXIT_UNRECOGNIZED_ARGUMENT
    fi
}

parse_arg() {
    local current_value="$1"
    local next_value="$2"

    case "$current_value" in
        -d|--dir)
            check_opt_missing_value "$current_value" "$next_value"

            VOLUME_DIR=$(strip_path "$next_value")

            return $TWO_VALUES_CONSUMED
            ;;
        -e|--exclude)
            check_opt_missing_value "$current_value" "$next_value"

            IFS=',' read -ra EXCLUSIONS < <(echo "$next_value")

            return $TWO_VALUES_CONSUMED
            ;;
        -f|--force)
            FORCE_ACTION=1

            return $ONE_VALUE_CONSUMED
            ;;
        -h|--help)
            display_help

            # NOTE: display_help will exit, so we don't need to do anything else here.
            ;;
        -t|--type)
            check_opt_missing_value "$current_value" "$next_value"

            validate_volume_type "$next_value"

            VOLUME_TYPE="$next_value"

            return $TWO_VALUES_CONSUMED
            ;;
        -V|--volume)
            check_opt_missing_value "$current_value" "$next_value"

            VOLUME_NAME=$(strip_path "$next_value")

            return $TWO_VALUES_CONSUMED
            ;;
        -y|--yes)
            AUTO_CONFIRM=1

            return $ONE_VALUE_CONSUMED
            ;;
        *)
            print error "Unrecognised option: $current_value"

            exit $EXIT_UNRECOGNIZED_OPTION
            ;;
    esac

    return $ONE_VALUE_CONSUMED
}

parse_options() {
    local options=("$@")
    local total_options=${#options[@]}
    local skip_current_value=0

    for (( i=0; i<total_options; i++ )); do

        if (( skip_current_value )); then
            skip_current_value=0

            continue
        fi

        local current_value="${options[$i]}"
        local next_value="${options[$((i+1))]:-}"

        if (( i+1 < total_options )); then
            parse_arg "$current_value" "$next_value"
            skip_current_value=$?  # 0 if only one value was consumed, 1 if two value were consumed
        else
            parse_arg "$current_value"
        fi

    done
}

parse_args_and_options() {
    local args_and_options=("$@")
    local total_args_and_options=${#args_and_options[@]}

    if (( total_args_and_options == 0 )); then
        display_help
    fi

    # NOTE: This logic relies (correctly) on all positional arguments appearing before any options.
    # Should this change in the future, this logic will need to be updated.
    local positional_args=($(echo "$@" | tr ' ' '\n' | sed -n '/^-/q;p' | tr '\n' ' '))
    local total_positional_args=${#positional_args[@]}
    local options=("${args_and_options[@]:$total_positional_args}")

    if ! is_early_exit_option "${args_and_options[@]}"; then
        parse_positional_args "${positional_args[@]}"
    fi

    parse_options "${options[@]}"
}
