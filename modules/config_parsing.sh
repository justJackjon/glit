VARS_FOR_PATH_PROCESSING=("VOLUME_DIR" "VOLUME_NAME")

process_paths() {
    local key="$1"
    local value="$2"

    if [[ " ${VARS_FOR_PATH_PROCESSING[@]} " =~ " $key " ]]; then
        value=$(strip_path "$value")
    fi

    echo "$value"
}

parse_config_file() {
    local config_file="$1"

    if [[ ! -f "$config_file" ]]; then
        return 1
    fi

    while IFS="=" read -r key value; do
        # NOTE: Skip commented lines (lines starting with #)
        if [[ "$key" =~ ^[[:space:]]*# ]]; then
            continue
        fi

        # NOTE: Removes double quotes from the value if present
        value=$(echo "$value" | sed -E 's/^"?([^"]*)"?$/\1/')

        local processed_value=$(process_paths "$key" "$value")

        if [[ -n "$key" && -n "$processed_value" ]]; then
            declare -g "$key=$processed_value"
        fi
    done < "$config_file"
}

parse_config() {
    # NOTE: `eval` is used cautiously here; only expanding known vars for tilde resolution.
    local user_home_config="$(eval echo "~${SUDO_USER:-$USER}")/$CONFIG_FILENAME"
    local git_repo_config="$(get_git_root "$(pwd)" 0)/$CONFIG_FILENAME"

    # NOTE: Parse the global config file within the user's home directory
    parse_config_file "$user_home_config"

    # NOTE: If present, any values in the local config file will override the global config
    parse_config_file "$git_repo_config"
}
