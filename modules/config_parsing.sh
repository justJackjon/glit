CONFIG_FILENAME=".glit_config"

parse_config_file() {
    local config_file="$1"

    if [[ ! -f "$config_file" ]]; then
        return 1
    fi

    while IFS="=" read -r key value; do
        # NOTE: Removes double quotes from the value if present
        local processed_value=$(echo "$value" | sed -E 's/^"?([^"]*)"?$/\1/')

        if [[ -n $key && -n $processed_value ]]; then
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
