export CMD_STASH_FILE="${CMD_STASH_FILE:-$HOME/.cmd_stash}"
[[ -e "$CMD_STASH_FILE" ]] || : > "$CMD_STASH_FILE"

# default tray name (can override per-session)
export CMD_STASH_TRAY="${CMD_STASH_TRAY:-main}"

# Generate a reasonably unique ID
_stash_gen_id() {
  if [[ -n ${EPOCHREALTIME-} ]]; then
    printf '%s.%s.%s' "${EPOCHREALTIME//./}" "$$" "$RANDOM"
  else
    printf '%s.%s.%s' "$(date +%s)" "$$" "$RANDOM"
  fi
}

# quick status message without polluting the prompt line
_stash_status() {
  if zle >/dev/null 2>&1; then
    zle -M -- "$*"
  else
    print -r -- "$*"
  fi
}

# one tray -> formatted picker input
# order is OLD -> NEW because we read the file as-is
_stash_entries_for_tray() {
  local tray="$1"
  [[ -n "$tray" && -s "$CMD_STASH_FILE" ]] || return 1

  awk -F'\t' -v tray="$tray" '
    NF >= 4 && $3 == tray {
      cmd = $0
      sub(/^[^\t]*\t[^\t]*\t[^\t]*\t/, "", cmd)
      printf "%s\t%s | %s\n", $1, $2, cmd
    }
  ' "$CMD_STASH_FILE"
}

# single-select picker
# +m keeps multiselect OFF even if FZF_DEFAULT_OPTS ever contains --multi
# --accept-nth=1 returns only the ID
_stash_choose_one_in_tray() {
  local tray="$1"; shift
  _stash_entries_for_tray "$tray" |
    fzf +m \
      --scheme=history \
      --no-sort \
      --delimiter=$'\t' \
      --with-nth=2 \
      --accept-nth=1 \
      --prompt="stash[$tray]> " \
      --bind='tab:down,btab:up' \
      "$@"
}

# multi-select picker, only for bulk operations
# returns one selected ID per line
_stash_choose_many_in_tray() {
  local tray="$1"; shift
  _stash_entries_for_tray "$tray" |
    fzf -m \
      --scheme=history \
      --no-sort \
      --delimiter=$'\t' \
      --with-nth=2 \
      --accept-nth=1 \
      --prompt="stash[$tray]> " \
      --bind='tab:toggle+down,btab:toggle+up,ctrl-a:select-all,ctrl-x:deselect-all' \
      "$@"
}

# append one command line to stash file
_stash_append() {
  local quiet=0
  if [[ $1 == --quiet ]]; then
    quiet=1
    shift
  fi

  local tray="${CMD_STASH_TRAY:-main}"
  local line="$*"
  [[ -z "$line" ]] && {
    (( quiet )) || print -r -- "Nothing to stash."
    return 1
  }

  # keep the TSV file one-record-per-line and four columns wide
  line=${line//$'\t'/    }
  line=${line//$'\n'/'; '}

  local id ts
  id="$(_stash_gen_id)"
  ts="$(date +%F' '%T)"

  printf '%s\t%s\t%s\t%s\n' "$id" "$ts" "$tray" "$line" >> "$CMD_STASH_FILE"

  (( quiet )) || print -r -- "Stashed: [$ts][$tray] $line"
}

# stash the CURRENT command line (Ctrl-S)
stash-add-buffer-widget() {
  local line="${LBUFFER}${RBUFFER}"

  if [[ -z "$line" ]]; then
    _stash_status "Stash: nothing to stash"
    return 0
  fi

  _stash_append --quiet "$line" || {
    _stash_status "Stash: failed to stash command"
    zle redisplay
    return 1
  }

  LBUFFER=""
  RBUFFER=""
  CURSOR=0

  _stash_status "Stashed to tray: ${CMD_STASH_TRAY:-main}"
  zle redisplay
}
zle -N stash-add-buffer-widget
bindkey '^s' stash-add-buffer-widget

# choose a tray
_stash_choose_tray() {
  [[ ! -s "$CMD_STASH_FILE" ]] && return 1

  local -a trays
  trays=("${(@f)$(awk -F'\t' 'NF>=4 {print $3}' "$CMD_STASH_FILE" | sort -u)}")
  (( ${#trays[@]} )) || return 1

  if (( ${#trays[@]} == 1 )); then
    print -r -- "$trays[1]"
    return 0
  fi

  print -l -- "${trays[@]}" | fzf --prompt='tray> ' --no-sort
}

# lookup a command by ID from the stash file
_stash_cmd_by_id() {
  local id="$1"
  awk -F'\t' -v id="$id" '
    NF>=4 && $1==id {
      print substr($0, index($0,$4))
      exit
    }
  ' "$CMD_STASH_FILE"
}

# pick from stash and insert into prompt (Ctrl-G)
stash-pick-widget() {
  zle -I

  local tray id cmd

  tray="$(_stash_choose_tray)" || {
    _stash_status "Stash: tray selection canceled"
    zle redisplay
    return 1
  }

  id="$(_stash_choose_one_in_tray "$tray")" || {
    _stash_status "Stash: command selection canceled"
    zle redisplay
    return 1
  }

  cmd="$(_stash_cmd_by_id "$id")" || true

  [[ -z "$cmd" ]] && {
    _stash_status "Stash: empty selection"
    zle redisplay
    return 1
  }

  BUFFER="$cmd"
  CURSOR=${#BUFFER}
  _stash_status "Inserted from tray: $tray"
  zle redisplay
}
zle -N stash-pick-widget
bindkey '^g' stash-pick-widget

# Public CLI helpers

stash-add() {
  _stash_append "$@"
}

# two-step chooser, returns only the selected ID
_stash_choose() {
  local tray id
  tray="$(_stash_choose_tray)" || return 1
  id="$(_stash_choose_one_in_tray "$tray" "$@")" || return 1
  print -r -- "$id"
}

# if called from a widget, insert into the buffer
# if called as a normal shell command, print the command
stash-pick() {
  local id cmd
  id="$(_stash_choose)" || return 1
  cmd="$(_stash_cmd_by_id "$id")"
  [[ -z "$cmd" ]] && return 1

  if zle >/dev/null 2>&1; then
    zle -U -- "$cmd"
  else
    print -r -- "$cmd"
  fi
}

stash-run() {
  local id cmd
  id="$(_stash_choose)" || return 1
  cmd="$(_stash_cmd_by_id "$id")"
  [[ -z "$cmd" ]] && return 1
  print -r -- "+ $cmd"
  eval "$cmd"
}

# Remove one or many stashed items
stash-rm() {
  local tray tmp
  local -a ids

  tray="$(_stash_choose_tray)" || return 1
  ids=("${(@f)$(_stash_choose_many_in_tray "$tray")}") || return 1
  (( ${#ids[@]} )) || return 0

  tmp="$(mktemp)" || return 1
  awk -F'\t' 'BEGIN{OFS=FS}
    NR==FNR { del[$1]=1; next }
    !($1 in del)
  ' <(printf '%s\n' "${ids[@]}") "$CMD_STASH_FILE" > "$tmp" && mv "$tmp" "$CMD_STASH_FILE"

  print -r -- "Removed ${#ids[@]} item(s) from tray: $tray."
}

# Remove ALL entries from the stash
stash-clear() {
  local file="${CMD_STASH_FILE:-$HOME/.cmd_stash}"
  [[ ! -e "$file" || ! -s "$file" ]] && {
    print -r -- "Stash is already empty."
    return 0
  }

  local count
  count=$(wc -l <"$file" | tr -d ' ')

  read -q "REPLY?Delete ALL $count stashed item(s)? [y/N] " || {
    echo
    print -r -- "Aborted."
    return 1
  }
  echo

  local __fd
  exec {__fd}>>"$file"
  command -v flock >/dev/null 2>&1 && flock -x "$__fd" || true
  : >| "$file"
  exec {__fd}>&-

  print -r -- "Cleared $count item(s)"
}

stash-list() {
  [[ ! -s "$CMD_STASH_FILE" ]] && {
    print -r -- "Stash is empty."
    return 0
  }

  awk -F'\t' '
    NF>=4 {
      cmd = substr($0, index($0,$4))
      printf "[%s] %s | %s\n", $3, $2, cmd
    }
  ' "$CMD_STASH_FILE"
}

stash-migrate-old() {
  local file="${CMD_STASH_FILE:-$HOME/.cmd_stash}"
  [[ ! -e "$file" || ! -s "$file" ]] && {
    print -r -- "Nothing to migrate."
    return 0
  }

  local tray="${CMD_STASH_TRAY:-main}"
  local tmp
  tmp="$(mktemp)"

  awk -F'\t' -v tray="$tray" 'BEGIN{OFS=FS}
    NF==3 {
      print $1, $2, tray, $3
      next
    }
    {print}
  ' "$file" > "$tmp" && mv "$tmp" "$file"

  print -r -- "Migration complete. Old entries tagged with tray: $tray"
}

alias sa='stash-add'
alias sp='stash-pick'
alias sr='stash-run'
alias srm='stash-rm'
alias sl='stash-list'
alias sclear='stash-clear'
