# ---- Command Stash (zsh + fzf) ---------------------------------------------
# deps: fzf; optional: tac (coreutils). zsh's `tac` alias below covers macOS.
# file format (TSV): ID \t ISO_TIMESTAMP \t COMMAND

export CMD_STASH_FILE="${CMD_STASH_FILE:-$HOME/.cmd_stash}"
[[ -e "$CMD_STASH_FILE" ]] || : > "$CMD_STASH_FILE"

# macOS doesn't ship tac; use tail -r as a fallback
command -v tac >/dev/null 2>&1 || alias tac='tail -r'

# Generate a reasonably unique ID (epochseconds.pid.rand)
_stash_gen_id() {
  printf '%s.%s.%s' "$(date +%s)" "$$" "$RANDOM"
}
# --- utilities ---------------------------------------------------------------
# quick status message without polluting the prompt line
_stash_status() {
  # Prefer ZLE status line; fall back to echo if not in ZLE context
  if zle >/dev/null 2>&1; then
    zle -M -- "$*"
  else
    print -r -- "$*"
  fi
}

# --- stash the CURRENT command line (Ctrl-S) ---------------------------------
stash-add-buffer-widget() {
  # Compose current line safely
  local line="${LBUFFER}${RBUFFER}"

  if [[ -z "$line" ]]; then
    _stash_status "Stash: nothing to stash"
    return 0
  fi

  # Append to file (real tabs)
  local id ts
  id="$(_stash_gen_id)"
  ts="$(date +%F' '%T)"
  printf '%s\t%s\t%s\n' "$id" "$ts" "$line" >> "$CMD_STASH_FILE"

  # Clear the user’s command line so nothing remains to accidentally run
  LBUFFER=""
  RBUFFER=""
  CURSOR=0

  # Show a transient status message, then redraw the clean prompt
  _stash_status "Stashed at $ts"
  zle redisplay
}
zle -N stash-add-buffer-widget
bindkey '^s' stash-add-buffer-widget   # Ctrl-S

# --- pick from stash and insert into prompt (Ctrl-G) -------------------------
stash-pick-widget() {
  # Tell ZLE to release the terminal BEFORE launching fzf (prevents “hang/subshell” feel)
  zle -I

  # Run the chooser in normal TTY mode
  local sel id cmd
  sel="$(_stash_choose)" || { _stash_status "Stash: canceled"; zle redisplay; return 1; }
  id="${sel%%$'\t'*}"
  cmd="$(awk -F'\t' -v id="$id" '$1==id {print substr($0, index($0,$3))}' "$CMD_STASH_FILE")" || true

  # If nothing found, just restore prompt
  [[ -z "$cmd" ]] && { _stash_status "Stash: empty selection"; zle redisplay; return 1; }

  # Replace the current prompt buffer with the picked command (not executed)
  BUFFER="$cmd"
  CURSOR=${#BUFFER}
  _stash_status "Inserted from stash"
  zle redisplay
}
zle -N stash-pick-widget
bindkey '^g' stash-pick-widget         # Ctrl-G
# Core: append one command line to stash file
_stash_append() {
  local line="$*"
  [[ -z "$line" ]] && { print -r -- "Nothing to stash."; return 1; }
  local id ts
  id="$(_stash_gen_id)"
  ts="$(date +%F' '%T)"
  printf '%s\t%s\t%s\n' "$id" "$ts" "$line" >> "$CMD_STASH_FILE"
  print -r -- "Stashed: [$ts] $line"
}

# Public: stash ad-hoc text you pass as args
# usage: sa "psql --csv -f get_device_log.sql"
stash-add() {
  _stash_append "$@"
}


# FZF chooser (latest first). Shows "timestamp | command"
_stash_choose() {
  tac "$CMD_STASH_FILE" 2>/dev/null \
    | awk -F'\t' 'NF>=3 {print $1 "\t" $2 " | " substr($0, index($0,$3))}' \
    | fzf +m --prompt='stash> ' --no-sort --tac --with-nth=2..   # +m == --no-multi
}

# Insert picked command into the prompt (editable; not executed)
stash-pick() {
  local sel id cmd
  sel="$(_stash_choose)" || return 1
  id="${sel%%$'\t'*}"
  cmd="$(awk -F'\t' -v id="$id" '$1==id {print substr($0, index($0,$3))}' "$CMD_STASH_FILE")"
  [[ -n "$cmd" ]] && zle -U -- "$cmd"
}

# Pick and run immediately
stash-run() {
  local sel id cmd
  sel="$(_stash_choose)" || return 1
  id="${sel%%$'\t'*}"
  cmd="$(awk -F'\t' -v id="$id" '$1==id {print substr($0, index($0,$3))}' "$CMD_STASH_FILE")"
  [[ -z "$cmd" ]] && return 1
  print -r -- "+ $cmd"
  eval "$cmd"
}

# Remove one or many stashed items (multi-select)
stash-rm() {
  local selections ids tmp
  selections="$(_stash_choose --multi)" || return 1
  ids="$(print -r -- "$selections" | awk -F'\t' '{print $1}')"
  [[ -z "$ids" ]] && return 0

  tmp="$(mktemp)"
  awk -F'\t' 'BEGIN{OFS=FS}
    NR==FNR {del[$1]=1; next}
    !($1 in del)
  ' <(print -r -- "$ids") "$CMD_STASH_FILE" > "$tmp" && mv "$tmp" "$CMD_STASH_FILE"
  print -r -- "Removed $(print -r -- "$ids" | wc -l | tr -d ' ') item(s) from stash."
}

# Remove ALL entries from the stash (with confirmation and backup)
stash-clear() {
  local file="${CMD_STASH_FILE:-$HOME/.cmd_stash}"
  [[ ! -e "$file" || ! -s "$file" ]] && { print -r -- "Stash is already empty."; return 0; }

  local count; count=$(wc -l <"$file" | tr -d ' ')
  # Confirm (press 'y' to proceed)
  read -q "REPLY?Delete ALL $count stashed item(s)? [y/N] " || { echo; print -r -- "Aborted."; return 1; }
  echo

  # Optional: backup before clearing
  local bak="${file}.bak.$(date +%Y%m%d-%H%M%S)"
  cp -p -- "$file" "$bak" 2>/dev/null || cp -- "$file" "$bak" 2>/dev/null || true

  # Atomically truncate with a lock (prevents races)
  {
    exec {__fd}>>"$file"
    command -v flock >/dev/null 2>&1 && flock -x "$__fd" || true
    : >| "$file"
  }

  print -r -- "Cleared $count item(s). Backup: $bak"
}

# List stash (human-readable)
stash-list() {
  awk -F'\t' 'NF>=3 {printf "%s | %s\n", $2, substr($0, index($0,$3))}' "$CMD_STASH_FILE"
}

# Friendly aliases (optional)
alias sa='stash-add'   # sa "command here"
alias sp='stash-pick'  # Ctrl-G does the same
alias sr='stash-run'
alias srm='stash-rm'
alias sl='stash-list'
alias sclear='stash-clear' # clear the stash list
# ---------------------------------------------------------------------------
