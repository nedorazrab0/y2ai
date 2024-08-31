#!/usr/bin/env bash
read -p '- Coutry (for mirrors): ' loc

# ntp
sed -i -e 's/#NTP=/NTP=/' -e 's/#FallbackNTP=.*/FallbackNTP=time.google.com/' /etc/systemd/timesyncd.conf
systemctl restart systemd-timesyncd

path='/tmp/njk'
# pacman configuration
sed -i -e 's/#ParallelDownloads = 5/ParallelDownloads = 15/' -e 's/#Color/Color/' -e 's/#VerbosePkgLists/VerbosePkgLists/' /etc/pacman.conf
pacman -Sy archlinux-keyring --needed --noconfirm
echo '- Configuring mirrors...'
reflector -c "$loc" -p https -f 6 --save /etc/pacman.d/mirrorlist || exit 1
pacman -Syy git --noconfirm
rm -rf "$path"
git clone https://github.com/nedorazrab0/arch-install "$path"

bash "$path/main.sh"
