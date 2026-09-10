#!/bin/bash

# Nutanix Enterprise AI prerequisite setup.
# The deployment commands remain unchanged; this layer provides the same
# polished terminal experience as nkpDeploy.sh.

# --- Nutanix terminal theme ---
PURPLE='\033[38;5;141m'
RED='\033[0;31m'
GREEN="$PURPLE"
CYAN="$PURPLE"
YELLOW="$PURPLE"
DIM='\033[38;5;245m'
RESET='\033[0m'
NC="$RESET"
SCREEN_COLS=80
SCREEN_ROWS=24
SCREEN_INNER=78
ALT_SCREEN_ACTIVE=0

tui_enter() {
    if [[ "$ALT_SCREEN_ACTIVE" != 1 && -t 1 ]]; then
        printf '\033[?1049h' >&2
        ALT_SCREEN_ACTIVE=1
    fi
}

tui_restore() {
    if [[ "$ALT_SCREEN_ACTIVE" == 1 ]]; then
        printf '\033[?7h\033[?25h\033[0m\033[?1049l' >&2
        ALT_SCREEN_ACTIVE=0
    else
        printf '\033[?7h\033[?25h\033[0m' >&2
    fi
}

tui_cleanup() { tui_restore; }
trap tui_cleanup EXIT

frame_setup() {
    SCREEN_COLS=$(tput cols 2>/dev/null || echo 80)
    SCREEN_ROWS=$(tput lines 2>/dev/null || echo 24)
    [[ "$SCREEN_COLS" =~ ^[0-9]+$ ]] || SCREEN_COLS=80
    [[ "$SCREEN_ROWS" =~ ^[0-9]+$ ]] || SCREEN_ROWS=24
    (( SCREEN_COLS < 64 )) && SCREEN_COLS=64
    (( SCREEN_ROWS < 16 )) && SCREEN_ROWS=16
    SCREEN_INNER=$((SCREEN_COLS - 2))
    printf -v FRAME_LINE '%*s' "$SCREEN_INNER" ''
    FRAME_LINE="${FRAME_LINE// /─}"
}

frame_row() {
    local TEXT="$1"
    (( ${#TEXT} > SCREEN_INNER )) && TEXT="${TEXT:0:SCREEN_INNER-3}..."
    printf '%b│%b %-*s %b│%b\n' "$PURPLE" "$RESET" "$((SCREEN_INNER - 2))" "$TEXT" "$PURPLE" "$RESET" >&2
}

frame_header() {
    local TITLE="$1"
    frame_setup
    tui_enter
    printf '\033[?7l\033[?25l\033[2J\033[H' >&2
    printf '%b╭%s╮%b\n' "$PURPLE" "$FRAME_LINE" "$RESET" >&2
    frame_row "  NUTANIX ENTERPRISE AI"
    frame_row "  $TITLE"
    printf '%b├%s┤%b\n' "$PURPLE" "$FRAME_LINE" "$RESET" >&2
}

frame_footer() {
    local CONTROLS="$1"
    printf '%b├%s┤%b\n' "$PURPLE" "$FRAME_LINE" "$RESET" >&2
    frame_row "  Controls: $CONTROLS"
    printf '%b╰%s╯%b' "$PURPLE" "$FRAME_LINE" "$RESET" >&2
}

status() {
    printf '%b  ●%b %s\n' "$1" "$RESET" "$2" >&2
}

prompt() {
    local INPUT_TEXT="  $1: "
    local INPUT_COLUMN=$((2 + ${#INPUT_TEXT}))
    local CONTENT_ROWS=0
    local BLANK_ROWS=0
    local INDEX=0

    # Redraw the complete full-height screen for each field. This keeps both
    # vertical borders and the footer visible while read waits for input.
    frame_header "Configure NAI prerequisites"
    frame_row ""
    frame_row "  Enter the values used by the NAI application."
    frame_row "  Credentials are only used to create image-pull secrets."
    frame_row ""
    case "$PROMPT_INDEX" in
        2) frame_row "  Kubeconfig File Path: $KUBECONFIG_PATH" ;;
        3) frame_row "  Kubeconfig File Path: $KUBECONFIG_PATH"; frame_row "  NFS Path: $NFS_PATH" ;;
        4) frame_row "  Kubeconfig File Path: $KUBECONFIG_PATH"; frame_row "  NFS Path: $NFS_PATH"; frame_row "  NFS Server: $NFS_SERVER" ;;
        5) frame_row "  Kubeconfig File Path: $KUBECONFIG_PATH"; frame_row "  NFS Path: $NFS_PATH"; frame_row "  NFS Server: $NFS_SERVER"; frame_row "  DockerHub Username: $DOCKER_USER" ;;
    esac
    frame_row "$INPUT_TEXT"
    CONTENT_ROWS=$((5 + PROMPT_INDEX - 1))
    BLANK_ROWS=$((SCREEN_ROWS - 7 - CONTENT_ROWS))
    (( BLANK_ROWS < 0 )) && BLANK_ROWS=0
    for ((INDEX=0; INDEX<BLANK_ROWS; INDEX++)); do
        frame_row ""
    done
    frame_footer "Enter submit   Ctrl-C exit"
    printf '\033[%dA\033[%dG\033[?25h' "$((BLANK_ROWS + 3))" "$INPUT_COLUMN" >&2
    if [[ "${2:-false}" == true ]]; then
        IFS= read -r -s REPLY < /dev/tty
    else
        IFS= read -r REPLY < /dev/tty
    fi
    printf '\033[1B\033[1G' >&2
}

summary_row() {
    local LABEL="$1" VALUE="$2" LABEL_WIDTH=24
    local VALUE_WIDTH=$((SCREEN_INNER - LABEL_WIDTH - 5))
    VALUE="${VALUE//$'\n'/ }"
    (( ${#VALUE} > VALUE_WIDTH )) && VALUE="${VALUE:0:VALUE_WIDTH-3}..."
    printf '%b│%b %b%-*s%b │ %-*s %b│%b\n' \
        "$PURPLE" "$RESET" "$DIM" "$LABEL_WIDTH" "$LABEL" "$RESET" \
        "$VALUE_WIDTH" "$VALUE" "$PURPLE" "$RESET" >&2
}

show_summary() {
    local BLANK_ROWS=0 INDEX=0
    frame_setup
    tui_enter
    printf '\033[?7l\033[?25l\033[2J\033[H' >&2
    printf '%b╭%s╮%b\n' "$PURPLE" "$FRAME_LINE" "$RESET" >&2
    frame_row "  NUTANIX ENTERPRISE AI"
    frame_row "  Final prerequisite summary"
    printf '%b├%s┤%b\n' "$PURPLE" "$FRAME_LINE" "$RESET" >&2
    summary_row "Kubeconfig Path" "$KUBECONFIG_PATH"
    summary_row "NFS Path" "$NFS_PATH"
    summary_row "NFS Server" "$NFS_SERVER"
    summary_row "DockerHub Username" "$DOCKER_USER"
    summary_row "DockerHub PAT" "********"
    frame_row ""
    frame_row "  Proceed with prerequisite setup? [Y/N]"
    BLANK_ROWS=$((SCREEN_ROWS - 7 - 7))
    (( BLANK_ROWS < 0 )) && BLANK_ROWS=0
    for ((INDEX=0; INDEX<BLANK_ROWS; INDEX++)); do
        frame_row ""
    done
    frame_footer "Type Y or N, then Enter   Ctrl-C exit"
}

read_confirmation() {
    local CONFIRM=""
    while true; do
        IFS= read -r CONFIRM < /dev/tty
        [[ "$CONFIRM" =~ ^[Yy]$ ]] && return 0
        [[ "$CONFIRM" =~ ^[Nn]$ ]] && return 1
    done
}

# --- Input screen ---
PROMPT_INDEX=1
prompt "Kubeconfig File Path"
KUBECONFIG_PATH="$REPLY"
PROMPT_INDEX=2
prompt "NFS Path"
NFS_PATH="$REPLY"
PROMPT_INDEX=3
prompt "NFS Server"
NFS_SERVER="$REPLY"
PROMPT_INDEX=4
prompt "DockerHub Username"
DOCKER_USER="$REPLY"
PROMPT_INDEX=5
prompt "DockerHub PAT" true
DOCKER_PAT="$REPLY"

show_summary
if ! read_confirmation; then
    printf '\n%b  ●%b Prerequisite setup cancelled.\n' "$YELLOW" "$RESET" >&2
    exit 1
fi

frame_header "Applying prerequisite configuration"
frame_row ""
status "$CYAN" "Configuring kubeconfig context..."
export KUBECONFIG="$KUBECONFIG_PATH"

status "$CYAN" "Applying NAI NFS StorageClass..."
cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nai-nfs-storage
parameters:
  nfsPath: $NFS_PATH
  nfsServer: $NFS_SERVER
  storageType: NutanixFiles
provisioner: csi.nutanix.com
reclaimPolicy: Delete
volumeBindingMode: Immediate
EOF

status "$CYAN" "Creating required namespaces..."
kubectl create namespace nai-system --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace envoy-gateway-system --dry-run=client -o yaml | kubectl apply -f -

status "$CYAN" "Creating DockerHub image-pull secrets..."
kubectl -n nai-system create secret docker-registry nai-regcred \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username="$DOCKER_USER" \
  --docker-password="$DOCKER_PAT" \
  --docker-email="$DOCKER_USER" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl -n envoy-gateway-system create secret docker-registry nai-regcred \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username="$DOCKER_USER" \
  --docker-password="$DOCKER_PAT" \
  --docker-email="$DOCKER_USER" \
  --dry-run=client -o yaml | kubectl apply -f -

frame_header "Prerequisites complete"
frame_row ""
status "$GREEN" "StorageClass applied: nai-nfs-storage"
status "$GREEN" "Namespaces ready: nai-system, envoy-gateway-system"
status "$GREEN" "Registry secrets ready: nai-regcred"
frame_row ""
frame_row "  Continue the install from the NKP Application Store."
frame_footer "Press Enter to exit"
read -r < /dev/tty
