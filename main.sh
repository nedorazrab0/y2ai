#!/usr/bin/env bash
set -e
path='/tmp/njk'

# install configurating
read -p '- Username: ' name
read -sp '- Password: ' password; echo
read -p '- Timezone (Europe/Moscow): ' zone
read -p '- Locale (ru_RU): ' kbl
read -p '- Target disk name: ' disk
read -p '- Do you want to destroy your own disk? (y/n): ' agreement

case "$agreement" in
    y) true;;
    n) exit 0;;
    *) exit 1;;
esac

# disk tuning
sysctl -w 'vm.vfs_cache_pressure = 150'
sysctl -w 'vm.dirty_bytes = 268435456'
sysctl -w 'vm.dirty_background_bytes = 134217728'
sysctl -w 'vm.dirty_writeback_centisecs = 1500'

echo 'none' > /sys/block/$disk/queue/scheduler
echo '128' > /sys/block/$disk/queue/nr_requests
echo '2' > /sys/block/$disk/queue/rq_affinity

# disk partition
echo '- You have 2 seconds to save your disk!'
sleep 2
cd /
umount -v /dev/$disk* || true
umount -vR /mnt || true
echo -e 'label:gpt\n,64M,U,-\n+' | sfdisk -w always -W always /dev/$disk

mkfs.fat -vF32 -S512 -n 'ESP' --codepage=437 /dev/$disk*1
mkfs.btrfs -fKL 'archlinux' -n65536 -m single /dev/$disk*2

mount -t btrfs -o 'noatime,nodiscard,ssd,compress=zstd:3' /dev/$disk*2 /mnt
mount -t vfat --mkdir=600 -o 'umask=0177,noexec,nosuid,noatime,utf8=false' /dev/$disk*1 /mnt/boot

# installing
pacstrap -KP /mnt base linux-zen booster linux-firmware amd-ucode \
                  opendoas vulkan-radeon libva-mesa-driver \
                  btrfs-progs f2fs-tools xfsprogs exfatprogs dosfstools \
                  android-tools android-udev git bash-completion zip flatpak zram-generator nano dhcpcd reflector \
                  hyprland polkit xdg-deskop-portal-hyprland mako kitty noto-fonts waybar otf-font-awesome brightnessctl \
                  grim slurp gnome-boxes bluez{,-utils} pipewire{,-alsa,-pulse,-jack}
sed -i -e 's/#en_US.UTF-8/en_US.UTF-8/' -e "s/#$kbl.UTF-8/$kbl.UTF-8/" /mnt/etc/locale.gen

mount --bind "$path" /mnt/mnt
arch-chroot /mnt bash /mnt/inchroot.sh "$name" "$password" "$zone"

# post configuration

sed -i -e 's/autogenerated = 0/autogenerated = 0/' -e 's/monitor=,preferred,auto,auto/monitor=,preferred,auto,1/' \
       -e 's/dolphin/systemctl poweroff/' -e 's/wofi/timeout 5 wofi -G/' -e 's/# exec-once = $terminal/exec-once = $terminal & waybar/' \
       -e 's/gaps_out = 20/gaps_out = 5/' -e 's/border_size = 2/border_size = 1/' -e 's/resize_on_border = false/resize_on_border = true/' \
       -e "s/kb_layout = us/&,${kbl::2}/" -e 's/kb_options =/kb_options = grp:caps_toggle/' "/home/$USER/.config/hypr/hyprland.conf" 

echo 'permit persist :wheel' > /mnt/etc/doas.conf
chmod 400 /mnt/etc/doas.conf
echo 'nedocomp' > /mnt/etc/hostname
sed -i 's/#DefaultTimeoutStopSec=.*/DefaultTimeoutStopSec=5s/' /mnt/etc/systemd/system.conf
cat /etc/systemd/timesyncd.conf > /mnt/etc/systemd/timesyncd.conf
cat /etc/xdg/reflector/reflector.conf > /mnt/etc/xdg/reflector/reflector.conf
genfstab -U /mnt > /mnt/etc/fstab

uuid="$(blkid -s UUID -o value /dev/$disk*2)"
cat $path/sys-configs/arch-zen.conf | sed "s/uuidv/$uuid/" > /mnt/boot/loader/entries/arch-zen.conf

cp $path/bin/{atp,wlc,fin.sh} /mnt/usr/bin
chmod +x /mnt/usr/bin/{atp,wlc,fin.sh}

cp $path/sys-configs/{20-wired,25-wireless}.network /mnt/etc/systemd/network
cp $path/sys-configs/60-ioschedulers.rules /mnt/etc/udev/rules.d
cp $path/sys-configs/99-yaebal.rules /mnt/etc/udev/rules.d
cp $path/sys-configs/99-sysctl.conf /mnt/etc/sysctl.d
cp $path/sys-configs/zram-generator.conf /mnt/etc/systemd
cat $path/sys-configs/loader.conf > /mnt/boot/loader/loader.conf
cat $path/sys-configs/nanorc > /mnt/etc/nanorc

echo '- Goodbye ;)'
sleep 2
fstrim -v /mnt
umount -R /mnt
systemctl poweroff
