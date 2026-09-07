# Minimal root shell for the live ISO.
autoload -Uz colors && colors
autoload -Uz compinit && compinit -u
autoload -Uz add-zsh-hook

set_prompt() { PS1="%B%{$fg[red]%}root%{$reset_color%}%b@%m:%~ %# "; }
add-zsh-hook precmd set_prompt

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'

HISTSIZE=1000
SAVEHIST=1000
HISTFILE=/root/.zsh_history
setopt appendhistory hist_ignore_dups
bindkey -e

alias ls='ls --color=auto'
alias ll='ls -lh'
alias la='ls -lha'
alias grep='grep --color=auto'
alias vi='nvim'

echo "hyperdrive live — run 'hyperdrive-install' or 'archinstall' to install."
