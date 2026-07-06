export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="starship"

plugins=(
  bun
  composer
  deno
  direnv
  docker
  docker-compose
  dotenv
  eza
  frontend-search
  fzf
  gh
  git
  gitignore
  laravel
  man
  mise
  node
  npm
  pip
  postgres
  python
  rust
  ssh
  sudo
  tldr
  ufw
  vscode
  yarn
  yazi
  zsh-autosuggestions
  zsh-history-substring-search
  zsh-interactive-cd
  zsh-navigation-tools
  zsh-syntax-highlighting
)

source $ZSH/oh-my-zsh.sh

export EDITOR="nvim"
export STARSHIP_CONFIG="$HOME/.config/starship/starship-streamline.toml"

eval "$(mise activate zsh)"
eval "$(zoxide init zsh)"
eval "$(~/.local/share/pvm/bin/pvm env)"
eval "$(zellij setup --generate-auto-start zsh)"
eval "$(atuin init zsh)"
