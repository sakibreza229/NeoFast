#!/bin/bash
# Common functions for FastFetch setup

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Text styles
BOLD='\033[1m'
DIM='\033[2m'

# Print functions
print_header() {
    echo -e "${BLUE}${BOLD}==>${NC} ${BOLD}$1${NC}"
}

print_section() {
    echo -e "${CYAN}${BOLD}>>>${NC} ${BOLD}$1${NC}"
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
    echo -e "${RED}✗${NC} $1"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Prompt for confirmation
confirm() {
    if [[ "$NON_INTERACTIVE" = true ]]; then
        return 0
    fi
    
    echo -en "${YELLOW}?${NC} $1 [y/N]: "
    read -r response
    [[ "$response" =~ ^[Yy]$ ]]
}

# Detect distribution
detect_distro() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        DISTRO_ID="${ID:-unknown}"
        DISTRO_NAME="${NAME:-Unknown}"
        DISTRO_VERSION="${VERSION_ID:-}"
    else
        DISTRO_ID="unknown"
        DISTRO_NAME="Unknown"
    fi
    
    echo "$DISTRO_NAME"
}

# Install package using system package manager
install_pkg() {
    local pkg="$1"
    
    if [[ "$EUID" -eq 0 ]]; then
        local sudo=""
    else
        local sudo="sudo"
    fi
    
    case "$DISTRO_ID" in
        arch|manjaro|endeavouros)
            $sudo pacman -S --needed --noconfirm "$pkg"
            ;;
        debian|ubuntu|linuxmint|popos)
            $sudo apt-get update
            $sudo apt-get install -y "$pkg"
            ;;
        fedora)
            $sudo dnf install -y "$pkg"
            ;;
        rhel|centos)
            $sudo yum install -y "$pkg"
            ;;
        opensuse|tumbleweed)
            $sudo zypper install -y "$pkg"
            ;;
        *)
            return 1
            ;;
    esac
}

# Check and install dependencies
check_dependencies() {
    local deps=("curl" "tar")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command_exists "$dep"; then
            missing+=("$dep")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        print_info "Installing dependencies: ${missing[*]}"
        for dep in "${missing[@]}"; do
            install_pkg "$dep" || {
                print_warning "Failed to install $dep"
            }
        done
    fi
}