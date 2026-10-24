# shellcheck shell=bash

# Read the profile links on the target, without relying on nix-env's display format
# shellcheck disable=SC2016
generation_scan='
  set -eu
  profile=/nix/var/nix/profiles/system
  name=${profile##*/}
  active=$(readlink "$profile")
  active=${active##*/}
  active=${active#"$name"-}
  active=${active%-link}
  case $active in ""|*[!0-9]*) echo "No numbered system generation" >&2; exit 1;; esac
  printf "current\t%s\t%s\n" "$active" "$(readlink -e "$profile")"
  for link in "$profile"-*-link; do
    [ -L "$link" ] || continue
    number=${link#"$profile"-}
    number=${number%-link}
    case $number in ""|*[!0-9]*) continue;; esac
    path=$(readlink -e "$link") || continue
    [ -x "$path/bin/switch-to-configuration" ] || continue
    printf "%s\t%s\n" "$number" "$path"
  done
'

select_generation() {
  local file=$1 number=${2:-} selected
  selected=$(awk -F '\t' -v wanted="$number" '
    $1 == "current" { current = $2; path = $3; next }
    wanted != "" && $1 == wanted { selected = $0 }
    wanted == "" && $1 < current && $2 != path && $1 > best { best = $1; selected = $0 }
    END { print selected }' "$file")
  [[ -n $selected ]] || {
    echo "No retained ${number:+generation }${number:-earlier distinct generation}. Use --list to inspect the available generations." >&2
    return 1
  }
  printf '%s\n' "$selected"
}

show_generations() {
  local file=$1 number path current
  current=$(awk -F '\t' '$1 == "current" { print $2 }' "$file")
  while IFS=$'\t' read -r number path; do
    item "generation $number" "$path$([[ $number != "$current" ]] || echo ' · current profile')"
  done < <(awk -F '\t' '$1 != "current"' "$file" | sort -rn)
}
