#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

[[ -z $DISPLAY && $XDG_VTNR -eq 1 ]] && exec startx &> /dev/null

alias ls='ls --color=auto'
PS1='[\u@\h \W]\$ '
