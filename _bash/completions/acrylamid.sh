_acrylamid() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    opts="init compile view autocompile clean import deploy dp new check
    info ping --help --version --no-color --verbose --quiet"

    case "${prev}" in
        init)
            COMPREPLY=( $(compgen -W "--force --mako --jinja2 --theme" -- ${cur}) )
            return 0
            ;;
        new)
            COMPREPLY=( $(compgen -W "" -- ${cur}) )
            return 0
            ;;
        compile|co|gen|generate)
            COMPREPLY=( $(compgen -W "--force --dry-run --ignore" -- ${cur}) )
            return 0
            ;;
        view)
            COMPREPLY=( $(compgen -W "--port" -- ${cur}) )
            return 0
            ;;
        autocompile|aco)
            COMPREPLY=( $(compgen -W "--force --dry-run --ignore --port" -- ${cur}) )
            return 0
            ;;
        clean|rm)
            COMPREPLY=( $(compgen -W "--force --dry-run" -- ${cur}) )
            return 0
            ;;
        import)
            COMPREPLY=( $(compgen -W "--force --keep-links --pandoc" -- ${cur}) )
            return 0
            ;;
        deploy|dp)
            local keys=$(for x in `acrylamid deploy`; do echo ${x};
            done)
            COMPREPLY=( $(compgen -W "${keys}" -- ${cur}) )
            return 0
            ;;
        check)
            COMPREPLY=( $(compgen -W "W3C links" -- ${cur}) )
            return 0
            ;;
        info)
            COMPREPLY=( $(compgen -W "" -- ${cur}) )
            return 0
            ;;
        ping)
            COMPREPLY=( $(compgen -W "back twitter" -- ${cur}) )
            return 0
            ;;
    esac

    COMPREPLY=($(compgen -W "${opts}" -- ${cur}))
}
complete -o default -F _acrylamid acrylamid
