# Get rid of any outside variables that might affect test behavior
unset EDITOR ${!LORE_@} histchars HISTCONTROL HISTFILE HISTIGNORE HISTTIMEFORMAT TMUX_PANE XDG_CONFIG_HOME

# Fake HOME, but also set a TEST_ROOT directory
export TEST_ROOT=$PWD
export HOME=$PWD

# Default history settings
HISTSIZE=500
HISTFILESIZE=500

# Dump command-line arguments in shell-quoted form
dumpargs() { local REPLY=; printf -v REPLY " %q" "$@"; echo "${REPLY# }" >&2; }
