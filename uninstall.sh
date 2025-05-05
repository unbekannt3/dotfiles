#!/bin/bash

# Set colors for better readability
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
RESET="\033[0m"

# Function to print colorful messages
print_info() {
    echo -e "${GREEN}INFO:${RESET} $1"
}

print_warning() {
    echo -e "${YELLOW}WARNING:${RESET} $1"
}

print_error() {
    echo -e "${RED}ERROR:${RESET} $1"
}

# Function to ask user for confirmation
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

print_info "Starting dotfiles uninstallation..."

# Find the latest backup directory, if any
BACKUP_ROOT="$HOME/.dotfiles_backup"
if [ -d "$BACKUP_ROOT" ]; then
    LATEST_BACKUP=$(find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d | sort -r | head -n 1)

    if [ -n "$LATEST_BACKUP" ]; then
        print_info "Found backup directory: $LATEST_BACKUP"
        USE_BACKUP=true
    else
        print_warning "No backup directories found in $BACKUP_ROOT"
        USE_BACKUP=false
    fi
else
    print_warning "No backup directory found at $BACKUP_ROOT"
    USE_BACKUP=false

    # Check for old-style .dtbak files as fallback
    OLD_BACKUPS=$(find "$HOME" -maxdepth 1 -name "*.dtbak" | wc -l)
    if [ "$OLD_BACKUPS" -gt 0 ]; then
        print_info "Found $OLD_BACKUPS old-style backup files"
        USE_OLD_BACKUP=true
    else
        print_warning "No old-style backup files found"
        USE_OLD_BACKUP=false
    fi
fi

# Check for dotfiles to remove
print_info "Checking for dotfiles that need to be removed..."
REMOVED_COUNT=0
RESTORED_COUNT=0

# Loop through all the dotfiles in the current directory
for file in $(find . -maxdepth 1 -name ".*" -type f -not -name ".git*" -printf "%f\n" 2>/dev/null); do
    # Check if the file in home directory is a symlink pointing to our dotfiles
    if [ -h "$HOME/$file" ] && [ "$(readlink "$HOME/$file")" = "$PWD/$file" ]; then
        print_info "Removing symlink: $HOME/$file"
        rm -f "$HOME/$file" && ((REMOVED_COUNT++)) || print_error "Failed to remove $HOME/$file"

        # Restore from the latest backup if available
        if [ "$USE_BACKUP" = true ] && [ -f "$LATEST_BACKUP/$file" ]; then
            print_info "Restoring $file from backup"
            cp "$LATEST_BACKUP/$file" "$HOME/$file" && ((RESTORED_COUNT++)) || print_error "Failed to restore $file"
        elif [ "$USE_OLD_BACKUP" = true ] && [ -f "$HOME/${file}.dtbak" ]; then
            print_info "Restoring $file from old-style backup"
            mv -f "$HOME/${file}.dtbak" "$HOME/$file" && ((RESTORED_COUNT++)) || print_error "Failed to restore $file from old backup"
        fi
    elif [ -f "$HOME/$file" ]; then
        print_warning "File $HOME/$file exists but is not a symlink to our dotfiles"
        if confirm "Remove this file anyway?"; then
            rm -f "$HOME/$file" && print_info "Removed $HOME/$file" && ((REMOVED_COUNT++)) || print_error "Failed to remove $HOME/$file"
        else
            print_info "Skipping $HOME/$file"
        fi
    fi
done

# Ask about oh-my-zsh
if [ -d "$HOME/.oh-my-zsh" ]; then
    if confirm "Do you want to remove oh-my-zsh?"; then
        print_info "Removing oh-my-zsh..."
        rm -rf "$HOME/.oh-my-zsh" && print_info "oh-my-zsh removed" || print_error "Failed to remove oh-my-zsh"
    else
        print_info "Keeping oh-my-zsh"
    fi
fi

# Ask about zsh plugins directories
ZSH_CUSTOM_DIR="$HOME/.oh-my-zsh/custom"
if [ -d "$ZSH_CUSTOM_DIR" ]; then
    for plugin_dir in "$ZSH_CUSTOM_DIR/themes/powerlevel10k" "$ZSH_CUSTOM_DIR/plugins/zsh-syntax-highlighting" "$ZSH_CUSTOM_DIR/plugins/zsh-autosuggestions"; do
        if [ -d "$plugin_dir" ]; then
            plugin_name=$(basename "$plugin_dir")
            if confirm "Do you want to remove $plugin_name?"; then
                print_info "Removing $plugin_name..."
                rm -rf "$plugin_dir" && print_info "$plugin_name removed" || print_error "Failed to remove $plugin_name"
            else
                print_info "Keeping $plugin_name"
            fi
        fi
    done
fi

# Cleanup old backup files if they exist
if [ "$USE_OLD_BACKUP" = true ]; then
    OLD_BACKUPS_COUNT=$(find "$HOME" -maxdepth 1 -name "*.dtbak" | wc -l)
    if [ "$OLD_BACKUPS_COUNT" -gt 0 ] && confirm "Remove all old-style backup files (*.dtbak)?"; then
        find "$HOME" -maxdepth 1 -name "*.dtbak" -delete
        print_info "Removed all old-style backup files"
    fi
fi

# Summary
print_info "------------------------------------------"
print_info "Uninstallation Summary:"
print_info "------------------------------------------"
print_info "Removed symlinks: $REMOVED_COUNT"
print_info "Restored files from backup: $RESTORED_COUNT"
if [ -d "$HOME/.oh-my-zsh" ]; then
    print_info "oh-my-zsh is still installed"
else
    print_info "oh-my-zsh was removed or not installed"
fi
print_info "------------------------------------------"

if [ "$REMOVED_COUNT" -eq 0 ] && [ "$RESTORED_COUNT" -eq 0 ]; then
    print_warning "No changes were made"
else
    print_info "Dotfiles have been uninstalled"

    # Ask about changing back the shell
    if [ -n "$(command -v zsh 2>/dev/null)" ] && [ "$(getent passwd $USER | cut -d: -f7)" = "$(which zsh)" ]; then
        available_shells=()
        if [ -n "$(command -v bash 2>/dev/null)" ]; then available_shells+=("bash"); fi
        if [ -n "$(command -v sh 2>/dev/null)" ]; then available_shells+=("sh"); fi

        if [ ${#available_shells[@]} -gt 0 ] && confirm "Do you want to change your shell back to ${available_shells[0]}?"; then
            chsh -s "$(which ${available_shells[0]})" && print_info "Shell changed to ${available_shells[0]}" || print_error "Failed to change shell"
        fi
    fi
fi
