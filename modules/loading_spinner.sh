is_pid_active() {
    kill -0 $1 2>/dev/null

    return $?
}

show_spinner() {
    local pid=$1
    local loading_message="$2"
    local completion_message="$3"
    local delay=0.15
    local spinner_frames=('|' '/' '-' '\')

    echo ""

    while is_pid_active $pid; do
        for frame in "${spinner_frames[@]}"; do
            echo -ne "\r$loading_message $frame"
            sleep $delay
        done
    done

    echo -ne "\r\e[K$completion_message\n"
}
