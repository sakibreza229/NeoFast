#!/bin/bash
# FastFetch Professional Setup
# Cross-distro, modular setup script

set -euo pipefail

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/scripts/common.sh"

# Default configuration
DEFAULT_CONFIG="compact"
AVAILABLE_CONFIGS=("compact" "minimal" "full")
AVAILABLE_LOGOS=("auto" "none" "simple" "custom")

# Print usage
print_usage() {
    cat << EOF
FastFetch Professional Setup v1.0

Usage: $0 [OPTIONS]

Options:
  -c, --config TYPE     Config type: compact, minimal, full (default: compact)
  -l, --logo TYPE       Logo type: auto, none, simple, custom (default: auto)
  -n, --non-interactive Run without prompts
  -h, --help            Show this help
  --test-mode           Test mode (no changes)
  --skip-shell          Skip shell integration
  --skip-config         Skip config creation

Examples:
  $0                    # Interactive setup with defaults
  $0 -c minimal -l none # Minimal config, no logo
  $0 --non-interactive  # Auto-install with defaults
EOF
}

# Parse arguments
NON_INTERACTIVE=false
TEST_MODE=false
SKIP_SHELL=false
SKIP_CONFIG=false
CONFIG_TYPE="$DEFAULT_CONFIG"
LOGO_TYPE="auto"

while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--config)
            CONFIG_TYPE="$2"
            shift 2
            ;;
        -l|--logo)
            LOGO_TYPE="$2"
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
        --skip-config)
            SKIP_CONFIG=true
            shift
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            print_usage
            exit 1
            ;;
    esac
done

# Validate config type
if [[ ! " ${AVAILABLE_CONFIGS[@]} " =~ " ${CONFIG_TYPE} " ]]; then
    print_error "Invalid config type: $CONFIG_TYPE"
    print_info "Available: ${AVAILABLE_CONFIGS[*]}"
    exit 1
fi

# Validate logo type
if [[ ! " ${AVAILABLE_LOGOS[@]} " =~ " ${LOGO_TYPE} " ]]; then
    print_error "Invalid logo type: $LOGO_TYPE"
    print_info "Available: ${AVAILABLE_LOGOS[*]}"
    exit 1
fi

# Main installation
install_fastfetch() {
    print_section "Installing FastFetch"
    
    if command_exists fastfetch; then
        print_success "FastFetch is already installed"
        return 0
    fi
    
    detect_distro
    
    case "$DISTRO_ID" in
        arch|manjaro|endeavouros)
            install_pkg "fastfetch"
            ;;
        debian|ubuntu|linuxmint|popos)
            install_pkg "fastfetch"
            ;;
        fedora|rhel|centos)
            install_pkg "fastfetch"
            ;;
        opensuse|tumbleweed)
            install_pkg "fastfetch"
            ;;
        *)
            print_warning "Unsupported distro. Trying generic install..."
            if command_exists curl; then
                install_from_binary
            else
                print_error "Cannot install on this distribution automatically"
                print_info "Please install FastFetch manually from: https://github.com/fastfetch-cli/fastfetch"
                exit 1
            fi
            ;;
    esac
    
    print_success "FastFetch installed successfully"
}

# Install from binary release
install_from_binary() {
    local url="https://github.com/fastfetch-cli/fastfetch/releases/latest/download"
    local bin_dir="/usr/local/bin"
    
    case "$(uname -m)" in
        x86_64|amd64)
            url="${url}/fastfetch-linux-amd64.tar.xz"
            ;;
        aarch64|arm64)
            url="${url}/fastfetch-linux-aarch64.tar.xz"
            ;;
        *)
            print_error "Unsupported architecture"
            return 1
            ;;
    esac
    
    print_info "Downloading FastFetch binary..."
    sudo curl -L "$url" -o /tmp/fastfetch.tar.xz
    sudo tar -xJf /tmp/fastfetch.tar.xz -C /tmp
    sudo mv /tmp/fastfetch "$bin_dir/"
    sudo chmod +x "$bin_dir/fastfetch"
    sudo rm -f /tmp/fastfetch.tar.xz
    
    print_success "FastFetch installed to $bin_dir"
}

# Setup configuration
setup_configuration() {
    if [[ "$SKIP_CONFIG" = true ]]; then
        print_info "Skipping configuration setup"
        return 0
    fi
    
    print_section "Setting up Configuration"
    
    local config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/fastfetch"
    local config_file="${config_dir}/config.jsonc"
    
    # Create backup if exists
    if [[ -f "$config_file" ]]; then
        local backup_file="${config_file}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$config_file" "$backup_file"
        print_info "Backed up existing config to: $backup_file"
    fi
    
    # Create config directory
    mkdir -p "$config_dir"
    
    # Copy selected config
    local source_config="${SCRIPT_DIR}/configs/${CONFIG_TYPE}.jsonc"
    if [[ ! -f "$source_config" ]]; then
        print_error "Config file not found: $source_config"
        return 1
    fi
    
    cp "$source_config" "$config_file"
    
    # Setup logo
    setup_logo "$config_file"
    
    print_success "Configuration installed to: $config_file"
}

# Setup logo
setup_logo() {
    local config_file="$1"
    
    case "$LOGO_TYPE" in
        "auto")
            # Use distro logo
            print_info "Using automatic distro logo"
            ;;
        "none")
            # Remove logo section
            sed -i '/"logo":/,/}/d' "$config_file"
            print_info "Logo disabled"
            ;;
        "simple")
            # Use simple ASCII
            local logo_file="${SCRIPT_DIR}/logos/default.ascii"
            if [[ -f "$logo_file" ]]; then
                # Convert ASCII to JSON format
                local logo_json=$(python3 -c "
import json, sys
with open('$logo_file', 'r') as f:
    lines = [line.rstrip() for line in f]
logo_data = {'type': 'ascii', 'lines': lines}
print(json.dumps(logo_data))
" 2>/dev/null || echo '{"type": "builtin"}')
                
                # Update config
                python3 -c "
import json, sys
with open('$config_file', 'r') as f:
    config = json.load(f)
config['logo'] = $logo_json
with open('$config_file', 'w') as f:
    json.dump(config, f, indent=2)
" 2>/dev/null || print_warning "Could not set custom logo"
            fi
            print_info "Using simple ASCII logo"
            ;;
        "custom")
            print_info "You can add custom logos to: ${SCRIPT_DIR}/logos/custom/"
            print_info "Update config manually to use custom image/logo"
            ;;
    esac
}

# Setup shell integration
setup_shell_integration() {
    if [[ "$SKIP_SHELL" = true ]]; then
        print_info "Skipping shell integration"
        return 0
    fi
    
    print_section "Shell Integration"
    
    local current_shell=$(basename "$SHELL")
    local config_files=()
    
    # Detect available shells
    declare -A shell_configs=(
        ["bash"]="$HOME/.bashrc"
        ["zsh"]="$HOME/.zshrc"
        ["fish"]="$HOME/.config/fish/config.fish"
    )
    
    for shell in "${!shell_configs[@]}"; do
        if [[ -f "${shell_configs[$shell]}" ]]; then
            config_files+=("$shell:${shell_configs[$shell]}")
        fi
    done
    
    if [[ ${#config_files[@]} -eq 0 ]]; then
        print_warning "No shell config files found"
        return 0
    fi
    
    if [[ "$NON_INTERACTIVE" = false ]]; then
        print_info "Available shells:"
        for item in "${config_files[@]}"; do
            echo "  - ${item%%:*}"
        done
        
        if confirm "Add FastFetch to shell startup?"; then
            print_info "Select shells (comma-separated or 'all'):"
            read -r selected_shells
            
            if [[ "$selected_shells" = "all" ]]; then
                for item in "${config_files[@]}"; do
                    add_to_shell "${item%%:*}" "${item#*:}"
                done
            else
                IFS=',' read -ra shells <<< "$selected_shells"
                for shell in "${shells[@]}"; do
                    shell=$(echo "$shell" | xargs)
                    for item in "${config_files[@]}"; do
                        if [[ "${item%%:*}" = "$shell" ]]; then
                            add_to_shell "$shell" "${item#*:}"
                        fi
                    done
                done
            fi
        fi
    else
        # Non-interactive: add to current shell only
        add_to_shell "$current_shell" "${shell_configs[$current_shell]}"
    fi
}

# Add FastFetch to shell config
add_to_shell() {
    local shell_name="$1"
    local config_file="$2"
    
    if [[ ! -f "$config_file" ]]; then
        return
    fi
    
    if grep -q "fastfetch" "$config_file" 2>/dev/null; then
        print_info "FastFetch already in $shell_name config"
        return
    fi
    
    {
        echo ""
        echo "# FastFetch - System Information"
        echo "if command -v fastfetch &> /dev/null; then"
        echo "    fastfetch"
        echo "fi"
    } >> "$config_file"
    
    print_success "Added to $shell_name"
}

# Test installation
test_installation() {
    print_section "Testing Installation"
    
    if command_exists fastfetch; then
        print_info "Running FastFetch test..."
        echo ""
        
        # Run with minimal output for test
        fastfetch --load-config off --structure title:break:os:kernel:shell:break 2>/dev/null || \
        fastfetch 2>/dev/null || \
        print_warning "FastFetch test failed (but installation may still work)"
        
        echo ""
        print_success "Test completed"
    else
        print_error "FastFetch not found after installation"
        return 1
    fi
}

# Main execution
main() {
    print_header "FastFetch Professional Setup"
    
    print_info "Distribution: $(detect_distro 2>/dev/null || echo "Unknown")"
    print_info "Config: $CONFIG_TYPE"
    print_info "Logo: $LOGO_TYPE"
    print_info "Interactive: $([[ "$NON_INTERACTIVE" = false ]] && echo "Yes" || echo "No")"
    echo ""
    
    if [[ "$TEST_MODE" = true ]]; then
        print_warning "TEST MODE - No changes will be made"
        return 0
    fi
    
    if [[ "$NON_INTERACTIVE" = false ]] && ! confirm "Start installation?"; then
        print_info "Installation cancelled"
        exit 0
    fi
    
    # Run installation steps
    install_fastfetch
    setup_configuration
    setup_shell_integration
    
    if [[ "$NON_INTERACTIVE" = false ]] && confirm "Test installation now?"; then
        test_installation
    fi
    
    print_section "Installation Complete"
    print_success "FastFetch has been successfully installed!"
    print_info "Configuration: ~/.config/fastfetch/config.jsonc"
    print_info "Run: fastfetch"
    
    if [[ "$NON_INTERACTIVE" = false ]]; then
        echo ""
        print_info "You can customize the configuration file or run:"
        print_info "  $0 --config full      # Switch to full config"
        print_info "  $0 --config minimal   # Switch to minimal config"
    fi
}

# Run main
main "$@"