#!/bin/bash
set -e

if [[ "$OSTYPE" == "darwin"* ]]; then
    OS_TYPE="macos"
    echo "Detected macOS"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS_TYPE="linux"
    echo "Detected Linux"
else
    echo "Unsupported operating system: $OSTYPE"
    exit 1
fi

if ! command -v gh &> /dev/null; then
    echo "github-cli (gh) not found. Installing..."
    
    if [[ "$OS_TYPE" == "macos" ]]; then
        if ! command -v brew &> /dev/null; then
            echo "Homebrew not found. Installing Homebrew first..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            
            if [[ -x "/opt/homebrew/bin/brew" ]]; then
                eval "$(/opt/homebrew/bin/brew shellenv)"
            elif [[ -x "/usr/local/bin/brew" ]]; then
                eval "$(/usr/local/bin/brew shellenv)"
            fi
        fi
        brew install gh
    elif [[ "$OS_TYPE" == "linux" ]]; then
        sudo pacman -S github-cli git make
    fi
fi

if ! gh auth status &>/dev/null; then
    echo "Not logged into GitHub. Please run 'gh auth login' and then rerun this script."
    exit 1
fi

if ! git config --global --get url."git@github.com:".insteadof &>/dev/null; then
    echo "Configuring git to use SSH for GitHub..."
    git config --global url."git@github.com:".insteadOf "https://github.com/"
fi

CONFIG_DIR="$HOME/.config"
ZSHRC_LINK="$HOME/.zshrc"
ZSHRC_TARGET="$CONFIG_DIR/.zshrc"
DOTFILES_REPO="Jonathan-Rowles/dotfiles"

if [ -d "$CONFIG_DIR/.git" ]; then
    REMOTE_URL=$(git -C "$CONFIG_DIR" remote get-url origin 2>/dev/null || echo "")
    if [[ $REMOTE_URL == *"$DOTFILES_REPO"* ]]; then
        echo "Dotfiles repository already exists in ~/.config. Pulling latest changes..."
        git -C "$CONFIG_DIR" pull origin main || git -C "$CONFIG_DIR" pull origin master
        
        if [ -f "$HOME/.config/install.sh" ]; then
            sh "$HOME/.config/install.sh"
        else
            echo "Warning: install.sh not found in ~/.config/"
        fi
        exit 0
    else
        echo "A different git repository exists in ~/.config."
        echo "Please manually back up and remove it before continuing."
        exit 1
    fi
fi

if [ -d "$CONFIG_DIR" ]; then
    echo "Found existing ~/.config directory."
    
    BACKUP_DIR="$HOME/.config.bak.$(date +%Y%m%d%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    GH_CONFIG_DIR="$CONFIG_DIR/gh"
    GH_BACKUP_DIR="$BACKUP_DIR/gh"

    if [ -d "$GH_CONFIG_DIR" ]; then
        echo "Preserving GitHub CLI credentials..."
        mkdir -p "$GH_BACKUP_DIR"
        cp -r "$GH_CONFIG_DIR"/* "$GH_BACKUP_DIR/"
    fi
    
    echo "Backing up existing .config contents to $BACKUP_DIR"
    find "$CONFIG_DIR" -mindepth 1 -maxdepth 1 -not -name ".git" -exec mv {} "$BACKUP_DIR/" \;

    if [ -d "$CONFIG_DIR/.git" ]; then
        rm -rf "$CONFIG_DIR/.git"
    fi
fi

mkdir -p "$CONFIG_DIR"

echo "Cloning dotfiles repository to ~/.config..."
git clone "git@github.com:$DOTFILES_REPO.git" "$CONFIG_DIR.tmp"

mv "$CONFIG_DIR.tmp"/* "$CONFIG_DIR" 2>/dev/null || true
mv "$CONFIG_DIR.tmp"/.[!.]* "$CONFIG_DIR" 2>/dev/null || true
rm -rf "$CONFIG_DIR.tmp"

if [ -d "$GH_BACKUP_DIR" ] && [ ! -d "$GH_CONFIG_DIR" ]; then
    echo "Restoring GitHub CLI credentials..."
    mkdir -p "$GH_CONFIG_DIR"
    cp -r "$GH_BACKUP_DIR"/* "$GH_CONFIG_DIR/"
fi

if [ -f "$ZSHRC_LINK" ] && [ ! -L "$ZSHRC_LINK" ]; then
    echo "Backing up existing ~/.zshrc to ~/.zshrc.backup"
    mv "$ZSHRC_LINK" "$ZSHRC_LINK.backup"
    ln -s "$ZSHRC_TARGET" "$ZSHRC_LINK"
    echo "Symlink created: ~/.zshrc -> $ZSHRC_TARGET"
elif [ -L "$ZSHRC_LINK" ]; then
    echo "Existing ~/.zshrc symlink detected. Skipping symlink creation."
else
    ln -s "$ZSHRC_TARGET" "$ZSHRC_LINK"
    echo "Symlink created: ~/.zshrc -> $ZSHRC_TARGET"
fi

if [ -f "$CONFIG_DIR/install.sh" ]; then
    echo "Running install.sh script..."
    sh "$CONFIG_DIR/install.sh"
else
    echo "Warning: install.sh not found in ~/.config/"
fi

echo "🔓 Dotfiles installation complete!"
