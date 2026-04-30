#!/bin/bash

sudo mkdir -p /etc/skel/.config/

# Desktop and taskbar layout
sudo cp ~/.config/plasma-org.kde.plasma.desktop-appletsrc /etc/skel/.config/


# Konsole settings and profiles
# Create the necessary directories in /etc/skel
sudo mkdir -p /etc/skel/.config
sudo mkdir -p /etc/skel/.local/share/konsole
sudo mkdir -p /etc/skel/.local/share/kxmlgui5/konsole
# Copy general Konsole settings (includes default profile pointer)
sudo cp ~/.config/konsolerc /etc/skel/.config/
# Copy your custom profile
sudo cp ~/.local/share/konsole/* /etc/skel/.local/share/konsole/
# Copy your custom hotkey settings
sudo cp ~/.local/share/kxmlgui5/konsole/konsoleui.rc /etc/skel/.local/share/kxmlgui5/konsole/
# (Optional) If you have global shortcuts to launch Konsole:
sudo cp ~/.config/kglobalshortcutsrc ~/.config/khotkeysrc ~/.config/kwinrc /etc/skel/.config/


# VS-code extensions
sudo cp -r ~/.vscode/extensions/* /usr/share/code/resources/app/extensions/
sudo sh -c 'find /usr/share/code/resources/app/extensions -type f -exec file {} \; | grep ELF | cut -d: -f1 | xargs chmod +rx'

