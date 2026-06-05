#!/bin/bash
# =====================================================
# Syndro - Linux Context Menu Uninstaller
# Removes "Send with Syndro" from Nautilus and Dolphin
# =====================================================

set -e

echo "🧹 Uninstalling Syndro context menu integration..."

# Remove Nautilus extension
remove_nautilus() {
    # User installation
    if [ -f "$HOME/.local/share/nautilus-python/extensions/syndro-nautilus.py" ]; then
        rm -f "$HOME/.local/share/nautilus-python/extensions/syndro-nautilus.py"
        echo "   ✅ Removed Nautilus extension (user)"
    fi
    
    # System installation
    if [ -f "/usr/share/nautilus-python/extensions/syndro-nautilus.py" ]; then
        sudo rm -f "/usr/share/nautilus-python/extensions/syndro-nautilus.py"
        echo "   ✅ Removed Nautilus extension (system)"
    fi
    
    # Restart Nautilus
    if command -v nautilus &> /dev/null; then
        nautilus -q 2>/dev/null || true
    fi
}

# Remove Dolphin service menu
remove_dolphin() {
    # User installation
    if [ -f "$HOME/.local/share/kservices5/ServiceMenus/syndro-dolphin.desktop" ]; then
        rm -f "$HOME/.local/share/kservices5/ServiceMenus/syndro-dolphin.desktop"
        echo "   ✅ Removed Dolphin service menu (user)"
    fi
    
    # System installation
    if [ -f "/usr/share/kservices5/ServiceMenus/syndro-dolphin.desktop" ]; then
        sudo rm -f "/usr/share/kservices5/ServiceMenus/syndro-dolphin.desktop"
        echo "   ✅ Removed Dolphin service menu (system)"
    fi
    
    # Update KDE service cache
    if command -v kbuildsycoca5 &> /dev/null; then
        kbuildsycoca5 2>/dev/null || true
    fi
}

# Remove Nemo action
remove_nemo() {
    # User installation
    if [ -f "$HOME/.local/share/nemo/actions/syndro.nemo_action" ]; then
        rm -f "$HOME/.local/share/nemo/actions/syndro.nemo_action"
        echo "   ✅ Removed Nemo action (user)"
    fi
    
    # System installation
    if [ -f "/usr/share/nemo/actions/syndro.nemo_action" ]; then
        sudo rm -f "/usr/share/nemo/actions/syndro.nemo_action"
        echo "   ✅ Removed Nemo action (system)"
    fi
}

# Perform removals
remove_nautilus
remove_dolphin
remove_nemo

echo ""
echo "✅ Syndro context menu uninstalled!"
