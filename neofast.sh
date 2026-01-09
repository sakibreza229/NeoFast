#!/bin/bash
# NeoFast Setup - Enhanced Version
# Safe, cross-distro FastFetch setup with presets

set -euo pipefail

# --- COLOR AND STYLE DEFINITIONS ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' 
BOLD='\033[1m'
DIM='\033[2m'

# --- PRINT FUNCTIONS ---
print_header() { 
    echo -e "\n${BLUE}${BOLD}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}${BOLD}║${NC} ${BOLD}$1${NC}"
    echo -e "${BLUE}${BOLD}╚══════════════════════════════════════════════╝${NC}"
}

print_section() { 
    echo -e "\n${CYAN}${BOLD}›${NC} ${BOLD}$1${NC}"
}

print_success() { 
    echo -e "${GREEN}✓${NC} $1"
}

print_info() { 
    echo -e "${BLUE}ℹ${NC} $1"
}

print_warning() { 
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() { 
    echo -e "${RED}✗${NC} $1" >&2
}

print_step() {
    echo -e "${MAGENTA}→${NC} $1"
}

# --- UTILITY FUNCTIONS ---
command_exists() { 
    command -v "$1" >/dev/null 2>&1
}

# Safe prompt function with timeout
prompt() {
    local msg="$1"
    local default="${2:-N}"
    local timeout="${3:-0}"
    
    if [[ "${NON_INTERACTIVE:-false}" = true ]]; then
        [[ "$default" =~ ^[Yy]$ ]] && return 0 || return 1
    fi
    
    local options="[y/N]"
    [[ "$default" =~ ^[Yy]$ ]] && options="[Y/n]"
    
    if [[ $timeout -gt 0 ]]; then
        echo -en "${YELLOW}?${NC} $msg $options (auto: $default in ${timeout}s): "
        if read -r -t "$timeout" response; then
            [[ "$response" =~ ^[Yy]$ ]]
        else
            echo ""
            [[ "$default" =~ ^[Yy]$ ]]
        fi
    else
        echo -en "${YELLOW}?${NC} $msg $options: "
        read -r response
        [[ "$response" =~ ^[Yy]$ ]]
    fi
}

# Safe distro detection
detect_distro() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release 2>/dev/null || true
        DISTRO_ID="${ID:-unknown}"
        DISTRO_NAME="${PRETTY_NAME:-$NAME}"
        DISTRO_NAME="${DISTRO_NAME:-Unknown}"
    elif [[ -f /etc/arch-release ]]; then
        DISTRO_ID="arch"
        DISTRO_NAME="Arch Linux"
    elif [[ -f /etc/debian_version ]]; then
        DISTRO_ID="debian"
        DISTRO_NAME="Debian"
    elif [[ -f /etc/fedora-release ]]; then
        DISTRO_ID="fedora"
        DISTRO_NAME="Fedora"
    elif [[ -f /etc/redhat-release ]]; then
        DISTRO_ID="rhel"
        DISTRO_NAME="Red Hat Enterprise Linux"
    else
        DISTRO_ID="unknown"
        DISTRO_NAME="Unknown"
    fi
}

# Package manager detection
detect_pkg_manager() {
    if command_exists pacman; then
        PKG_MANAGER="pacman"
    elif command_exists apt-get; then
        PKG_MANAGER="apt"
    elif command_exists dnf; then
        PKG_MANAGER="dnf"
    elif command_exists yum; then
        PKG_MANAGER="yum"
    elif command_exists zypper; then
        PKG_MANAGER="zypper"
    elif command_exists apk; then
        PKG_MANAGER="apk"
    elif command_exists xbps-install; then
        PKG_MANAGER="xbps"
    else
        PKG_MANAGER="unknown"
    fi
}

# --- WELCOME SCREEN ---
show_welcome() {
    clear
    echo -e "${CYAN}${BOLD}"
    cat << "EOF"
╔═══════════════════════════════════════════════════╗
║ _____   __          __________             _____  ║
║ ___  | / /_____________  ____/_____ _________  /_ ║
║ __   |/ /_  _ \  __ \_  /_   _  __ `/_  ___/  __/ ║
║ _  /|  / /  __/ /_/ /  __/   / /_/ /_(__  )/ /_   ║
║ /_/ |_/  \___/\____//_/      \__,_/ /____/ \__/   ║ 
║                                                   ║
║                 FastFetch Presets                 ║
╚═══════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    print_header "NEOFAST SETUP"
echo -e "$(tput setaf 6)$(tput bold)A beautiful FastFetch preset for professionals$(tput sgr0)"
echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    detect_distro
    detect_pkg_manager
    
    echo -e "${DIM}System:${NC} ${BOLD}$DISTRO_NAME${NC}"
    echo -e "${DIM}Package Manager:${NC} ${BOLD}$PKG_MANAGER${NC}"
    echo -e "${DIM}Shell:${NC} ${BOLD}$(basename "$SHELL")${NC}"
    echo -e "${DIM}User:${NC} ${BOLD}$(whoami)${NC}"
    echo ""
    echo -e "${CYAN}This script will:${NC}"
    echo "  1. Install FastFetch (if needed)"
    echo "  2. Apply your chosen preset"
    echo "  3. Optionally add to shell startup"
    echo ""
}

# --- INSTALLATION FUNCTIONS ---
install_fastfetch() {
    print_step "Checking FastFetch installation..."
    
    if command_exists fastfetch; then
        local version=$(fastfetch --version 2>/dev/null | head -n1 || echo "unknown")
        print_success "FastFetch is already installed ($version)"
        return 0
    fi
    
    print_step "Installing FastFetch..."
    
    local sudo_cmd=""
    [[ "$EUID" -ne 0 ]] && sudo_cmd="sudo"
    
    case "$PKG_MANAGER" in
        pacman)
            $sudo_cmd pacman -S --needed --noconfirm fastfetch 2>/dev/null || \
            print_error "Failed to install via pacman" && return 1
            ;;
        apt)
            $sudo_cmd apt-get update && \
            $sudo_cmd apt-get install -y fastfetch 2>/dev/null || \
            print_error "Failed to install via apt" && return 1
            ;;
        dnf)
            $sudo_cmd dnf install -y fastfetch 2>/dev/null || \
            print_error "Failed to install via dnf" && return 1
            ;;
        yum)
            $sudo_cmd yum install -y fastfetch 2>/dev/null || \
            print_error "Failed to install via yum" && return 1
            ;;
        zypper)
            $sudo_cmd zypper install -y fastfetch 2>/dev/null || \
            print_error "Failed to install via zypper" && return 1
            ;;
        apk)
            $sudo_cmd apk add fastfetch 2>/dev/null || \
            print_error "Failed to install via apk" && return 1
            ;;
        xbps)
            $sudo_cmd xbps-install -Sy fastfetch 2>/dev/null || \
            print_error "Failed to install via xbps" && return 1
            ;;
        *)
            install_from_binary
            ;;
    esac
    
    if command_exists fastfetch; then
        print_success "FastFetch installed successfully"
        return 0
    else
        print_error "Failed to install FastFetch"
        print_info "Please install manually: https://github.com/fastfetch-cli/fastfetch"
        return 1
    fi
}

install_from_binary() {
    print_step "Installing from binary release..."
    
    local arch=""
    case "$(uname -m)" in
        x86_64|amd64) arch="amd64" ;;
        aarch64|arm64) arch="aarch64" ;;
        *) 
            print_error "Unsupported architecture: $(uname -m)"
            return 1
            ;;
    esac
    
    local url="https://github.com/fastfetch-cli/fastfetch/releases/latest/download/fastfetch-linux-$arch.tar.xz"
    local tmp_dir="/tmp/fastfetch-install-$$"
    
    mkdir -p "$tmp_dir"
    
    if ! command_exists curl && ! command_exists wget; then
        print_error "Need curl or wget to download binary"
        return 1
    fi
    
    if command_exists curl; then
        curl -L "$url" -o "$tmp_dir/fastfetch.tar.xz" || {
            print_error "Failed to download"
            rm -rf "$tmp_dir"
            return 1
        }
    else
        wget -q "$url" -O "$tmp_dir/fastfetch.tar.xz" || {
            print_error "Failed to download"
            rm -rf "$tmp_dir"
            return 1
        }
    fi
    
    tar -xJf "$tmp_dir/fastfetch.tar.xz" -C "$tmp_dir" 2>/dev/null || {
        print_error "Failed to extract archive"
        rm -rf "$tmp_dir"
        return 1
    }
    
    # Find the binary
    local binary_path=""
    if [[ -f "$tmp_dir/fastfetch" ]]; then
        binary_path="$tmp_dir/fastfetch"
    elif [[ -d "$tmp_dir/fastfetch-linux-$arch" ]]; then
        binary_path=$(find "$tmp_dir/fastfetch-linux-$arch" -name "fastfetch" -type f | head -n1)
    fi
    
    if [[ -n "$binary_path" && -f "$binary_path" ]]; then
        sudo mkdir -p /usr/local/bin
        sudo cp "$binary_path" /usr/local/bin/fastfetch
        sudo chmod +x /usr/local/bin/fastfetch
        print_success "Installed to /usr/local/bin/fastfetch"
    else
        print_error "Could not find binary in archive"
        rm -rf "$tmp_dir"
        return 1
    fi
    
    rm -rf "$tmp_dir"
    return 0
}

# --- CONFIGURATION FUNCTIONS ---
select_preset() {
    print_section "Select Preset"
    
    local presets=("compact" "minimal" "full")
    local descriptions=(
        "Compact: Balanced layout, fits 80x24 terminals"
        "Minimal: Basic info only, very clean"
        "Full: Detailed info with icons and colors"
    )
    
    echo -e "${CYAN}Available presets:${NC}"
    for i in "${!presets[@]}"; do
        echo -e "  ${GREEN}$((i+1)))${NC} ${descriptions[$i]}"
    done
    
    if [[ -n "$CONFIG_TYPE" && " ${presets[*]} " =~ " $CONFIG_TYPE " ]]; then
        SELECTED_PRESET="$CONFIG_TYPE"
        print_info "Using preset: $SELECTED_PRESET (from command line)"
        return 0
    fi
    
    if [[ "$NON_INTERACTIVE" = true ]]; then
        SELECTED_PRESET="compact"
        print_info "Auto-selected: compact (non-interactive mode)"
        return 0
    fi
    
    local choice=""
    while [[ ! "$choice" =~ ^[1-3]$ ]]; do
        echo -en "${YELLOW}Select preset (1-3): ${NC}"
        read -r choice
        
        case "$choice" in
            1) SELECTED_PRESET="compact" ;;
            2) SELECTED_PRESET="minimal" ;;
            3) SELECTED_PRESET="full" ;;
            *) echo -e "${RED}Invalid selection. Please enter 1, 2, or 3.${NC}" ;;
        esac
    done
}

apply_preset() {
    print_step "Applying '$SELECTED_PRESET' preset..."
    
    local config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/fastfetch"
    local config_file="$config_dir/config.jsonc"
    
    # Backup existing config
    if [[ -f "$config_file" ]]; then
        local backup_file="$config_file.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$config_file" "$backup_file"
        print_info "Backed up existing config to: $(basename "$backup_file")"
    fi
    
    # Create config directory
    mkdir -p "$config_dir"
    
    # Look for preset file
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local preset_file="$script_dir/configs/${SELECTED_PRESET}.jsonc"
    
    if [[ -f "$preset_file" ]]; then
        cp "$preset_file" "$config_file"
        print_success "Applied preset: $SELECTED_PRESET"
    else
        print_error "Preset file not found: $preset_file"
        print_error "Please make sure the configs/ directory contains ${SELECTED_PRESET}.jsonc"
        exit 1
    fi
    
    print_info "Config location: $config_file"
    print_info "Logo: Using FastFetch's default distro logo"
    print_info "To customize: Edit $config_file"
}

# --- SHELL INTEGRATION ---
setup_shell_integration() {
    if [[ "$SKIP_SHELL" = true ]]; then
        print_info "Skipping shell integration (--skip-shell)"
        return
    fi
    
    print_section "Shell Integration"
    
    local current_shell=$(basename "$SHELL")
    local config_file=""
    
    case "$current_shell" in
        bash) config_file="$HOME/.bashrc" ;;
        zsh) config_file="$HOME/.zshrc" ;;
        fish) config_file="$HOME/.config/fish/config.fish" ;;
        *)
            print_warning "Unsupported shell: $current_shell"
            print_info "Manually add 'fastfetch' to your shell's config file"
            return
            ;;
    esac
    
    if [[ ! -f "$config_file" ]]; then
        print_warning "Config file not found: $config_file"
        return
    fi
    
    if grep -q "fastfetch" "$config_file" 2>/dev/null; then
        print_info "FastFetch already in $current_shell config"
        return
    fi
    
    if prompt "Add FastFetch to $current_shell startup?" "Y"; then
        {
            echo ""
            echo "# FastFetch - System Information Display"
            echo "if command -v fastfetch &> /dev/null; then"
            echo "    fastfetch"
            echo "fi"
        } >> "$config_file"
        
        print_success "Added to $current_shell"
        print_info "Restart terminal or run: source $config_file"
    else
        print_info "Skipped shell integration"
    fi
}

# --- TEST FUNCTION ---
test_fastfetch() {
    print_section "Testing Installation"
    
    if ! command_exists fastfetch; then
        print_error "FastFetch not found"
        return 1
    fi
    
    print_step "Running FastFetch..."
    echo ""
    
    # Try to run with minimal output
    if fastfetch --version &>/dev/null; then
        fastfetch --load-config off --structure os:kernel:shell:break 2>/dev/null || \
        fastfetch --structure title:os:kernel:break 2>/dev/null || \
        fastfetch 2>/dev/null || true
    else
        fastfetch 2>/dev/null || true
    fi
    
    echo ""
    print_success "Test completed successfully!"
}

# --- MAIN EXECUTION ---
main() {
    # Parse arguments
    local CONFIG_TYPE=""
    local NON_INTERACTIVE=false
    local TEST_MODE=false
    local SKIP_SHELL=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--config)
                CONFIG_TYPE="$2"
                shift 2
                ;;
            -n|--non-interactive)
                NON_INTERACTIVE=true
                shift
                ;;
            --test-mode)
                TEST_MODE=true
                shift
                ;;
            --skip-shell)
                SKIP_SHELL=true
                shift
                ;;
            -h|--help)
                echo "Usage: $0 [OPTIONS]"
                echo "Options:"
                echo "  -c, --config TYPE     Preset type: compact, minimal, full"
                echo "  -n, --non-interactive Run without prompts"
                echo "  --test-mode           Test mode (no changes)"
                echo "  --skip-shell          Skip shell integration"
                echo "  -h, --help            Show this help"
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Use -h for help"
                exit 1
                ;;
        esac
    done
    
    # Show welcome screen
    show_welcome
    
    if [[ "$TEST_MODE" = true ]]; then
        print_warning "TEST MODE - No changes will be made"
        print_info "Would install FastFetch and apply preset"
        exit 0
    fi
    
    # Confirm installation
    if [[ "$NON_INTERACTIVE" = false ]]; then
        if ! prompt "Start NeoFast setup?" "Y" 10; then
            print_info "Setup cancelled by user"
            exit 0
        fi
    fi
    
    # Installation
    print_header "Installation Phase"
    install_fastfetch || exit 1
    
    # Configuration
    print_header "Configuration Phase"
    select_preset
    apply_preset
    
    # Shell Integration
    print_header "Shell Integration Phase"
    setup_shell_integration
    
    # Test
    if prompt "Test FastFetch now?" "Y"; then
        test_fastfetch
    fi
    
    # Completion
    print_header "Setup Complete! 🎉"
    print_success "NeoFast has been successfully configured!"
    echo ""
    print_info "Commands:"
    echo "  fastfetch           # Run FastFetch"
    echo "  fastfetch --help    # Show all options"
    echo ""
    print_info "Files:"
    echo "  Config: ~/.config/fastfetch/config.jsonc"
    echo "  Edit: nano ~/.config/fastfetch/config.jsonc"
    echo ""
    print_info "Presets can be changed by running:"
    echo "  $0 --config [compact|minimal|full]"
    echo ""
    echo -e "${DIM}Thank you for using NeoFast!${NC}"
}

# Run main function
main "$@"