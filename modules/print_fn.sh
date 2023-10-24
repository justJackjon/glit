print() {
    local message_type="$1"
    local message="$2"
    local color=""
    local prefix=""
    local suffix=""

    case "$message_type" in
        error) color="$RED"; prefix="Error: ";;
        warning) color="$YELLOW"; prefix="Warning: ";;
        success) color="$GREEN"; suffix=" ✔";;
        info) color="$BLUE";;
    esac

    if [[ -t 1 ]]; then
        echo -e "${color}\n${prefix}${message}${suffix}$RESET"
    else
        echo -e "\n${prefix}${message}${suffix}"
    fi
}
