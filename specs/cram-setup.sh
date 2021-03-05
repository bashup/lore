# Get rid of any outside variables that might affect test behavior
unset ${!LORE_@} TMUX_PANE XDG_CONFIG_HOME HISTFILE EDITOR

# Fake HOME, but also set a TEST_BASE directory
export TEST_ROOT=$PWD
export HOME=$PWD

# Dump command-line arguments in shell-quoted form
dumpargs() { local REPLY=; printf -v REPLY " %q" "$@"; echo "${REPLY# }" >&2; }
