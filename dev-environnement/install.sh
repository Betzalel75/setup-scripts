#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'


RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' 

function log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

function log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

function log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

function log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

function is_installed() {
    command -v "$1" >/dev/null 2>&1
}

function install_go() {
    log_info "Installation de Go..."
    if [[ -f /tmp/go-installer.sh ]]; then
        rm -f /tmp/go-installer.sh
    fi
    
    if curl -sL https://git.io/go-installer.sh -o /tmp/go-installer.sh; then
        chmod +x /tmp/go-installer.sh
        bash /tmp/go-installer.sh
        log_success "Go installé avec succès"
    else
        log_error "Échec du téléchargement de l'installateur Go"
        return 1
    fi
}

function install_nodejs() {
    log_info "Installation de Node.js..."
    
    # Vérifier si nvm est déjà installé
    if [[ ! -d "$HOME/.nvm" ]]; then
        if curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash; then
            export NVM_DIR="$HOME/.nvm"
            [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
            log_success "nvm installé"
        else
            log_error "Échec de l'installation de nvm"
            return 1
        fi
    fi
    
    # Charger nvm
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    
    # Installer Node.js
    if nvm install --lts; then
        nvm use --lts
        nvm alias default --lts
        log_success "Node.js lts installé"
        echo "Node.js version: $(node -v)"
        echo "npm version: $(npm -v)"
    else
        log_error "Échec de l'installation de Node.js"
        return 1
    fi
}

function install_bun() {
    log_info "Installation de Bun..."
    if curl -fsSL https://bun.sh/install | bash; then
        export BUN_INSTALL="$HOME/.bun"
        export PATH="$BUN_INSTALL/bin:$PATH"
        log_success "Bun installé"
        echo "Bun version: $(bun --version 2>/dev/null || echo "Non détecté")"
    else
        log_error "Échec de l'installation de Bun"
        return 1
    fi
}

function install_rust() {
    log_info "Installation de Rust..."
    if curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y; then
        source "$HOME/.cargo/env"
        log_success "Rust installé"
        echo "Rust version: $(rustc --version 2>/dev/null || echo "Non détecté")"
    else
        log_error "Échec de l'installation de Rust"
        return 1
    fi
}

function install_tldr() {
    log_info "Installation de tldr..."
    if cargo install tlrc --locked; then
        log_success "tldr installé"
        echo "tldr version: $(tldr --version 2>/dev/null || echo "Non détecté")"
    else
        log_error "Échec de l'installation de tldr"
        return 1
    fi
}

function install_docker() {
    log_info "Installation de Docker..."
    
    if is_installed docker; then
        log_warning "Docker est déjà installé"
        return 0
    fi
    
    sudo apt update
    sudo apt install -y ca-certificates curl gnupg
    
    # Ajouter la clé GPG
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
    
    # Ajouter le repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
    https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Démarrer Docker
    sudo systemctl enable --now docker
    sudo systemctl start docker
    
    sudo usermod -aG docker "$USER"
    
    log_success "Docker installé"
    echo "Docker version: $(docker --version)"
    
    log_warning "Vous devez vous déconnecter et reconnecter pour que les permissions Docker soient appliquées"
}

function install_helix() {
    log_info "Installation de Helix..."
    sudo add-apt-repository ppa:maveonair/helix-editor
    sudo apt update
    sudo apt install helix
}

function install_shellcheck() {
    log_info "Installation de ShellCheck..."
    sudo apt install shellcheck
}

function install_font() {
    log_info "Installation des polices..."
    
    FONTS_DIR="$HOME/.local/share/fonts"
    mkdir -p "$FONTS_DIR"
    
    local fonts=(
        "JetBrainsMono"
        "Go-Mono"
        "Hack"
    )
    
    for font in "${fonts[@]}"; do
        log_info "Installation de $font..."
        local zip_file="/tmp/${font}.zip"
        local extract_dir="/tmp/${font}"
        
        # Télécharger et extraire
        if wget -q "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/${font}.zip" -O "$zip_file"; then
            mkdir -p "$extract_dir"
            unzip -q -o "$zip_file" -d "$extract_dir"
            
            # Copier les polices
            find "$extract_dir" -name "*.ttf" -o -name "*.otf" | while read -r font_file; do
                cp "$font_file" "$FONTS_DIR/"
            done
            
            log_success "$font installée"
        else
            log_error "Échec du téléchargement de $font"
        fi
    done
    
    fc-cache -fv
    log_success "Polices installées et cache mis à jour"
}

function install_fastfetch() {
    log_info "Installation de fastfetch..."
    sudo apt install -y fastfetch
    log_success "fastfetch installé"
}

function main() {
    log_info "Début de l'installation..."
    
    if [[ $EUID -eq 0 ]]; then
        log_warning "Le script est exécuté en tant que root"
        log_warning "Certaines installations (nvm, rustup) peuvent ne pas fonctionner correctement"
        read -p "Voulez-vous continuer? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    log_info "Mise à jour des paquets apt..."
    sudo apt update
    
    log_info "Installation des outils de base..."
    sudo apt install -y gpg curl wget git unzip axel
    
    # Installer eza
    log_info "Installation de eza..."
    sudo mkdir -p /etc/apt/keyrings
    wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | \
        sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
    
    echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | \
        sudo tee /etc/apt/sources.list.d/gierens.list
    
    sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
    sudo apt update
    sudo apt install -y eza
    
    # Installer starship
    log_info "Installation de Starship..."
    if curl -sS https://starship.rs/install.sh | sh -s -- -y; then
        mkdir -p ~/.config
        if wget -q https://raw.githubusercontent.com/Betzalel75/setup-scripts/refs/heads/main/dev-environnement/starship.toml -O ~/.config/starship.toml; then
            log_success "Configuration Starship téléchargée"
        fi
    fi
    
    # Installer zsh
    log_info "Installation de Zsh..."
    sudo apt install -y zsh fonts-powerline
    
    # Installer oh-my-zsh
    log_info "Installation de Oh My Zsh..."
    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    fi
    
    # Installer les plugins Zsh
    log_info "Installation des plugins Zsh..."
    
    local zsh_custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
    
    # Zsh Autosuggestions
    if [[ ! -d "$zsh_custom/plugins/zsh-autosuggestions" ]]; then
        git clone https://github.com/zsh-users/zsh-autosuggestions "$zsh_custom/plugins/zsh-autosuggestions"
    fi
    
    # Zsh Syntax Highlighting
    if [[ ! -d "$zsh_custom/plugins/zsh-syntax-highlighting" ]]; then
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$zsh_custom/plugins/zsh-syntax-highlighting"
    fi
    
    # Télécharger la configuration personnalisée
    log_info "Configuration de Zsh..."
    if wget -q https://raw.githubusercontent.com/Betzalel75/setup-scripts/refs/heads/main/dev-environnement/zshrc -O ~/.zshrc; then
        log_success "Configuration Zsh téléchargée"
    fi
    
    if wget -q https://raw.githubusercontent.com/Betzalel75/setup-scripts/refs/heads/main/dev-environnement/aliases.zsh -O "$zsh_custom/aliases.zsh"; then
        log_success "Aliases téléchargés"
    fi
    
    # Installer les polices
    install_font
    
    # Installer zsh-history-substring-search
    if [[ ! -d "$zsh_custom/plugins/zsh-history-substring-search" ]]; then
        git clone https://github.com/zsh-users/zsh-history-substring-search.git "$zsh_custom/plugins/zsh-history-substring-search"
    fi
    
    # Proposer l'installation des outils de développement
    log_info "Installation des outils de développement..."
    
    read -p "Voulez-vous installer les outils de développement? (Go, Node.js, Rust, Docker, etc.) (y/n) " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        local tools=(
            "Bun:install_bun"
            "Node.js:install_nodejs"
            "Rust:install_rust"
            "Go:install_go"
            "Docker:install_docker"
            "tldr:install_tldr"
            "Helix:install_helix"
            "ShellCheck:install_shellcheck"
        )
        
        for tool in "${tools[@]}"; do
            local name="${tool%:*}"
            local function="${tool#*:}"
            
            read -p "Installer $name? (y/n) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                log_info "Installation de $name..."
                if $function; then
                    log_success "$name installé avec succès"
                else
                    log_error "Échec de l'installation de $name"
                fi
            fi
        done
    fi
    
    # Changer le shell par défaut
    if [[ $(basename "$SHELL") != "zsh" ]]; then
        log_info "Changement du shell par défaut vers Zsh..."
        chsh -s "$(which zsh)"
        log_success "Shell changé vers Zsh"
        log_warning "Vous devez vous déconnecter et reconnecter pour que le changement prenne effet"
    fi
    
    # Installation de fastfetch
    install_fastfetch
    
    log_success "🎉Installation terminée!"
    echo ""
    echo "Résumé:"
    echo "- Zsh et Oh My Zsh installés"
    echo "- Starship et eza configurés"
    echo "- Plugins Zsh installés"
    echo "- Polices Nerd Fonts installées"
    echo ""
    echo "Prochaines étapes:"
    echo "1. Déconnectez-vous et reconnectez-vous"
    echo "2. Exécutez 'source ~/.zshrc'"
    echo "3. Profitez de votre nouvel environnement!"
}

main "$@"