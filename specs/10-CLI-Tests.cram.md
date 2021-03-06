## Setup and Mocks

For testing purposes, we will replace the history built-in with a function so we can see what history commands lore invokes, with what values of `HISTFILE`:

~~~sh
# Track the value of HISTFILE so we can log changes
    $ __last_history=xxx

    $ history() {
    >     local HISTFILE=${HISTFILE-}
    >     [[ $__last_history == "$HISTFILE" ]] || dumpargs "HISTFILE=${HISTFILE/#$TEST_ROOT//TEST}"
    >     __last_history=$HISTFILE
    >     dumpargs "history" "$@"
    >     # -a and -w should create the file if it doesn't exist:
    >     case $1 in -a|-w) set -- "${2-$HISTFILE}"; ${1:+touch "$1"};; esac
    > }

# It should work like this:
    $ history -a
    HISTFILE=
    history -a
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
    history -a
    history -c
    lore: loading history from .lore
    HISTFILE=/TEST/.lore
    history -r
    history -a

# Subsequent run: last directory is PWD, so just save most recent command(s)
    $ lore prompt
    history -a

# Subdirectory: no change in .lore path, so just append again:
    $ LORE_GLOBAL=$PWD/.lore
    $ mkdir x
    $ cd x
    $ lore prompt
    history -a

# Subdirectory w/change in .lore path
    $ mkdir y; touch .lore
    $ cd y
    $ lore prompt  # cd will be saved because it's the global dir
    history -a
    history -c
    lore: loading history from ~/x/.lore
    HISTFILE=/TEST/x/.lore
    history -r
    history -a

# Subdir change again, but locked this time
    $ cd ../..
    $ lore lock
    $ lore prompt
    history -a

# Now unlock
    $ lore unlock
    $ lore prompt
    history -c
    lore: loading history from .lore
    HISTFILE=/TEST/.lore
    history -r
    history -a

# And change dirs, but without a global match
    $ unset LORE_GLOBAL
    $ cd x/y
    $ lore prompt
    history -c
    lore: loading history from ~/x/.lore
    HISTFILE=/TEST/x/.lore
    history -r
    history -a
~~~

#### lore use

`lore use` *file-or-dir* selects (and loads) the specified history file, and switches the `LORE_MODE` to `locked` so it won't be immediately switched away from.  (Any pending history writes are flushed first.)

~~~sh
    $ lore use .
    history -a
    history -c
    lore: loading history from .lore
    HISTFILE=/TEST/x/y/.lore
    history -r

    $ lore status
    lore is off, in 'locked' mode; HISTFILE=.lore

    $ lore unlock
~~~

#### lore global

`lore global` is equivalent to `lore use` *global-history-file*: i.e., it selects and loads the global history, switching the `LORE_MODE` to `locked`.  (Any pending history writes are flushed first.)

~~~sh
    $ lore global
    history -a
    history -c
    lore: loading history from ~/.bash_history
    HISTFILE=/TEST/.bash_history
    history -r

    $ lore status
    lore is off, in 'locked' mode; HISTFILE=~/.bash_history
~~~

#### lore local

`lore local` selects (and loads) the local history file, and switches the `LORE_MODE` to `auto`.  (Any pending history writes are flushed first.)

~~~sh
    $ rm .lore  # drop ~/x/y/.lore so we fallback to ~/x

    $ lore local
    history -a
    history -c
    lore: loading history from ~/x/.lore
    HISTFILE=/TEST/x/.lore
    history -r

    $ lore status
    lore is off, in 'auto' mode; HISTFILE=~/x/.lore
~~~

#### Cleanup

~~~sh
    $ cd ../..
    $ rm x/.lore
    $ rmdir x/y x
    $ unset HISTFILE
~~~

### History File Management

#### lore reload

`lore reload` forces a reload of the current history file, after saving any currently-unwritten history to it.  If there is no current history file, a local or global history file is selected automatically.  (Note: if a `HISTFILE` is already selected, this command does not select a different one, so if you're trying to get lore to recognize a newly-created local history file,  you should probably use `lore local` instead.)

~~~sh
# Auto-detect history file if no HISTFILE

    $ lore reload
    HISTFILE=
    history -a
    history -c
    lore: loading history from .lore
    HISTFILE=/TEST/.lore
    history -r

# Reload of existing file

    $ lore reload
    history -a
    HISTFILE=
    history -c
    lore: loading history from .lore
    HISTFILE=/TEST/.lore
    history -r

~~~

#### lore save

`lore save` *[dir-or-file] [`-f`]* saves a copy of the current history to *dir-or-file* (or the current history file, if only `-f` is provided).  It doesn't overwrite an existing file unless `-f` is supplied.  If no arguments are given, it just writes any unwritten history to the current history file (if any).  (i.e. a manual version of what `lore prompt` does when lore is `on`.)

(This command also resets the working directory cache, so that if lore is `on` and in `auto` mode and the file should be the new local history file, it will switch to it as of the next prompt.)

~~~sh
# No arg, just saves unwritten history to current file
    $ lore save
    history -a

# Just -f, just saves unwritten history to current file
    $ lore save -f
    history -a
    history -w /*/.lore (glob)

# New file/dir, saves unwritten to old file, all history to new file
    $ mkdir x
    $ cd x
    $ lore prompt
    history -a

    $ lore save .
    history -a
    history -w ./.lore

# New file gets selected as of prompt
    $ lore prompt
    history -a
    history -c
    lore: loading history from .lore
    HISTFILE=/TEST/x/.lore
    history -r
    history -a

# Save to same file warns of overwrite
    $ lore save .
    history -a
    lore: ./.lore already exists; use 'lore save . -f' to overwrite
    [73]

# Unless forced
    $ lore save . -f
    history -a
    history -w ./.lore

~~~

#### lore edit

`lore edit` opens the current history file (in `$LORE_EDITOR` or `$EDITOR`), creating it first if necessary, and saving any unwritten history to it.  If `HISTFILE` is empty, a local or global history file is selected first.  After the editor exits, a `lore reload` is performed.

~~~sh
# No editor set -- treats edit as no-op and just reloads
    $ lore edit
    history -a
    No LORE_EDITOR or EDITOR set; file '/*/x/.lore' unchanged (glob)
    history -a
    HISTFILE=
    history -c
    lore: loading history from .lore
    HISTFILE=/TEST/x/.lore
    history -r

# Runs the EDITOR if set
    $ editor() { dumpargs editor "$@"; }
    $ EDITOR=editor lore edit
    history -a
    editor /*/x/.lore (glob)
    history -a
    HISTFILE=
    history -c
    lore: loading history from .lore
    HISTFILE=/TEST/x/.lore
    history -r

# Runs the LORE_EDITOR with precedence over EDITOR
    $ editor() { dumpargs editor "$@"; }
    $ EDITOR=echo LORE_EDITOR=editor lore edit
    history -a
    editor /*/x/.lore (glob)
    history -a
    HISTFILE=
    history -c
    lore: loading history from .lore
    HISTFILE=/TEST/x/.lore
    history -r

~~~

#### Cleanup

~~~sh
    $ cd ..
    $ rm x/.lore
    $ rmdir x
~~~

