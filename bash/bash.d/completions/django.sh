# #########################################################################
# This bash script adds tab-completion feature to django-admin.py and
# manage.py.
#
# Testing it out without installing
# =================================
#
# To test out the completion without "installing" this, just run this file
# directly, like so:
#
#     . ~/path/to/django_bash_completion
#
# Note: There's a dot ('.') at the beginning of that command.
#
# After you do that, tab completion will immediately be made available in your
# current Bash shell. But it won't be available next time you log in.
#
# Installing
# ==========
#
# To install this, point to this file from your .bash_profile, like so:
#
#     . ~/path/to/django_bash_completion
#
# Do the same in your .bashrc if .bashrc doesn't invoke .bash_profile.
#
# Settings will take effect the next time you log in.
#
# Uninstalling
# ============
#
# To uninstall, just remove the line from your .bash_profile and .bashrc.

_django_completion()
{
    COMPREPLY=( $( COMP_WORDS="${COMP_WORDS[*]}" \
                   COMP_CWORD=$COMP_CWORD \
                   DJANGO_AUTO_COMPLETE=1 $1 ) )
}
complete -F _django_completion -o default django-admin.py manage.py django-admin
