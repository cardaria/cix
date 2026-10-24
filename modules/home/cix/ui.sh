# shellcheck shell=bash
# Output helpers shared by the cix scripts; prepended to each at build time

step() {
  if [[ -t 1 ]]; then
    printf '\n\033[1m%s\033[0m\n' "$*"
  else
    printf '\n%s\n' "$*"
  fi
}

row() {
  printf '%-9s %s\n' "$1" "$2"
}

confirm() {
  local reply
  read -r -p "$1 [y/N] " reply || return 1
  [[ ${reply,,} == y || ${reply,,} == yes ]]
}
