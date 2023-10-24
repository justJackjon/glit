MISSING_REQUIRED_PKGS=()
MISSING_RECOMMENDED_PKGS=()

declare -A DEPENDENCIES=(
    ["curl"]="required"
    ["git"]="required"
    ["rsync"]="required"
    ["uname"]="required"
    ["realpath"]="required"
    ["tput"]="recommended"
)

declare -A DEP_TO_PKG_MAP=(
    ["curl"]="curl"
    ["git"]="git"
    ["rsync"]="rsync"
    ["uname"]="coreutils"
    ["realpath"]="coreutils"
    ["tput"]="ncurses"
    ["bash"]="bash"
)

if [[ "$PLATFORM" == "Linux" && -f "/etc/debian_version" ]]; then
    DEP_TO_PKG_MAP["tput"]="ncurses-bin"
fi

check_available_commands() {
    for DEPENDENCY in "${!DEPENDENCIES[@]}"; do
        command -v "$DEPENDENCY" &> /dev/null && continue

        if [[ "${DEPENDENCIES[$DEPENDENCY]}" == "required" ]]; then
            MISSING_REQUIRED_PKGS+=("${DEP_TO_PKG_MAP["$DEPENDENCY"]}")
        else
            MISSING_RECOMMENDED_PKGS+=("${DEP_TO_PKG_MAP["$DEPENDENCY"]}")
        fi
    done
}

print_bash_version_error() {
    local installed_bash_version="${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}"

    print error "Bash version $installed_bash_version.x is installed."
    echo
    echo "The minimum version requred by \`glit\` is $MINIMUM_BASH_VERSION.x."
    echo "Please upgrade Bash and try again."
}

print_dependencies() {
    local message_type=$1; shift
    local message=$1; shift
    local dependencies=("$@")

    print "$message_type" "$message\n"

    for dependency in "${dependencies[@]}"; do
        echo " - $dependency"
    done
}

create_os_advice() {
    local os_message=$1; shift
    local command_prefix=$2; shift
    local command_name=$3; shift
    local install_command=$4; shift
    local extra_command=$5; shift
    local lines_of_additional_info=("$@")
    local deps_space=""

    if (( ${#MISSING_REQUIRED_PKGS[@]} > 0 && ${#MISSING_RECOMMENDED_PKGS[@]} > 0 )); then
        deps_space=" "
    fi

    print info "It seems you are using $os_message. You may be able to install missing dependencies using $command_name:\n"

    if [[ ! -z "$extra_command" ]]; then
        echo -e "  \`${command_prefix}${extra_command}\`"
    fi

    echo -e "  \`${command_prefix}${install_command} ${MISSING_REQUIRED_PKGS[*]-}${deps_space}${MISSING_RECOMMENDED_PKGS[*]-}\`"

    for line in "${lines_of_additional_info[@]}"; do
        echo -e "$line"
    done
}

print_os_specific_advice() {
    local prefix_command="$(string_ternary "$IS_ROOT" "" "sudo ")"

    case "$PLATFORM" in
        Darwin)
            create_os_advice "macOS" "$prefix_command" "Homebrew" "brew install" "" \
            "If you don't have Homebrew yet, visit https://brew.sh to get started." \
            "In a typical installation, you must ensure \`/usr/local/bin/\` is before \`/bin/\` in your \$PATH."
            ;;
        Linux)
            if [[ -f /etc/debian_version ]]; then
                create_os_advice "a Debian-based system" "$prefix_command" "apt" "apt install" "apt update" ""
            elif [[ -f /etc/redhat-release ]]; then
                create_os_advice "a RedHat-based system" "$prefix_command" "yum or dnf" "yum install" "" ""
            elif [[ -f /etc/alpine-release ]]; then
                create_os_advice "Alpine Linux" "$prefix_command" "apk" "apk add" "" ""
            fi
            ;;
        *)
            echo "Please install these dependencies using your system's package manager."
            ;;
    esac

    if ! "$IS_ROOT"; then
        echo -e "INFO: Only use \`sudo\` when necessary and when you understand the risks.\n"
    fi
}

print_dependency_issues() {
    local bash_version_issue="$1"
    local num_missing_required_pkgs="$2"
    local num_missing_recommended_pkgs="$3"

    echo -e "\n!!!--------------------------------------------"

    if "$bash_version_issue"; then
        print_bash_version_error

        MISSING_REQUIRED_PKGS+=("${DEP_TO_PKG_MAP["bash"]}")
    fi

    if (( $num_missing_required_pkgs > 0 )); then
        print_dependencies "error" "Missing or unsupported dependencies:" "${MISSING_REQUIRED_PKGS[@]}"
    fi

    if (( $num_missing_recommended_pkgs > 0 )); then
        print_dependencies "warning" "For the best experience with \`glit\`, install the following recommended dependencies:" "${MISSING_RECOMMENDED_PKGS[@]}"
    fi

    echo -e "\n--------------------------------------------!!!"

    print_os_specific_advice

    echo -e "!!!--------------------------------------------"
}

key_in_file() {
    local key="$1"
    local file="$2"

    grep -q "$key=" "$file"
}

create_config_and_insert() {
    local filepath="$1"
    local key="$2"
    local value="$3"

    echo "$key=$value" > "$filepath"

    if [[ ! -f "$filepath" ]]; then
        print error "Failed to create the \`glit\` configuration file at \`$filepath\`."

        exit $EXIT_CONFIG_CREATION_FAILED
    fi
}

update_config() {
    local filepath="$1"
    local key="$2"
    local value="$3"

    # NOTE: The -i option in GNU sed works differently than BSD sed,
    # so we use a temp file to ensure cross-platform compatibility.
    sed "s/$key=[A-Za-z]*/$key=$value/" "$filepath" > "${filepath}.tmp" &&
    mv "${filepath}.tmp" "$filepath"
}

adjust_file_permissions() {
    local file="$1"

    (( $EUID == 0 )) && [[ -n $SUDO_USER ]] && chown "$SUDO_USER" "$file"

    # NOTE: There should be nothing sensitive in the config file,
    # so read permissions for all users is fine.
    chmod 644 "$file"
}

set_dependencies_checked() {
    local config_path="$1"
    local value="$2"

    if ! [[ "$value" =~ ^(true|false)$ ]]; then

        return 1
    fi

    local key="DEPENDENCIES_CHECKED"
    local action=""

    if [[ ! -f "$config_path" ]]; then
        create_config_and_insert "$config_path" "$key" "$value"

        action="Created a"

    elif key_in_file "$key" "$config_path"; then
        update_config "$config_path" "$key" "$value"

        action="Updated the"
    else
        echo "$key=$value" >> "$config_path"

        action="Appended the"
    fi

    adjust_file_permissions "$config_path"

    print success "$action \`glit\` configuration file at \`$config_path\` with \`$key=$value\`."
    print warning "Dependencies for \`glit\` will not be checked again until \`$key\` is set to \`false\`."
}

is_bash_version_issue() {
    local installed=()
    local required=()

    IFS='.' read -ra installed <<< "${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}"
    IFS='.' read -ra required <<< "$MINIMUM_BASH_VERSION"

    for i in "${!installed[@]}"; do
        if (( installed[i] < required[i] )); then
            return 0
        elif (( installed[i] > required[i] )); then
            return 1
        fi
    done

    return 1
}

check_dependencies() {
    if "$DEPENDENCIES_CHECKED"; then

        return
    fi

    check_available_commands

    local bash_version_issue=$(predicate is_bash_version_issue)
    local num_missing_required_pkgs=${#MISSING_REQUIRED_PKGS[@]}
    local num_missing_recommended_pkgs=${#MISSING_RECOMMENDED_PKGS[@]}
    local num_total_missing_pkgs=$(( $num_missing_required_pkgs + $num_missing_recommended_pkgs ))

    if "$bash_version_issue" || (( $num_total_missing_pkgs > 0 )); then
        print_dependency_issues "$bash_version_issue" "$num_missing_required_pkgs" "$num_missing_recommended_pkgs"
    fi

    if "$bash_version_issue" || (( $num_missing_required_pkgs > 0 )); then
        print error "Execution aborted due to unmet prerequisites."

        exit $EXIT_MISSING_DEPS
    fi

    if (( $num_total_missing_pkgs == 0 )); then
        # Using `eval` for home directory expansion. This relies on system-defined variables and
        # manipulation of these implies prior system compromise.
        local actual_home=$(eval echo ~${SUDO_USER:-$USER})
        local global_config_path="$actual_home/$CONFIG_FILENAME"
        local value="true"

        set_dependencies_checked "$global_config_path" "$value"

        if (( $? != 0 )) || ! key_in_file "$key" "$global_config_path"; then
            print error "Failed to set \`DEPENDENCIES_CHECKED\` to \`$value\` in global config file at $global_config_path."

            exit $EXIT_CONFIG_MODIFICATION_FAILED
        fi
    fi
}
