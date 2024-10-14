#!/usr/bin/env bash

# flatpak aliases
case "$1" in
    i) flatpak install flathub "$2" --noninteractive;;
    r) flatpak uninstall "$2";;
    u) flatpak update;;
    l) flatpak list;;
    s) flatpak search "$2" --columns=name,application;;
    sq) flatpak search "$2" --columns=application;;
    sd) flatpak search "$2" --columns=application,description;;
    ha) flatpak override "$2" --filesystem=home:ro
    *) flatpak "$@"
esac
