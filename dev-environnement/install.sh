#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'


RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

INSTALL_ALL=false
TOOLS=(
    "Bun:install_bun"
    "Node.js:install_nodejs"
    "Rust:install_rust"
    "Go:install_go"
    "Docker:install_docker"
    "tldr:install_tldr"
    "Helix:install_helix"
    "ShellCheck:install_shellcheck"
    "Dioxus:install_dioxus"
    "Ghostty:install_ghostty"
    "Iriunwebcam:install_iriun_webcam"
    "DeepSeek-tui:install_deepseek"
    "flatpak:install_flatpaks"
    "Zed:install_zed"
)

function usage() {
    echo "Usage: $0 [OPTIONS] [TOOLS...]"
    echo ""
    echo "Options:"
    echo "  -a, --all       Installer tous les outils de développement sans confirmation"
    echo "  -l, --list      Lister les outils disponibles"
    echo "  -h, --help      Afficher cette aide"
    echo ""
    echo "Outils disponibles:"
    for tool in "${TOOLS[@]}"; do
        local name="${tool%:*}"
        echo "  $name"
    done
    echo ""
    echo "Exemples:"
    echo "  $0 --all                              # Tout installer"
    echo "  $0                                    # Mode interactif"
    echo "  $0 Docker Rust Go                     # Installer uniquement Docker, Rust et Go"
    echo "  $0 Node.js Bun Helix                  # Installer Node.js, Bun et Helix"
    exit 0
}

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
    local arch
    arch=$(uname -m)

    case "$arch" in
        x86_64) arch="amd64" ;;
        aarch64) arch="arm64" ;;
        armv6l|armv7l) arch="armv6l" ;;
        *) log_error "Architecture non supportée : $arch"; return 1 ;;
    esac

    local latest_version
    latest_version=$(curl -s https://go.dev/VERSION?m=text | head -n1)
    if [ -z "$latest_version" ]; then
        log_error "Impossible de déterminer la dernière version de Go."
        return 1
    fi

    local filename="${latest_version}.linux-${arch}.tar.gz"
    local url="https://go.dev/dl/${filename}"

    log_info "Téléchargement de $filename..."
    archive_file=$(mktemp "/tmp/${filename}")
    curl -L -o "$archive_file" "$url" || {
        log_error "Échec du téléchargement de Go."
        rm -f "$archive_file"
        return 1
    }

    log_info "Installation de Go dans /usr/local..."
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf "$archive_file"

    export PATH=$PATH:/usr/local/go/bin

    local path_export="export PATH=$PATH:/usr/local/go/bin"
    local shell_rc

    if [ -n "$ZSH_VERSION" ]; then
        shell_rc="$HOME/.zshrc"
    elif [ -n "$BASH_VERSION" ]; then
        shell_rc="$HOME/.bashrc"
    else
        shell_rc="$HOME/.profile"
    fi

    if ! grep -q "/usr/local/go/bin" "$shell_rc" 2>/dev/null; then
        log_info "Configuration des variables d'environnement dans $shell_rc..."
        log_info "# Ajout de Go au PATH\n$path_export" >> "$shell_rc"
    fi

    [[ "$archive_file" == /tmp/* ]] && rm -f "$archive_file"
}

function install_nodejs() {
    log_info "Installation de Node.js..."

    if [[ ! -d "$HOME/.nvm" ]]; then
        if curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash; then
            export NVM_DIR="$HOME/.nvm"
            # shellcheck disable=SC1091
            [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
            log_success "nvm installé"
        else
            log_error "Échec de l'installation de nvm"
            return 1
        fi
    fi

    # Charger nvm
    set +u
    export NVM_DIR="$HOME/.nvm"
    # shellcheck disable=SC1091
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    set -u
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
        # shellcheck disable=SC1091
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

function install_deepseek() {
    log_info "Installation de DeepSeek..."
    if cargo install deepseek-tui --locked; then
        log_success "DeepSeek installé"
        echo "DeepSeek version: $(deepseek-tui --version 2>/dev/null || echo "Non détecté")"
    else
        log_error "Échec de l'installation de DeepSeek"
        return 1
    fi
}

function install_dioxus() {
    log_info "Installation de Dioxus..."
    if cargo binstall dioxus-cli --force; then
        log_success "Dioxus installé"
        echo "Dioxus version: $(dx --version 2>/dev/null || echo "Non détecté")"
    else
        log_error "Échec de l'installation de Dioxus"
        return 1
    fi
}

function install_docker() {
    sudo apt update
    sudo apt install -y ca-certificates curl gnupg

    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    # shellcheck disable=SC1091
    OS_RELEASE_CODE=$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
    https://download.docker.com/linux/ubuntu \
    $OS_RELEASE_CODE stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

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
    sudo add-apt-repository ppa:zhangsongcui3371/fastfetch
    sudo apt update
    sudo apt install -y fastfetch
    log_success "fastfetch installé"
}

function install_ghostty() {
    log_info "Installation de ghostty..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/mkasberg/ghostty-ubuntu/HEAD/install.sh)"
    log_success "ghostty installé"
}

function install_iriun_webcam() {
    log_info "Installation de Iriun Webcam..."
    wget -O iriun.deb "https://iriun.gitlab.io/iriunwebcam-2.9.1.deb"
    sudo apt install -y ./iriun.deb
    log_success "Iriun Webcam installé"
}

function install_flatpaks() {
    log_info "Installation des paquets Flatpak..."
    xargs -a ~/liste_flatpaks.txt flatpak install --system -y
    log_success "Flatpak installé"
}

function install_zed() {
    log_info "Installation de Zed..."
    curl -f https://zed.dev/install.sh | sh
    log_success "Zed installé"
}

function install_all_tools() {
    log_info "Installation de tous les outils de développement..."
    for tool in "${TOOLS[@]}"; do
        local name="${tool%:*}"
        local func="${tool#*:}"
        log_info "Installation de $name..."
        if $func; then
            log_success "$name installé avec succès"
        else
            log_error "Échec de l'installation de $name"
        fi
    done
}

function install_dev_tools_interactive() {
    log_info "Installation des outils de développement..."

    read -p "Voulez-vous installer les outils de développement? (Go, Node.js, Rust, Docker, etc.) [y/n/A (all)] " -n 1 -r
    echo

    case "$REPLY" in
        [Aa]*)
            install_all_tools
            return
            ;;
        [Nn]*)
            log_info "Installation des outils de développement ignorée."
            return
            ;;
        [Yy]*)
            for tool in "${TOOLS[@]}"; do
                local name="${tool%:*}"
                local func="${tool#*:}"
                read -p "Installer $name? (y/n) " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    log_info "Installation de $name..."
                    if $func; then
                        log_success "$name installé avec succès"
                    else
                        log_error "Échec de l'installation de $name"
                    fi
                fi
            done
            ;;
        *)
            log_info "Installation des outils de développement ignorée."
            return
            ;;
    esac
}

function main() {
    local selected_tools=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -a|--all)
                INSTALL_ALL=true
                shift
                ;;
            -l|--list)
                log_info "Outils disponibles:"
                for tool in "${TOOLS[@]}"; do
                    echo "  ${tool%:*}"
                done
                exit 0
                ;;
            -h|--help)
                usage
                ;;
            -*)
                log_error "Option inconnue : $1"
                usage
                ;;
            *)
                selected_tools+=("$1")
                shift
                ;;
        esac
    done

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

    # Installer les outils de développement
    if [[ "$INSTALL_ALL" == true ]]; then
        install_all_tools
    elif [[ ${#selected_tools[@]} -gt 0 ]]; then
        log_info "Installation des outils sélectionnés..."
        for selected in "${selected_tools[@]}"; do
            local found=false
            for tool in "${TOOLS[@]}"; do
                local name="${tool%:*}"
                local func="${tool#*:}"
                if [[ "${selected,,}" == "${name,,}" ]]; then
                    found=true
                    log_info "Installation de $name..."
                    if $func; then
                        log_success "$name installé avec succès"
                    else
                        log_error "Échec de l'installation de $name"
                    fi
                    break
                fi
            done
            if [[ "$found" == false ]]; then
                log_warning "Outil inconnu : '$selected'"
                log_info "Utilisez --list pour voir les outils disponibles"
            fi
        done
    else
        install_dev_tools_interactive
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
