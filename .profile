# ~/.profile: executed by the command interpreter for login shells.

export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export HISTSIZE=1000000
export EDITOR=vim

export PATH=$HOME/bin:/usr/local/bin:$PATH
export CPLUS_INCLUDE_PATH=$HOME/include:$CPLUS_INCLUDE_PATH
export C_INCLUDE_PATH=$HOME/include:$C_INCLUDE_PATH
export LIBRARY_PATH=$HOME/lib:$LIBRARY_PATH

alias l='less'
alias ll='ls -alG'
alias lr='less -r'
alias t='top'
alias c='cat'
alias p='ps aux | l'
alias ka='killall.sh'
alias ac='zcat -f'

shopt -s direxpand

export PYTHONSTARTUP="$HOME/.pythonrc"

