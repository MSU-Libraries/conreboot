_coreboot()
{
    shopt -s nullglob
    COMPREPLY=()
    CURRENT="${COMP_WORDS[$COMP_CWORD]}"

    if [[ $COMP_CWORD -eq 1 ]]; then
        FLAGS=( -s --status -m --manual -c --cancel -d --daemon -h --help )
        COMPREPLY=( $(compgen -W "${FLAGS[*]}" -- "$CURRENT") )
    fi
    shopt -u nullglob
    return 0
}
complete -F _coreboot coreboot
