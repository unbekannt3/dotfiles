#!/bin/bash

# Set colors
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
RESET="\033[0m"

print_info() {
    echo -e "${GREEN}INFO:${RESET} $1"
}

print_warning() {
    echo -e "${YELLOW}WARNING:${RESET} $1"
}

print_error() {
    echo -e "${RED}ERROR:${RESET} $1"
}

print_info "Starting dotfiles installation..."

confirm() {
    read -p "$1 [y/N] " response
    case "$response" in
        [yY][eE][sS]|[yY])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Check if sudo is available
check_sudo() {
    if ! command -v sudo &> /dev/null; then
        print_error "sudo is not installed or not in PATH"
        print_info "You may need to install packages manually with root privileges"
        print_info "Required packages: $REQUIRED_PKGS"
        if confirm "Continue without installing packages?"; then
            return 1
        else
            print_info "Exiting installation..."
            exit 1
        fi
    fi
    return 0
}

# Create backup directory if it doesn't exist
BACKUP_DIR="$HOME/.dotfiles_backup/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"
print_info "Created backup directory: $BACKUP_DIR"

# Define packages for different distributions
FEDORA_PKGS="zsh git curl wget htop iftop iotop screen nano tmux btop fastfetch util-linux-user stow"
DEB_PKGS="zsh git curl wget htop iftop iotop screen nano tmux btop fastfetch passwd stow"
ARCH_PKGS="zsh git curl wget htop iftop iotop screen nano tmux btop fastfetch util-linux stow"
# Common packages across distributions for manual installation
REQUIRED_PKGS="zsh git curl wget nano stow"

# Determine user's system
DNF_CMD=$(which dnf 2>/dev/null)
APT_CMD=$(which apt-get 2>/dev/null)
YUM_CMD=$(which yum 2>/dev/null)
PACMAN_CMD=$(which pacman 2>/dev/null)
ZYPPER_CMD=$(which zypper 2>/dev/null)

# Install basic packages
if [[ ! -z $DNF_CMD ]]; then
    print_info "Detected Fedora/RHEL-based system, installing packages..."
    if check_sudo; then
        sudo dnf install -y $FEDORA_PKGS || {
            print_error "Failed to install packages with dnf"
            if confirm "Continue without all packages?"; then
                print_warning "Continuing without complete package installation"
            else
                print_info "Exiting installation..."
                exit 1
            fi
        }
    fi
elif [[ ! -z $APT_CMD ]]; then
    print_info "Detected Debian-based system, installing packages..."
    if check_sudo; then
        sudo apt-get update && sudo apt-get install -y $DEB_PKGS || {
            print_error "Failed to install packages with apt"
            if confirm "Continue without all packages?"; then
                print_warning "Continuing without complete package installation"
            else
                print_info "Exiting installation..."
                exit 1
            fi
        }
    fi
elif [[ ! -z $YUM_CMD ]]; then
    print_info "Detected older RHEL-based system, installing packages..."
    if check_sudo; then
        sudo yum install -y $FEDORA_PKGS || {
            print_error "Failed to install packages with yum"
            if confirm "Continue without all packages?"; then
                print_warning "Continuing without complete package installation"
            else
                print_info "Exiting installation..."
                exit 1
            fi
        }
    fi
elif [[ ! -z $PACMAN_CMD ]]; then
    print_info "Detected Arch-based system, installing packages..."
    if check_sudo; then
        sudo pacman -Syu --noconfirm $ARCH_PKGS || {
            print_error "Failed to install packages with pacman"
            if confirm "Continue without all packages?"; then
                print_warning "Continuing without complete package installation"
            else
                print_info "Exiting installation..."
                exit 1
            fi
        }
    fi
elif [[ ! -z $ZYPPER_CMD ]]; then
    print_info "Detected openSUSE/SUSE-based system, installing packages..."
    if check_sudo; then
        sudo zypper install -y $FEDORA_PKGS || {
            print_error "Failed to install packages with zypper"
            if confirm "Continue without all packages?"; then
                print_warning "Continuing without complete package installation"
            else
                print_info "Exiting installation..."
                exit 1
            fi
        }
    fi
else
    print_warning "Unsupported package manager detected"
    print_info "The following packages are needed:"
    echo "---------------------------------------------"
    echo "$REQUIRED_PKGS"
    echo "---------------------------------------------"
    print_info "Additional useful packages if available:"
    echo "---------------------------------------------"
    echo "htop iftop iotop screen tmux btop fastfetch/neofetch"
    echo "---------------------------------------------"

    if confirm "Continue without package installation?"; then
        print_warning "Continuing without package installation"
    else
        print_info "Exiting installation..."
        exit 1
    fi
fi

# Check if oh-my-zsh is already installed
if [ -d "$HOME/.oh-my-zsh" ]; then
    print_warning "oh-my-zsh is already installed at $HOME/.oh-my-zsh"
    if confirm "Would you like to back up and reinstall oh-my-zsh?"; then
        print_info "Backing up existing oh-my-zsh installation..."
        cp -r "$HOME/.oh-my-zsh" "$BACKUP_DIR/"
        rm -rf "$HOME/.oh-my-zsh"
        print_info "Installing oh-my-zsh..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended || {
            print_error "Failed to install oh-my-zsh"
            if confirm "Restore backup and continue?"; then
                print_info "Restoring oh-my-zsh from backup..."
                rm -rf "$HOME/.oh-my-zsh" 2>/dev/null
                cp -r "$BACKUP_DIR/.oh-my-zsh" "$HOME/" 2>/dev/null
            fi
        }
    else
        print_info "Skipping oh-my-zsh installation"
    fi
else
    print_info "Installing oh-my-zsh..."
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended || {
        print_error "Failed to install oh-my-zsh"
        if ! confirm "Continue without oh-my-zsh?"; then
            print_info "Exiting installation..."
            exit 1
        fi
    }
fi

# Handle dotfiles
print_info "Setting up dotfiles..."
for file in $(find . -maxdepth 1 -name ".*" -type f -not -name ".git*" -printf "%f\n" 2>/dev/null); do
    if [ -e "$HOME/$file" ]; then
        print_warning "Found existing $file in home directory"
        if confirm "Would you like to back up and replace $file?"; then
            print_info "Backing up $file to $BACKUP_DIR/$file"
            cp "$HOME/$file" "$BACKUP_DIR/" 2>/dev/null
            rm "$HOME/$file" 2>/dev/null
            ln -s "$PWD/$file" "$HOME/$file" && print_info "Created symlink for $file" || print_error "Failed to create symlink for $file"
        else
            print_info "Skipping $file"
        fi
    else
        ln -s "$PWD/$file" "$HOME/$file" && print_info "Created symlink for $file" || print_error "Failed to create symlink for $file"
    fi
done

# Check if .oh-my-zsh exists before proceeding with themes and plugins
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    print_warning "oh-my-zsh directory not found, skipping themes and plugins installation"
else
    # Handle zsh themes and plugins
    P10K_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
    if [ -d "$P10K_DIR" ]; then
        print_warning "powerlevel10k theme already installed"
        if confirm "Would you like to update powerlevel10k?"; then
            print_info "Updating powerlevel10k..."
            (cd "$P10K_DIR" && git pull) || print_error "Failed to update powerlevel10k"
        fi
    else
        print_info "Installing powerlevel10k theme..."
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR" || print_error "Failed to install powerlevel10k"
    fi

    SYNTAX_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"
    if [ -d "$SYNTAX_DIR" ]; then
        print_warning "zsh-syntax-highlighting already installed"
        if confirm "Would you like to update zsh-syntax-highlighting?"; then
            print_info "Updating zsh-syntax-highlighting..."
            (cd "$SYNTAX_DIR" && git pull) || print_error "Failed to update zsh-syntax-highlighting"
        fi
    else
        print_info "Installing zsh-syntax-highlighting..."
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$SYNTAX_DIR" || print_error "Failed to install zsh-syntax-highlighting"
    fi

    # Add zsh-autosuggestions plugin
    AUTOSUGGEST_DIR="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"
    if [ -d "$AUTOSUGGEST_DIR" ]; then
        print_warning "zsh-autosuggestions already installed"
        if confirm "Would you like to update zsh-autosuggestions?"; then
            print_info "Updating zsh-autosuggestions..."
            (cd "$AUTOSUGGEST_DIR" && git pull) || print_error "Failed to update zsh-autosuggestions"
        fi
    else
        print_info "Installing zsh-autosuggestions..."
        git clone https://github.com/zsh-users/zsh-autosuggestions.git "$AUTOSUGGEST_DIR" || print_error "Failed to install zsh-autosuggestions"
    fi
fi

# Install MesloLGS NF Font
print_info "Setting up MesloLGS NF font..."
font_dir="$HOME/.local/share/fonts"
mkdir -p "$font_dir"

if [ -d "./font" ] && [ "$(ls -A ./font/*.ttf 2>/dev/null)" ]; then
    cp ./font/*.ttf "$font_dir/" || print_error "Failed to copy fonts"
    print_info "Fonts copied to $font_dir"

    # Reset font cache
    if command -v fc-cache &>/dev/null; then
        print_info "Updating font cache..."
        fc-cache -f "$font_dir" || print_warning "Failed to update font cache"
    else
        print_warning "fc-cache not found, skipping font cache update"
    fi
else
    print_warning "Font directory not found or empty, skipping font installation"
fi

# Check if zsh is installed before attempting to change shell
if command -v zsh &>/dev/null; then
    # Check if zsh is already the default shell
    current_shell=$(getent passwd $USER | cut -d: -f7)
    if [ "$current_shell" != "$(which zsh)" ]; then
        print_info "Current shell is: $current_shell"
        if confirm "Change default shell to zsh?"; then
            chsh -s "$(which zsh)" || {
                print_error "Failed to change shell automatically"
                print_info "To change your shell manually, run:"
                print_info "  chsh -s $(which zsh)"
            }
            if [ $? -eq 0 ]; then
                print_info "Default shell changed to zsh"
            fi
        else
            print_info "Keeping current shell: $current_shell"
        fi
    else
        print_info "zsh is already the default shell"
    fi
else
    print_error "zsh is not installed, can't change default shell"
    print_info "Please install zsh and then run: chsh -s \$(which zsh)"
fi

print_info "Dotfiles installation completed!"
print_info "Please reload your shell for the changes to take effect."
print_info "For best results also set your GUI Terminal font to \"MesloLGS NF\""

# Check if any backups were made
if [ "$(ls -A $BACKUP_DIR 2>/dev/null)" ]; then
    print_info "Backup of previous configurations can be found at: $BACKUP_DIR"
else
    # Remove empty backup directory
    rmdir "$BACKUP_DIR" 2>/dev/null
    # Check if backup parent directory is empty
    parent_dir=$(dirname "$BACKUP_DIR")
    if [ -z "$(ls -A $parent_dir 2>/dev/null)" ]; then
        rmdir "$parent_dir" 2>/dev/null
    fi
fi

# Final notes and reminders
print_info "------------------------------------------"
print_info "Installation summary:"
print_info "------------------------------------------"
if command -v zsh &>/dev/null; then
    print_info "✓ zsh is installed"
else
    print_warning "✗ zsh is not installed"
fi

if [ -d "$HOME/.oh-my-zsh" ]; then
    print_info "✓ oh-my-zsh is installed"
else
    print_warning "✗ oh-my-zsh is not installed"
fi

if [ -d "$P10K_DIR" ]; then
    print_info "✓ powerlevel10k theme is installed"
else
    print_warning "✗ powerlevel10k theme is not installed"
fi

print_info "------------------------------------------"
