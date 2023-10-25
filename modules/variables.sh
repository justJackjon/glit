string_ternary() {
    local condition="$1"
    local true_case="$2"
    local false_case="$3"

    { "$condition" && echo "$true_case"; } || echo "$false_case"
}

predicate() {
    { "$@" && echo "true"; } || echo "false"
}

is_root() {
    (( $(id -u) == 0 ))
}

is_input_interactive() {
    [[ -t 0 ]]
}

is_output_interactive() {
    [[ -t 1 ]]
}

IS_ROOT=$(predicate is_root)
IS_INPUT_INTERACTIVE=$(predicate is_input_interactive)
IS_OUTPUT_INTERACTIVE=$(predicate is_output_interactive)
FORCE_ACTION=0
AUTO_CONFIRM=0
VERSION="v0.1-beta.2"
RELEASE_DATE="October 25, 2023"
MINIMUM_BASH_VERSION=4.2
DEFAULT_VOLUME_NAME="z"
DEFAULT_EXCLUSIONS=("node_modules/" ".git/" "bin/" "obj/")
PLATFORM=$(uname)
ACCEPTABLE_ACTION_ARGS=("push" "pull")
ACCEPTABLE_TYPE_ARGS=("networked" "removable")
VOLUME_TYPE="networked"
VOLUME_DIR="SharedRepos"
VOLUME_NAME=""
ACTION=""
REPO_PATH=""
BASE_PATH=""
EXCLUSIONS=()
EXCLUDE_ARGS=()
CONFIG_FILENAME=".glit_config"
DEPENDENCIES_CHECKED=false

RED=$(tput setaf 1 2>/dev/null || echo -e "\e[31m")
GREEN=$(tput setaf 2 2>/dev/null || echo -e "\e[32m")
YELLOW=$(tput setaf 3 2>/dev/null || echo -e "\e[33m")
BLUE=$(tput setaf 4 2>/dev/null || echo -e "\e[34m")
RESET=$(tput sgr0 2>/dev/null || echo -e "\e[0m")
