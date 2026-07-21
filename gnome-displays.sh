#!/bin/bash

set -o pipefail

SCRIPT_NAME=$(basename "$0" .sh)
VERSION="dev"
CONFIG_DIR="$HOME/.config/gnome-displays"
INSTALL_DIR="$HOME/.local/bin"
INSTALL_PATH="$INSTALL_DIR/gnome-displays"
SERVICE_NAME="gnome-displays.service"
SERVICE_DIR="$HOME/.config/systemd/user"
SERVICE_PATH="$SERVICE_DIR/$SERVICE_NAME"
AUTOSTART_DIR="$HOME/.config/autostart"
AUTOSTART_PATH="$AUTOSTART_DIR/gnome-displays.desktop"
SETTLE_SECONDS=3
MUTTER_DEST="org.gnome.Mutter.DisplayConfig"
MUTTER_PATH="/org/gnome/Mutter/DisplayConfig"

bold() {
  echo -e "\033[1m$1\033[0m"
}

err() {
  echo "$@" >&2
}

version() {
  echo "$SCRIPT_NAME $VERSION"
}

help() {
  echo "Usage: $SCRIPT_NAME <action> [arguments]"
  echo
  echo "Actions:"
  echo "  apply        Apply a saved display configuration, or auto-select the best one."
  echo "  completion   Generate a shell completion script."
  echo "  delete       Delete a saved display configuration."
  echo "  help         Show this help message."
  echo "  list         List all saved display configurations."
  echo "  save         Save the current display configuration."
  echo "  service      Manage the auto-apply user service (login & monitor hotplug)."
  echo "  setup        Install this script as a command in ~/.local/bin."
  echo "  show         Show details of a saved display configuration."
  echo "  verify       Verify a saved display configuration."
  echo "  version      Show the installed version."
  echo
  echo "Arguments and options:"
  echo "  apply [<name>|auto] [--force] [--persistent|--temporary]"
  echo "    <name>       Name of the configuration to apply."
  echo "    auto         Pick the best profile for the connected monitors (default when omitted)."
  echo "    --force      Re-apply even if the profile is already in use."
  echo "    --persistent Persist across reboots; prompts for confirmation (default)."
  echo "    --temporary  Apply for this session only; no confirmation prompt."
  echo "  completion <shell>"
  echo "    <shell>      Shell to target: bash, fish or zsh."
  echo "  delete <name>"
  echo "    <name>       Name of the configuration to delete."
  echo "  list [--available] [--raw]"
  echo "    --available  Only list configurations whose monitors are all connected."
  echo "    --raw        Print names only, without monitor counts."
  echo "  save <name>"
  echo "    <name>       Name to save the current configuration under."
  echo "  service [--install|--status|--remove]"
  echo "    --install    Install, enable and start the service (requires setup first)."
  echo "    --status     Show install and running state (default when omitted)."
  echo "    --remove     Stop, disable and remove the service."
  echo "  setup [--remove]"
  echo "    --remove     Uninstall the command from ~/.local/bin."
  echo "  show <name>"
  echo "    <name>       Name of the configuration to show."
  echo "  verify <name>"
  echo "    <name>       Name of the configuration to verify."
  echo
  echo "Advanced usage:"
  echo "  watch          Apply the best profile now, then re-apply on every monitor"
  echo "                 change (temporary mode). Normally run by the service; you"
  echo "                 can run it in the foreground to watch its behaviour."
}

completion() {
  local SHELL_TYPE="$2"
  if [[ -z "$SHELL_TYPE" ]]; then
    err "Error: Please specify a shell type (bash, zsh, fish)."
    exit 1
  fi
  case "$SHELL_TYPE" in
  bash)
    cat <<'EOF' | sed "s/__SCRIPT_NAME__/$SCRIPT_NAME/g"
_gnome_displays_completions() {
  local cur prev opts configs
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"
  opts="apply completion delete help list save service setup show verify"
  case "$prev" in
    apply)
      configs="auto --force --persistent --temporary $(__SCRIPT_NAME__ list --available --raw 2>/dev/null)"
      COMPREPLY=( $(compgen -W "$configs" -- "$cur") )
      return 0
      ;;
    show|save|verify|delete)
      configs="$(__SCRIPT_NAME__ list --raw 2>/dev/null)"
      COMPREPLY=( $(compgen -W "$configs" -- "$cur") )
      return 0
      ;;
    completion)
      COMPREPLY=( $(compgen -W "bash fish zsh" -- "$cur") )
      return 0
      ;;
    list)
      COMPREPLY=( $(compgen -W "--available --raw" -- "$cur") )
      return 0
      ;;
    service)
      COMPREPLY=( $(compgen -W "--install --status --remove" -- "$cur") )
      return 0
      ;;
    setup)
      COMPREPLY=( $(compgen -W "--remove" -- "$cur") )
      return 0
      ;;
  esac
  if [[ $COMP_CWORD -eq 1 ]]; then
    COMPREPLY=( $(compgen -W "$opts" -- "$cur") )
    return 0
  fi
}
complete -F _gnome_displays_completions __SCRIPT_NAME__
EOF
    ;;
  fish)
    cat <<'EOF' | sed "s/__SCRIPT_NAME__/$SCRIPT_NAME/g"
function __gnome_displays_config_names
  eval "__SCRIPT_NAME__ list --raw 2>/dev/null"
end

function __gnome_displays_available_config_names
  eval "__SCRIPT_NAME__ list --available --raw 2>/dev/null"
end

# Avoid duplicated suggestions when this file is sourced multiple times.
complete --command __SCRIPT_NAME__ --erase

# <action>
complete --command __SCRIPT_NAME__ --exclusive --condition "__fish_use_subcommand" --arguments "apply" --description "Apply a saved display configuration"
complete --command __SCRIPT_NAME__ --exclusive --condition "__fish_use_subcommand" --arguments "completion" --description "Generate shell completion script"
complete --command __SCRIPT_NAME__ --exclusive --condition "__fish_use_subcommand" --arguments "delete" --description "Delete a saved display configuration"
complete --command __SCRIPT_NAME__ --exclusive --condition "__fish_use_subcommand" --arguments "help" --description "Show help message"
complete --command __SCRIPT_NAME__ --exclusive --condition "__fish_use_subcommand" --arguments "list" --description "List all saved display configurations"
complete --command __SCRIPT_NAME__ --exclusive --condition "__fish_use_subcommand" --arguments "save" --description "Save the current display configuration"
complete --command __SCRIPT_NAME__ --exclusive --condition "__fish_use_subcommand" --arguments "service" --description "Manage the auto-apply user service"
complete --command __SCRIPT_NAME__ --exclusive --condition "__fish_use_subcommand" --arguments "setup" --description "Install the command in ~/.local/bin"
complete --command __SCRIPT_NAME__ --exclusive --condition "__fish_use_subcommand" --arguments "show" --description "Show details of a specific display configuration"
complete --command __SCRIPT_NAME__ --exclusive --condition "__fish_use_subcommand" --arguments "verify" --description "Verify a saved display configuration"
complete --command __SCRIPT_NAME__ --exclusive --condition "__fish_use_subcommand" --arguments "watch" --description "Advanced: apply now and re-apply on monitor changes"
# <name>
complete --command __SCRIPT_NAME__ --exclusive --condition "__fish_seen_subcommand_from show" --arguments "(__gnome_displays_config_names)" --description "Configuration name"
complete --command __SCRIPT_NAME__ --exclusive --condition "__fish_seen_subcommand_from save" --arguments "(__gnome_displays_config_names)" --description "Configuration name"
complete --command __SCRIPT_NAME__ --exclusive --condition "__fish_seen_subcommand_from apply" --arguments "auto" --description "Auto-select the best profile"
complete --command __SCRIPT_NAME__ --exclusive --condition "__fish_seen_subcommand_from apply" --arguments "(__gnome_displays_available_config_names)" --description "Configuration name"
complete --command __SCRIPT_NAME__ --condition "__fish_seen_subcommand_from apply" --long-option "force" --description "Re-apply even if already in use"
complete --command __SCRIPT_NAME__ --condition "__fish_seen_subcommand_from apply" --long-option "persistent" --description "Persist across reboots (default)"
complete --command __SCRIPT_NAME__ --condition "__fish_seen_subcommand_from apply" --long-option "temporary" --description "Apply for this session only, no prompt"
complete --command __SCRIPT_NAME__ --exclusive --condition "__fish_seen_subcommand_from verify" --arguments "(__gnome_displays_config_names)" --description "Configuration name"
complete --command __SCRIPT_NAME__ --exclusive --condition "__fish_seen_subcommand_from delete" --arguments "(__gnome_displays_config_names)" --description "Configuration name"
# service / setup options
complete --command __SCRIPT_NAME__ --condition "__fish_seen_subcommand_from service" --long-option "install" --description "Install, enable and start the service"
complete --command __SCRIPT_NAME__ --condition "__fish_seen_subcommand_from service" --long-option "status" --description "Show install and running state"
complete --command __SCRIPT_NAME__ --condition "__fish_seen_subcommand_from service" --long-option "remove" --description "Stop, disable and remove the service"
complete --command __SCRIPT_NAME__ --condition "__fish_seen_subcommand_from setup" --long-option "remove" --description "Uninstall the command"
# <shell>
complete --command __SCRIPT_NAME__ --exclusive --condition "__fish_seen_subcommand_from completion" --arguments "bash fish zsh" --description "Shell type"
EOF
    ;;
  zsh)
    cat <<'EOF' | sed "s/__SCRIPT_NAME__/$SCRIPT_NAME/g"
#compdef __SCRIPT_NAME__

___SCRIPT_NAME___completions() {
  local context state line
  local -a actions
  actions=(apply completion delete help list save service setup show verify watch)
  local -a configs_all
  local -a configs_available
  configs_all=()
  configs_available=()
  if [[ -n $(command -v __SCRIPT_NAME__) ]]; then
    configs_all=($(__SCRIPT_NAME__ list --raw 2>/dev/null))
    configs_available=($(__SCRIPT_NAME__ list --available --raw 2>/dev/null))
  elif [[ -d $HOME/.config/gnome-displays ]]; then
    for f in $HOME/.config/gnome-displays/*.json(.N); do
      configs_all+="${f:t:r}"
      configs_available+="${f:t:r}"
    done
  fi
  _arguments -C \
    '1:action:((apply completion delete help list save service setup show verify watch))' \
    '2:shell:(bash fish zsh)' \
    '2:config name:->config'

  case $state in
    config)
      if [[ ${words[2]} == "apply" ]]; then
        configs_available=(auto --force --persistent --temporary $configs_available)
        _describe -t configs 'available configs' configs_available
      elif [[ ${words[2]} == "show" || ${words[2]} == "save" || ${words[2]} == "verify" || ${words[2]} == "delete" ]]; then
        _describe -t configs 'configs' configs_all
      elif [[ ${words[2]} == "service" ]]; then
        _describe -t options 'service options' '(--install --status --remove)'
      elif [[ ${words[2]} == "setup" ]]; then
        _describe -t options 'setup options' '(--remove)'
      fi
      ;;
  esac
}
compdef ___SCRIPT_NAME___completions __SCRIPT_NAME__
EOF
    ;;
  *)
    err "Unsupported shell type: $SHELL_TYPE"
    exit 1
    ;;
  esac
}

check_dependencies() {
  local DEPENDENCIES=("jq" "gdctl" "gawk" "column" "$@")
  local MISSING_DEPS=()
  for DEP in "${DEPENDENCIES[@]}"; do
    if ! command -v "$DEP" &>/dev/null; then
      MISSING_DEPS+=("$DEP")
    fi
  done
  if [[ ${#MISSING_DEPS[@]} -gt 0 ]]; then
    err "Missing dependencies: ${MISSING_DEPS[*]}"
    err "Please install them using your package manager."
    exit 1
  fi
}

mutter_available() {
  gdbus introspect --session --dest "$MUTTER_DEST" --object-path "$MUTTER_PATH" &>/dev/null
}

require_gnome_session() {
  check_dependencies gdbus
  if ! mutter_available; then
    err "This action requires an active GNOME (Mutter) session."
    err "'$MUTTER_DEST' is not reachable on the current session bus."
    exit 1
  fi
}

has_systemd_user() {
  [[ -n "$XDG_RUNTIME_DIR" ]] && systemctl --user show-environment &>/dev/null
}

check_configuration() { 
  local NAME="$1"
  local ACTION="$2"
  if [[ -z "$NAME" ]]; then
    err "Error: Please provide a configuration name."
    err "Usage: $SCRIPT_NAME $ACTION <name>"
    exit 1
  fi
  if [[ ! -f "$CONFIG_DIR/$NAME.json" ]]; then
    err "Configuration $NAME does not exist."
    err ""
    err "Available configurations:"
    print_configurations false false >&2
    exit 1
  fi
}

get_monitor() {
  local VENDOR="$1"
  local PRODUCT="$2"
  local SERIAL="$3"
  gdctl show | gawk -v vendor="$VENDOR" -v product="$PRODUCT" -v serial="$SERIAL" '
    /Monitor / {
        match($0, /Monitor ([^ ]+)/, m)
        connector = m[1]
        current_vendor = ""
        current_product = ""
        current_serial = ""
    }
    /Vendor:/ { sub(/^.*Vendor:[ ]*/, ""); current_vendor = $0 }
    /Product:/ {
        sub(/^.*Product:[ ]*/, "");
        current_product = $0
    }
    /Serial:/ {
        sub(/^.*Serial:[ ]*/, ""); current_serial = $0
        if (current_product == product && current_vendor == vendor && current_serial == serial) {
            print connector
            exit
        }
    }
  '
}

print_monitor() {
  local NAME="$1"
  local FOUND_MONITORS="$2"
  local MONITORS="$3"

  echo "$(bold "$NAME") ($FOUND_MONITORS/$MONITORS monitors)"
}

count_found_monitors() {
  local CONFIG_FILE="$1"
  jq -r '.[] | "\(.vendor)\t\(.product)\t\(.serial)"' "$CONFIG_FILE" |
    while IFS=$'\t' read -r vendor product serial; do
      get_monitor "$vendor" "$product" "$serial" | grep -q . && echo 1
    done | wc -l
}

print_configurations() {
  local RAW_MODE="$1"
  local AVAILABLE_ONLY="$2"
  local FILE NAME MONITORS FOUND_MONITORS

  shopt -s nullglob
  local FILES=("$CONFIG_DIR"/*.json)
  shopt -u nullglob

  if [[ ${#FILES[@]} -eq 0 ]]; then
    err "No display configurations found."
    err "Hint: use $SCRIPT_NAME save <name> to save the current display configuration."
    exit 1
  fi

  if [[ "$RAW_MODE" == "true" && "$AVAILABLE_ONLY" != "true" ]]; then
    for FILE in "${FILES[@]}"; do
      NAME=$(basename "$FILE" .json)
      echo "$NAME"
    done
    return 0
  fi

  check_dependencies

  for FILE in "${FILES[@]}"; do
    NAME=$(basename "$FILE" .json)
    MONITORS=$(jq -r '. | length' "$FILE")
    FOUND_MONITORS=$(count_found_monitors "$FILE")
    if [[ "$AVAILABLE_ONLY" == "true" && $FOUND_MONITORS -lt $MONITORS ]]; then
      continue
    fi
    if [[ "$RAW_MODE" == "true" ]]; then
      echo "$NAME"
    else
      print_monitor "$NAME" "$FOUND_MONITORS" "$MONITORS"
    fi
  done
}

list() {
  shift
  local RAW_MODE=false AVAILABLE_ONLY=false ARG
  for ARG in "$@"; do
    case "$ARG" in
    --raw)
      RAW_MODE=true
      ;;
    --available)
      AVAILABLE_ONLY=true
      ;;
    esac
  done
  print_configurations "$RAW_MODE" "$AVAILABLE_ONLY"
}

show() {
  local NAME="$2"

  check_configuration "$NAME" "show"
  check_dependencies

  local MISSING_MONITORS MISSING_MONITORS_ARR
  MISSING_MONITORS=$(get_missing_monitors "$CONFIG_DIR/$NAME.json")
  IFS=$'\n' read -rd '' -a MISSING_MONITORS_ARR <<< "$MISSING_MONITORS"

  {
    bold "vendor | product | serial | mode | colorMode | x | y | scale | transform | primary | connected"
    jq -r '.[] | "\(.vendor)|\(.product)|\(.serial)|\(.mode)|\(.colorMode)|\(.x)|\(.y)|\(.scale)|\(.transform)|\(.primary)"' "$CONFIG_DIR/$NAME.json" |
      while IFS='|' read -r vendor product serial mode colorMode x y scale transform primary; do
        local MONITOR="$vendor $product ($serial)"
        local display_transform="$transform"
        local connected='✅'
        case "$transform" in
        90|180|270)
          display_transform="${transform}°"
          ;;
        flipped-90|flipped-180|flipped-270)
          display_transform="${transform}°"
          ;;
        esac
        for missing in "${MISSING_MONITORS_ARR[@]}"; do
          if [[ "$missing" == "$MONITOR" ]]; then
            connected='❌'
            break
          fi
        done
        printf "%s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s\n" \
          "$vendor" "$product" "$serial" "$mode" "$colorMode" "$x" "$y" "$scale" "$display_transform" "$primary" "$connected"
      done
  } | column -t -s '|'

  if [[ -n "$MISSING_MONITORS" ]]; then
    echo
    echo "The following monitors are missing or not connected:"
    while IFS= read -r MONITOR; do
      echo "- $MONITOR"
    done <<< "$MISSING_MONITORS"
  fi
}

current_config_json() {
  local OUTPUT
  OUTPUT=$(gdctl show -p)

  declare -A vendors
  declare -A products
  declare -A serials
  declare -A modes
  declare -A colorModes
  local current_connector=""
  while IFS= read -r line; do
    if [[ "$line" =~ Monitor[[:space:]]([^[:space:]]+) ]]; then
      current_connector="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ Vendor:[[:space:]](.+) ]]; then
      vendors["$current_connector"]="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ Product:[[:space:]](.+) ]]; then
      products["$current_connector"]="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ Serial:[[:space:]](.+) ]]; then
      serials["$current_connector"]="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ Current[[:space:]]mode ]]; then
      read -r mode_line
      if [[ "$mode_line" =~ ([0-9]+x[0-9]+@[0-9\.]+) ]]; then
        modes["$current_connector"]="${BASH_REMATCH[1]}"
      fi
    elif [[ "$line" =~ color-mode[[:space:]]*⇒[[:space:]]*(default|bt2100|sdr-native) ]]; then
      colorModes["$current_connector"]="${BASH_REMATCH[1]}"
    fi
  done < <(echo "$OUTPUT" | sed -n '/^Monitors:/,/^Logical monitors:/p')

  echo "$OUTPUT" |
    gawk '
      BEGIN { RS = "Logical monitor" }
      NR > 1 {
        x = y = scale = transform = primary = connector = ""
        if (match($0, /Position:[[:space:]]+\(([0-9]+),[[:space:]]+([0-9]+)\)/, m)) { x = m[1]; y = m[2] }
        if (match($0, /Scale:[[:space:]]+([0-9\.]+)/, m)) { scale = m[1] }
        if (match($0, /Transform:[[:space:]]+(normal|90|180|270|flipped|flipped-90|flipped-180|flipped-270)/, m)) { transform = m[1] }
        if (match($0, /Primary:[[:space:]]+(yes|no)/, m)) { primary = (m[1] == "yes" ? "true" : "false") }
        if (match($0, /([a-zA-Z0-9-]+) \(/, m)) { connector = m[1] }
        if (connector) {
          print connector "|" x "|" y "|" scale "|" transform "|" primary
        }
      }
    ' |
    while IFS='|' read -r connector x y scale transform primary; do
      [[ -z "$connector" ]] && continue
      printf "%s|%s|%s|%s|%s|%s|%s|%s|%s|%s\n" \
        "${vendors[$connector]}" \
        "${products[$connector]}" \
        "${serials[$connector]}" \
        "${modes[$connector]}" \
        "${colorModes[$connector]}" \
        "$x" \
        "$y" \
        "$scale" \
        "$transform" \
        "$primary"
    done |
    jq --raw-input --slurp '
    split("\n") |
    map(select(length > 0)) |
    map(
        split("|") |
        {
            vendor: .[0],
            product: .[1],
            serial: .[2],
            mode: .[3],
            colorMode: .[4],
            x: (.[5] | tonumber),
            y: (.[6] | tonumber),
            scale: (.[7] | tonumber),
            transform: .[8],
            primary: (.[9] == "true")
        }
    )
'
}

save() {
  local NAME="$2"

  if [[ -z "$NAME" ]]; then
    err "Error: Please provide a configuration name."
    err "Usage: $SCRIPT_NAME save <name>"
    exit 1
  fi

  check_dependencies

  if [[ -f "$CONFIG_DIR/$NAME.json" ]]; then
    echo "Configuration $(bold "$NAME") already exists."
    read -rp "Do you want to overwrite it? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      echo "Save aborted."
      exit 0
    fi
  fi

  mkdir -p "$CONFIG_DIR"

  current_config_json >"$CONFIG_DIR/$NAME.json"
  echo "Display configuration $(bold "$NAME") saved."
}

config_matches_current() {
  local CONFIG_FILE="$1"
  local CURRENT
  CURRENT=$(current_config_json) || return 1
  jq -es \
    '(.[0] | sort_by(.vendor, .product, .serial))
       == (.[1] | sort_by(.vendor, .product, .serial))' \
    <(echo "$CURRENT") "$CONFIG_FILE" >/dev/null 2>&1
}

get_missing_monitors() {
  local CONFIG_FILE="$1"
  local MISSING_MONITORS=()
  while IFS=$'\t' read -r vendor product serial; do
    if [[ -z "$vendor" ]]; then continue; fi
    if ! get_monitor "$vendor" "$product" "$serial" | grep -q "."; then
      MISSING_MONITORS+=("$vendor $product ($serial)")
    fi
  done < <(jq -r '.[] | "\(.vendor)\t\(.product)\t\(.serial)"' "$CONFIG_FILE")

  if [[ ${#MISSING_MONITORS[@]} -gt 0 ]]; then
    printf '%s\n' "${MISSING_MONITORS[@]}"
  fi
}

run_gdctl() {
  local NAME="$1"
  local MODE_FLAG="$2"
  local FORCE="$3"

  local VERB GDCTL_FLAGS=()
  case "$MODE_FLAG" in
  --persistent)
    VERB="apply"
    GDCTL_FLAGS=(--persistent)
    ;;
  --temporary)
    VERB="apply"
    ;;
  --verify)
    VERB="verify"
    GDCTL_FLAGS=(--verify)
    ;;
  *)
    VERB="run"
    ;;
  esac

  check_configuration "$NAME" "$VERB"
  check_dependencies

  case "$VERB" in
  apply)
    echo -n "Applying $NAME... "
    ;;
  verify)
    echo -n "Validating $NAME... "
    ;;
  *)
    echo -n "Running $NAME... "
    ;;
  esac

  local MISSING_MONITORS
  MISSING_MONITORS=$(get_missing_monitors "$CONFIG_DIR/$NAME.json")
  if [[ -n "$MISSING_MONITORS" ]]; then
    echo "❌"
    err "The following monitors are missing or not connected:"
    while IFS= read -r monitor; do
      err "- $monitor"
    done <<< "$MISSING_MONITORS"
    exit 1
  fi

  if [[ "$VERB" == "apply" && "$FORCE" != "true" ]] && config_matches_current "$CONFIG_DIR/$NAME.json"; then
    echo "✅ (already applied)"
    return 0
  fi

  local CMD monitor OUTPUT
  CMD=(gdctl set "${GDCTL_FLAGS[@]}")
  while IFS='|' read -r vendor product serial mode colorMode x y scale transform primary; do
    [[ -z "$vendor" ]] && continue
    monitor=$(get_monitor "$vendor" "$product" "$serial")
    CMD+=(--logical-monitor)
    if [[ "$primary" == "true" ]]; then
      CMD+=(--primary)
    fi
    CMD+=(
      --monitor "$monitor"
      --mode "$mode"
    )
    if [[ "$colorMode" == "default" || "$colorMode" == "bt2100" || "$colorMode" == "sdr-native" ]]; then
      CMD+=(--color-mode "$colorMode")
    fi
    CMD+=(
      --x "$x"
      --y "$y"
      --scale "$scale"
      --transform "$transform"
    )
  done < <(jq -r '.[] | "\(.vendor)|\(.product)|\(.serial)|\(.mode)|\(.colorMode)|\(.x)|\(.y)|\(.scale)|\(.transform)|\(.primary)"' "$CONFIG_DIR/$NAME.json")

  if ! OUTPUT=$("${CMD[@]}" 2>&1); then
    echo "❌"
    err "$OUTPUT"
    exit 1
  fi
  echo "✅"
}

apply_auto() {
  local FORCE="$1"
  local MODE="${2:---persistent}"
  check_dependencies

  shopt -s nullglob
  local FILES=("$CONFIG_DIR"/*.json)
  shopt -u nullglob

  if [[ ${#FILES[@]} -eq 0 ]]; then
    err "No display configurations found."
    err "Hint: use $SCRIPT_NAME save <name> to save the current display configuration."
    exit 1
  fi

  local FILE NAME MONITORS FOUND_MONITORS
  local BEST_NAME=""
  local BEST_COUNT=-1

  for FILE in "${FILES[@]}"; do
    NAME=$(basename "$FILE" .json)
    MONITORS=$(jq -r '. | length' "$FILE")
    FOUND_MONITORS=$(count_found_monitors "$FILE")
    [[ $FOUND_MONITORS -lt $MONITORS ]] && continue
    if [[ $MONITORS -gt $BEST_COUNT ]]; then
      BEST_COUNT=$MONITORS
      BEST_NAME=$NAME
    fi
  done

  if [[ -z "$BEST_NAME" ]]; then
    err "No applicable display configuration found for the currently connected monitors."
    exit 1
  fi

  local MONITOR_LABEL="monitors"
  [[ "$BEST_COUNT" -eq 1 ]] && MONITOR_LABEL="monitor"
  echo "Auto-selected $(bold "$BEST_NAME") ($BEST_COUNT $MONITOR_LABEL)."
  run_gdctl "$BEST_NAME" "$MODE" "$FORCE"
}

apply() {
  shift
  local FORCE=false
  local MODE="--persistent"
  local NAME=""
  local ARG
  for ARG in "$@"; do
    case "$ARG" in
    --force)
      FORCE=true
      ;;
    --persistent)
      MODE="--persistent"
      ;;
    --temporary)
      MODE="--temporary"
      ;;
    --*)
      err "Error: Unknown option: $ARG"
      err "Usage: $SCRIPT_NAME apply [<name>|auto] [--force] [--persistent|--temporary]"
      exit 1
      ;;
    *)
      [[ -z "$NAME" ]] && NAME="$ARG"
      ;;
    esac
  done

  if [[ -z "$NAME" || "$NAME" == "auto" ]]; then
    apply_auto "$FORCE" "$MODE"
    return
  fi
  check_configuration "$NAME" "apply"
  run_gdctl "$NAME" "$MODE" "$FORCE"
}

verify() {
  local NAME="$2"
  check_configuration "$NAME" "verify"
  run_gdctl "$NAME" --verify
}

delete() {
  local NAME="$2"
  check_configuration "$NAME" "delete"
  local FILE="$CONFIG_DIR/$NAME.json"
  read -rp "Are you sure you want to delete configuration '$NAME'? [y/N]: " confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    rm -f "$FILE"
    echo "Configuration '$NAME' deleted."
  else
    echo "Delete aborted."
  fi
}

watch() {
  check_dependencies gdbus

  local i
  for ((i = 0; i < 30; i++)); do
    mutter_available && break
    if [[ $i -eq 0 ]]; then
      echo "Waiting for the GNOME (Mutter) session..."
    fi
    if [[ $i -eq 29 ]]; then
      err "GNOME (Mutter) session not available after 30s; giving up."
      exit 1
    fi
    sleep 1
  done

  echo "Watching for display changes (settle ${SETTLE_SECONDS}s, Ctrl-C to stop)."
  (apply_auto false --temporary) || true

  local line pending=0 rc
  while true; do
    IFS= read -r -t "$SETTLE_SECONDS" line
    rc=$?
    if [[ $rc -eq 0 ]]; then
      [[ "$line" == *MonitorsChanged* ]] && pending=1
    elif [[ $rc -gt 128 ]]; then
      if [[ $pending -eq 1 ]]; then
        pending=0
        (apply_auto false --temporary) || true
      fi
    else
      err "Display change stream closed; exiting for restart."
      exit 1
    fi
  done < <(gdbus monitor --session --dest "$MUTTER_DEST" --object-path "$MUTTER_PATH" 2>/dev/null)
}

setup() {
  shift
  local REMOVE=false ARG
  for ARG in "$@"; do
    case "$ARG" in
    --remove)
      REMOVE=true
      ;;
    *)
      err "Error: Unknown option: $ARG"
      err "Usage: $SCRIPT_NAME setup [--remove]"
      exit 1
      ;;
    esac
  done

  if [[ "$REMOVE" == "true" ]]; then
    if [[ ! -e "$INSTALL_PATH" ]]; then
      echo "Not installed at $INSTALL_PATH."
      exit 0
    fi
    read -rp "Remove $INSTALL_PATH? [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      echo "Aborted."
      exit 0
    fi
    rm -f "$INSTALL_PATH"
    echo "Removed $INSTALL_PATH."
    return 0
  fi

  local SOURCE
  SOURCE=$(readlink -f "$0")
  mkdir -p "$INSTALL_DIR"
  if [[ "$SOURCE" == "$INSTALL_PATH" ]]; then
    echo "Already installed at $(bold "$INSTALL_PATH")."
  else
    install -m 755 "$SOURCE" "$INSTALL_PATH"
    echo "Installed $(bold "$INSTALL_PATH")."
  fi

  case ":$PATH:" in
  *":$INSTALL_DIR:"*) ;;
  *)
    err ""
    err "Note: $INSTALL_DIR is not on your PATH. Add it, e.g.:"
    err "  fish:     fish_add_path $INSTALL_DIR"
    err "  bash/zsh: export PATH=\"$INSTALL_DIR:\$PATH\""
    ;;
  esac
}

write_service_unit() {
  mkdir -p "$SERVICE_DIR"
  cat >"$SERVICE_PATH" <<EOF
[Unit]
Description=Auto-apply GNOME display configuration on login and monitor hotplug
After=graphical-session.target
PartOf=graphical-session.target

[Service]
Type=simple
ExecStart=$INSTALL_PATH watch
Restart=on-failure
RestartSec=2

[Install]
WantedBy=graphical-session.target
EOF
}

install_autostart() {
  mkdir -p "$AUTOSTART_DIR"
  cat >"$AUTOSTART_PATH" <<EOF
[Desktop Entry]
Type=Application
Name=GNOME Displays auto-apply
Exec=$INSTALL_PATH watch
X-GNOME-Autostart-enabled=true
NoDisplay=true
EOF
  echo "Installed autostart entry $(bold "$AUTOSTART_PATH")."
}

service_install() {
  require_gnome_session

  if [[ ! -x "$INSTALL_PATH" ]]; then
    err "The gnome-displays binary is not installed at $INSTALL_PATH."
    err "Run '$SCRIPT_NAME setup' first."
    exit 1
  fi

  if ! has_systemd_user; then
    err "No systemd user instance detected."
    read -rp "Install an XDG autostart entry instead? [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      echo "Aborted."
      exit 0
    fi
    install_autostart
    return 0
  fi

  check_dependencies systemctl
  write_service_unit
  systemctl --user daemon-reload
  systemctl --user enable --now "$SERVICE_NAME"
  echo "Service $(bold "$SERVICE_NAME") installed and started."
  echo "Logs: journalctl --user -u $SERVICE_NAME -f"
}

service_status() {
  check_dependencies systemctl
  if [[ -x "$INSTALL_PATH" ]]; then
    echo "Binary:    installed ($INSTALL_PATH)"
  else
    echo "Binary:    not installed"
  fi
  if [[ -f "$SERVICE_PATH" ]]; then
    local enabled active
    enabled=$(systemctl --user is-enabled "$SERVICE_NAME" 2>/dev/null || echo "disabled")
    active=$(systemctl --user is-active "$SERVICE_NAME" 2>/dev/null || echo "inactive")
    echo "Unit:      $SERVICE_PATH"
    echo "Enabled:   $enabled"
    echo "Active:    $active"
  else
    echo "Unit:      not installed"
  fi
  if [[ -f "$AUTOSTART_PATH" ]]; then
    echo "Autostart: $AUTOSTART_PATH"
  fi
}

service_remove() {
  check_dependencies systemctl
  local REMOVED=false
  if [[ -f "$SERVICE_PATH" ]]; then
    systemctl --user disable --now "$SERVICE_NAME" 2>/dev/null
    rm -f "$SERVICE_PATH"
    systemctl --user daemon-reload
    echo "Removed $SERVICE_NAME."
    REMOVED=true
  fi
  if [[ -f "$AUTOSTART_PATH" ]]; then
    rm -f "$AUTOSTART_PATH"
    echo "Removed autostart entry."
    REMOVED=true
  fi
  if [[ "$REMOVED" != "true" ]]; then
    echo "Nothing to remove."
  fi
}

service() {
  shift
  local OP="status" ARG
  for ARG in "$@"; do
    case "$ARG" in
    --install)
      OP="install"
      ;;
    --status)
      OP="status"
      ;;
    --remove)
      OP="remove"
      ;;
    *)
      err "Error: Unknown option: $ARG"
      err "Usage: $SCRIPT_NAME service [--install|--status|--remove]"
      exit 1
      ;;
    esac
  done

  case "$OP" in
  install)
    service_install
    ;;
  status)
    service_status
    ;;
  remove)
    service_remove
    ;;
  esac
}

ACTION="$1"
case "$ACTION" in
apply)
  COMMAND="apply"
  ;;
completion)
  COMMAND="completion"
  ;;
delete)
  COMMAND="delete"
  ;;
list)
  COMMAND="list"
  ;;
save)
  COMMAND="save"
  ;;
service)
  COMMAND="service"
  ;;
setup)
  COMMAND="setup"
  ;;
show)
  COMMAND="show"
  ;;
verify)
  COMMAND="verify"
  ;;
version | --version | -v)
  version
  exit 0
  ;;
watch)
  COMMAND="watch"
  ;;
help | "")
  help
  exit 0
  ;;
*)
  err "Unknown action: $ACTION"
  err ""
  help >&2
  exit 1
  ;;
esac

"$COMMAND" "$@"
