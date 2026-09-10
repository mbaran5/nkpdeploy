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
DEPLOYMENT_RESULTS=()
LOG_FILE="${TMPDIR:-/tmp}/nai-predeploy-$(date +%Y%m%d-%H%M%S).log"
SCREEN_LOG="${LOG_FILE%.log}-screen.log"
: > "$LOG_FILE"
: > "$SCREEN_LOG"
exec > >(tee -a "$SCREEN_LOG") 2>&1

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

clean_text() {
    printf '%s' "$1" | sed -E $'s|\033\\[[0-9;?]*[ -/]*[@-~]||g; s|\r| |g; s|\t| |g'
}

frame_row() {
    local TEXT="$1"
    TEXT=$(clean_text "$TEXT")
    (( ${#TEXT} > SCREEN_INNER - 2 )) && TEXT="${TEXT:0:SCREEN_INNER-5}..."
    # Anchor the right border at the terminal edge instead of relying on
    # printf padding, which can drift with wide characters or control codes.
    printf '\033[2K\033[1G%b│%b%s\033[%dG%b│%b\n' \
        "$PURPLE" "$RESET" "$TEXT" "$SCREEN_COLS" "$PURPLE" "$RESET" >&2
}

frame_row_color() {
    local COLOR="$1"
    local TEXT="$2"
    TEXT=$(clean_text "$TEXT")
    (( ${#TEXT} > SCREEN_INNER - 2 )) && TEXT="${TEXT:0:SCREEN_INNER-5}..."
    printf '\033[2K\033[1G%b│%b%b%s\033[%dG%b│%b\n' \
        "$PURPLE" "$RESET" "$COLOR" "$TEXT" "$SCREEN_COLS" "$PURPLE" "$RESET" >&2
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
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$2" >> "$LOG_FILE"
    frame_row_color "$1" "  ● $2"
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
    local INPUT_COLUMN=$((1 + ${#INPUT_TEXT}))
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
    VALUE=$(clean_text "$VALUE" | tr '\n' ' ')
    (( ${#VALUE} > VALUE_WIDTH )) && VALUE="${VALUE:0:VALUE_WIDTH-3}..."
    printf '%b│%b %b%-*s%b │ %-*s ' \
        "$PURPLE" "$RESET" "$DIM" "$LABEL_WIDTH" "$LABEL" "$RESET" \
        "$VALUE_WIDTH" "$VALUE" >&2
    printf '\033[%dG%b│%b\n' "$SCREEN_COLS" "$PURPLE" "$RESET" >&2
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

resolve_dependency() {
    local DEPENDENCY="$1"
    local APP_OUTPUT="$2"
    local RESOURCE_KIND="$3"
    local CANDIDATE="${DEPENDENCY}"
    local CANDIDATE_NAME CANDIDATE_ID CANDIDATE_VERSION

    # The dependency annotation may contain either an app ID or an app ID
    # with a version suffix. The authoritative version is always taken from
    # the inventory captured earlier in this script.
    if [[ "$CANDIDATE" =~ ^(.+)-[0-9]+\.[0-9]+\.[0-9]+.*$ ]]; then
        CANDIDATE="${BASH_REMATCH[1]}"
    fi

    while IFS=$'\t' read -r CANDIDATE_NAME CANDIDATE_ID CANDIDATE_VERSION; do
        [[ -z "$CANDIDATE_ID" || "$CANDIDATE_ID" == "APP-ID" ]] && continue
        if [[ "$CANDIDATE_NAME" == "$CANDIDATE" || "$CANDIDATE_ID" == "$CANDIDATE" ]]; then
            RESOLVED_APP_ID="$CANDIDATE_ID"
            RESOLVED_VERSION="$CANDIDATE_VERSION"
            RESOLVED_KIND="$RESOURCE_KIND"
            return 0
        fi
    done < <(printf '%s\n' "$APP_OUTPUT" | sed $'s/\302\240/ /g' | awk 'NF >= 3 && $1 != "NAME" {print $1 "\t" $2 "\t" $3}')
    return 1
}

appdeployment_exists() {
    local APP_ID="$1"
    local APP_VERSION="$2"
    local WORKSPACE_NAMESPACE="$3"
    local EXISTING EXISTING_RC

    EXISTING=$(kubectl get appdeployments -n "$WORKSPACE_NAMESPACE" -o name 2>&1)
    EXISTING_RC=$?
    printf '[%s] kubectl get appdeployments -n %s\n%s\n' \
        "$(date '+%Y-%m-%d %H:%M:%S')" "$WORKSPACE_NAMESPACE" "${EXISTING:-<none>}" >> "$LOG_FILE"

    # If the resource type is unavailable, let the create command report the
    # authoritative error rather than falsely claiming it already exists.
    (( EXISTING_RC != 0 )) && return 1
    printf '%s\n' "$EXISTING" | grep -Eq "/(${APP_ID}|${APP_ID}-${APP_VERSION})$"
}

install_required_apps() {
    local WORKSPACE_NAME="$1"
    local WORKSPACE_NAMESPACE="$2"
    local APP_OUTPUT="$3"
    local REQUIRED="${REQUIRED_DEPENDENCIES:-}"
    local DEPENDENCY APP_NAME APP_VERSION DEPLOY_OUTPUT DEPLOY_RC

    if [[ -z "$REQUIRED" ]]; then
        status "$YELLOW" "No required-dependencies annotation found for nutanix-ai-2.8.0."
        DEPLOYMENT_RESULTS+=("$YELLOW|No NAI prerequisite app dependencies found")
        return 0
    fi

    frame_row ""
    frame_row "  Required dependencies for nutanix-ai-2.8.0"
    while IFS= read -r DEPENDENCY; do
        DEPENDENCY=$(printf '%s' "$DEPENDENCY" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/[\[\]" ]//g')
        [[ -z "$DEPENDENCY" ]] && continue

        RESOLVED_APP_ID=""
        RESOLVED_VERSION=""
        RESOLVED_KIND=""
        if ! resolve_dependency "$DEPENDENCY" "$APP_OUTPUT" "App" && \
           ! resolve_dependency "$DEPENDENCY" "${CLUSTER_APPS:-}" "ClusterApp"; then
            status "$YELLOW" "Required dependency not found in app inventory: $DEPENDENCY"
            DEPLOYMENT_RESULTS+=("$YELLOW|Dependency $DEPENDENCY not found")
            continue
        fi
        APP_NAME="$RESOLVED_APP_ID"
        APP_VERSION="$RESOLVED_VERSION"
        local RESOURCE_KIND="$RESOLVED_KIND"
        if appdeployment_exists "$APP_NAME" "$APP_VERSION" "$WORKSPACE_NAMESPACE"; then
            status "$GREEN" "$RESOURCE_KIND $APP_NAME-$APP_VERSION already installed."
            DEPLOYMENT_RESULTS+=("$GREEN|$RESOURCE_KIND $APP_NAME-$APP_VERSION already installed")
            continue
        fi
        DEPLOYMENT_RESULTS+=("$CYAN|Installing $RESOURCE_KIND $APP_NAME-$APP_VERSION")
        status "$CYAN" "Installing $APP_NAME-$APP_VERSION in $(workspace_display_name "$WORKSPACE_NAME")..."
        DEPLOY_OUTPUT=$(nkp create appdeployment "$APP_NAME" \
            --app "$APP_NAME-$APP_VERSION" \
            --workspace "$WORKSPACE_NAME" 2>&1)
        DEPLOY_RC=$?
        {
            printf '\n[%s] nkp create appdeployment %s --app %s-%s --workspace %s\n' \
                "$(date '+%Y-%m-%d %H:%M:%S')" "$APP_NAME" "$APP_NAME" "$APP_VERSION" "$WORKSPACE_NAME"
            printf '%s\n' "$DEPLOY_OUTPUT"
        } >> "$LOG_FILE"
        if (( DEPLOY_RC != 0 )); then
            DEPLOY_OUTPUT=$(printf '%s' "$DEPLOY_OUTPUT" | tr '\n' ' ' | cut -c1-180)
            status "$RED" "Failed to install $APP_NAME-$APP_VERSION: ${DEPLOY_OUTPUT:-no error output}"
            DEPLOYMENT_RESULTS+=("$RED|$RESOURCE_KIND $APP_NAME-$APP_VERSION failed: ${DEPLOY_OUTPUT:-no error output}")
            return 1
        fi
        DEPLOYMENT_RESULTS+=("$GREEN|$RESOURCE_KIND $APP_NAME-$APP_VERSION deployed")
    done < <(printf '%s' "$REQUIRED" | tr ',' '\n')
}

discover_workspaces_and_apps() {
    local WORKSPACES_OUTPUT=""
    CLUSTER_APPS=""
    local WORKSPACE_NAME WORKSPACE_NAMESPACE DISPLAY_NAME APPS
    WORKSPACE_ROWS=()
    local INDEX=0

    frame_header "Discovering workspaces and applications"
    frame_row ""
    status "$CYAN" "Running nkp get workspaces..."
    WORKSPACES_OUTPUT=$(nkp get workspaces 2>&1) || {
        status "$RED" "Unable to retrieve workspaces."
        printf '%s\n' "$WORKSPACES_OUTPUT" >&2
        return 1
    }
    printf '[%s] nkp get workspaces\n%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$WORKSPACES_OUTPUT" >> "$LOG_FILE"

    status "$CYAN" "Workspace list captured."

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
    printf '[%s] kubectl get clusterapps\n%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$CLUSTER_APPS" >> "$LOG_FILE"
    status "$CYAN" "Cluster application inventory captured."

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
        printf '[%s] kubectl get apps -n %s\n%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$WORKSPACE_NAMESPACE" "$APPS" >> "$LOG_FILE"
        status "$CYAN" "Application inventory captured for $DISPLAY_NAME."
        INDEX=$((INDEX + 1))
    done
}

select_workspace() {
    local CURRENT=0 KEY KEY2 ROW NAME NAMESPACE DISPLAY INDEX
    local OLD_STTY
    [[ -c /dev/tty ]] || return 1
    OLD_STTY=$(stty -g < /dev/tty) || return 1
    stty -echo -icanon min 1 time 0 < /dev/tty || return 1
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
        if [[ -z "$KEY" ]]; then
            stty "$OLD_STTY" < /dev/tty
            ROW="${WORKSPACE_ROWS[$CURRENT]}"
            SELECTED_WORKSPACE="${ROW%%|*}"
            SELECTED_NAMESPACE="${ROW#*|}"
            return 0
        elif [[ "$KEY" == $'\033' ]]; then
            IFS= read -r -s -n 2 -t 0.1 KEY2 < /dev/tty || true
            case "${KEY}${KEY2}" in
                $'\033[A') (( CURRENT > 0 )) && CURRENT=$((CURRENT - 1)) ;;
                $'\033[B') (( CURRENT < ${#WORKSPACE_ROWS[@]} - 1 )) && CURRENT=$((CURRENT + 1)) ;;
            esac
        elif [[ "$KEY" == "k" || "$KEY" == "K" ]]; then
            (( CURRENT > 0 )) && CURRENT=$((CURRENT - 1))
        elif [[ "$KEY" == "j" || "$KEY" == "J" ]]; then
            (( CURRENT < ${#WORKSPACE_ROWS[@]} - 1 )) && CURRENT=$((CURRENT + 1))
        elif [[ -z "$KEY" || "$KEY" == $'\n' || "$KEY" == $'\r' ]]; then
            ROW="${WORKSPACE_ROWS[$CURRENT]}"
            SELECTED_WORKSPACE="${ROW%%|*}"
            SELECTED_NAMESPACE="${ROW#*|}"
            stty "$OLD_STTY" < /dev/tty
            return 0
        elif [[ "$KEY" == "q" || "$KEY" == "Q" ]]; then
            stty "$OLD_STTY" < /dev/tty
            return 1
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
    printf '[%s] required dependencies for nutanix-ai-2.8.0 in %s\n%s\n' \
        "$(date '+%Y-%m-%d %H:%M:%S')" "$SELECTED_NAMESPACE" "${REQUIRED_DEPENDENCIES:-<none>}" >> "$LOG_FILE"
}

confirm_final_summary() {
    local PROMPT_TEXT="  Proceed with prerequisite and app setup? [Y/N] "
    local INPUT_COLUMN=$((1 + ${#PROMPT_TEXT}))
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
    summary_row "Execution Log" "$LOG_FILE"
    frame_row ""
    frame_row "$PROMPT_TEXT"
    CONTENT_ROWS=12
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
cat <<EOF | kubectl apply -f - >> "$LOG_FILE" 2>&1
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
DEPLOYMENT_RESULTS+=("$GREEN|StorageClass nai-nfs-storage applied")

status "$CYAN" "Creating required namespaces..."
kubectl create namespace nai-system --dry-run=client -o yaml 2>> "$LOG_FILE" | kubectl apply -f - >> "$LOG_FILE" 2>&1
kubectl create namespace envoy-gateway-system --dry-run=client -o yaml 2>> "$LOG_FILE" | kubectl apply -f - >> "$LOG_FILE" 2>&1
DEPLOYMENT_RESULTS+=("$GREEN|Namespaces nai-system and envoy-gateway-system ready")

status "$CYAN" "Creating DockerHub image-pull secrets..."
kubectl -n nai-system create secret docker-registry nai-regcred \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username="$DOCKER_USER" \
  --docker-password="$DOCKER_PAT" \
  --docker-email="$DOCKER_USER" \
  --dry-run=client -o yaml 2>> "$LOG_FILE" | kubectl apply -f - >> "$LOG_FILE" 2>&1
DEPLOYMENT_RESULTS+=("$GREEN|Secret nai-regcred created in nai-system")

kubectl -n envoy-gateway-system create secret docker-registry nai-regcred \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username="$DOCKER_USER" \
  --docker-password="$DOCKER_PAT" \
  --docker-email="$DOCKER_USER" \
  --dry-run=client -o yaml 2>> "$LOG_FILE" | kubectl apply -f - >> "$LOG_FILE" 2>&1
DEPLOYMENT_RESULTS+=("$GREEN|Secret nai-regcred created in envoy-gateway-system")

install_required_apps "$SELECTED_WORKSPACE" "$SELECTED_NAMESPACE" "$SELECTED_APPS" || true

frame_header "Prerequisites complete"
frame_row ""
for RESULT in "${DEPLOYMENT_RESULTS[@]}"; do
    RESULT_COLOR="${RESULT%%|*}"
    RESULT_MESSAGE="${RESULT#*|}"
    status "$RESULT_COLOR" "$RESULT_MESSAGE"
done
frame_row ""
frame_row "  Continue the install from the NKP Application Store."
frame_row "  Execution log: $LOG_FILE"
frame_footer "Press Enter to exit"
read -r < /dev/tty
