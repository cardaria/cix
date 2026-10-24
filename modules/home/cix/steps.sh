# shellcheck shell=bash
# The look of the update commands: a spinner per step, then ✓ or ✗; prepended to them at build time

if [[ -t 1 ]]; then
  ui_bold=$'\033[1m' ui_dim=$'\033[2m' ui_green=$'\033[32m' ui_red=$'\033[31m' ui_cyan=$'\033[36m' ui_off=$'\033[0m'
else
  ui_bold='' ui_dim='' ui_green='' ui_red='' ui_cyan='' ui_off=''
fi
ui_verbose=false
ui_pid=
ui_status=

section() {
  printf '\n%s%s%s\n' "$ui_bold" "$*" "$ui_off"
}

mark_ok() {
  printf '  %s✓%s %-16s%s\n' "$ui_green" "$ui_off" "$1" "${2:-}"
}
mark_fail() {
  printf '  %s✗%s %-16s%s\n' "$ui_red" "$ui_off" "$1" "${2:-}" >&2
}

item() {
  printf '    %-22s %s\n' "$1" "${2:-}"
}

detail() {
  printf '%20s%s\n' '' "$1"
}
note() {
  printf '  %s%s%s\n' "$ui_dim" "$*" "$ui_off"
}

# The cursor stays hidden for the whole run, so it never blinks between steps; questions show it
ui_hide() { [[ ! -t 1 ]] || printf '\033[?25l'; }
ui_show() { [[ ! -t 1 ]] || printf '\033[?25h'; }

# Runs one step: a spinner while it works, its output in the log; --verbose shows it all instead
task() {
  local label=$1 log=$2 status=0 i=0 text=
  local frames=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
  shift 2
  if $ui_verbose; then
    section "$label"
  fi
  # A separate process group keeps interrupted steps from leaving deploy commands running
  set -m
  (
    set +m
    if $ui_verbose; then
      "$@" 2>&1 | tee -a "$log"
    else
      "$@" >> "$log" 2>&1 < /dev/null
    fi
  ) &
  ui_pid=$!
  set +m
  if [[ -t 1 ]] && ! $ui_verbose; then
    ui_hide
    while kill -0 "$ui_pid" 2> /dev/null; do
      text=
      [[ -z $ui_status || ! -r $ui_status ]] || text=$(< "$ui_status")
      printf '\r\033[K  %s%s%s %s  %s%s%s' "$ui_cyan" "${frames[i++ % ${#frames[@]}]}" "$ui_off" "$label" "$ui_dim" "$text" "$ui_off"
      sleep 0.08
    done
    printf '\r\033[K'
  fi
  wait "$ui_pid" || status=$?
  ui_pid=
  if ((status)); then
    mark_fail "$label" "failed ($( ((status > 128)) && echo "signal $((status - 128))" || echo "status $status")); its log ends:"
    tail -n 12 "$log" | sed 's/^/      /' >&2
  fi
  return "$status"
}

ui_cleanup() {
  [[ -z $ui_pid ]] || kill -- "-$ui_pid" 2> /dev/null || true
  ui_show
}

# Shows what a function prints in a full-screen pager (arrows or Page Up/Down to scroll, q to go back); plain when not a terminal
view() {
  if [[ -t 1 ]]; then
    ui_show
    { "$@" | less -R -P "All changes  ·  arrows and Page Up/Down scroll  ·  q goes back"; } || true
    ui_hide
  else
    "$@"
  fi
}

# y or yes is yes; the more key runs a function that shows more, then asks again; anything else is no
ask() {
  local question=$1 key=${2:-} more=${3:-} reply
  while :; do
    ui_show
    read -r -p "  $question [y/N${key:+, $key}] " reply || { ui_hide; return 1; }
    ui_hide
    case ${reply,,} in
      y | yes) return 0 ;;
      "${key%% *}")
        [[ -n $key && -n $more ]] || return 1
        view "$more"
        ;;
      *) return 1 ;;
    esac
  done
}
