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

export VCP_PREFIX=" "
export VCP_NAME="{white}({value}) "
export VCP_BRANCH="{blue}{value}{reset}"
export VCP_SEPARATOR=" | "
export VCP_CHANGED="{yellow}↻ {value}"
export VCP_BEHIND=" ⇣ {value}"
export VCP_AHEAD=" ⇡ {value}"
export VCP_STAGED="{blue}✚ {value}"
export VCP_CONFLICT="{red}✖︎ {value}"
export VCP_UNTRACKED="{magenta}…{value}"
export VCP_OPERATION="{red}{value}{reset}"
export VCP_CLEAN="{green}✔︎"
export VCP_SUFFIX="{reset}"

EQ_PROMPT='\e${TXT_BOLD}\e${CLR_CYAN}\u@\h\e${CLR_WHITE}:\e${CLR_GREEN}\w`vcprompt`'

PS1="${EQ_PROMPT}
» "
