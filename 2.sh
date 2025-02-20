#!/usr/bin/env bash
# ---------------------------------------------------------------------------------------
# Bug Bounty VM Template Setup Script for Kali Linux / Debian-based Distros
# ---------------------------------------------------------------------------------------
# This script:
#  1. Installs a curated set of bug bounty tools.
#  2. Installs & configures ZSH, starship, powerlevel10k, fzf, zoxide, thefuck, eza, etc.
#  3. Replaces ~/.zshrc with a custom config that includes bug bounty aliases & functions.
#
# Usage:
#   chmod +x 2.sh
#   ./2.sh
#
# Recommended to run on a fresh Kali VM or Debian-based VM as a template.
#
# CAUTION: This script overwrites ~/.zshrc. Back up your existing ~/.zshrc if needed.
# ---------------------------------------------------------------------------------------

set -e

# 0. Preliminary Checks
if [[ "$EUID" -eq 0 ]]; then
  echo "Please do NOT run this script as root. Instead, run as a normal user with sudo privileges."
  exit 1
fi

if [[ -z "$(command -v apt)" ]]; then
  echo "ERROR: This script is meant for apt-based distros (Kali, Debian, Ubuntu). Exiting."
  exit 1
fi

# 1. Update Packages & Install Essentials
echo "[*] Updating package lists..."
sudo apt update -y

echo "[*] Installing base packages..."
sudo apt install -y \
  git curl wget python3 python3-pip build-essential \
  zsh fzf fd-find thefuck bat \
  sqlmap nmap amass dirsearch \
  libnotify-bin xclip jq

# On some distros, bat is named 'batcat', fd is 'fdfind', etc. Symlink them:
if [[ -x "$(command -v batcat)" && ! -x "$(command -v bat)" ]]; then
  sudo ln -sf "$(which batcat)" /usr/local/bin/bat
fi
if [[ -x "$(command -v fdfind)" && ! -x "$(command -v fd)" ]]; then
  sudo ln -sf "$(which fdfind)" /usr/local/bin/fd
fi

# 2. Install Go (if not installed) -- required for many bug bounty tools
if ! command -v go &> /dev/null; then
  echo "[*] Installing Golang (latest stable)..."
  GO_URL="https://go.dev/dl/$(curl -s https://go.dev/VERSION?m=text).linux-amd64.tar.gz"
  wget -q "$GO_URL" -O /tmp/go.tar.gz
  sudo tar -C /usr/local -xzf /tmp/go.tar.gz
  echo "export PATH=\$PATH:/usr/local/go/bin" | sudo tee /etc/profile.d/go.sh >/dev/null
  source /etc/profile.d/go.sh
fi

# Ensure Go is available to the current session
export PATH=$PATH:/usr/local/go/bin

# 3. Install Bug Bounty Tools via Go
echo "[*] Installing bug bounty tools with go get / go install..."

go install github.com/tomnomnom/assetfinder@latest
go install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go install github.com/projectdiscovery/httpx/cmd/httpx@latest
go install github.com/projectdiscovery/nuclei/v2/cmd/nuclei@latest
go install github.com/hahwul/dalfox@latest
go install github.com/tomnomnom/gf@latest
go install github.com/tomnomnom/httprobe@latest
go install github.com/tomnomnom/gau@latest
go install github.com/ffuf/ffuf@latest

# EZA (Better LS)
if ! command -v eza &> /dev/null; then
  echo "[*] Installing eza (enhanced 'ls')..."
  wget -qO eza.deb "https://github.com/eza-community/eza/releases/latest/download/eza_ubuntu_amd64.deb"
  sudo dpkg -i eza.deb && rm eza.deb
fi

# Zoxide
if ! command -v zoxide &> /dev/null; then
  echo "[*] Installing zoxide..."
  curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
  sudo mv ~/.zoxide/bin/zoxide /usr/local/bin/
fi

# Starship prompt
if ! command -v starship &> /dev/null; then
  echo "[*] Installing Starship prompt..."
  sh -c "$(curl -fsSL https://starship.rs/install.sh)" -- -y
fi

# Powerlevel10k
if [ ! -d /usr/local/share/powerlevel10k ]; then
  echo "[*] Cloning powerlevel10k..."
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

# 4. Optionally Make ZSH the Default Shell
if [[ "$SHELL" != *"zsh"* ]]; then
  echo "[*] Changing default shell to zsh..."
  chsh -s "$(which zsh)"
fi

# 5. Backup Existing ~/.zshrc & Write the New One
echo "[*] Backing up any existing ~/.zshrc to ~/.zshrc.bak..."
if [ -f "$HOME/.zshrc" ]; then
  mv "$HOME/.zshrc" "$HOME/.zshrc.bak_$(date +%F-%T)"
fi

echo "[*] Creating a new ~/.zshrc with custom bug bounty config..."

cat << 'EOF' > "$HOME/.zshrc"
# -----------------------------------------------------------------------------------------------
# BUG BOUNTY VM ZSHRC TEMPLATE
# -----------------------------------------------------------------------------------------------
# This ZSH configuration is designed for a Kali VM focused on bug bounty workflows.
# -----------------------------------------------------------------------------------------------

# Enable Powerlevel10k instant prompt. Must stay at the top for best performance.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# -----------------------------------------------------------------------------------------------
# PATH and Environment Variables Setup
# -----------------------------------------------------------------------------------------------
export PATH="$PATH:/usr/local/go/bin"
export PATH="$HOME/go/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"
export DISPLAY=:0

# Additional environment variables or custom tool paths can go below:
# e.g., export PATH="$HOME/tools/Scripts/Reconnaissance:$HOME/tools/Scripts/Vulnerability_Scanners:$PATH"

# -----------------------------------------------------------------------------------------------
# Dynamic Network Info Aliases & Variables
# -----------------------------------------------------------------------------------------------
dns=$(ip r | grep dhcp | awk '{print $3}')
extip=$(curl -s http://ifconfig.me)
ip=$(ifconfig | grep 'inet ' | awk 'NR==1{print $2}')
mac=$(ifconfig | grep ether | awk '{print $2}')

alias n='echo; echo -n "External IP:  $extip"; echo; echo -n "Internal IP:  $ip"; echo; echo -n "MAC address:  $mac"; echo; echo -n "DNS:          $dns"; echo; echo; netstat -ant; echo; ping -c3 8.8.8.8'

# Quick housekeeping aliases
alias c='clear'
alias cl='clear ; ls -lh --color=auto'
alias cla='clear ; ls -lah --color=auto'
alias h='cd $HOME/Desktop/ ; clear'
alias r='cd $HOME ; clear'
alias date='date +"%a %b %d, %Y - %r %Z"'
alias e='exit'

# Sort unique IP addresses
alias sip='sort -n -u -t . -k 1,1 -k 2,2 -k 3,3 -k 4,4'

# Python web servers
alias web='echo 127.0.0.1; python3 -m http.server 80'
alias web2='echo 127.0.0.1; python3 -m http.server 8000'

# -----------------------------------------------------------------------------------------------
# Bounty Tools & Aliases
# -----------------------------------------------------------------------------------------------

# Subdomain enumeration / Recon
function all_recon() {
    target=$1
    echo "Running subfinder, assetfinder, and amass for $target..."
    subfinder -d "$target" | httpx -silent -o subfinder_live_$target.txt
    assetfinder --subs-only "$target" | httpx -silent -o assetfinder_live_$target.txt
    amass enum -d "$target" | httpx -silent -o amass_live_$target.txt
    cat subfinder_live_$target.txt assetfinder_live_$target.txt amass_live_$target.txt | sort -u > combined_live_$target.txt
    echo "Combined live subdomains saved to combined_live_$target.txt"
}

alias subfinder_run='subfinder -d $1 -silent > subfinder_output.txt'
alias subfinder_live='subfinder -d $1 | httpx -silent -title -status-code'

# Quick recon
alias quickrecon='subfinder -d $1 | httpx -title -status-code'
alias httpx-toolkit='httpx -silent -timeout 10 -threads 50 -title -status-code'

# Nuclei
alias nuclei_update='nuclei -update-templates'
alias nuclei_scan='nuclei -t ~/nuclei-templates -u $1 -o nuclei_$1.txt'

# Port scanning
alias portscan='nmap -sC -sV -oN nmap_scan_$1.txt'

# SQL injection
alias sqlhunt="sqlmap --batch --level=5 --risk=3 -u $1"

# LFI fuzzing example
alias fuzz_lfi="cat parameters.txt | qsreplace FUZZ | while read url; do ffuf -u $url -w /usr/share/seclists/Fuzzing/LFI-payloads.txt -mr 'root:'; done"

# JavaScript file analysis
alias findjs='echo $1 | gau | grep "\.js$" > js_files.txt && while read js_url; do python3 /path/to/SecretFinder.py -i $js_url -o cli >> secrets.txt; done'

# Combined vulnerability scan function
function vulnscan() {
    domain=$1
    echo "Running combined vulnerability scan for $domain..."
    subfinder -d "$domain" | httpx -silent -o live_hosts_$domain.txt
    nuclei -t ~/nuclei-templates -l live_hosts_$domain.txt -o nuclei_$domain.txt
    echo "Scans completed. Results saved in nuclei_$domain.txt."
}

# Directory Brute Forcing
alias dirbrute="gobuster dir -u $1 -w /usr/share/seclists/Discovery/Web-Content/directory-list-2.3-medium.txt -t 50"
alias bruteforce_dir="dirsearch -l live_hosts.txt -w /usr/share/seclists/Discovery/Web-Content/directory-list-2.3-medium.txt -t 50 -o directory_results.txt"

# XSS Testing
alias xsshunt="cat $1 | dalfox pipe --no-color --skip-bav --mass --output dalfox_$1.txt"

# Create a new bug bounty project folder structure
function create_project() {
    project_name=$1
    mkdir -p "$HOME/BugBounty/$project_name"/{recon,scans,payloads,reports}
    echo "Project $project_name created with standard folder structure."
}

# Automated one-liners
alias quickscan="subfinder -d $1 | httpx -silent | nuclei -t ~/nuclei-templates -o results.txt"
alias auto_bounty="all_recon $1 && nuclei_scan $1 && sqlhunt $1 && xsshunt $1 && dirbrute $1"
alias auto_recon="all_recon $1 && quickscan $1"

# -----------------------------------------------------------------------------------------------
# Eza (Better ls) Aliases
# -----------------------------------------------------------------------------------------------
alias ls="eza --icons"
alias l="eza --icons"
alias ll="eza -lg --icons"
alias la="eza -lag --icons"
alias lt="eza -lTg --icons"
alias lt1="eza -lTg --level=1 --icons"
alias lt2="eza -lTg --level=2 --icons"
alias lt3="eza -lTg --level=3 --icons"
alias lta="eza -lTag --icons"
alias lta1="eza -lTag --level=1 --icons"
alias lta2="eza -lTag --level=2 --icons"
alias lta3="eza -lTag --level=3 --icons"

# -----------------------------------------------------------------------------------------------
# Powerlevel10k & Starship Prompt
# -----------------------------------------------------------------------------------------------
source /usr/local/share/powerlevel10k/powerlevel10k.zsh-theme
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

eval "$(starship init zsh)"

# -----------------------------------------------------------------------------------------------
# History Settings
# -----------------------------------------------------------------------------------------------
HISTFILE=$HOME/.zhistory
SAVEHIST=1000
HISTSIZE=999
setopt share_history
setopt hist_expire_dups_first
setopt hist_ignore_dups
setopt hist_verify

# Completion using arrow keys (based on history)
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward

# -----------------------------------------------------------------------------------------------
# Zoxide (Better cd)
# -----------------------------------------------------------------------------------------------
eval "$(zoxide init zsh)"
alias cd="z"

# -----------------------------------------------------------------------------------------------
# FZF Configuration
# -----------------------------------------------------------------------------------------------
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

# -----------------------------------------------------------------------------------------------
# Thefuck Alias
# -----------------------------------------------------------------------------------------------
eval $(thefuck --alias)
eval $(thefuck --alias fk)

# -----------------------------------------------------------------------------------------------
# zsh-autosuggestions & zsh-syntax-highlighting
# -----------------------------------------------------------------------------------------------
source /usr/local/opt/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/local/opt/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

EOF

echo "[*] Done! A new ~/.zshrc has been written."

# 6. Final Prompt
echo ""
echo "---------------------------------------------------------------------------------------"
echo "Setup Complete. Please log out or open a new terminal to start using your new Kali VM."
echo "Default shell is zsh now. All bug bounty tools & aliases installed!"
echo "---------------------------------------------------------------------------------------"
