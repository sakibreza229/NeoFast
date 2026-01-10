#!/bin/bash
# Awesome Fastfetch Setup - A modular configurator for FastFetch presets.
# Only configures FastFetch presets (doesn't install FastFetch)

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
print_section() { 
    echo -e "\n${CYAN}${BOLD}›${NC} ${BOLD}$1${NC}"
}

print_success() { 
    echo -e "${GREEN}✓ $1${NC}"
}

print_info() { 
    echo -e "${BLUE}ℹ${NC} $1"
}

print_warning() { 
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() { 
    echo -e "${RED}✗ $1${NC}" >&2
}

print_step() {
    echo -e "${MAGENTA}→ $1${NC}"
}

# --- UTILITY FUNCTIONS ---
command_exists() { 
    command -v "$1" >/dev/null 2>&1
}

# Prompt function
prompt() {
    local msg="$1"
    local default="${2:-N}"
    
    if [[ "${NON_INTERACTIVE:-false}" = true ]]; then
        [[ "$default" =~ ^[Yy]$ ]] && return 0 || return 1
    fi
    
    local options="[y/N]"
    [[ "$default" =~ ^[Yy]$ ]] && options="[Y/n]"
    
    echo -en "${YELLOW}?${NC} $msg $options: "
    read -r response
    [[ "$response" =~ ^[Yy]$ ]]
}

# --- WELCOME SCREEN ---
show_welcome() {
    clear
    echo -e "${CYAN}${BOLD}"
    cat << "EOF"
   ___                               
  / _ |_    _____ ___ ___  __ _  ___ 
 / __ | |/|/ / -_|_-</ _ \/  ' \/ -_)
/_/ |_|__,__/\__/___/\___/_/_/_/\__/ 
EOF
    echo -e "${NC}"
    echo -e "$(tput setaf 6)$(tput bold)A modular configurator for FastFetch presets$(tput sgr0)"
    echo -e "${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    print_section "Check Requirements"
    # Show distro & shell name
    # Get distro name directly
if [[ -f /etc/os-release ]]; then
    # Source the file to get variables
    . /etc/os-release
    DISTRO_NAME="${PRETTY_NAME:-$NAME}"
    DISTRO_NAME="${DISTRO_NAME:-Unknown}"
else
    # Fallback for systems without /etc/os-release
    DISTRO_NAME="Unknown"
fi
    local shell_name=$(basename "$SHELL")
    print_info "${DIM}System:${NC} ${BOLD}${DISTRO_NAME}${NC} ${DIM}| Shell:${NC} ${BOLD}${shell_name}${NC}"
    
    # Check if FastFetch is installed
    if ! command_exists fastfetch; then
        print_error "FastFetch is not installed"
        echo ""
        print_warning "This script only configures FastFetch presets."
        print_warning "Please install FastFetch first, then run this script again."
        echo ""
        exit 1
    else
        local version=$(fastfetch --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
        print_success "FastFetch is installed (v${version})"
    fi
    
    echo ""
    print_warning "${YELLOW}${BOLD}This script will:${NC}"
    echo "  • Apply your chosen FastFetch preset"
    echo "  • Optionally add to shell startup"
    echo ""
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
            *) print_error "Invalid selection. Please enter 1, 2, or 3." ;;
        esac
    done
}

apply_preset() {
    print_step "Applying '$SELECTED_PRESET' preset..."
    
    local config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/fastfetch"
    local config_file="$config_dir/config.jsonc"
    
    # Backup existing config
    if [[ -f "$config_file" ]]; then
        local backup_file="$config_file.backup.$(date +%Y%m%d_%H%M%S_%N)"
        cp "$config_file" "$backup_file"
        print_info "Backed up existing config to: $(basename "$backup_file")"
    fi
    
    # Create config directory
    mkdir -p "$config_dir"
    
    # Look for preset file
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local preset_file="$script_dir/presets/${SELECTED_PRESET}.jsonc"
    
    if [[ -f "$preset_file" ]]; then
        cp "$preset_file" "$config_file"
        print_success "Applied preset: $SELECTED_PRESET"
    else
        print_error "Preset file not found: $preset_file"
        print_error "Please make sure the /presets directory contains ${SELECTED_PRESET}.jsonc"
        exit 1
    fi
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
            print_info "# FastFetch - System Information Display"
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

# --- MAIN EXECUTION ---
main() {
    # Parse arguments
    local CONFIG_TYPE=""
    local NON_INTERACTIVE=false
    local SKIP_SHELL=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--config)
                if [[ -n "${2:-}" && ! "$2" =~ ^- ]]; then
        CONFIG_TYPE="$2"
        shift 2
    else
        print_error "Error: -c/--config requires a value (compact, minimal, or full)"
        exit 1
    fi
    ;;
            -n|--non-interactive)
                NON_INTERACTIVE=true
                shift
                ;;
            --skip-shell)
                SKIP_SHELL=true
                shift
                ;;
            -h|--help)
                echo "Usage: $0 [OPTIONS]"
                print_info "Options:"
                echo "  -c, --config TYPE     Preset type: compact, minimal, full"
                echo "  -n, --non-interactive Run without prompts"
                echo "  --skip-shell          Skip shell integration"
                echo "  -h, --help            Show this help"
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                print_info "Use -h for help"
                exit 1
                ;;
        esac
    done
    
    # Show welcome screen (exits if FastFetch not installed)
    show_welcome
    
    # Confirm setup
    if [[ "$NON_INTERACTIVE" = false ]]; then
        if ! prompt "Configure FastFetch presets?" "Y"; then
            print_error "Setup cancelled by user"
            exit 0
        fi
    fi
    
    # Configuration
    select_preset
    apply_preset
    
    # Shell Integration
    setup_shell_integration
    
    # Completion
    print_success "Awesome Fastfetch preset has been successfully configured!"
    echo ""

    # Action Items Box
    echo -e "${CYAN}Next Steps:${NC}"
    echo -e "  ${GREEN}•${NC} Restart your terminal to apply changes"
    echo -e "  ${GREEN}•${NC} Run ${BOLD}fastfetch${NC}"
    echo -e "  ${GREEN}•${NC} Execute ${DIM}$0 --config [compact|minimal|full]${NC} to switch preset"
    echo -e "  ${GREEN}•${NC} Edit ${DIM}~/.config/fastfetch/config.jsonc${NC} to customize and change the ascii art"  
    echo ""
    echo -e "${MAGENTA}${BOLD}Enjoy your new beautiful terminal experience!${NC}"
    echo ""
}

# Run main function
main "$@"