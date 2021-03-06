## Internal Tests

~~~sh
    $ source lore
    $ set -u   # ensure lore has explicit handling for all missing vars
~~~

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

