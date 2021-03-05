## Lore - Local Bash History

```shell @mdsh
@module lore.md
@require pjeby/license @comment LICENSE
```

### The Lore Command

The `lore` command is an exported function, so it can be shared by subshells.  The functions it uses, however, have non-exportable names, so it automatically re-sources itself if it is used in a subshell where it hasn't been sourced before.

Subcommands are looked for as `lore.X` where `X` is the name of the command;  if no subcommand is given (or it's `-h` or `--help`), the `help` command is selected.  The `--` subcommand is used internally to optionally chain subcommands.

```shell
export LORE_SOURCE="${LORE_SOURCE-$BASH_SOURCE}"
lore() {
	local REPLY; declare -F lore::loaded &>/dev/null || source "$LORE_SOURCE" --
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

```shell
lore.status() {
	local is_on=ON; [[ ${PROMPT_COMMAND-} == *'lore prompt;'* ]] || is_on=off;
	printf "lore is %s, in '%s' mode; HISTFILE=%q\\n" "$is_on" "${LORE_MODE-auto}" "${HISTFILE-}"
}
```

#### lore help

### History File Selection

#### lore local

#### lore global

#### lore use

### Live History Saving and File-Swapping

While `lore` commands can be manually used to switch between history files, and `history` used to save the history, it's generally more useful to have these things done automatically.  `lore on` and `lore off` toggle lore's automatic history saving, and `lore unlock` and `lore lock` toggle lore's automatic local history file selection.

#### lore on

`lore on` adds `lore prompt` to `$PROMPT_COMMAND`, so that automatic saving and switching can occur.

```shell
lore.on() {	lore off; declare -gx PROMPT_COMMAND="{ lore prompt;};${PROMPT_COMMAND-}"; }
```

#### lore off

`lore off ` removes the `lore prompt` from `$PROMPT_COMMAND`, disabling auto-save and auto-switching.

```shell
lore.off() {
	[[ ! ${PROMPT_COMMAND-} ]] || declare -gx PROMPT_COMMAND=${PROMPT_COMMAND//\{ lore prompt;\};/}
}
```

#### lore lock

`lore lock` sets `LORE_MODE` to `fixed`, disabling auto-switching of the current history file.

#### lore unlock

`lore unlock` sets `LORE_MODE` to `auto`, enabling auto-switching of the current history file (if lore is currently enabled via `lore on`).

#### lore prompt

`lore prompt` is run at each command prompt (assuming lore is `on`).  If `LORE_MODE` is `auto` (or empty), and the current directory has changed, it will search for the correct `.lore` file (or global history) and switch to it.  If the history file hasn't changed, the most recent command history is appended to it.

```shell
# Cache the last working directory so we don't search for the file
# on every single prompt
declare -g __lore_pwd=

lore.prompt() {
	# Record current history and select local history file if needed
	if [[ ${LORE_MODE-auto} == auto && $PWD != "$__lore_pwd" ]]; then
		if lore::find-local; [[ $REPLY != "${HISTFILE-}" ]]; then
			# Switch files, but don't save the command that did the switching
			lore::select "$REPLY"
			return
		fi
		declare -g __lore_pwd=$PWD
	fi
	history -a   # save last command(s)
}
```

### History File Management

#### lore save

#### lore edit

#### lore reload

### Lore Files

#### lore::select

```shell
lore::select() {
	lore::abspath "$1"; lore::to-file "$REPLY"
	if [[ $REPLY != "${HISTFILE-}" ]]; then
		# Clear current history and load the new one
		history -c; declare -g HISTFILE=$REPLY; history -r
	fi
}
```


#### lore::find-global

`lore::find-global` returns (in `REPLY`) the global history file.  It's either `$LORE_GLOBAL` or `$HOME/.bash_history`, unless tmux is in use (i.e. `$TMUX_PANE` is set and `$LORE_DISABLE_TMUX` isn't).  If tmux is in use and enabled, a dynamic global history filename is generated under `$LORE_TMUX_DIR` using `$LORE_TMUX_FILE` as a pattern.  `$LORE_TMUX_DIR` defaults to `$XDG_CONFIG_HOME/lore-tmux` or `$HOME/.lore-tmux`, and `$LORE_TMUX_FILE` defaults to `w#lp#{pane_index}`, which will create files like `w3p0` (for window 3, pane 0).

```shell
lore::find-global() {
	REPLY=${LORE_GLOBAL:-$HOME/.bash_history};
	[[ ${TMUX_PANE-} && ! ${LORE_DISABLE_TMUX-} ]] || return 0
	[[ ${LORE_TMUX_FILE-} ]] || local LORE_TMUX_FILE="w#Ip#{pane_index}"
	[[ ${LORE_TMUX_DIR-} ]] || {
		local LORE_TMUX_DIR=$HOME/.lore-tmux
		[[ ! ${XDG_CONFIG_HOME-} ]] || LORE_TMUX_DIR=$XDG_CONFIG_HOME/lore-tmux
	}
	[[ -d "$LORE_TMUX_DIR" ]] || mkdir -p "$LORE_TMUX_DIR"
	REPLY="${LORE_TMUX_DIR}/$(tmux display-message -pt "$TMUX_PANE" "$LORE_TMUX_FILE")"
}
```

#### lore::find-local

`lore::find-local` looks "upward" from a path until a `$LORE_FILE` is found, returning its path in `REPLY`.  If no file is found, the result of `lore::find-global` is returned instead.

```shell
lore::find-local() {
	lore::abspath "${1-$PWD}"; set -- "$REPLY"
	while true; do
		# Search up to find nearest local history file
		lore::to-file "$1"; [[ ! -f "$REPLY" ]] || return 0;
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

## Bootstrapping

Now that all the commands and other functions have been defined, we can define another function to indicate that lore is fully loaded:

```shell
lore::loaded() { :; }
```

Lore is loaded by sourcing; it's not directly executable, as it needs to be able to manipulate shell variables.

```shell
[[ $BASH_SOURCE != "$0" ]] || {
	printf "lore must be sourced into your shell before use; try 'source %q' first\\n" "$0" >&2
	exit 64 # EX_USAGE
}
```

It does, however, support command line arguments when sourced:

```shell
((!$#)) || lore "$@"
```

