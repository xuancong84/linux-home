#!/bin/bash

alias RSYNC="sudo rsync -avlP --delete --no-owner --no-group"

sudo mkdir -p /etc/skel/.config/


# Desktop and taskbar layout
RSYNC ~/.config/plasma-org.kde.plasma.desktop-appletsrc /etc/skel/.config/


# Konsole settings and profiles
# Create the necessary directories in /etc/skel
sudo mkdir -p /etc/skel/.config
sudo mkdir -p /etc/skel/.local/share/konsole
sudo mkdir -p /etc/skel/.local/share/kxmlgui5/konsole
# Copy general Konsole settings (includes default profile pointer)
RSYNC ~/.config/konsolerc /etc/skel/.config/
# Copy your custom profile
RSYNC ~/.local/share/konsole/* /etc/skel/.local/share/konsole/
# Copy your custom hotkey settings
RSYNC ~/.local/share/kxmlgui5/konsole/konsoleui.rc /etc/skel/.local/share/kxmlgui5/konsole/
# (Optional) If you have global shortcuts to launch Konsole:
RSYNC ~/.config/kglobalshortcutsrc ~/.config/khotkeysrc ~/.config/kwinrc /etc/skel/.config/

if [ -s ~/.continue/config.json ]; then
	sudo mkdir -p /etc/skel/.continue
	RSYNC ~/.continue/config.json /etc/skel/.continue/
fi

# VS-code extensions
RSYNC ~/.vscode/extensions /usr/share/code/resources/app/
sudo sh -c 'find /usr/share/code/resources/app/extensions -type f -exec file {} \; | grep ELF | cut -d: -f1 | xargs chmod +rx'

