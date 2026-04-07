# eza (modern ls)
alias ls='eza'
alias ll='eza -alF --git'
alias tree='eza --tree'

# bat (modern cat)
alias cat='bat --paging=never'
alias rm='rm -i'
alias mv='mv -i'
alias cp='cp -iv'
alias vi='vim'
alias ex='vim'
alias pstree='pstree -Ap'
alias gcd='cd "$(git rev-parse --show-toplevel)"'

# kubectl
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get svc'
alias kgn='kubectl get nodes'
alias kns='kubens'
alias kctx='kubectx'

# python / uv
alias py='python3'
alias uvr='uv run'
