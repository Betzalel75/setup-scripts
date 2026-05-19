#!/usr/bin/env bash

# ==============================================
# Script d'installation des outils de cybersécurité
# pour Linux Mint / Ubuntu
# Auteur : DeepSeek
# Usage : sudo bash install_sec_tools.sh
# ==============================================

set -euo pipefail


RESET="\033[0m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
CYAN="\033[36m"
BOLD="\033[1m"


REAL_USER=${SUDO_USER:-$USER}
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

log_info() {
    echo -e "${BLUE}[INFO]${RESET} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${RESET} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${RESET} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${RESET} $1" >&2
}

log_step() {
    echo -e "\n${CYAN}${BOLD}==> $1${RESET}\n"
}


if [[ $EUID -ne 0 ]]; then
    log_error "Ce script doit être exécuté avec sudo (ou en tant que root)."
    exit 1
fi


if ! grep -qi "ubuntu\|mint" /etc/os-release; then
    log_warning "Ce script est optimisé pour Ubuntu / Linux Mint. Il peut fonctionner sur d'autres distributions, mais certaines commandes pourraient échouer."
fi


log_step "Mise à jour des dépôts APT"
apt update -y

# -------------------------------------------------------------------
# 1. Outils réseau et analyse
# -------------------------------------------------------------------

log_step "Installation des outils réseau et analyse"

apt install -y \
    wireshark \
    nmap \
    socat \
    dnsutils \
    whois \
    arp-scan \
    netdiscover \
    proxychains4 \
    tmux \
    ffuf

# Configuration de Wireshark pour permettre la capture sans root (déjà demandé à l'installation)
log_info "Wireshark : si vous n'avez pas autorisé les non-root à capturer, exécutez 'sudo dpkg-reconfigure wireshark-common' plus tard."
sudo usermod -aG wireshark "$REAL_USER"
log_warning "Vous devrez redémarrer votre session pour que les changements prennent effet."
# -------------------------------------------------------------------
# 2. Outils web (ZAP)
# -------------------------------------------------------------------
log_step "Installation d'OWASP ZAP (alternative à Burp)"
flatpak install flathub org.zaproxy.ZAP --system -y

# -------------------------------------------------------------------
# 3. Brute-force / cracking
# -------------------------------------------------------------------
log_step "Installation des outils de brute-force et cracking"
apt install -y \
    hashcat \
    john \
    hydra

# -------------------------------------------------------------------
# 4. Metasploit Framework
# -------------------------------------------------------------------

log_step "Installation de Metasploit Framework"
if command -v msfconsole &> /dev/null; then
    log_success "Metasploit est déjà installé."
else
    log_info "Téléchargement et installation du script Metasploit..."
    apt install gpgv autoconf bison build-essential postgresql libaprutil1 libgmp3-dev libpcap-dev openssl libpq-dev libreadline6-dev libsqlite3-dev libssl-dev locate libsvn1 libtool libxml2 libxml2-dev libxslt-dev wget libyaml-dev ncurses-dev  postgresql-contrib xsel zlib1g zlib1g-dev curl -y
    curl https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb > msfinstall
    chmod +x msfinstall
    ./msfinstall
    rm msfinstall
    log_success "Metasploit installé."
fi

# -------------------------------------------------------------------
# 5. Outils Python via pipx (impacket, bloodhound, pwntools, crackmapexec)
# -------------------------------------------------------------------

log_step "Installation des outils Python avec pipx pour l'utilisateur $REAL_USER"

if ! command -v pipx &> /dev/null; then
    apt install -y pipx
    pipx ensurepath
    export PATH="$PATH:$REAL_HOME/.local/bin"
fi


sudo -u "$REAL_USER" pipx ensurepath

sudo -u "$REAL_USER" pipx install impacket
sudo -u "$REAL_USER" pipx install bloodhound
sudo -u "$REAL_USER" pipx install pwntools
sudo -u "$REAL_USER" pipx install git+https://github.com/Pennyw0rth/NetExec.git
log_success "Outils Python installés."

# -------------------------------------------------------------------
# 6. Reverse engineering
# -------------------------------------------------------------------

log_step "Installation des outils de reverse engineering"

apt install -y radare2
flatpak install flathub org.ghidra_sre.Ghidra  --system -y

# -------------------------------------------------------------------
# 7. OSINT
# -------------------------------------------------------------------

log_step "Installation des outils OSINT"

# Installation de theHarvester
if command -v theharvester &> /dev/null; then
    log_success "theHarvester est déjà installé."
else
    log_info "Installation de theHarvester depuis GitHub..."
    apt install -y git python3-venv
    cd /opt
    git clone https://github.com/laramies/theHarvester.git
    cd theHarvester
    python3 -m venv venv
    venv/bin/pip install .
    ln -sf /opt/theHarvester/venv/bin/theHarvester /usr/local/bin/theharvester
    log_success "theHarvester installé."
fi

# Installation de Recon-ng
if command -v recon-ng &> /dev/null; then
    log_success "Recon-ng est déjà installé."
else
    log_info "Installation de Recon-ng depuis GitHub..."
    cd /opt
    git clone https://github.com/lanmaster53/recon-ng.git
    cd recon-ng
    python3 -m venv venv
    venv/bin/pip install -r REQUIREMENTS
    ln -sf /opt/recon-ng/venv/bin/recon-ng /usr/local/bin/recon-ng
    log_success "Recon-ng installé."
fi


# Maltego : téléchargement du .deb officiel
if ! command -v maltego &> /dev/null; then
    log_info "Téléchargement de Maltego Community Edition..."
    wget -q -O /tmp/maltego.deb "https://downloads.maltego.com/maltego-v4/linux/Maltego.v4.11.2.deb"
    if [[ -f /tmp/maltego.deb ]]; then
        dpkg -i /tmp/maltego.deb || apt-get install -f -y  # corriger les dépendances si besoin
        rm /tmp/maltego.deb
        log_success "Maltego installé."
    else
        log_warning "Impossible de télécharger Maltego. Installez-le manuellement depuis https://www.maltego.com/"
    fi
else
    log_success "Maltego est déjà installé."
fi

# -------------------------------------------------------------------
# 8. Outils supplémentaires utiles pour CTF
# -------------------------------------------------------------------

log_step "Installation d'outils supplémentaires (gobuster, sqlmap)"

# SecLists via GitHub
SECLISTS_DIR="/usr/share/seclists"
if [[ -d "$SECLISTS_DIR" ]]; then
    log_success "SecLists est déjà présent dans $SECLISTS_DIR"
else
    log_info "Clonage de SecLists depuis GitHub dans $SECLISTS_DIR..."
    if ! command -v git &> /dev/null; then
        log_info "Installation de git..."
        apt install -y git
    fi
    git clone --depth 1 https://github.com/danielmiessler/SecLists.git "$SECLISTS_DIR"
    log_success "SecLists cloné."
fi

apt install -y \
    gobuster \
    sqlmap \
    dirb \
    wfuzz

# Install de l'interface graphique de BloodHound

log_step "Installation de l'UI de BloodHound"

if ! command -v bloodhound &> /dev/null; then
    log_info "Installation de BloodHound..."

    TEMP_DIR=$(mktemp -d)
    
    # On s'assure de revenir au point de départ et de supprimer le dossier à la fin
    # même si le script plante (trap)
    trap 'rm -rf "$TEMP_DIR"' EXIT

    cd "$TEMP_DIR" || exit 1
    wget https://github.com/SpecterOps/bloodhound-cli/releases/latest/download/bloodhound-cli-linux-amd64.tar.gz -q
    tar -xzf bloodhound-cli-linux-amd64.tar.gz

    mkdir -p /opt/bloodhound/bin/    
    mv bloodhound-cli /opt/bloodhound/bin/bloodhound
    chmod +x /opt/bloodhound/bin/bloodhound
    ln -sf /opt/bloodhound/bin/bloodhound /usr/local/bin/bloodhound

    bloodhound install
    
    log_success "BloodHound installé avec succès"
else
    log_success "BloodHound est déjà présent"
fi

# -------------------------------------------------------------------
# 9. Configuration de l'environnement utilisateur (zsh + alias)
# -------------------------------------------------------------------

log_step "Configuration de l'environnement utilisateur"


if [[ -n "$REAL_HOME" && -f "$ZSH_CUSTOM/aliases.zsh" ]]; then
    if ! grep -q "# SecTools aliases" "$ZSH_CUSTOM/aliases.zsh"; then
        cat >> "$ZSH_CUSTOM/aliases.zsh" << 'EOF'

# SecTools aliases
alias nmap='nmap -vv'
alias wireshark='sudo wireshark'
alias msfconsole='msfconsole'
alias zaproxy='zaproxy'
alias sqlmap='sqlmap --batch'
alias crackmapexec='nxc'
EOF
        log_success "Alias ajoutés dans $ZSH_CUSTOM/aliases.zsh"
    else
        log_info "Alias déjà présents dans aliases.zsh"
    fi
else
    log_warning "aliases.zsh non trouvé pour $REAL_USER. Les alias n'ont pas été ajoutés."
fi

# -------------------------------------------------------------------
# 10. Nettoyage final
# -------------------------------------------------------------------
log_step "Nettoyage des paquets inutilisés"
apt autoremove -y

log_success "Installation terminée !"
echo -e "${GREEN}${BOLD}Vous pouvez maintenant utiliser les outils suivants :${RESET}"
echo -e "  - Réseau : ${CYAN}nmap, wireshark, socat, proxychains, tmux${RESET}"
echo -e "  - Web : ${CYAN}zaproxy${RESET}"
echo -e "  - Cracking : ${CYAN}hashcat, john, hydra${RESET}"
echo -e "  - Exploitation : ${CYAN}msfconsole${RESET}"
echo -e "  - Python : ${CYAN}impacket, bloodhound, pwntools, crackmapexec${RESET}"
echo -e "  - Reverse : ${CYAN}ghidra, radare2${RESET}"
echo -e "  - OSINT : ${CYAN}theharvester, recon-ng, maltego${RESET}"
echo -e "  - Supplément : ${CYAN}gobuster, sqlmap, seclists${RESET}"
echo -e "\n${YELLOW}Note : Pour BloodHound, lancez 'bloodhound' puis accédez à http://localhost:8080${RESET}"
echo -e "\r\n${YELLOW}-> Si vous oubliez le mot de passe, tapez bloodhound resetpwd${RESET}"