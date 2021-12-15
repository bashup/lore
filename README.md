# lore: bash history per project (or tmux pane)

If you work on a lot of different projects using different languages and tools, it can get pretty annoying to keep your bash history straight.  (Especially if you have something you come back to after six months and want to know what options you used before...)

Enter `lore`.  It's a simple tool that lets you use "lore files" (named `.lore` by default).  If you've sourced `lore` in your shell, then any time you enter a subdirectory with a lore file in a parent directory, your existing history will be saved to your previous history file, and the lore file will become your new history file.  As you enter commands, they're saved immediately to the lore file, so even if your shell has to be hard-killed (or your computer gets rebooted), you won't lose any history.

(You can think of it as being sort of like a "[direnv](https://direnv.net/) for bash history".)

In addition to allowing per-project lore files, `lore` will fall back to the global `.bash_history` if it doesn't find a lore file above the current directory.  Or, if you're working inside tmux, the global history file will actually be a per-pane history file (labeled by window and pane numbers), unless you disable the [tmux integration](#tmux-integration).

## Installation and Use

`lore` is implemented as a sourceable script for bash 4.4 and up.  To install it, just place the raw version of [the built script](bin/lore) in a directory on your `PATH`.  (No need to make it executable, since you'll be sourcing it, not executing it.)

(If you have basher, the fast way to do that is with `basher install bashup/lore`.  Or you can just clone this repository somewhere on your system and source the binary from there.)

Once `lore` is physically present on your system, you can install it for use in new terminal windows by adding this line to your `~/.bash_profile`:

~~~sh
source lore on
~~~

You can also just type that on the command line if you want to try it out, or just want to use it manually.

Either way, this will define the `lore` function and run `lore on` to activate history auto-saving and auto-switching.  (If you just want to define the `lore` function without activating it, you can `source lore off` instead, or `source lore --` to load lore and its completions without changing its modes or the currently-selected history file.)

bash tab completion is supported for `lore` subcommands and their arguments, though if lore is `off` and you enter a new subshell, the completions won't be active until you've used the `lore` function in the subshell at least once.

### Usage Overview

Once `lore` is activated, it will check at every command prompt to see if the current directory has changed, and if so, whether it needs to load a different local lore file or global history file.  It also saves any as-yet unwritten commands to the current lore or history file.

You can deactivate `lore` at any time using `lore off`, then reactivate with `lore on`.  (This will not change what history file you're currently using: it just disables automatic switching and automatic saving.)

If you want to keep automatic saving on, and just turn off automatic switching, you can use `lore lock`, and go back to normal using `lore unlock`.

More commonly, though, you will use `lore global` (to switch to the global history and lock it) or `lore use` (to switch to a specific history and lock it).  `lore local` can then be used to unlock and switch to whatever the nearest lore file is.

You can copy the current history to a new lore file with `lore save /some/file-or-directory`, and edit the current history with `lore edit`.

In general, lore commands targeting specific history files will accept a directory in place of a file, and automatically add `.lore` to them (or whatever `LORE_FILE` is set to.)

See the [CLI Reference](#cli-reference) and [Configuration](#configuration) sections below for more info.

## Configuration

### Lore Variables

#### Basic Settings

* `LORE_FILE` -- the filename used for lore files (defaults to `.lore`)
* `LORE_GLOBAL` -- If set, this will be the default global history file (in place of `$HOME/.bash_history`)
* `LORE_EDITOR` -- if set, this will be the command used to edit history files (instead of `$EDITOR`)

#### Tmux Integration

Lore's tmux integration is enabled by default if there is a value in `TMUX_PANE`.  When active, it overrides the global history file using the variables below:

* `LORE_DISABLE_TMUX` -- when set to a non-empty value, it disables tmux integration, forcing the global history file to always be `$LORE_GLOBAL` (if set) or `$HOME/.bash_history`.
* `LORE_TMUX_FILE` -- A `tmux display-message` format string to create the history filename from.  Defaults to `w#Ip#{pane_index}`, which will create filenames like `w3p0` for the zeroth pane of window 3.
* `LORE_TMUX_DIR` -- The directory under which the tmux history files will be stored.  Defaults to `$XDG_CONFIG_HOME/lore-tmux` or `$HOME/.lore-tmux`.

#### Miscellaneous

* `LORE_MODE` -- can be set to `auto` (to enable automatic history file switching) or `locked` (to disable it).  Automatically set by the `lore lock` and `lore unlock` commands, but you can set a default value in your profile.
* `LORE_SOURCE` -- the full path to the file `lore` was sourced from; automatically configured by `lore`, but it can be manipulated in order to extend `lore` with additional commands.  (See [Extending Lore](#extending-lore), below.)

### Bash Variables

Lore reads or writes these variables:

* `EDITOR` -- read to select an editor if `LORE_EDITOR` isn't set
* `HISTFILE` -- changed to point to the active lore file or global history file, manually or automatically
* `HOME`, `XDG_CONFIG_HOME` -- used to determine the default global history location and/or per-pane history location
* `PROMPT_COMMAND` -- altered by `lore on` and `lore off`, to enable automatic saving and switching

The behavior of Lore is also affected by most bash history settings, including `HISTSIZE`, `HISTFILESIZE`, `HISTIGNORE`, and `HISTCONTROL`, as well as the various `shopt` settings.  Lore doesn't read or write any of these settings, but they influence what gets put into the history, and thus what Lore will save to history files.  (And how those files will be truncated as they grow larger.)

#### erasedups

Note that because lore writes to history file(s) using `history -a`, a `HISTCONTROL` of `erasedups` will have no effect by default, as the duplicates will be removed from the history in memory, but not on disk.  You can force a cleanup of the disk file at any time using `lore save -f`, which will replace the current history file's contents with the in-memory history.

(Note, however that this will only erase duplicates of commands you've actually *used* in your current session, and if you've done things in other terminals sharing the same history file, you'll lose any commands entered in those other terminals unless you use `history -n` to load those new entries into your current session.)

## CLI Reference

### History File Selection

#### lore local

`lore local` selects (and loads) the local lore file, and does a `lore unlock`.   (Any pending history writes are flushed first.)  If there is no lore file in the current directory or any of its parent directories, the global history file is used.

#### lore global

`lore global` is equivalent to `lore use` *global-history-file*: i.e., it selects and loads the global history, switching the `LORE_MODE` to `locked`.  (Any pending history writes are flushed first.)

#### lore use

`lore use` *file-or-dir* selects (and loads) the specified history file, and switches the `LORE_MODE` to `locked` so it won't be immediately switched away from.  (Any pending history writes are flushed first.)

### History File Management

#### lore save

`lore save` *[dir-or-file] [`-f`]* saves a copy of the current history to *dir-or-file* (or the current history file, if only `-f` is provided).  It doesn't overwrite an existing file unless `-f` is supplied.  If no arguments are given, it just writes any unwritten history to the current history file (if any).  (i.e. a manual version of what `lore prompt` does when lore is `on`.)

(This command also resets the working directory cache, so that if lore is `on` and in `auto` mode, and the new file should be the new local history file, it will switch to it as of the next prompt.)

#### lore edit

`lore edit` opens the current history file (in `$LORE_EDITOR` or `$EDITOR`), creating it first if necessary, and saving any unwritten history to it.  If `HISTFILE` is empty, a local or global history file is selected first.  After the editor exits, a `lore reload` is performed.

#### lore dedupe

`lore dedupe` cleans the history of older duplicates of the same commands.  That is, for every line in the history, only the most recent copy of that line is kept, with earlier copies removed.

Like most lore subcommands, dedupe can be chained with other subcommands, e.g. `lore dedupe edit` to edit the history after cleaning it.

#### lore reload

`lore reload` forces a reload of the current history file, after saving any currently-unwritten history to it.  If there is no current history file, a local or global history file is selected automatically.

(Note: if a history file is already selected, this command does *not* select a different one, so if you're trying to get lore to recognize a newly-created local history file,  you should probably use `lore local` instead.)

### Administrative Commands

#### lore status

`lore status` displays some info about lore's current state: whether it's active in `PROMPT_COMMAND`, whether it is in `locked` or `auto` mode, and the current lore/history file in use.

#### lore on / off

`lore on` adds `lore prompt` to `$PROMPT_COMMAND`, so that automatic saving and switching can occur.  `lore off ` does the reverse, removing the `lore prompt` from `$PROMPT_COMMAND` to disable auto-save and auto-switching.

#### lore lock / unlock

`lore lock` sets `LORE_MODE` to `locked`, disabling auto-switching of the current history file.  `lore unlock` does the reverse, setting `LORE_MODE` to `auto` to re-enable auto-switching of the current history file (assuming lore is currently enabled via `lore on`).

#### lore prompt

`lore prompt` is run at each command prompt (assuming lore is `on`).  If `LORE_MODE` is `auto` (or empty), and the current directory has changed, it will search for the correct `.lore` file (or global history) and switch to it.  If the history file hasn't changed, the most recent command history is appended to it.

(You should not normally need to invoke this command directly; it's only exposed because test scripts need to explicitly invoke it, due to `PROMPT_COMMAND` not working in scripts.)

## Advanced Uses

### Extending Lore

You can add your own subcommands to `lore` by defining shell functions in your `.bashrc`.  For example, if you define a `lore.foo` function, then `lore foo` will call that function.

If you want to bundle such extensions in a separate file rather than including them in `.bashrc`, you can make a lore extension script like this, e.g. in `my-lore.sh`:

~~~sh
# Tell Lore to load this file if it needs commands
# (but don't override if already set)
declare -gx LORE_SOURCE=${LORE_SOURCE:-$BASH_SOURCE}

# Bootstrap Lore's core, without changing any current state
source lore --

# Define your custom commands
lore.my-command() {
    # ...
}

# Last line in the file
lore::on-load "$@"
~~~

You can then source this file as a replacement for `source lore` (e.g. `source my-lore.sh on` or `source my-lore.sh off`).

