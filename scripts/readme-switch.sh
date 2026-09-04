#!/usr/bin/env bash
# readme-switch — keep several GitHub profile READMEs side by side and swap the live one.
#
#   ./scripts/readme-switch.sh              list the variants, mark the active one
#   ./scripts/readme-switch.sh use b-signal set that variant live
#   ./scripts/readme-switch.sh next         rotate to the next variant in order
#   ./scripts/readme-switch.sh random       pick a different one at random
#   ./scripts/readme-switch.sh save         fold edits you made to README.md back into its variant
#   ./scripts/readme-switch.sh diff         show what README.md has that its variant doesn't
#
#   flags:  -c / --commit   commit the switch
#           -p / --push     commit and push it
#           -f / --force    switch even though README.md has unsaved edits

set -euo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DIR="$ROOT/readmes"
ACTIVE_FILE="$DIR/active.txt"
README="$ROOT/README.md"
COMMIT=0; PUSH=0; FORCE=0

die() { printf '\033[31mreadme-switch:\033[0m %s\n' "$1" >&2; exit 1; }
say() { printf '%s\n' "$1"; }

[ -d "$DIR" ] || die "no readmes/ directory in $ROOT — run the setup script first."

names() {
  find "$DIR" -maxdepth 1 -type f -name '*.md' -exec basename {} .md \; \
    | grep -vx -e 'IMPLEMENTATION' -e 'README' | sort
}
active() { [ -f "$ACTIVE_FILE" ] && tr -d '[:space:]' <"$ACTIVE_FILE" || printf ''; }
exists() { [ -f "$DIR/$1.md" ]; }

# first meaningful line of a variant, for the listing
blurb() {
  local f="$DIR/$1.md" line
  # a variant can name itself on line 1: <!-- variant: short description -->
  line="$(sed -n '1s/^<!-- *variant: *\(.*[^ ]\) *-->.*$/\1/p' "$f")"
  if [ -z "$line" ]; then
    line="$(sed -e '/^ *```/d' -e 's/<[^>]*>//g' -e 's/[#*`_>|]//g' "$f" \
      | grep -m1 '[A-Za-z].\{11,\}' || true)"
  fi
  printf '%s' "$line" | cut -c1-62 | sed 's/^ *//;s/ *$//'
}

drifted() {
  local a; a="$(active)"
  [ -n "$a" ] && [ -f "$DIR/$a.md" ] && [ -f "$README" ] && ! cmp -s "$README" "$DIR/$a.md"
}

cmd_list() {
  local a n; a="$(active)"
  printf '\n  \033[1mProfile README variants\033[0m  ·  %s\n\n' "${ROOT##*/}/readmes"
  while IFS= read -r n; do
    if [ "$n" = "$a" ]; then
      printf '  \033[32m●\033[0m \033[1m%-12s\033[0m %s\n' "$n" "$(blurb "$n")"
    else
      printf '  ○ %-12s %s\n' "$n" "$(blurb "$n")"
    fi
  done < <(names)
  printf '\n'
  if drifted; then
    printf '  \033[33m!\033[0m README.md has edits that are not in \033[1m%s\033[0m.\n' "$a"
    printf '    Keep them with:  %s save        See them with:  %s diff\n\n' "$0" "$0"
  fi
}

apply() {
  local name="$1"
  exists "$name" || die "no variant called '$name'. Run without arguments to see the list."
  if drifted && [ "$FORCE" -ne 1 ]; then
    die "README.md has edits not saved to '$(active)'.
    Keep them:     $0 save
    Discard them:  $0 use $name --force"
  fi
  cp -- "$DIR/$name.md" "$README"
  printf '%s\n' "$name" >"$ACTIVE_FILE"
  printf '  \033[32m●\033[0m now live: \033[1m%s\033[0m\n' "$name"
  if [ "$COMMIT" -eq 1 ] || [ "$PUSH" -eq 1 ]; then publish "$name"; fi
  return 0
}

publish() {
  command -v git >/dev/null || die "git not found."
  git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1 || die "$ROOT is not a git repository."
  git -C "$ROOT" add -- README.md readmes/active.txt
  if git -C "$ROOT" diff --cached --quiet; then
    say "  nothing to commit — README.md already matched."
    return 0
  fi
  git -C "$ROOT" commit -q -m "readme: switch profile to $1"
  say "  committed."
  if [ "$PUSH" -eq 1 ]; then
    git -C "$ROOT" push -q && say "  pushed."
  fi
}

cmd_next() {
  local a list i n total; a="$(active)"
  mapfile -t list < <(names)
  total=${#list[@]}
  [ "$total" -gt 1 ] || die "only one variant saved — nothing to rotate to."
  for i in "${!list[@]}"; do
    if [ "${list[$i]}" = "$a" ]; then n=$(( (i + 1) % total )); fi
  done
  apply "${list[${n:-0}]}"
}

cmd_random() {
  local a list pick total; a="$(active)"
  mapfile -t list < <(names)
  total=${#list[@]}
  [ "$total" -gt 1 ] || die "only one variant saved — nothing to rotate to."
  while :; do
    pick="${list[$((RANDOM % total))]}"
    [ "$pick" != "$a" ] && break
  done
  apply "$pick"
}

cmd_save() {
  local a; a="$(active)"
  [ -n "$a" ] || die "no active variant recorded in readmes/active.txt."
  [ -f "$README" ] || die "no README.md to save."
  if ! drifted; then say "  '$a' already matches README.md — nothing to save."; return 0; fi
  cp -- "$README" "$DIR/$a.md"
  printf '  saved your README.md edits into \033[1m%s\033[0m\n' "$a"
}

cmd_diff() {
  local a; a="$(active)"
  [ -n "$a" ] || die "no active variant recorded."
  if ! drifted; then say "  README.md matches '$a'."; return 0; fi
  diff -u --label "readmes/$a.md" --label "README.md" "$DIR/$a.md" "$README" || true
}

# ---- argument parsing -------------------------------------------------------
CMD=""; ARG=""
while [ $# -gt 0 ]; do
  case "$1" in
    -c|--commit) COMMIT=1 ;;
    -p|--push)   COMMIT=1; PUSH=1 ;;
    -f|--force)  FORCE=1 ;;
    -h|--help)   sed -n '2,17p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    use)         CMD="use" ;;
    next|random|save|diff|list) CMD="$1" ;;
    -*)          die "unknown flag '$1'" ;;
    *)           if [ -z "$CMD" ]; then CMD="use"; ARG="$1"; else ARG="$1"; fi ;;
  esac
  shift
done

case "${CMD:-list}" in
  list)   cmd_list ;;
  use)    [ -n "$ARG" ] || die "which one? e.g. $0 use a-quiet"; apply "$ARG" ;;
  next)   cmd_next ;;
  random) cmd_random ;;
  save)   cmd_save ;;
  diff)   cmd_diff ;;
esac
