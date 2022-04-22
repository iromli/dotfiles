#!/usr/bin/env bash

# ANSI code
RESET_ATTR="[0m"    # Reset
TXT_BOLD="[1m"      # Bold
CLR_BLACK="[30m"    # Black
CLR_RED="[31m"      # Red
CLR_GREEN="[32m"    # Green
CLR_YELLOW="[33m"   # Yellow
CLR_BLUE="[34m"     # Blue
CLR_MAGENTA="[35m"  # Magenta
CLR_CYAN="[36m"     # Cyan
CLR_WHITE="[37m"    # White

export VCP_PREFIX=" :: "
export VCP_NAME="{white}({value}) "
export VCP_SEPARATOR=" | "

EQ_PROMPT='\e${TXT_BOLD}\e${CLR_GREEN}\w`vcprompt`'

# Set the title
case "$TERM" in
    xterm*|rxvt*)
        TITLEBAR="\[\e]0;\u@\h:\w\a\]"
    ;;
    *)
    ;;
esac

PS1="${TITLEBAR}${EQ_PROMPT}
» "
