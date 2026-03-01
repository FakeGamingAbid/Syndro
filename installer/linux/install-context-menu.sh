#!/bin/bash
# =====================================================
# Syndro - Linux Context Menu Installer
# Installs "Send with Syndro" for Nautilus and Dolphin
# =====================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_MODE="${1:-user}"

echo "🚀 Installing Syndro context menu integration..."
echo "   Mode: $INSTALL_MODE"

# Detect installed file managers
HAS_NAUTILUS=false
HAS_DOLPHIN=false

if command -v nautilus &> /dev/null; then
    HAS_NAUTILUS=true
    echo "   ✓ Nautilus detected"
fi

if command -v dolphin &> /dev/null; then
    HAS_DOLPHIN=true
    echo "   ✓ Dolphin detected"
fi

if [ "$HAS_NAUTILUS" = false ] && [ "$HAS_DOLPHIN" = false ]; then
    echo "   ⚠ No supported file manager detected (Nautilus or Dolphin)"
    echo "   Installing both anyway..."
fi

# Install Nautilus extension
install_nautilus() {
    if [ "$INSTALL_MODE" = "system" ]; then
        NAUTILUS_DIR="/usr/share/nautilus-python/extensions"
        sudo mkdir -p "$NAUTILUS_DIR"
        sudo cp "$SCRIPT_DIR/syndro-nautilus.py" "$NAUTILUS_DIR/"
        echo "   ✅ Nautilus extension installed (system-wide)"
    else
        NAUTILUS_DIR="$HOME/.local/share/nautilus-python/extensions"
        mkdir -p "$NAUTILUS_DIR"
        cp "$SCRIPT_DIR/syndro-nautilus.py" "$NAUTILUS_DIR/"
        echo "   ✅ Nautilus extension installed (user)"
    fi
    
    # Restart Nautilus
    if [ "$HAS_NAUTILUS" = true ]; then
        echo "   🔄 Restarting Nautilus..."
        nautilus -q 2>/dev/null || pkill -U $USER nautilus 2>/dev/null || true
    fi
}

# Install Dolphin service menu
install_dolphin() {
    if [ "$INSTALL_MODE" = "system" ]; then
        DOLPHIN_DIR="/usr/share/kservices5/ServiceMenus"
        sudo mkdir -p "$DOLPHIN_DIR"
        sudo cp "$SCRIPT_DIR/syndro-dolphin.desktop" "$DOLPHIN_DIR/"
        echo "   ✅ Dolphin service menu installed (system-wide)"
    else
        DOLPHIN_DIR="$HOME/.local/share/kservices5/ServiceMenus"
        mkdir -p "$DOLPHIN_DIR"
        cp "$SCRIPT_DIR/syndro-dolphin.desktop" "$DOLPHIN_DIR/"
        echo "   ✅ Dolphin service menu installed (user)"
    fi
    
    # Update KDE service cache
    if command -v kbuildsycoca5 &> /dev/null; then
        kbuildsycoca5 2>/dev/null || true
    fi
}

# Install Thunar custom action (optional)
install_thunar() {
    if command -v thunar &> /dev/null; then
        echo "   ℹ Thunar detected - custom actions need manual setup"
        echo "   Add custom action in Thunar Edit → Configure custom actions"
    fi
}

# Install Nemo action (optional)
install_nemo() {
    if command -v nemo &> /dev/null; then
        NEMO_ACTION="[Nemo Action]
Name=Send with Syndro
Comment=Send files with Syndro
Exec=syndro %F
Icon-Name=document-send
Selection=any
Extensions=any;"
        
        if [ "$INSTALL_MODE" = "system" ]; then
            NEMO_DIR="/usr/share/nemo/actions"
            sudo mkdir -p "$NEMO_DIR"
            echo "$NEMO_ACTION" | sudo tee "$NEMO_DIR/syndro.nemo_action" > /dev/null
            echo "   ✅ Nemo action installed (system-wide)"
        else
            NEMO_DIR="$HOME/.local/share/nemo/actions"
            mkdir -p "$NEMO_DIR"
            echo "$NEMO_ACTION" > "$NEMO_DIR/syndro.nemo_action"
            echo "   ✅ Nemo action installed (user)"
        fi
    fi
}

# Perform installations
if [ "$HAS_NAUTILUS" = true ] || [ "$1" = "--all" ]; then
    install_nautilus
fi

if [ "$HAS_DOLPHIN" = true ] || [ "$1" = "--all" ]; then
    install_dolphin
fi

# Optional: Install for other file managers
install_thunar
install_nemo

echo ""
echo "✅ Syndro context menu installation complete!"
echo ""
echo "Usage:"
echo "  Right-click on any file or folder → 'Send with Syndro'"
echo ""
echo "To uninstall:"
echo "  Run: $SCRIPT_DIR/uninstall-context-menu.sh"
