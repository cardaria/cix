#!/usr/bin/env bash
# Called by nix flake check to validate frontmatter, source coverage and privacy
# Usage: _check.sh <repo root>
set -euo pipefail

root=$1
cd "$root"
status=0
fail() {
  printf 'docs-sources: %s\n' "$*" >&2
  status=1
}

sources=wiki/_sources.yaml
yq -e 'type == "!!map"' "$sources" > /dev/null || fail "$sources is not a mapping"

# Frontmatter
while IFS= read -r page; do
  rel=${page#wiki/}
  if [[ $(head -n1 "$page") != '---' ]]; then
    fail "$page: missing frontmatter"
    continue
  fi
  front=$(awk 'NR == 1 { next } /^---$/ { exit } { print }' "$page")
  for key in title category tags updated; do
    [[ $(yq ".$key" <<< "$front") != null ]] || fail "$page: frontmatter lacks '$key'"
  done
  [[ $(yq '.tags | type' <<< "$front") == '!!seq' ]] || fail "$page: tags must be a list"
  [[ $(yq '.updated' <<< "$front") =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] ||
    fail "$page: updated must be YYYY-MM-DD"
  category=$(yq '.category' <<< "$front")
  if [[ $rel == */* ]]; then
    expected=${rel%%/*}
  else
    expected=overview
  fi
  [[ $category == "$expected" ]] || fail "$page: category '$category' should be '$expected'"
  if [[ $rel != README.md ]]; then
    [[ $(yq "has(\"$rel\")" "$sources") == true ]] || fail "$page: no entry in $sources"
  fi
done < <(find wiki -name '*.md' | sort)

# Entries point at real pages and real sources
while IFS= read -r rel; do
  [[ -f wiki/$rel ]] || fail "$sources: page '$rel' does not exist"
  while IFS= read -r src; do
    [[ -z $src ]] && continue
    [[ -e $src ]] || fail "$sources: '$rel' lists missing source '$src'"
  done < <(yq ".\"$rel\".sources[]" "$sources")
done < <(yq 'keys | .[]' "$sources")

# Every module is documented somewhere
listed=$(yq '.[].sources[]' "$sources" | sort -u)
while IFS= read -r module; do
  grep -qxF "$module" <<< "$listed" || fail "$module is not listed in $sources"
done < <({ echo flake.nix; find hosts modules home pkgs secrets -name '*.nix'; } | sort)

# Private identifiers stay in code; docs name the file instead
while IFS= read -r hit; do
  fail "$hit: IP address in docs; reference the file that holds it instead"
done < <(grep -rnoE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' README.md AGENTS.md wiki .agents | cut -d: -f1,2)

exit "$status"
