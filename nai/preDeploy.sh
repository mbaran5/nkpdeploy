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
    stty echo icanon < /dev/tty 2>/dev/null || true
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

abort_with_error() {
    local MESSAGE="$1"
    frame_header "Unable to continue"
    frame_row ""
    status "$RED" "$MESSAGE"
    frame_row ""
    frame_footer "Press Enter to exit   Ctrl-C exit"
    printf '\n' >&2
    read -r < /dev/tty
    exit 1
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

workspace_display_name() {
    [[ "$1" == "kommander-workspace" ]] && printf '%s' "Management Cluster" || printf '%s' "$1"
}

show_app_table() {
    local TITLE="$1" OUTPUT="$2"
    frame_row ""
    frame_row "  $TITLE"
    while IFS= read -r LINE; do
        [[ -n "$LINE" ]] && frame_row "    $LINE"
    done <<< "$OUTPUT"
}

install_required_apps() {
    local WORKSPACE_NAME="$1"
    local WORKSPACE_NAMESPACE="$2"
    local APP_OUTPUT="$3"
    local REQUIRED="${REQUIRED_DEPENDENCIES:-}"
    local DEPENDENCY APP_NAME APP_VERSION

    [[ -z "$REQUIRED" ]] && return 0

    frame_row ""
    frame_row "  Required dependencies for nutanix-ai-2.8.0"
    while IFS= read -r DEPENDENCY; do
        DEPENDENCY=$(printf '%s' "$DEPENDENCY" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/[\[\]" ]//g')
        [[ -z "$DEPENDENCY" ]] && continue

        # Dependencies are represented as app-name-version. Split at the
        # version suffix so app names containing hyphens remain intact.
        if [[ "$DEPENDENCY" =~ ^(.+)-([0-9]+\.[0-9]+\.[0-9]+[^/]*)$ ]]; then
            APP_NAME="${BASH_REMATCH[1]}"
            APP_VERSION="${BASH_REMATCH[2]}"
        else
            status "$YELLOW" "Skipping unrecognized dependency: $DEPENDENCY"
            continue
        fi

        if printf '%s\n' "$APP_OUTPUT" | grep -Eq "^[[:space:]]*${APP_NAME}[[:space:]]+.*${APP_VERSION}([[:space:]]|$)"; then
            status "$GREEN" "$APP_NAME-$APP_VERSION already available in $(workspace_display_name "$WORKSPACE_NAME")."
            continue
        fi

        status "$CYAN" "Installing $APP_NAME-$APP_VERSION in $(workspace_display_name "$WORKSPACE_NAME")..."
        if ! nkp create appdeployment "$APP_NAME" \
            --app "$APP_NAME-$APP_VERSION" \
            --workspace "$WORKSPACE_NAME"; then
            status "$RED" "Failed to install $APP_NAME-$APP_VERSION."
            return 1
        fi
    done < <(printf '%s' "$REQUIRED" | tr ',' '\n')
}

discover_workspaces_and_apps() {
    local WORKSPACES_OUTPUT=""
    local CLUSTER_APPS=""
    local WORKSPACE_NAME WORKSPACE_NAMESPACE DISPLAY_NAME APPS
    local WORKSPACE_ROWS=()
    local INDEX=0

    frame_header "Discovering workspaces and applications"
    frame_row ""
    status "$CYAN" "Running nkp get workspaces..."
    WORKSPACES_OUTPUT=$(nkp get workspaces 2>&1) || {
        status "$RED" "Unable to retrieve workspaces."
        printf '%s\n' "$WORKSPACES_OUTPUT" >&2
        return 1
    }

    show_app_table "Available workspaces" "$WORKSPACES_OUTPUT"

    # Prefer structured output. The human-readable table varies between NKP
    # releases and may include notices before the header, which made the
    # earlier positional parser miss every workspace.
    local WORKSPACES_JSON=""
    WORKSPACES_JSON=$(nkp get workspaces -o json 2>/dev/null) || true
    if [[ "$WORKSPACES_JSON" == \{* ]] && command -v jq >/dev/null 2>&1; then
        while IFS=$'\t' read -r WORKSPACE_NAME WORKSPACE_NAMESPACE; do
            [[ -z "$WORKSPACE_NAME" ]] && continue
            [[ -z "$WORKSPACE_NAMESPACE" || "$WORKSPACE_NAMESPACE" == "null" ]] && WORKSPACE_NAMESPACE="$WORKSPACE_NAME"
            WORKSPACE_ROWS+=("$WORKSPACE_NAME|$WORKSPACE_NAMESPACE")
        done < <(printf '%s' "$WORKSPACES_JSON" | jq -r '(.items // .entities // [])[] | [(.metadata.name // .name), (.metadata.namespace // .namespace // "")] | @tsv' 2>/dev/null)
    fi

    # Fallback for NKP versions that do not support -o json.
    if (( ${#WORKSPACE_ROWS[@]} == 0 )); then
        while IFS=$'\t' read -r WORKSPACE_NAME WORKSPACE_NAMESPACE; do
            [[ -z "$WORKSPACE_NAME" ]] && continue
            [[ "$WORKSPACE_NAME" =~ ^(NAME|NAMESPACE|No|Error|Warning)$ || "$WORKSPACE_NAME" =~ ^-+$ ]] && continue
            [[ -z "$WORKSPACE_NAMESPACE" || "$WORKSPACE_NAMESPACE" =~ ^-+$ ]] && WORKSPACE_NAMESPACE="$WORKSPACE_NAME"
            WORKSPACE_ROWS+=("$WORKSPACE_NAME|$WORKSPACE_NAMESPACE")
        done < <(printf '%s\n' "$WORKSPACES_OUTPUT" | sed $'s/\033\\[[0-9;]*m//g;s/\302\240/ /g' | awk '/^[[:space:]]*NAME([[:space:]]|$)/ {found=1; next} found && NF {print $1 "\t" $2}')
    fi

    if (( ${#WORKSPACE_ROWS[@]} == 0 )); then
        status "$RED" "No workspaces were found in nkp output."
        return 1
    fi

    status "$CYAN" "Listing cluster-scoped applications..."
    if ! CLUSTER_APPS=$(kubectl get clusterapps \
        -o custom-columns='NAME:.metadata.name,APP-ID:.spec.appId,VERSION:.spec.version' 2>&1); then
        status "$RED" "Unable to retrieve cluster applications."
        show_app_table "kubectl error" "$CLUSTER_APPS"
        return 1
    fi
    show_app_table "Cluster applications" "$CLUSTER_APPS"

    for ROW in "${WORKSPACE_ROWS[@]}"; do
        WORKSPACE_NAME="${ROW%%|*}"
        WORKSPACE_NAMESPACE="${ROW#*|}"
        DISPLAY_NAME=$(workspace_display_name "$WORKSPACE_NAME")
        status "$CYAN" "Listing applications in $DISPLAY_NAME..."
        if ! APPS=$(kubectl get apps -n "$WORKSPACE_NAMESPACE" \
            -o custom-columns='NAME:.metadata.name,APP-ID:.spec.appId,VERSION:.spec.version' 2>&1); then
            status "$RED" "Unable to access namespace '$WORKSPACE_NAMESPACE'."
            show_app_table "kubectl error" "$APPS"
            return 1
        fi
        show_app_table "Workspace applications: $DISPLAY_NAME" "$APPS"
        INDEX=$((INDEX + 1))
    done
}

select_workspace() {
    local CURRENT=0 KEY KEY2 ROW NAME NAMESPACE DISPLAY INDEX
    stty -icanon -echo < /dev/tty 2>/dev/null || true
    while true; do
        frame_header "Select target workspace"
        frame_row ""
        frame_row "  Use ↑/↓ or j/k to select a workspace, then press Enter."
        frame_row ""
        for INDEX in "${!WORKSPACE_ROWS[@]}"; do
            ROW="${WORKSPACE_ROWS[$INDEX]}"
            NAME="${ROW%%|*}"
            NAMESPACE="${ROW#*|}"
            DISPLAY=$(workspace_display_name "$NAME")
            if (( INDEX == CURRENT )); then
                frame_row "  > $DISPLAY ($NAME)"
            else
                frame_row "    $DISPLAY ($NAME)"
            fi
        done
        local CONTENT_ROWS=$((3 + ${#WORKSPACE_ROWS[@]}))
        local BLANK_ROWS=$((SCREEN_ROWS - 7 - CONTENT_ROWS))
        (( BLANK_ROWS < 0 )) && BLANK_ROWS=0
        for ((INDEX=0; INDEX<BLANK_ROWS; INDEX++)); do frame_row ""; done
        frame_footer "↑/↓ select   Enter confirm   Ctrl-C exit"

        IFS= read -r -s -n 1 KEY < /dev/tty
        if [[ "$KEY" == $'\033' ]]; then
            IFS= read -r -s -n 2 KEY2 < /dev/tty
            case "$KEY2" in
                '[A') (( CURRENT > 0 )) && CURRENT=$((CURRENT - 1)) ;;
                '[B') (( CURRENT < ${#WORKSPACE_ROWS[@]} - 1 )) && CURRENT=$((CURRENT + 1)) ;;
            esac
        elif [[ "$KEY" == "k" || "$KEY" == "K" ]]; then
            (( CURRENT > 0 )) && CURRENT=$((CURRENT - 1))
        elif [[ "$KEY" == "j" || "$KEY" == "J" ]]; then
            (( CURRENT < ${#WORKSPACE_ROWS[@]} - 1 )) && CURRENT=$((CURRENT + 1))
        elif [[ "$KEY" == $'\n' || "$KEY" == $'\r' ]]; then
            ROW="${WORKSPACE_ROWS[$CURRENT]}"
            SELECTED_WORKSPACE="${ROW%%|*}"
            SELECTED_NAMESPACE="${ROW#*|}"
            stty echo icanon < /dev/tty 2>/dev/null || true
            return 0
        fi
    done
}

load_selected_dependencies() {
    if ! SELECTED_APPS=$(kubectl get apps -n "$SELECTED_NAMESPACE" \
        -o custom-columns='NAME:.metadata.name,APP-ID:.spec.appId,VERSION:.spec.version' 2>&1); then
        return 1
    fi
    REQUIRED_DEPENDENCIES=$(kubectl get app nutanix-ai-2.8.0 \
        -n "$SELECTED_NAMESPACE" \
        -o jsonpath='{.metadata.annotations.apps\.kommander\.d2iq\.io/required-dependencies}{"\n"}' 2>/dev/null) || true
}

confirm_final_summary() {
    local PROMPT_TEXT="  Proceed with prerequisite and app setup? [Y/N]"
    local INPUT_COLUMN=$((2 + ${#PROMPT_TEXT}))
    local CONTENT_ROWS=0 BLANK_ROWS=0 INDEX=0 CONFIRM=""

    frame_setup
    printf '\033[?7l\033[?25l\033[2J\033[H' >&2
    printf '%b╭%s╮%b\n' "$PURPLE" "$FRAME_LINE" "$RESET" >&2
    frame_row "  NUTANIX ENTERPRISE AI"
    frame_row "  Final deployment summary"
    printf '%b├%s┤%b\n' "$PURPLE" "$FRAME_LINE" "$RESET" >&2
    summary_row "Kubeconfig Path" "$KUBECONFIG_PATH"
    summary_row "NFS Path" "$NFS_PATH"
    summary_row "NFS Server" "$NFS_SERVER"
    summary_row "DockerHub Username" "$DOCKER_USER"
    summary_row "DockerHub PAT" "********"
    summary_row "Workspaces Discovered" "${#WORKSPACE_ROWS[@]}"
    summary_row "Target Workspace" "$(workspace_display_name "$SELECTED_WORKSPACE")"
    summary_row "Target Namespace" "$SELECTED_NAMESPACE"
    summary_row "Target Prerequisites" "${REQUIRED_DEPENDENCIES:-None found}"
    frame_row ""
    frame_row "$PROMPT_TEXT"
    CONTENT_ROWS=11
    BLANK_ROWS=$((SCREEN_ROWS - 7 - CONTENT_ROWS))
    (( BLANK_ROWS < 0 )) && BLANK_ROWS=0
    for ((INDEX=0; INDEX<BLANK_ROWS; INDEX++)); do frame_row ""; done
    frame_footer "Type Y or N, then Enter   Ctrl-C exit"
    printf '\033[%dA\033[%dG\033[?25h' "$((BLANK_ROWS + 3))" "$INPUT_COLUMN" >&2

    while true; do
        IFS= read -r CONFIRM < /dev/tty
        [[ "$CONFIRM" =~ ^[Yy]$ ]] && return 0
        [[ "$CONFIRM" =~ ^[Nn]$ ]] && return 1
    done
}

# --- Capture inputs, then discover and review before changing the cluster ---
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

export KUBECONFIG="$KUBECONFIG_PATH"
if [[ ! -r "$KUBECONFIG_PATH" ]]; then
    abort_with_error "Kubeconfig file was not found or is not readable: $KUBECONFIG_PATH"
fi

if ! discover_workspaces_and_apps; then
    abort_with_error "No usable workspaces or namespaces were found. Check the kubeconfig and cluster access."
fi
select_workspace
if ! load_selected_dependencies; then
    abort_with_error "Unable to access the selected workspace namespace: $SELECTED_NAMESPACE"
fi

if ! confirm_final_summary; then
    printf '\n%b  ●%b Setup cancelled; no resources or applications were installed.\n' "$YELLOW" "$RESET" >&2
    exit 1
fi

frame_header "Applying prerequisite configuration"
frame_row ""
status "$CYAN" "Kubeconfig exported for this session."

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

install_required_apps "$SELECTED_WORKSPACE" "$SELECTED_NAMESPACE" "$SELECTED_APPS" || true

frame_header "Prerequisites complete"
frame_row ""
status "$GREEN" "StorageClass applied: nai-nfs-storage"
status "$GREEN" "Namespaces ready: nai-system, envoy-gateway-system"
status "$GREEN" "Registry secrets ready: nai-regcred"
frame_row ""
frame_row "  Continue the install from the NKP Application Store."
frame_footer "Press Enter to exit"
read -r < /dev/tty
