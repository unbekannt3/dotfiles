#!/bin/bash

echo "Installing dot files and needed packages..."

# Determine users system
DNF_CMD=$(which dnf)
APT_CMD=$(which apt-get)

FEDORA_PKGS="zsh git curl wget htop iftop iotop screen nano tmux btop fastfetch util-linux-user stow"
DEB_PKGS="zsh git curl wget htop iftop iotop screen nano tmux btop neofetch passwd stow"

# install basic packages
if [[ ! -z $DNF_CMD ]]; then
    sudo dnf install -y $FEDORA_PKGS
elif [[ ! -z $APT_CMD ]]; then
    sudo apt-get update && sudo apt-get install -y $DEB_PKGS
else
    echo "error can't install packages"
    echo "install script is not compatible with your system atm!"
    exit 1;
fi

# install ohmyzsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# Find all dot files then if the original file exists, create a backup
# Once backed up to {file}.dtbak symlink the new dotfile in place
for file in $(find . -maxdepth 1 -name ".*" -type f  -printf "%f\n" ); do
    if [ -e ~/$file ]; then
        mv -f ~/$file{,.dtbak}
    fi
    ln -s $PWD/$file ~/$file
done

# install zsh themes and plugins
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

# install MesloLGS NF Font
font_dir="$HOME/.local/share/fonts"
mkdir -p $font_dir
cp font/*.ttf "$font_dir/"
# Reset font cache
if command -v fc-cache @>/dev/null ; then
    fc-cache -f $font_dir
fi

# change default shell to zsh for current user
chsh -s $(which zsh)

echo "dotfiles installed!"
echo "Please reload your shell for the changes to take effect."
echo "For best results also set your GUI Terminal font to \"MesloLGS NF\""
