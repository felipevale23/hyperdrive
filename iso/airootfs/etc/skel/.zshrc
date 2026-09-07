# Live-session user shell. The real config is deployed by hyperdrive-apply-dotfiles
# after install; this is just a sane fallback for the live ISO.
autoload -Uz compinit && compinit -u
HISTSIZE=2000 SAVEHIST=2000 HISTFILE=~/.zsh_history
setopt appendhistory hist_ignore_dups
bindkey -e
alias ls='ls --color=auto'
alias ll='ls -lh'
alias vi='nvim'
