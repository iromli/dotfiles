# bash completion for cue                                  -*- shell-script -*-

__cue_debug()
{
    if [[ -n ${BASH_COMP_DEBUG_FILE:-} ]]; then
        echo "$*" >> "${BASH_COMP_DEBUG_FILE}"
    fi
}

# Homebrew on Macs have version 1.3 of bash-completion which doesn't include
# _init_completion. This is a very minimal version of that function.
__cue_init_completion()
{
    COMPREPLY=()
    _get_comp_words_by_ref "$@" cur prev words cword
}

__cue_index_of_word()
{
    local w word=$1
    shift
    index=0
    for w in "$@"; do
        [[ $w = "$word" ]] && return
        index=$((index+1))
    done
    index=-1
}

__cue_contains_word()
{
    local w word=$1; shift
    for w in "$@"; do
        [[ $w = "$word" ]] && return
    done
    return 1
}

__cue_handle_go_custom_completion()
{
    __cue_debug "${FUNCNAME[0]}: cur is ${cur}, words[*] is ${words[*]}, #words[@] is ${#words[@]}"

    local shellCompDirectiveError=1
    local shellCompDirectiveNoSpace=2
    local shellCompDirectiveNoFileComp=4
    local shellCompDirectiveFilterFileExt=8
    local shellCompDirectiveFilterDirs=16

    local out requestComp lastParam lastChar comp directive args

    # Prepare the command to request completions for the program.
    # Calling ${words[0]} instead of directly cue allows to handle aliases
    args=("${words[@]:1}")
    requestComp="${words[0]} __completeNoDesc ${args[*]}"

    lastParam=${words[$((${#words[@]}-1))]}
    lastChar=${lastParam:$((${#lastParam}-1)):1}
    __cue_debug "${FUNCNAME[0]}: lastParam ${lastParam}, lastChar ${lastChar}"

    if [ -z "${cur}" ] && [ "${lastChar}" != "=" ]; then
        # If the last parameter is complete (there is a space following it)
        # We add an extra empty parameter so we can indicate this to the go method.
        __cue_debug "${FUNCNAME[0]}: Adding extra empty parameter"
        requestComp="${requestComp} \"\""
    fi

    __cue_debug "${FUNCNAME[0]}: calling ${requestComp}"
    # Use eval to handle any environment variables and such
    out=$(eval "${requestComp}" 2>/dev/null)

    # Extract the directive integer at the very end of the output following a colon (:)
    directive=${out##*:}
    # Remove the directive
    out=${out%:*}
    if [ "${directive}" = "${out}" ]; then
        # There is not directive specified
        directive=0
    fi
    __cue_debug "${FUNCNAME[0]}: the completion directive is: ${directive}"
    __cue_debug "${FUNCNAME[0]}: the completions are: ${out[*]}"

    if [ $((directive & shellCompDirectiveError)) -ne 0 ]; then
        # Error code.  No completion.
        __cue_debug "${FUNCNAME[0]}: received error from custom completion go code"
        return
    else
        if [ $((directive & shellCompDirectiveNoSpace)) -ne 0 ]; then
            if [[ $(type -t compopt) = "builtin" ]]; then
                __cue_debug "${FUNCNAME[0]}: activating no space"
                compopt -o nospace
            fi
        fi
        if [ $((directive & shellCompDirectiveNoFileComp)) -ne 0 ]; then
            if [[ $(type -t compopt) = "builtin" ]]; then
                __cue_debug "${FUNCNAME[0]}: activating no file completion"
                compopt +o default
            fi
        fi
    fi

    if [ $((directive & shellCompDirectiveFilterFileExt)) -ne 0 ]; then
        # File extension filtering
        local fullFilter filter filteringCmd
        # Do not use quotes around the $out variable or else newline
        # characters will be kept.
        for filter in ${out[*]}; do
            fullFilter+="$filter|"
        done

        filteringCmd="_filedir $fullFilter"
        __cue_debug "File filtering command: $filteringCmd"
        $filteringCmd
    elif [ $((directive & shellCompDirectiveFilterDirs)) -ne 0 ]; then
        # File completion for directories only
        local subdir
        # Use printf to strip any trailing newline
        subdir=$(printf "%s" "${out[0]}")
        if [ -n "$subdir" ]; then
            __cue_debug "Listing directories in $subdir"
            __cue_handle_subdirs_in_dir_flag "$subdir"
        else
            __cue_debug "Listing directories in ."
            _filedir -d
        fi
    else
        while IFS='' read -r comp; do
            COMPREPLY+=("$comp")
        done < <(compgen -W "${out[*]}" -- "$cur")
    fi
}

__cue_handle_reply()
{
    __cue_debug "${FUNCNAME[0]}"
    local comp
    case $cur in
        -*)
            if [[ $(type -t compopt) = "builtin" ]]; then
                compopt -o nospace
            fi
            local allflags
            if [ ${#must_have_one_flag[@]} -ne 0 ]; then
                allflags=("${must_have_one_flag[@]}")
            else
                allflags=("${flags[*]} ${two_word_flags[*]}")
            fi
            while IFS='' read -r comp; do
                COMPREPLY+=("$comp")
            done < <(compgen -W "${allflags[*]}" -- "$cur")
            if [[ $(type -t compopt) = "builtin" ]]; then
                [[ "${COMPREPLY[0]}" == *= ]] || compopt +o nospace
            fi

            # complete after --flag=abc
            if [[ $cur == *=* ]]; then
                if [[ $(type -t compopt) = "builtin" ]]; then
                    compopt +o nospace
                fi

                local index flag
                flag="${cur%=*}"
                __cue_index_of_word "${flag}" "${flags_with_completion[@]}"
                COMPREPLY=()
                if [[ ${index} -ge 0 ]]; then
                    PREFIX=""
                    cur="${cur#*=}"
                    ${flags_completion[${index}]}
                    if [ -n "${ZSH_VERSION:-}" ]; then
                        # zsh completion needs --flag= prefix
                        eval "COMPREPLY=( \"\${COMPREPLY[@]/#/${flag}=}\" )"
                    fi
                fi
            fi

            if [[ -z "${flag_parsing_disabled}" ]]; then
                # If flag parsing is enabled, we have completed the flags and can return.
                # If flag parsing is disabled, we may not know all (or any) of the flags, so we fallthrough
                # to possibly call handle_go_custom_completion.
                return 0;
            fi
            ;;
    esac

    # check if we are handling a flag with special work handling
    local index
    __cue_index_of_word "${prev}" "${flags_with_completion[@]}"
    if [[ ${index} -ge 0 ]]; then
        ${flags_completion[${index}]}
        return
    fi

    # we are parsing a flag and don't have a special handler, no completion
    if [[ ${cur} != "${words[cword]}" ]]; then
        return
    fi

    local completions
    completions=("${commands[@]}")
    if [[ ${#must_have_one_noun[@]} -ne 0 ]]; then
        completions+=("${must_have_one_noun[@]}")
    elif [[ -n "${has_completion_function}" ]]; then
        # if a go completion function is provided, defer to that function
        __cue_handle_go_custom_completion
    fi
    if [[ ${#must_have_one_flag[@]} -ne 0 ]]; then
        completions+=("${must_have_one_flag[@]}")
    fi
    while IFS='' read -r comp; do
        COMPREPLY+=("$comp")
    done < <(compgen -W "${completions[*]}" -- "$cur")

    if [[ ${#COMPREPLY[@]} -eq 0 && ${#noun_aliases[@]} -gt 0 && ${#must_have_one_noun[@]} -ne 0 ]]; then
        while IFS='' read -r comp; do
            COMPREPLY+=("$comp")
        done < <(compgen -W "${noun_aliases[*]}" -- "$cur")
    fi

    if [[ ${#COMPREPLY[@]} -eq 0 ]]; then
        if declare -F __cue_custom_func >/dev/null; then
            # try command name qualified custom func
            __cue_custom_func
        else
            # otherwise fall back to unqualified for compatibility
            declare -F __custom_func >/dev/null && __custom_func
        fi
    fi

    # available in bash-completion >= 2, not always present on macOS
    if declare -F __ltrim_colon_completions >/dev/null; then
        __ltrim_colon_completions "$cur"
    fi

    # If there is only 1 completion and it is a flag with an = it will be completed
    # but we don't want a space after the =
    if [[ "${#COMPREPLY[@]}" -eq "1" ]] && [[ $(type -t compopt) = "builtin" ]] && [[ "${COMPREPLY[0]}" == --*= ]]; then
       compopt -o nospace
    fi
}

# The arguments should be in the form "ext1|ext2|extn"
__cue_handle_filename_extension_flag()
{
    local ext="$1"
    _filedir "@(${ext})"
}

__cue_handle_subdirs_in_dir_flag()
{
    local dir="$1"
    pushd "${dir}" >/dev/null 2>&1 && _filedir -d && popd >/dev/null 2>&1 || return
}

__cue_handle_flag()
{
    __cue_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"

    # if a command required a flag, and we found it, unset must_have_one_flag()
    local flagname=${words[c]}
    local flagvalue=""
    # if the word contained an =
    if [[ ${words[c]} == *"="* ]]; then
        flagvalue=${flagname#*=} # take in as flagvalue after the =
        flagname=${flagname%=*} # strip everything after the =
        flagname="${flagname}=" # but put the = back
    fi
    __cue_debug "${FUNCNAME[0]}: looking for ${flagname}"
    if __cue_contains_word "${flagname}" "${must_have_one_flag[@]}"; then
        must_have_one_flag=()
    fi

    # if you set a flag which only applies to this command, don't show subcommands
    if __cue_contains_word "${flagname}" "${local_nonpersistent_flags[@]}"; then
      commands=()
    fi

    # keep flag value with flagname as flaghash
    # flaghash variable is an associative array which is only supported in bash > 3.
    if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
        if [ -n "${flagvalue}" ] ; then
            flaghash[${flagname}]=${flagvalue}
        elif [ -n "${words[ $((c+1)) ]}" ] ; then
            flaghash[${flagname}]=${words[ $((c+1)) ]}
        else
            flaghash[${flagname}]="true" # pad "true" for bool flag
        fi
    fi

    # skip the argument to a two word flag
    if [[ ${words[c]} != *"="* ]] && __cue_contains_word "${words[c]}" "${two_word_flags[@]}"; then
        __cue_debug "${FUNCNAME[0]}: found a flag ${words[c]}, skip the next argument"
        c=$((c+1))
        # if we are looking for a flags value, don't show commands
        if [[ $c -eq $cword ]]; then
            commands=()
        fi
    fi

    c=$((c+1))

}

__cue_handle_noun()
{
    __cue_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"

    if __cue_contains_word "${words[c]}" "${must_have_one_noun[@]}"; then
        must_have_one_noun=()
    elif __cue_contains_word "${words[c]}" "${noun_aliases[@]}"; then
        must_have_one_noun=()
    fi

    nouns+=("${words[c]}")
    c=$((c+1))
}

__cue_handle_command()
{
    __cue_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"

    local next_command
    if [[ -n ${last_command} ]]; then
        next_command="_${last_command}_${words[c]//:/__}"
    else
        if [[ $c -eq 0 ]]; then
            next_command="_cue_root_command"
        else
            next_command="_${words[c]//:/__}"
        fi
    fi
    c=$((c+1))
    __cue_debug "${FUNCNAME[0]}: looking for ${next_command}"
    declare -F "$next_command" >/dev/null && $next_command
}

__cue_handle_word()
{
    if [[ $c -ge $cword ]]; then
        __cue_handle_reply
        return
    fi
    __cue_debug "${FUNCNAME[0]}: c is $c words[c] is ${words[c]}"
    if [[ "${words[c]}" == -* ]]; then
        __cue_handle_flag
    elif __cue_contains_word "${words[c]}" "${commands[@]}"; then
        __cue_handle_command
    elif [[ $c -eq 0 ]]; then
        __cue_handle_command
    elif __cue_contains_word "${words[c]}" "${command_aliases[@]}"; then
        # aliashash variable is an associative array which is only supported in bash > 3.
        if [[ -z "${BASH_VERSION:-}" || "${BASH_VERSINFO[0]:-}" -gt 3 ]]; then
            words[c]=${aliashash[${words[c]}]}
            __cue_handle_command
        else
            __cue_handle_noun
        fi
    else
        __cue_handle_noun
    fi
    __cue_handle_word
}

_cue_cmd()
{
    last_command="cue_cmd"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--inject=")
    two_word_flags+=("--inject")
    two_word_flags+=("-t")
    local_nonpersistent_flags+=("--inject")
    local_nonpersistent_flags+=("--inject=")
    local_nonpersistent_flags+=("-t")
    flags+=("--inject-vars")
    flags+=("-T")
    local_nonpersistent_flags+=("--inject-vars")
    local_nonpersistent_flags+=("-T")
    flags+=("--all-errors")
    flags+=("-E")
    flags+=("--ignore")
    flags+=("-i")
    flags+=("--simplify")
    flags+=("-s")
    flags+=("--strict")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_cue_completion()
{
    last_command="cue_completion"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--help")
    flags+=("-h")
    local_nonpersistent_flags+=("--help")
    local_nonpersistent_flags+=("-h")
    flags+=("--all-errors")
    flags+=("-E")
    flags+=("--ignore")
    flags+=("-i")
    flags+=("--simplify")
    flags+=("-s")
    flags+=("--strict")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    must_have_one_noun+=("bash")
    must_have_one_noun+=("fish")
    must_have_one_noun+=("powershell")
    must_have_one_noun+=("zsh")
    noun_aliases=()
}

_cue_def()
{
    last_command="cue_def"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--expression=")
    two_word_flags+=("--expression")
    two_word_flags+=("-e")
    local_nonpersistent_flags+=("--expression")
    local_nonpersistent_flags+=("--expression=")
    local_nonpersistent_flags+=("-e")
    flags+=("--force")
    flags+=("-f")
    local_nonpersistent_flags+=("--force")
    local_nonpersistent_flags+=("-f")
    flags+=("--inject=")
    two_word_flags+=("--inject")
    two_word_flags+=("-t")
    local_nonpersistent_flags+=("--inject")
    local_nonpersistent_flags+=("--inject=")
    local_nonpersistent_flags+=("-t")
    flags+=("--inject-vars")
    flags+=("-T")
    local_nonpersistent_flags+=("--inject-vars")
    local_nonpersistent_flags+=("-T")
    flags+=("--list")
    local_nonpersistent_flags+=("--list")
    flags+=("--merge")
    local_nonpersistent_flags+=("--merge")
    flags+=("--name=")
    two_word_flags+=("--name")
    two_word_flags+=("-n")
    local_nonpersistent_flags+=("--name")
    local_nonpersistent_flags+=("--name=")
    local_nonpersistent_flags+=("-n")
    flags+=("--out=")
    two_word_flags+=("--out")
    local_nonpersistent_flags+=("--out")
    local_nonpersistent_flags+=("--out=")
    flags+=("--outfile=")
    two_word_flags+=("--outfile")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--outfile")
    local_nonpersistent_flags+=("--outfile=")
    local_nonpersistent_flags+=("-o")
    flags+=("--package=")
    two_word_flags+=("--package")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--package")
    local_nonpersistent_flags+=("--package=")
    local_nonpersistent_flags+=("-p")
    flags+=("--path=")
    two_word_flags+=("--path")
    two_word_flags+=("-l")
    local_nonpersistent_flags+=("--path")
    local_nonpersistent_flags+=("--path=")
    local_nonpersistent_flags+=("-l")
    flags+=("--proto_enum=")
    two_word_flags+=("--proto_enum")
    local_nonpersistent_flags+=("--proto_enum")
    local_nonpersistent_flags+=("--proto_enum=")
    flags+=("--proto_path=")
    two_word_flags+=("--proto_path")
    two_word_flags+=("-I")
    local_nonpersistent_flags+=("--proto_path")
    local_nonpersistent_flags+=("--proto_path=")
    local_nonpersistent_flags+=("-I")
    flags+=("--schema=")
    two_word_flags+=("--schema")
    two_word_flags+=("-d")
    local_nonpersistent_flags+=("--schema")
    local_nonpersistent_flags+=("--schema=")
    local_nonpersistent_flags+=("-d")
    flags+=("--show-attributes")
    flags+=("-A")
    local_nonpersistent_flags+=("--show-attributes")
    local_nonpersistent_flags+=("-A")
    flags+=("--with-context")
    local_nonpersistent_flags+=("--with-context")
    flags+=("--all-errors")
    flags+=("-E")
    flags+=("--ignore")
    flags+=("-i")
    flags+=("--simplify")
    flags+=("-s")
    flags+=("--strict")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_cue_eval()
{
    last_command="cue_eval"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--all")
    flags+=("-a")
    local_nonpersistent_flags+=("--all")
    local_nonpersistent_flags+=("-a")
    flags+=("--concrete")
    flags+=("-c")
    local_nonpersistent_flags+=("--concrete")
    local_nonpersistent_flags+=("-c")
    flags+=("--expression=")
    two_word_flags+=("--expression")
    two_word_flags+=("-e")
    local_nonpersistent_flags+=("--expression")
    local_nonpersistent_flags+=("--expression=")
    local_nonpersistent_flags+=("-e")
    flags+=("--force")
    flags+=("-f")
    local_nonpersistent_flags+=("--force")
    local_nonpersistent_flags+=("-f")
    flags+=("--inject=")
    two_word_flags+=("--inject")
    two_word_flags+=("-t")
    local_nonpersistent_flags+=("--inject")
    local_nonpersistent_flags+=("--inject=")
    local_nonpersistent_flags+=("-t")
    flags+=("--inject-vars")
    flags+=("-T")
    local_nonpersistent_flags+=("--inject-vars")
    local_nonpersistent_flags+=("-T")
    flags+=("--list")
    local_nonpersistent_flags+=("--list")
    flags+=("--merge")
    local_nonpersistent_flags+=("--merge")
    flags+=("--name=")
    two_word_flags+=("--name")
    two_word_flags+=("-n")
    local_nonpersistent_flags+=("--name")
    local_nonpersistent_flags+=("--name=")
    local_nonpersistent_flags+=("-n")
    flags+=("--out=")
    two_word_flags+=("--out")
    local_nonpersistent_flags+=("--out")
    local_nonpersistent_flags+=("--out=")
    flags+=("--outfile=")
    two_word_flags+=("--outfile")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--outfile")
    local_nonpersistent_flags+=("--outfile=")
    local_nonpersistent_flags+=("-o")
    flags+=("--package=")
    two_word_flags+=("--package")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--package")
    local_nonpersistent_flags+=("--package=")
    local_nonpersistent_flags+=("-p")
    flags+=("--path=")
    two_word_flags+=("--path")
    two_word_flags+=("-l")
    local_nonpersistent_flags+=("--path")
    local_nonpersistent_flags+=("--path=")
    local_nonpersistent_flags+=("-l")
    flags+=("--proto_enum=")
    two_word_flags+=("--proto_enum")
    local_nonpersistent_flags+=("--proto_enum")
    local_nonpersistent_flags+=("--proto_enum=")
    flags+=("--proto_path=")
    two_word_flags+=("--proto_path")
    two_word_flags+=("-I")
    local_nonpersistent_flags+=("--proto_path")
    local_nonpersistent_flags+=("--proto_path=")
    local_nonpersistent_flags+=("-I")
    flags+=("--schema=")
    two_word_flags+=("--schema")
    two_word_flags+=("-d")
    local_nonpersistent_flags+=("--schema")
    local_nonpersistent_flags+=("--schema=")
    local_nonpersistent_flags+=("-d")
    flags+=("--show-attributes")
    flags+=("-A")
    local_nonpersistent_flags+=("--show-attributes")
    local_nonpersistent_flags+=("-A")
    flags+=("--show-hidden")
    flags+=("-H")
    local_nonpersistent_flags+=("--show-hidden")
    local_nonpersistent_flags+=("-H")
    flags+=("--show-optional")
    flags+=("-O")
    local_nonpersistent_flags+=("--show-optional")
    local_nonpersistent_flags+=("-O")
    flags+=("--with-context")
    local_nonpersistent_flags+=("--with-context")
    flags+=("--all-errors")
    flags+=("-E")
    flags+=("--ignore")
    flags+=("-i")
    flags+=("--simplify")
    flags+=("-s")
    flags+=("--strict")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_cue_export()
{
    last_command="cue_export"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--escape")
    local_nonpersistent_flags+=("--escape")
    flags+=("--expression=")
    two_word_flags+=("--expression")
    two_word_flags+=("-e")
    local_nonpersistent_flags+=("--expression")
    local_nonpersistent_flags+=("--expression=")
    local_nonpersistent_flags+=("-e")
    flags+=("--force")
    flags+=("-f")
    local_nonpersistent_flags+=("--force")
    local_nonpersistent_flags+=("-f")
    flags+=("--inject=")
    two_word_flags+=("--inject")
    two_word_flags+=("-t")
    local_nonpersistent_flags+=("--inject")
    local_nonpersistent_flags+=("--inject=")
    local_nonpersistent_flags+=("-t")
    flags+=("--inject-vars")
    flags+=("-T")
    local_nonpersistent_flags+=("--inject-vars")
    local_nonpersistent_flags+=("-T")
    flags+=("--list")
    local_nonpersistent_flags+=("--list")
    flags+=("--merge")
    local_nonpersistent_flags+=("--merge")
    flags+=("--name=")
    two_word_flags+=("--name")
    two_word_flags+=("-n")
    local_nonpersistent_flags+=("--name")
    local_nonpersistent_flags+=("--name=")
    local_nonpersistent_flags+=("-n")
    flags+=("--out=")
    two_word_flags+=("--out")
    local_nonpersistent_flags+=("--out")
    local_nonpersistent_flags+=("--out=")
    flags+=("--outfile=")
    two_word_flags+=("--outfile")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--outfile")
    local_nonpersistent_flags+=("--outfile=")
    local_nonpersistent_flags+=("-o")
    flags+=("--package=")
    two_word_flags+=("--package")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--package")
    local_nonpersistent_flags+=("--package=")
    local_nonpersistent_flags+=("-p")
    flags+=("--path=")
    two_word_flags+=("--path")
    two_word_flags+=("-l")
    local_nonpersistent_flags+=("--path")
    local_nonpersistent_flags+=("--path=")
    local_nonpersistent_flags+=("-l")
    flags+=("--proto_enum=")
    two_word_flags+=("--proto_enum")
    local_nonpersistent_flags+=("--proto_enum")
    local_nonpersistent_flags+=("--proto_enum=")
    flags+=("--proto_path=")
    two_word_flags+=("--proto_path")
    two_word_flags+=("-I")
    local_nonpersistent_flags+=("--proto_path")
    local_nonpersistent_flags+=("--proto_path=")
    local_nonpersistent_flags+=("-I")
    flags+=("--schema=")
    two_word_flags+=("--schema")
    two_word_flags+=("-d")
    local_nonpersistent_flags+=("--schema")
    local_nonpersistent_flags+=("--schema=")
    local_nonpersistent_flags+=("-d")
    flags+=("--with-context")
    local_nonpersistent_flags+=("--with-context")
    flags+=("--all-errors")
    flags+=("-E")
    flags+=("--ignore")
    flags+=("-i")
    flags+=("--simplify")
    flags+=("-s")
    flags+=("--strict")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_cue_fix()
{
    last_command="cue_fix"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--force")
    flags+=("-f")
    local_nonpersistent_flags+=("--force")
    local_nonpersistent_flags+=("-f")
    flags+=("--all-errors")
    flags+=("-E")
    flags+=("--ignore")
    flags+=("-i")
    flags+=("--simplify")
    flags+=("-s")
    flags+=("--strict")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_cue_fmt()
{
    last_command="cue_fmt"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--all-errors")
    flags+=("-E")
    flags+=("--ignore")
    flags+=("-i")
    flags+=("--simplify")
    flags+=("-s")
    flags+=("--strict")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_cue_get_go()
{
    last_command="cue_get_go"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--exclude=")
    two_word_flags+=("--exclude")
    two_word_flags+=("-e")
    local_nonpersistent_flags+=("--exclude")
    local_nonpersistent_flags+=("--exclude=")
    local_nonpersistent_flags+=("-e")
    flags+=("--local")
    local_nonpersistent_flags+=("--local")
    flags+=("--package=")
    two_word_flags+=("--package")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--package")
    local_nonpersistent_flags+=("--package=")
    local_nonpersistent_flags+=("-p")
    flags+=("--all-errors")
    flags+=("-E")
    flags+=("--ignore")
    flags+=("-i")
    flags+=("--simplify")
    flags+=("-s")
    flags+=("--strict")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_cue_get()
{
    last_command="cue_get"

    command_aliases=()

    commands=()
    commands+=("go")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--all-errors")
    flags+=("-E")
    flags+=("--ignore")
    flags+=("-i")
    flags+=("--simplify")
    flags+=("-s")
    flags+=("--strict")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_cue_help()
{
    last_command="cue_help"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--all-errors")
    flags+=("-E")
    flags+=("--ignore")
    flags+=("-i")
    flags+=("--simplify")
    flags+=("-s")
    flags+=("--strict")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    has_completion_function=1
    noun_aliases=()
}

_cue_import()
{
    last_command="cue_import"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--dryrun")
    local_nonpersistent_flags+=("--dryrun")
    flags+=("--ext=")
    two_word_flags+=("--ext")
    local_nonpersistent_flags+=("--ext")
    local_nonpersistent_flags+=("--ext=")
    flags+=("--files")
    local_nonpersistent_flags+=("--files")
    flags+=("--force")
    flags+=("-f")
    local_nonpersistent_flags+=("--force")
    local_nonpersistent_flags+=("-f")
    flags+=("--list")
    local_nonpersistent_flags+=("--list")
    flags+=("--merge")
    local_nonpersistent_flags+=("--merge")
    flags+=("--name=")
    two_word_flags+=("--name")
    two_word_flags+=("-n")
    local_nonpersistent_flags+=("--name")
    local_nonpersistent_flags+=("--name=")
    local_nonpersistent_flags+=("-n")
    flags+=("--outfile=")
    two_word_flags+=("--outfile")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--outfile")
    local_nonpersistent_flags+=("--outfile=")
    local_nonpersistent_flags+=("-o")
    flags+=("--package=")
    two_word_flags+=("--package")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--package")
    local_nonpersistent_flags+=("--package=")
    local_nonpersistent_flags+=("-p")
    flags+=("--path=")
    two_word_flags+=("--path")
    two_word_flags+=("-l")
    local_nonpersistent_flags+=("--path")
    local_nonpersistent_flags+=("--path=")
    local_nonpersistent_flags+=("-l")
    flags+=("--proto_enum=")
    two_word_flags+=("--proto_enum")
    local_nonpersistent_flags+=("--proto_enum")
    local_nonpersistent_flags+=("--proto_enum=")
    flags+=("--proto_path=")
    two_word_flags+=("--proto_path")
    two_word_flags+=("-I")
    local_nonpersistent_flags+=("--proto_path")
    local_nonpersistent_flags+=("--proto_path=")
    local_nonpersistent_flags+=("-I")
    flags+=("--recursive")
    flags+=("-R")
    local_nonpersistent_flags+=("--recursive")
    local_nonpersistent_flags+=("-R")
    flags+=("--schema=")
    two_word_flags+=("--schema")
    two_word_flags+=("-d")
    local_nonpersistent_flags+=("--schema")
    local_nonpersistent_flags+=("--schema=")
    local_nonpersistent_flags+=("-d")
    flags+=("--with-context")
    local_nonpersistent_flags+=("--with-context")
    flags+=("--all-errors")
    flags+=("-E")
    flags+=("--ignore")
    flags+=("-i")
    flags+=("--simplify")
    flags+=("-s")
    flags+=("--strict")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_cue_mod_init()
{
    last_command="cue_mod_init"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--force")
    flags+=("-f")
    local_nonpersistent_flags+=("--force")
    local_nonpersistent_flags+=("-f")
    flags+=("--all-errors")
    flags+=("-E")
    flags+=("--ignore")
    flags+=("-i")
    flags+=("--simplify")
    flags+=("-s")
    flags+=("--strict")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_cue_mod()
{
    last_command="cue_mod"

    command_aliases=()

    commands=()
    commands+=("init")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--all-errors")
    flags+=("-E")
    flags+=("--ignore")
    flags+=("-i")
    flags+=("--simplify")
    flags+=("-s")
    flags+=("--strict")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_cue_trim()
{
    last_command="cue_trim"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--force")
    flags+=("-f")
    local_nonpersistent_flags+=("--force")
    local_nonpersistent_flags+=("-f")
    flags+=("--outfile=")
    two_word_flags+=("--outfile")
    two_word_flags+=("-o")
    local_nonpersistent_flags+=("--outfile")
    local_nonpersistent_flags+=("--outfile=")
    local_nonpersistent_flags+=("-o")
    flags+=("--all-errors")
    flags+=("-E")
    flags+=("--ignore")
    flags+=("-i")
    flags+=("--simplify")
    flags+=("-s")
    flags+=("--strict")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_cue_version()
{
    last_command="cue_version"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--all-errors")
    flags+=("-E")
    flags+=("--ignore")
    flags+=("-i")
    flags+=("--simplify")
    flags+=("-s")
    flags+=("--strict")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_cue_vet()
{
    last_command="cue_vet"

    command_aliases=()

    commands=()

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--concrete")
    flags+=("-c")
    local_nonpersistent_flags+=("--concrete")
    local_nonpersistent_flags+=("-c")
    flags+=("--inject=")
    two_word_flags+=("--inject")
    two_word_flags+=("-t")
    local_nonpersistent_flags+=("--inject")
    local_nonpersistent_flags+=("--inject=")
    local_nonpersistent_flags+=("-t")
    flags+=("--inject-vars")
    flags+=("-T")
    local_nonpersistent_flags+=("--inject-vars")
    local_nonpersistent_flags+=("-T")
    flags+=("--list")
    local_nonpersistent_flags+=("--list")
    flags+=("--merge")
    local_nonpersistent_flags+=("--merge")
    flags+=("--name=")
    two_word_flags+=("--name")
    two_word_flags+=("-n")
    local_nonpersistent_flags+=("--name")
    local_nonpersistent_flags+=("--name=")
    local_nonpersistent_flags+=("-n")
    flags+=("--package=")
    two_word_flags+=("--package")
    two_word_flags+=("-p")
    local_nonpersistent_flags+=("--package")
    local_nonpersistent_flags+=("--package=")
    local_nonpersistent_flags+=("-p")
    flags+=("--path=")
    two_word_flags+=("--path")
    two_word_flags+=("-l")
    local_nonpersistent_flags+=("--path")
    local_nonpersistent_flags+=("--path=")
    local_nonpersistent_flags+=("-l")
    flags+=("--proto_enum=")
    two_word_flags+=("--proto_enum")
    local_nonpersistent_flags+=("--proto_enum")
    local_nonpersistent_flags+=("--proto_enum=")
    flags+=("--proto_path=")
    two_word_flags+=("--proto_path")
    two_word_flags+=("-I")
    local_nonpersistent_flags+=("--proto_path")
    local_nonpersistent_flags+=("--proto_path=")
    local_nonpersistent_flags+=("-I")
    flags+=("--schema=")
    two_word_flags+=("--schema")
    two_word_flags+=("-d")
    local_nonpersistent_flags+=("--schema")
    local_nonpersistent_flags+=("--schema=")
    local_nonpersistent_flags+=("-d")
    flags+=("--with-context")
    local_nonpersistent_flags+=("--with-context")
    flags+=("--all-errors")
    flags+=("-E")
    flags+=("--ignore")
    flags+=("-i")
    flags+=("--simplify")
    flags+=("-s")
    flags+=("--strict")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

_cue_root_command()
{
    last_command="cue"

    command_aliases=()

    commands=()
    commands+=("cmd")
    commands+=("completion")
    commands+=("def")
    commands+=("eval")
    commands+=("export")
    commands+=("fix")
    commands+=("fmt")
    commands+=("get")
    commands+=("help")
    commands+=("import")
    commands+=("mod")
    commands+=("trim")
    commands+=("version")
    commands+=("vet")

    flags=()
    two_word_flags=()
    local_nonpersistent_flags=()
    flags_with_completion=()
    flags_completion=()

    flags+=("--all-errors")
    flags+=("-E")
    flags+=("--ignore")
    flags+=("-i")
    flags+=("--simplify")
    flags+=("-s")
    flags+=("--strict")
    flags+=("--trace")
    flags+=("--verbose")
    flags+=("-v")

    must_have_one_flag=()
    must_have_one_noun=()
    noun_aliases=()
}

__start_cue()
{
    local cur prev words cword split
    declare -A flaghash 2>/dev/null || :
    declare -A aliashash 2>/dev/null || :
    if declare -F _init_completion >/dev/null 2>&1; then
        _init_completion -s || return
    else
        __cue_init_completion -n "=" || return
    fi

    local c=0
    local flag_parsing_disabled=
    local flags=()
    local two_word_flags=()
    local local_nonpersistent_flags=()
    local flags_with_completion=()
    local flags_completion=()
    local commands=("cue")
    local command_aliases=()
    local must_have_one_flag=()
    local must_have_one_noun=()
    local has_completion_function=""
    local last_command=""
    local nouns=()
    local noun_aliases=()

    __cue_handle_word
}

if [[ $(type -t compopt) = "builtin" ]]; then
    complete -o default -F __start_cue cue
else
    complete -o default -o nospace -F __start_cue cue
fi

# ex: ts=4 sw=4 et filetype=sh
