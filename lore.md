## Lore - Local Bash History

```shell @mdsh
@module lore.md
@require pjeby/license @comment LICENSE
```

### The Lore Command

The `lore` command is an exported function, so it can be shared by subshells.  The functions it uses, however, have non-exportable names, so it automatically re-sources itself if it is used in a subshell where it hasn't been sourced before.

Subcommands are looked for as `lore.X` where `X` is the name of the command;  if no subcommand is given (or it's `-h` or `--help`), the `help` command is selected.  The `--` subcommand is used internally to optionally chain subcommands.

```shell
declare -gx LORE_SOURCE="${LORE_SOURCE:-$BASH_SOURCE}"
lore() {
	local REPLY; declare -F lore::on-load &>/dev/null || source "$LORE_SOURCE" --
	(($#)) || set -- help;
	! declare -F lore."$1" &>/dev/null || { lore."$@"; return; }
	case $1 in
	--) shift; ((!$#)) || lore "$@";;  # no-op if no subsequent args
	-h|--help) lore help ;;
	*) return 64  # XXX alias lookup, error handling
	;;
	esac
}
export -f lore
```

#### lore status

`lore status` displays some info about lore's current state: whether it's active in `PROMPT_COMMAND`, whether it is in `locked` or `auto` mode, and the current lore/history file in use.

```shell
lore.status() {
	local REPLY is_on=ON; lore::enabled || is_on=off;
	lore::format-histfile
	printf "lore is %s, in '%s' mode; HISTFILE=%s\\n" "$is_on" "${LORE_MODE-auto}" "${REPLY}" >&2
	lore -- "$@"
}

lore::enabled() { [[ ${PROMPT_COMMAND-} == *'lore prompt;'* ]]; }

lore::format-histfile() { #set -x
	REPLY=${HISTFILE-}; REPLY=${REPLY/#$PWD\//}
	[[ ! ${HOME-} ]] || REPLY=${REPLY/#$HOME\//'~'/}
	REPLY="${REPLY:-''}"
}
```

#### lore help (TODO)

### History File Selection

#### lore local

`lore local` selects (and loads) the local history file, and switches the `LORE_MODE` to `auto`.  (Any pending history writes are flushed first.)

```shell
lore.local() { history -a; lore::find-local; lore::select "$REPLY"; lore unlock "$@"; }
```

#### lore global

`lore global` is equivalent to `lore use` *global-history-file*: i.e., it selects and loads the global history, switching the `LORE_MODE` to `locked`.  (Any pending history writes are flushed first.)

```shell
lore.global() { lore::find-global; lore use "$REPLY" "$@"; }
```

#### lore use

`lore use` *file-or-dir* selects (and loads) the specified history file, and switches the `LORE_MODE` to `locked` so it won't be immediately switched away from.  (Any pending history writes are flushed first.)

```shell
lore.use() { history -a; lore::select "${1-$PWD}"; lore lock "${@:2}"; }

lore::complete.use() {
	if (($#>1)); then lore::complete "${@:2}"; else mapfile -t COMPREPLY < <(compgen -fd "$1"); fi
}
```

### Live History Saving and File-Swapping

While `lore` commands can be manually used to switch between history files, and `history` used to save the history, it's generally more useful to have these things done automatically.  `lore on` and `lore off` toggle lore's automatic history saving, and `lore unlock` and `lore lock` toggle lore's automatic local history file selection.

#### lore on

`lore on` adds `lore prompt` to `$PROMPT_COMMAND`, so that automatic saving and switching can occur.

```shell
lore.on() {	lore off; declare -gx PROMPT_COMMAND="{ lore prompt;};${PROMPT_COMMAND-}"; lore -- "$@"; }
```

#### lore off

`lore off ` removes the `lore prompt` from `$PROMPT_COMMAND`, disabling auto-save and auto-switching.

```shell
lore.off() {
	! lore::enabled || declare -gx PROMPT_COMMAND=${PROMPT_COMMAND//\{ lore prompt;\};/}
	lore -- "$@"
}
```

#### lore lock

`lore lock` sets `LORE_MODE` to `locked`, disabling auto-switching of the current history file.

```shell
lore.lock() { lore::set-mode locked "disabling autoselect; use 'lore unlock' to re-enable" "$@"; }

lore::set-mode() {
	if [[ ${LORE_MODE-auto} != "$1" ]]; then
		declare -gx LORE_MODE="$1"; ! lore::enabled || echo "lore: $2" >&2
	fi
	lore -- "${@:3}"
}
```

#### lore unlock

`lore unlock` sets `LORE_MODE` to `auto`, enabling auto-switching of the current history file (if lore is currently enabled via `lore on`).

```shell
lore.unlock() { lore::set-mode auto "re-entering autoselect mode" "$@"; }
```

#### lore prompt

`lore prompt` is run at each command prompt (assuming lore is `on`).  If `LORE_MODE` is `auto` (or empty), and the current directory has changed, it will search for the correct `.lore` file (or global history) and switch to it.  If the history file hasn't changed, the most recent command history is appended to it.

```shell
# Cache the last working directory so we don't search for the file
# on every single prompt
declare -g __lore_pwd=

lore.prompt() {
	if [[ ${LORE_MODE-auto} == auto && $PWD != "$__lore_pwd" ]]; then
		# Current directory changed; check for new history file
		[[ $__lore_pwd ]] || history -a
		declare -g __lore_pwd=$PWD
		if lore::find-local; [[ $REPLY != "${HISTFILE-}" ]]; then
			set -- "$REPLY"	"$@" # Save the new history file's name
			if lore::find-global; [[ $REPLY == "${HISTFILE-}" ]]; then
				history -a   # Only save directory-changing commands to global history
			fi
			lore::select "$1"	# Load the new history file
			shift
		fi
	fi
	history -a   # save last command(s)
	lore -- "$@"
}
```

### History File Management

#### lore save

`lore save` *[dir-or-file] [`-f`]* saves a copy of the current history to *dir-or-file* (or the current history file, if only `-f` is provided).  It doesn't overwrite an existing file unless `-f` is supplied.  If no arguments are given, it just writes any unwritten history to the current history file (if any).  (i.e. a manual version of what `lore prompt` does when lore is `on`.)

(This command also resets the working directory cache, so that if lore is `on` and in `auto` mode and the file should be the new local history file, it will switch to it as of the next prompt.)

```shell
lore.save() {
	history -a  # save current history to current file
	if (($#)); then
		case $1 in -f) set -- "${2-$HISTFILE}" "$1" ;; esac
		lore::to-file "$1"
		if [[ -f "$REPLY" && ${2-} != "-f" ]]; then
			echo "lore: $REPLY already exists; use 'lore save $1 -f' to overwrite" >&2
			return 73  # EX_CANTCREAT
		else
			history -w "$REPLY"
			[[ $HISTFILE == "$REPLY" ]] || declare -g __lore_pwd=
		fi
	fi
}
lore::complete.save() {
	if (($#==2)); then COMPREPLY=(-f); else mapfile -t COMPREPLY < <(compgen -fd "$1"); fi
}
```

#### lore edit

`lore edit` opens the current history file (in `$LORE_EDITOR` or `$EDITOR`), creating it first if necessary, and saving any unwritten history to it.  If `HISTFILE` is empty, a local or global history file is selected first.  After the editor exits, a `lore reload` is performed.

```shell
lore.edit() {
	lore::ensure-editable
	"${LORE_EDITOR:-${EDITOR:-lore::no-editor}}" "$REPLY"
	lore reload "$@"
}

lore::ensure-editable() {
	# ensure history exists and saved and filename in REPLY
	lore::current-history
	[[ -f "$REPLY" ]] || touch "$REPLY"
	history -a  # save any unwritten history
}

lore::no-editor() { echo "No LORE_EDITOR or EDITOR set; file '$1' unchanged" >&2; }
lore::current-history() { REPLY=${HISTFILE-}; [[ $REPLY ]] || lore::find-local; }
```

#### lore dedupe

`lore dedupe` cleans the history of older duplicates of the same commands.  That is, for every line in the history, only the most recent copy of that line is kept, with earlier copies removed.

```shell
lore.dedupe() {
	lore::ensure-editable
	local -A seen; local -a lines; local -i i; local line
	mapfile lines <"$REPLY"
	#set -x
	for ((i=${#lines[@]}-1; i>=0; i--)); do
		line=${lines[$i]}
		if [[ ${seen[$line]+x} ]]; then
			unset lines[$i]
		else seen[$line]=y
		fi
	done
	printf %s "${lines[@]}" >|"$REPLY";
	lore reload "$@"
}
```

#### lore reload

`lore reload` forces a reload of the current history file, after saving any currently-unwritten history to it.  If there is no current history file, a local or global history file is selected automatically.

(Note: if a history file is already selected, this command does *not* select a different one, so if you're trying to get lore to recognize a newly-created local history file,  you should probably use `lore local` instead.)

```shell
lore.reload() {
	history -a  # save current history to current file
	lore::current-history
	declare -g HISTFILE=
	lore::select "$REPLY"
	lore -- "$@"
}
```

### Lore Files

#### lore::select

`lore::select` *file-or-dir* updates `HISTFILE` to match *file-or-dir*.  If the result changes `HISTFILE`, the current history is cleared and then reloaded from the new file, with a message printed to stderr about it.  (Note that in most cases this means you should `history -a` before calling this function, to ensure no history is lost.)

```shell
lore::select() {
	lore::abspath "$1"; lore::to-file "$REPLY"
	if [[ $REPLY != "${HISTFILE-}" ]]; then
		# Clear current history and load the new one
		history -c
		declare -gx HISTFILE=$REPLY; lore::format-histfile
		echo "lore: loading history from $REPLY" >&2
		history -r
	fi
}
```

#### lore::find-global

`lore::find-global` returns (in `REPLY`) the global history file.  It's either `$LORE_GLOBAL` or `$HOME/.bash_history`, unless tmux is in use (i.e. `$TMUX_PANE` is set and `$LORE_DISABLE_TMUX` isn't).  If tmux is in use and enabled, a dynamic global history filename is generated under `$LORE_TMUX_DIR` using `$LORE_TMUX_FILE` as a pattern.  `$LORE_TMUX_DIR` defaults to `$XDG_CONFIG_HOME/lore-tmux` or `$HOME/.lore-tmux`, and `$LORE_TMUX_FILE` defaults to `w#lp#{pane_index}`, which will create files like `w3p0` (for window 3, pane 0).

```shell
declare -g __lore_tmux_cache=("" "" "")

lore::find-global() {
	REPLY=${LORE_GLOBAL:-$HOME/.bash_history};
	[[ ${TMUX_PANE-} && ! ${LORE_DISABLE_TMUX-} ]] || return 0
	[[ ${LORE_TMUX_FILE-} ]] || local LORE_TMUX_FILE="w#Ip#{pane_index}"
	[[ ${LORE_TMUX_DIR-} ]] || {
		local LORE_TMUX_DIR=$HOME/.lore-tmux
		[[ ! ${XDG_CONFIG_HOME-} ]] || LORE_TMUX_DIR=$XDG_CONFIG_HOME/lore-tmux
	}
	[[ -d "$LORE_TMUX_DIR" ]] || mkdir -p "$LORE_TMUX_DIR"
	set -- "${__lore_tmux_cache[@]}" . . .
	if [[ $TMUX_PANE != "$1" || $LORE_TMUX_FILE != "$2" ]]; then
		set -- "$TMUX_PANE" "$LORE_TMUX_FILE" \
			"$(tmux display-message -pt "$TMUX_PANE" "$LORE_TMUX_FILE")"
		__lore_tmux_cache=("$@")
	fi
	REPLY="${LORE_TMUX_DIR}/$3"
}
```

#### lore::find-local

`lore::find-local` looks "upward" from a path until a `$LORE_FILE` is found, returning its path in `REPLY`.  If no file is found, the result of `lore::find-global` is returned instead.

```shell
lore::find-local() {
	lore::abspath "${1-$PWD}"; set -- "$REPLY"
	while true; do
		# Search up to find nearest local history file
		REPLY=${1%/}/${LORE_FILE-.lore}; [[ ! -f "$REPLY" ]] || return 0;
		# Any parent directories left?  If not, go global
		if ! [[ $1 =~ /+[^/]+/*$ ]]; then lore::find-global; return; fi
		# Strip one directory name and continue
		set -- "${1%${BASH_REMATCH[0]}}"; set -- "${1:-/}";
	done
}
```

#### lore::abspath

`lore::abspath` takes the absolute form of its given argument (normalizing `.` and `..` path parts), and returns it in `$REPLY`.

```shell
lore::abspath() {
	[[ $1 == /* ]] || set -- "${PWD%/}/$1/"
	while [[ $1 = */./* ]]; do set --  "${1//\/.\//\/}"; done
	while [[ $1 =~ ([^/][^/]*/\.\.(/|$)) ]]; do set -- "${1/${BASH_REMATCH[0]}/}"; done
	while [[ $1 == */ && $1 != // && $1 != / ]]; do set -- "${1%/}"; done
	REPLY=$1
}
```

#### lore::to-file

`lore::to-file` adds `$LORE_FILE` or `.lore` to its argument, if it's a directory.  The result is returned in `$REPLY`.

```shell
lore::to-file() { REPLY=$1; [[ ! -d $REPLY ]] || REPLY=${REPLY%/}/${LORE_FILE-.lore}; }
```

### Command Completion

```shell
lore::complete() {
	while (($#>1)); do
		if declare -F lore::complete."$1" &>/dev/null; then
			lore::complete."$@"; return
		fi
		shift
	done
	mapfile -t COMPREPLY < <(compgen -A function lore."${1-}")
	COMPREPLY=("${COMPREPLY[@]#lore.}")
}
lore::_complete() { COMPREPLY=(); lore::complete "${COMP_WORDS[@]:0:COMP_CWORD+1}"; }
complete -F lore::_complete lore
```

### Bootstrapping

Lore is loaded by sourcing; it's not directly executable, as it needs to be able to manipulate shell variables.  It does, however, support command line arguments when sourced.

```shell
lore::on-load() {
	if [[ ${BASH_SOURCE[1]} == "$0" ]]; then
		printf "lore must be sourced into your shell before use; try 'source %q' first\\n" "$0" >&2
		exit 64 # EX_USAGE
	fi
	if (($#)); then lore "$@"; fi
}

lore::on-load "$@"
```
