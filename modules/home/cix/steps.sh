# shellcheck shell=bash
# The look of the update commands: a spinner per step, then ✓ or ✗; prepended to them at build time

if [[ -t 1 ]]; then
  ui_bold=$'\033[1m' ui_dim=$'\033[2m' ui_green=$'\033[32m' ui_red=$'\033[31m' ui_cyan=$'\033[36m' ui_off=$'\033[0m'
else
  ui_bold='' ui_dim='' ui_green='' ui_red='' ui_cyan='' ui_off=''
fi
ui_verbose=false
ui_pid=

section() {
  printf '\n%s%s%s\n' "$ui_bold" "$*" "$ui_off"
}

# A finished step: its mark, the label in a column, a detail
mark_ok() {
  printf '  %s✓%s %-16s%s\n' "$ui_green" "$ui_off" "$1" "${2:-}"
}
mark_fail() {
  printf '  %s✗%s %-16s%s\n' "$ui_red" "$ui_off" "$1" "${2:-}" >&2
}

# A line inside a section, and a dimmed side note
item() {
  printf '    %-22s %s\n' "$1" "${2:-}"
}

# A second detail under a finished step's first
detail() {
  printf '%20s%s\n' '' "$1"
}
note() {
  printf '  %s%s%s\n' "$ui_dim" "$*" "$ui_off"
}

# Runs one step: a spinner while it works, its output in the log; --verbose shows it all instead
task() {
  local label=$1 log=$2 status=0 i=0
  local frames=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
  shift 2
  if $ui_verbose; then
    section "$label"
    "$@" 2>&1 | tee -a "$log" || status=$?
  else
    "$@" >> "$log" 2>&1 < /dev/null &
    ui_pid=$!
    if [[ -t 1 ]]; then
      printf '\033[?25l'
      while kill -0 "$ui_pid" 2> /dev/null; do
        printf '\r  %s%s%s %s' "$ui_cyan" "${frames[i++ % ${#frames[@]}]}" "$ui_off" "$label"
        sleep 0.08
      done
      printf '\r\033[K\033[?25h'
    fi
    wait "$ui_pid" || status=$?
    ui_pid=
  fi
  if ((status)); then
    mark_fail "$label" "failed ($( ((status > 128)) && echo "signal $((status - 128))" || echo "status $status")); its log ends:"
    tail -n 12 "$log" | sed 's/^/      /' >&2
  fi
  return "$status"
}

# Stops a running step and shows the cursor again
ui_cleanup() {
  [[ -z $ui_pid ]] || kill "$ui_pid" 2> /dev/null || true
  [[ ! -t 1 ]] || printf '\033[?25h'
}

# y or yes is yes; the more key runs a function that shows more, then asks again; anything else is no
ask() {
  local question=$1 key=${2:-} more=${3:-} reply
  while :; do
    read -r -p "  $question [y/N${key:+, $key}] " reply || return 1
    case ${reply,,} in
      y | yes) return 0 ;;
      "${key%% *}")
        [[ -n $key && -n $more ]] || return 1
        "$more"
        ;;
      *) return 1 ;;
    esac
  done
}
