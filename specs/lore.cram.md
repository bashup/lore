## Setup and Mocks

For testing purposes, we will replace the history built-in with a function so we can see what history commands lore invokes:

~~~sh
    $ history() {
    >     local HISTFILE=${HISTFILE-}
    >     dumpargs "HISTFILE=${HISTFILE/#$TEST_ROOT//TEST}" "history" "$@"
    > }

    $ history -a
    HISTFILE= history -a
~~~

We'll also `set -u` so we can make sure lore explicitly defines how it will handle missing values.

~~~sh
    $ set -u
~~~

## CLI Tests

### Startup

Lore displays an error and exits if it's not sourced:

~~~sh
    $ bash "$BASHER_INSTALL_BIN/lore"
    lore must be sourced into your shell before use; try 'source */lore' first (glob)
    [64]
~~~

But if you source it, the `lore` function will be available, both in the current shell and in any subshells:

~~~sh
    $ (source lore; type -t lore)
    function

    $ (source lore; bash -c 'type -t lore')
    function
~~~

And it also accepts subcommands when sourced:

~~~sh
    $ (source lore status)
    lore is off, in 'auto' mode; HISTFILE=''
~~~

And when run in a subshell relative to where it's sourced, it'll automatically source itself again:

~~~sh
    $ source lore

    $ bash -c 'lore status'
    lore is off, in 'auto' mode; HISTFILE=''
~~~

### Status Manipulation

#### lore on

Turning lore on puts `lore prompt` at the start of the prompt command, without duplication:

~~~sh
    $ lore on
    $ lore status
    lore is ON, in 'auto' mode; HISTFILE=''

    $ declare -p PROMPT_COMMAND
    declare -x PROMPT_COMMAND="{ lore prompt;};"

    $ PROMPT_COMMAND="echo test 1;$PROMPT_COMMAND"
    $ lore on
    $ declare -p PROMPT_COMMAND
    declare -x PROMPT_COMMAND="{ lore prompt;};echo test 1;"

    $ PROMPT_COMMAND="echo test 2;$PROMPT_COMMAND"
    $ lore on
    $ declare -p PROMPT_COMMAND
    declare -x PROMPT_COMMAND="{ lore prompt;};echo test 2;echo test 1;"

    $ lore status
    lore is ON, in 'auto' mode; HISTFILE=''
~~~

#### lore off

Turning lore off removes the `lore prompt`:

~~~sh
    $ PROMPT_COMMAND="echo test 3;$PROMPT_COMMAND"

    $ lore off
    $ lore status
    lore is off, in 'auto' mode; HISTFILE=''

    $ declare -p PROMPT_COMMAND
    declare -x PROMPT_COMMAND="echo test 3;echo test 2;echo test 1;"

    $ unset PROMPT_COMMAND
~~~

#### lore lock/unlock

`lore lock` sets `LORE_MODE` to `locked`, disabling auto-switching of the current history file.

`lore unlock` sets `LORE_MODE` to `auto`, enabling auto-switching of the current history file (if lore is currently enabled via `lore on`).

~~~sh
    $ lore status
    lore is off, in 'auto' mode; HISTFILE=''

# Basic lock/unlock
    $ lore lock; lore status
    lore is off, in 'locked' mode; HISTFILE=''

    $ lore unlock; lore status
    lore is off, in 'auto' mode; HISTFILE=''

# With messages (in 'lore on' mode)
    $ lore on

    $ lore lock; lore status
    lore: disabling autoselect; use 'lore unlock' to re-enable
    lore is ON, in 'locked' mode; HISTFILE=''

    $ lore lock  # no-op if already locked

    $ lore unlock; lore status
    lore: re-entering autoselect mode
    lore is ON, in 'auto' mode; HISTFILE=''

    $ lore unlock  # no-op if already unlocked
    $ lore off
~~~

#### lore prompt

`lore prompt` is run at each command prompt (assuming lore is `on`).  If `LORE_MODE` is `auto` (or empty), and the current directory has changed, it will search for the correct `.lore` file (or global history) and switch to it.  If the history file hasn't changed, the most recent command history is appended to it.

~~~sh
# Initial run: no "last directory", so load from .lore
    $ touch .lore
    $ lore prompt   # will save first, since no last dir
    HISTFILE= history -a
    HISTFILE= history -c
    lore: loading history from .lore
    HISTFILE=/TEST/.lore history -r
    HISTFILE=/TEST/.lore history -a

# Subsequent run: last directory is PWD, so just save most recent command(s)
    $ lore prompt
    HISTFILE=/TEST/.lore history -a

# Subdirectory: no change in .lore path, so just append again:
    $ LORE_GLOBAL=$PWD/.lore
    $ mkdir x
    $ cd x
    $ lore prompt
    HISTFILE=/TEST/.lore history -a

# Subdirectory w/change in .lore path
    $ mkdir y; touch .lore
    $ cd y
    $ lore prompt  # cd will be saved because it's the global dir
    HISTFILE=/TEST/.lore history -a
    HISTFILE=/TEST/.lore history -c
    lore: loading history from ~/x/.lore
    HISTFILE=/TEST/x/.lore history -r
    HISTFILE=/TEST/x/.lore history -a

# Subdir change again, but locked this time
    $ cd ../..
    $ lore lock
    $ lore prompt
    HISTFILE=/TEST/x/.lore history -a

# Now unlock
    $ lore unlock
    $ lore prompt
    HISTFILE=/TEST/x/.lore history -c
    lore: loading history from .lore
    HISTFILE=/TEST/.lore history -r
    HISTFILE=/TEST/.lore history -a

# And change dirs, but without a global match
    $ unset LORE_GLOBAL
    $ cd x/y
    $ lore prompt
    HISTFILE=/TEST/.lore history -c
    lore: loading history from ~/x/.lore
    HISTFILE=/TEST/x/.lore history -r
    HISTFILE=/TEST/x/.lore history -a
~~~

#### lore use

`lore use` *file-or-dir* selects (and loads) the specified history file, and switches the `LORE_MODE` to `locked` so it won't be immediately switched away from.  (Any pending history writes are flushed first.)

~~~sh
    $ lore use .
    HISTFILE=/TEST/x/.lore history -a
    HISTFILE=/TEST/x/.lore history -c
    lore: loading history from .lore
    HISTFILE=/TEST/x/y/.lore history -r

    $ lore status
    lore is off, in 'locked' mode; HISTFILE=.lore

    $ lore unlock
~~~

#### lore global

`lore global` is equivalent to `lore use` *global-history-file*: i.e., it selects and loads the global history, switching the `LORE_MODE` to `locked`.  (Any pending history writes are flushed first.)

~~~sh
    $ lore global
    HISTFILE=/TEST/x/y/.lore history -a
    HISTFILE=/TEST/x/y/.lore history -c
    lore: loading history from ~/.bash_history
    HISTFILE=/TEST/.bash_history history -r

    $ lore status
    lore is off, in 'locked' mode; HISTFILE=~/.bash_history
~~~

#### lore local

`lore local` selects (and loads) the local history file, and switches the `LORE_MODE` to `auto`.  (Any pending history writes are flushed first.)

~~~sh
    $ lore local
    HISTFILE=/TEST/.bash_history history -a
    HISTFILE=/TEST/.bash_history history -c
    lore: loading history from ~/x/.lore
    HISTFILE=/TEST/x/.lore history -r

    $ lore status
    lore is off, in 'auto' mode; HISTFILE=~/x/.lore
~~~

#### Cleanup

~~~sh
    $ cd ../..
    $ rm x/.lore
    $ rmdir x/y x
~~~

## Internal Tests

### Path Manipulation

As we'll be using relative paths a lot, we'll use a wrapper to convert absolute paths to relative ones.

~~~sh
    $ show-path() { "$@"; echo "${REPLY/#$PWD/.}"; }
~~~

#### `lore::abspath`

`lore::abspath` takes the absolute form of its given argument (normalizing `.` and `..` path parts), and returns it in `$REPLY`.

~~~sh
# Relative path from current directory
    $ show-path lore::abspath xyz/../././abc/../q
    ./q

# Absolute path to directory
    $ show-path lore::abspath /foo/./././bar/../baz
    /foo/baz

~~~

#### `lore::to-file`

`lore::to-file` takes the absolute form of its given argument (normalizing `.` and `..` path parts), and if the result is a directory, it adds `$LORE_FILE` or `.lore` to it.  The result is returned in `$REPLY`:

~~~sh
# Relative path to current directory
    $ show-path lore::to-file .
    ./.lore

# Absolute path to directory
    $ show-path lore::to-file /
    /.lore

# Relative path to non-directory
    $ show-path lore::to-file ./xyz
    ./xyz

# Alternate LORE_FILE
    $ LORE_FILE=foo show-path lore::to-file .
    ./foo
~~~

#### `lore::find-global`

`lore::find-global` returns (in `REPLY`) the global history file.  It's either `$LORE_GLOBAL` or `$HOME/.bash_history`, unless tmux is in use (i.e. `$TMUX_PANE` is set and `$LORE_DISABLE_TMUX` isn't).

~~~sh
    $ LORE_GLOBAL=/foo/bar show-path lore::find-global
    /foo/bar

    $ HOME=/home/lore-demo show-path lore::find-global
    /home/lore-demo/.bash_history
~~~

If tmux is in use and enabled, a dynamic global history filename is generated under `$LORE_TMUX_DIR` using `$LORE_TMUX_FILE` as a pattern.  `$LORE_TMUX_DIR` defaults to `$XDG_CONFIG_HOME/lore-tmux` or `$HOME/.lore-tmux`, and `$LORE_TMUX_FILE` defaults to `w#lp#{pane_index}`, which will create files like `w3p0` (for window 3, pane 0).  Any necessary parent directories are created automatically.

~~~sh
# Mock tmux environment
    $ TMUX_PANE=%36
    $ tmux_out=w6p1
    $ tmux() { dumpargs "tmux" "$@"; echo "$tmux_out"; }

# Default to HOME/.lore-tmux/w#lp#{pane_index}
    $ HOME=./lore-demo
    $ show-path lore::find-global
    tmux display-message -pt %36 w#Ip#\{pane_index\}
    ./lore-demo/.lore-tmux/w6p1

# Unless LORE_DISABLE_TMUX is set
    $ LORE_DISABLE_TMUX=1 show-path lore::find-global
    ./lore-demo/.bash_history

# Use XDG_CONFIG_HOME if available
    $ XDG_CONFIG_HOME=./lore-demo/config
    $ show-path lore::find-global
    ./lore-demo/config/lore-tmux/w6p1

# Use LORE_TMUX_DIR if available
    $ LORE_TMUX_DIR=./lore-tmux-files
    $ show-path lore::find-global
    ./lore-tmux-files/w6p1

# Use LORE_TMUX_FILE pattern if available
    $ LORE_TMUX_FILE="pane-number-#{pane_index}-of-window-#I.history"
    $ tmux_out="pane-number-1-of-window-6.history"
    $ show-path lore::find-global
    tmux display-message -pt %36 pane-number-#\{pane_index\}-of-window-#I.history
    ./lore-tmux-files/pane-number-1-of-window-6.history

# Directories get created to hold the tmux files
    $ ls -p
    lore-demo/
    lore-tmux-files/

    $ ls -p lore-demo/config
    lore-tmux/

# Go back to default, but leave $HOME and directories available for find-local tests
    $ unset TMUX_PANE
~~~

#### `lore::find-local`

`lore::find-local` looks "upward" from a path until a `$LORE_FILE` is found, returning its path in `REPLY`.  If no file is found, the result of `lore::find-global` is returned instead.

~~~sh
# Root directory should fall back to global
    $ show-path lore::find-local /
    ./lore-demo/.bash_history

# Local dir
    $ touch .lore
    $ show-path lore::find-local .
    ./.lore

# Search dir defaults to $PWD
    $ show-path lore::find-local
    ./.lore

# Finds nearest file
    $ show-path lore::find-local lore-demo/config/lore-tmux
    ./.lore

# Using LORE_FILE
    $ LORE_FILE=.testme
    $ touch lore-demo/.testme

    $ show-path lore::find-local lore-demo/config/lore-tmux
    ./lore-demo/.testme

    $ show-path lore::find-local lore-demo/config
    ./lore-demo/.testme

    $ show-path lore::find-local lore-demo
    ./lore-demo/.testme

~~~

