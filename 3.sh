#!/usr/bin/env bash
# -------------------------------------------------------------------------------
# Title: Kali Bug Bounty "Game Changer" Automation
# -------------------------------------------------------------------------------
# Description:
#   This script transforms a fresh Kali VM into a powerful bug bounty machine:
#    1. Installs essential bug bounty tools (Subfinder, Amass, Assetfinder, etc.)
#    2. Clones & configures advanced recon frameworks (e.g., ReconFTW)
#    3. Sets up Docker-based workflows for ephemeral usage of specialized tools
#    4. Configures a polished ZSH environment (powerlevel10k, starship, zsh-autosuggestions)
#    5. Creates a single "manage_tools" script for easy updating & usage
# 
# Usage:
#   chmod +x 3.sh
#   ./3.sh
# 
# Afterward, log out or open a new terminal. Tools & environment should be ready.
# 
# NOTES:
#   - This script overwrites your ~/.zshrc
#   - Recommended for a fresh Kali VM, run as a NON-ROOT user with sudo privileges
# -------------------------------------------------------------------------------

set -e

#############################################
# 0. PRELIMINARY CHECKS
#############################################
if [[ "$EUID" -eq 0 ]]; then
  echo "Please run this script as a normal user (non-root) with sudo privileges, not as root."
  exit 1
fi
if [[ -z "$(command -v apt)" ]]; then
  echo "ERROR: This script is intended for apt-based systems (Kali, Debian, Ubuntu)."
  exit 1
fi

#############################################
# 1. UPDATE & INSTALL BASE PACKAGES
#############################################
echo "[*] Updating packages..."
sudo apt update -y && sudo apt full-upgrade -y

echo "[*] Installing essential packages..."
sudo apt install -y \
    git curl wget python3 python3-pip build-essential \
    zsh fzf fd-find thefuck bat jq \
    sqlmap nmap amass dirsearch \
    docker.io docker-compose \
    libnotify-bin xclip

# On some distros, 'bat' is 'batcat' and 'fd' is 'fdfind'. Symlink them if needed.
if [[ -x "$(command -v batcat)" && ! -x "$(command -v bat)" ]]; then
  sudo ln -sf "$(which batcat)" /usr/local/bin/bat
fi
if [[ -x "$(command -v fdfind)" && ! -x "$(command -v fd)" ]]; then
  sudo ln -sf "$(which fdfind)" /usr/local/bin/fd
fi

# Enable Docker service
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker "$USER"  # add current user to Docker group (need re-login)

#############################################
# 2. INSTALL GOLANG (IF NOT INSTALLED)
#############################################
if ! command -v go &> /dev/null; then
  echo "[*] Installing Golang (latest version)..."
  GO_URL="https://go.dev/dl/$(curl -s https://go.dev/VERSION?m=text).linux-amd64.tar.gz"
  wget -qO /tmp/go.tar.gz "$GO_URL"
  sudo tar -C /usr/local -xzf /tmp/go.tar.gz
  echo "export PATH=\$PATH:/usr/local/go/bin" | sudo tee /etc/profile.d/go.sh >/dev/null
  source /etc/profile.d/go.sh
fi

export PATH=$PATH:/usr/local/go/bin

#############################################
# 3. INSTALL BUG BOUNTY TOOLS VIA GO
#############################################
echo "[*] Installing bug bounty tools with go..."
go install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go install github.com/hahwul/dalfox@latest
go install github.com/ffuf/ffuf@latest
go install github.com/tomnomnom/assetfinder@latest
go install github.com/projectdiscovery/httpx/cmd/httpx@latest
go install github.com/projectdiscovery/nuclei/v2/cmd/nuclei@latest
go install github.com/tomnomnom/gf@latest
go install github.com/tomnomnom/httprobe@latest
go install github.com/tomnomnom/gau@latest

# EZA (enhanced ls)
if ! command -v eza &> /dev/null; then
  echo "[*] Installing eza..."
  wget -qO eza.deb "https://github.com/eza-community/eza/releases/latest/download/eza_ubuntu_amd64.deb"
  sudo dpkg -i eza.deb && rm eza.deb
fi

# Zoxide
if ! command -v zoxide &> /dev/null; then
  echo "[*] Installing zoxide..."
  curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
  sudo mv ~/.zoxide/bin/zoxide /usr/local/bin/
fi

# Starship Prompt
if ! command -v starship &> /dev/null; then
  echo "[*] Installing Starship prompt..."
  sh -c "$(curl -fsSL https://starship.rs/install.sh)" -- -y
fi

# Powerlevel10k
if [ ! -d /usr/local/share/powerlevel10k ]; then
  echo "[*] Installing Powerlevel10k..."
  sudo git clone --depth=1 https://github.com/romkatv/powerlevel10k.git /usr/local/share/powerlevel10k
fi

# zsh-autosuggestions
if [ ! -d /usr/local/opt/zsh-autosuggestions ]; then
  echo "[*] Installing zsh-autosuggestions..."
  sudo git clone https://github.com/zsh-users/zsh-autosuggestions /usr/local/opt/zsh-autosuggestions
fi

# zsh-syntax-highlighting
if [ ! -d /usr/local/opt/zsh-syntax-highlighting ]; then
  echo "[*] Installing zsh-syntax-highlighting..."
  sudo git clone https://github.com/zsh-users/zsh-syntax-highlighting.git /usr/local/opt/zsh-syntax-highlighting
fi

#############################################
# 4. CLONE & SETUP RECONFTW (ADVANCED FRAMEWORK)
#############################################
if [ ! -d "$HOME/tools" ]; then
  mkdir -p "$HOME/tools"
fi

if [ ! -d "$HOME/tools/ReconFTW" ]; then
  echo "[*] Cloning ReconFTW..."
  git clone https://github.com/six2dez/reconftw.git "$HOME/tools/ReconFTW"
  cd "$HOME/tools/ReconFTW"
  sudo bash install.sh  # This runs the official ReconFTW installer script
  cd ~
fi

#############################################
# 5. CREATE A "MANAGE_TOOLS" SCRIPT
#############################################
# This script will let you easily update or run certain tools from one place
cat << 'EOS' > "$HOME/manage_tools.sh"
#!/usr/bin/env bash
# -------------------------------------------------------------------------
# A helper script to update and manage bug bounty tools in one command.
# Usage:
#   ./manage_tools.sh update   -> Updates all bug bounty tools
#   ./manage_tools.sh reconftw -> Runs ReconFTW interactive usage message
# -------------------------------------------------------------------------

TOOLS_INSTALL_DIR="$HOME/go/bin"
NUCLEI_TEMPLATES_DIR="$HOME/nuclei-templates"

function update_tools() {
  echo "[*] Updating GO-based tools..."
  go install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
  go install github.com/hahwul/dalfox@latest
  go install github.com/ffuf/ffuf@latest
  go install github.com/tomnomnom/assetfinder@latest
  go install github.com/projectdiscovery/httpx/cmd/httpx@latest
  go install github.com/projectdiscovery/nuclei/v2/cmd/nuclei@latest
  go install github.com/tomnomnom/gf@latest
  go install github.com/tomnomnom/httprobe@latest
  go install github.com/tomnomnom/gau@latest

  if [ -x "$(command -v nuclei)" ]; then
    echo "[*] Updating Nuclei templates..."
    nuclei -update-templates
  fi

  echo "[*] Updating ReconFTW..."
  if [ -d "$HOME/tools/ReconFTW" ]; then
    cd "$HOME/tools/ReconFTW" && git pull
    sudo bash install.sh
    cd ~
  fi

  echo "[*] All updates complete!"
}

case "$1" in
  update)
    update_tools
    ;;
  reconftw)
    echo "[*] ReconFTW usage examples:"
    echo "    cd ~/tools/ReconFTW && ./reconftw.sh -d example.com -r full"
    echo "    ./reconftw.sh -d example.com -r sub,all -o /path/to/output/"
    ;;
  *)
    echo "[*] Usage: $0 [update | reconftw]"
    echo "    update   -> Update all bug bounty tools (GO-based, ReconFTW, Nuclei templates)"
    echo "    reconftw -> Display common usage examples for ReconFTW"
    ;;
esac
EOS

chmod +x "$HOME/manage_tools.sh"

#############################################
# 6. SET ZSH AS DEFAULT SHELL
#############################################
if [[ "$SHELL" != *"zsh"* ]]; then
  echo "[*] Changing default shell to zsh..."
  chsh -s "$(which zsh)"
fi

#############################################
# 7. OVERWRITE ~/.zshrc WITH BUG BOUNTY CONFIG
#############################################
if [ -f "$HOME/.zshrc" ]; then
  mv "$HOME/.zshrc" "$HOME/.zshrc.bak_$(date +%F-%T)"
fi

echo "[*] Creating new ~/.zshrc with advanced bug bounty environment..."

cat << 'EOF' > "$HOME/.zshrc"
# -------------------------------------------------------------------------------
# Kali Bug Bounty "Game Changer" ZSHRC
# -------------------------------------------------------------------------------
# - Powerlevel10k or Starship for prompt
# - Comprehensive aliases for recon & scanning
# - Docker integration
# - ReconFTW quick usage
# -------------------------------------------------------------------------------

# Powerlevel10k Instant Prompt
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ZSH ENV
export PATH="$PATH:/usr/local/go/bin"
export PATH="$HOME/go/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"

# Docker setup
if ! groups | grep -qw "docker"; then
    echo "WARNING: Current user not in 'docker' group. Please re-login or run 'sudo usermod -aG docker $USER' and log out/in."
fi

# Basic Aliases
alias c='clear'
alias cl='clear; ls -lh --color=auto'
alias cla='clear; ls -lah --color=auto'
alias e='exit'
alias l="eza --icons"
alias ls="eza --icons"
alias ll="eza -lg --icons"
alias la="eza -lag --icons"

# Sort unique IPs
alias sip='sort -n -u -t . -k1,1 -k2,2 -k3,3 -k4,4'

# Python simple servers
alias web='python3 -m http.server 80'
alias web2='python3 -m http.server 8000'

# Bug Bounty Tools Aliases
alias subfinder_run='subfinder -d $1 -silent > subfinder_output.txt'
alias httpx-toolkit='httpx -silent -threads 50 -title -status-code'
alias nuclei_update='nuclei -update-templates && nuclei'
alias portscan='nmap -sC -sV -oN nmap_scan_$1.txt'
alias dirbrute='gobuster dir -u $1 -w /usr/share/seclists/Discovery/Web-Content/common.txt -t 50'
alias xsshunt='cat $1 | dalfox pipe --no-color --skip-bav --mass --output dalfox_$1.txt'
alias findjs='echo $1 | gau | grep "\.js$" > js_files.txt && while read js_url; do echo "Analyzing: $js_url"; done'

# ReconFTW direct alias
alias reconftw='cd ~/tools/ReconFTW && ./reconftw.sh'

# Manage Tools Script
alias update_tools="~/manage_tools.sh update"

# All-In-One Recon
function all_recon() {
    domain=$1
    echo "[*] Running subfinder, assetfinder, amass..."
    subfinder -d "$domain" | httpx -silent -o subfinder_$domain.txt
    assetfinder --subs-only "$domain" | httpx -silent -o assetfinder_$domain.txt
    amass enum -d "$domain" | httpx -silent -o amass_$domain.txt
    cat subfinder_$domain.txt assetfinder_$domain.txt amass_$domain.txt | sort -u > combined_$domain.txt
    echo "[*] Combined subdomains -> combined_$domain.txt"
}

# Docker-based usage examples
alias docker_ffuf='docker run -it --rm ffuf/ffuf'
alias docker_nmap='docker run -it --rm uzyexe/nmap'
# (These can be expanded or replaced with custom docker images)

# Powerlevel10k & Starship
source /usr/local/share/powerlevel10k/powerlevel10k.zsh-theme
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh
eval "$(starship init zsh)"

# zsh-autosuggestions & syntax-highlighting
source /usr/local/opt/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/local/opt/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# zsh history settings
HISTFILE=$HOME/.zhistory
HISTSIZE=9999
SAVEHIST=9999
setopt share_history
setopt hist_expire_dups_first
setopt hist_ignore_dups
setopt hist_verify

# fzf & zoxide
eval "$(zoxide init zsh)"
eval "$(fzf --completion zsh)"

export FZF_DEFAULT_COMMAND="fd --hidden --strip-cwd-prefix --exclude .git"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND="fd --type=d --hidden --strip-cwd-prefix --exclude .git"

show_file_or_dir_preview="if [ -d {} ]; then eza --tree --color=always {} | head -200; else bat -n --color=always --line-range :500 {}; fi"
export FZF_DEFAULT_OPTS="--color=fg:#CBE0F0,bg:#011628,hl:#B388FF,fg+:#CBE0F0,bg+:#143652,hl+:#B388FF,info:#06BCE4,prompt:#2CF9ED,pointer:#2CF9ED,marker:#2CF9ED,spinner:#2CF9ED,header:#2CF9ED"
export FZF_CTRL_T_OPTS="--preview '$show_file_or_dir_preview'"
export FZF_ALT_C_OPTS="--preview 'eza --tree --color=always {} | head -200'"

_fzf_comprun() {
  local command=$1
  shift
  case "$command" in
    cd)           fzf --preview 'eza --tree --color=always {} | head -200' "$@" ;;
    export|unset) fzf --preview "eval 'echo ${}'"         "$@" ;;
    ssh)          fzf --preview 'dig {}'                  "$@" ;;
    *)            fzf --preview "$show_file_or_dir_preview" "$@" ;;
  esac
}

eval $(thefuck --alias)
eval $(thefuck --alias fk)

EOF

#############################################
# 8. DONE
#############################################
echo ""
echo "============================================================"
echo "Kali Bug Bounty 'Game Changer' Automation completed!"
echo "1) Re-login or open a new terminal to use ZSH + Docker + Tools."
echo "2) Tools installed in ~/go/bin, Docker group updated for $USER."
echo "3) manage_tools.sh -> for updates & ReconFTW usage."
echo "Happy Hunting!"
echo "============================================================"
