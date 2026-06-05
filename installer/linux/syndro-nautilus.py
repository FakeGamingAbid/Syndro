#!/usr/bin/env python3
"""
Syndro - Nautilus File Manager Extension
Adds "Send with Syndro" to right-click context menu in Nautilus (GNOME Files)

Installation:
    cp syndro-nautilus.py ~/.local/share/nautilus-python/extensions/
    OR system-wide:
    cp syndro-nautilus.py /usr/share/nautilus-python/extensions/
    
    Then restart Nautilus:
    nautilus -q

Requirements:
    - nautilus-python (python3-nautilus on Ubuntu/Debian)
    - syndro installed and in PATH
"""

from gi.repository import Nautilus, GObject
from typing import List
import subprocess
import os

class SyndroExtension(GObject.GObject, Nautilus.MenuProvider):
    """Nautilus extension for Syndro file sharing"""
    
    def _get_syndro_path(self) -> str:
        """Find syndro executable path"""
        # Check common installation locations
        possible_paths = [
            "/usr/local/bin/syndro",
            "/usr/bin/syndro",
            os.path.expanduser("~/.local/bin/syndro"),
            os.path.expanduser("~/Apps/syndro/syndro"),
        ]
        
        for path in possible_paths:
            if os.path.isfile(path) and os.access(path, os.X_OK):
                return path
        
        # Fallback to PATH
        return "syndro"
    
    def _send_with_syndro(self, menu, files):
        """Send selected files with Syndro"""
        file_paths = []
        for file in files:
            path = file.get_location().get_path()
            if path:
                file_paths.append(path)
        
        if file_paths:
            syndro_path = self._get_syndro_path()
            try:
                subprocess.Popen(
                    [syndro_path] + file_paths,
                    start_new_session=True,
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                )
            except Exception as e:
                print(f"Syndro: Error launching: {e}")
    
    def get_file_items(self, files: List) -> List:
        """Add context menu item for files"""
        if not files:
            return []
        
        item = Nautilus.MenuItem(
            name="SyndroExtension::SendWithSyndro",
            label="Send with Syndro",
            tip="Send selected files with Syndro",
            icon="document-send",
        )
        item.connect("activate", self._send_with_syndro, files)
        
        return [item]
    
    def get_background_items(self, current_folder) -> List:
        """Add context menu item for folder background"""
        item = Nautilus.MenuItem(
            name="SyndroExtension::SendFolderWithSyndro",
            label="Send with Syndro",
            tip="Send this folder with Syndro",
            icon="document-send",
        )
        item.connect("activate", self._send_with_syndro, [current_folder])
        
        return [item]
