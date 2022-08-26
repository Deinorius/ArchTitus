#!/usr/bin/env bash
#github-action genshdoc
#
# @file Post-Setup
# @brief Finalizing installation configurations and cleaning up after script.
echo -ne "
-------------------------------------------------------------------------
   █████╗ ██████╗  ██████╗██╗  ██╗████████╗██╗████████╗██╗   ██╗███████╗
  ██╔══██╗██╔══██╗██╔════╝██║  ██║╚══██╔══╝██║╚══██╔══╝██║   ██║██╔════╝
  ███████║██████╔╝██║     ███████║   ██║   ██║   ██║   ██║   ██║███████╗
  ██╔══██║██╔══██╗██║     ██╔══██║   ██║   ██║   ██║   ██║   ██║╚════██║
  ██║  ██║██║  ██║╚██████╗██║  ██║   ██║   ██║   ██║   ╚██████╔╝███████║
  ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝   ╚═╝   ╚═╝   ╚═╝    ╚═════╝ ╚══════╝
-------------------------------------------------------------------------
                    Automated Arch Linux Installer
                        SCRIPTHOME: ArchTitus
-------------------------------------------------------------------------

Final Setup and Configurations
"

source ${HOME}/ArchTitus/configs/setup.conf

if [[ "${FS}" == "luks" || "${FS}" == "btrfs" ]]; then
 sed -i '14 s/.*/BINARIES=(btrfs)/' /etc/mkinitcpio.conf

echo -ne "
-------------------------------------------------------------------------
                    Creating Snapper Config
-------------------------------------------------------------------------
"

SNAPPER_CONF="$HOME/ArchTitus/configs/etc/snapper/configs/root"
mkdir -p /etc/snapper/configs/
cp -rfv ${SNAPPER_CONF} /etc/snapper/configs/

SNAPPER_CONF_D="$HOME/ArchTitus/configs/etc/conf.d/snapper"
mkdir -p /etc/conf.d/
cp -rfv ${SNAPPER_CONF_D} /etc/conf.d/

fi

echo -ne "
-------------------------------------------------------------------------
               Creating EFI BOOT
-------------------------------------------------------------------------
"
# set qemu modules, if installing via QEMU/virt-manager
if [[ "${DISK}" == *"/dev/vd"* ]]; then
    sed -i '7 s/.*/MODULES=(virtio virtio_blk virtio_pci virtio_net)/' /etc/mkinitcpio.conf
    sudo pacman -S --noconfirm qemu-guest-agent;
    systemctl enable qemu-guest-agent.service
fi
# Editing mkinitcpio configuration for unified kernel image

echo -e "Creating /EFI/Arch folder"
mkdir -p /efi/EFI/Arch

echo -e "Editing mkinitcpio.conf..."
sed -i "s/#default_options=\"\"/default_efi_image=\"\/efi\/EFI\/Arch\/${KERNEL}.efi\"\ndefault_options=\"--splash \/usr\/share\/systemd\/bootctl\/splash-arch.bmp\"/" /etc/mkinitcpio.d/${KERNEL}.preset
sed -i "s/fallback_options=\"-S autodetect\"/fallback_efi_image=\"\/efi\/EFI\/Arch\/${KERNEL}-fallback.efi\"\nfallback_options=\"-S autodetect --splash \/usr\/share\/systemd\/bootctl\/splash-arch.bmp\"/" /etc/mkinitcpio.d/${KERNEL}.preset

echo -e "Kernel command line..."

DISK_UUID=$(blkid -o value -s UUID ${DISK}2)
if [[ "${HIBERNATION}" == "do_hibernate" ]]; then
   wget https://raw.githubusercontent.com/osandov/osandov-linux/master/scripts/btrfs_map_physical.c
   gcc -O2 -o btrfs_map_physical btrfs_map_physical.c
   PHYS_OFFSET=$(./btrfs_map_physical /swap/swapfile | rev | awk -F: 'NR==2 {print $1}' | cut -f 1 | rev)
   PGSZ=$(getconf PAGESIZE)
   RESUME_OFF=$((PHYS_OFFSET / PGSZ))
   MAJMIN=$(lsblk ${DISK} -o MAJ:MIN | awk 'END{print}')
   
   if [[ "${FS}" == "luks" ]]; then
      sed -i 's/HOOKS=(base systemd \(.*block\) /&sd-encrypt/' /etc/mkinitcpio.conf # create sd-encrypt after block hook
      echo "rd.luks.name=${DISK_UUID}=cryptroot rootflags=subvol=@ root=/dev/mapper/cryptroot resume=/dev/mapper/cryptroot resume_offset=${RESUME_OFF} rw bgrt_disable quiet loglevel=4" > /etc/kernel/cmdline
   else
      echo "rootflags=subvol=@ root=UUID=${DISK_UUID} resume=${DISK_UUID} resume_offset=${RESUME_OFF} rw bgrt_disable quiet loglevel=4" > /etc/kernel/cmdline
   fi
   echo ${MAJMIN} > /sys/power/resume
   echo ${RESUME_OFF} > /sys/power/resume_offset
   #rm btrfs_map_physical*

elif [[ "${HIBERNATION}" == "dont_hibernate" ]]; then
   if [[ "${FS}" == "luks" ]]; then
      sed -i 's/HOOKS=(base systemd \(.*block\) /&sd-encrypt/' /etc/mkinitcpio.conf # create sd-encrypt after block hook
      echo "rd.luks.name=${DISK_UUID}=cryptroot rootflags=subvol=@ root=/dev/mapper/cryptroot rw bgrt_disable quiet loglevel=4" > /etc/kernel/cmdline
   else
      echo "rootflags=subvol=@ root=UUID=${DISK_UUID} rw bgrt_disable quiet loglevel=4" > /etc/kernel/cmdline
   fi
fi
echo -e "Regenerate the initramfs"
mkinitcpio -P

echo -ne "
-------------------------------------------------------------------------
               Creating UEFI boot entries for the .efi files
-------------------------------------------------------------------------
"
efibootmgr --create --disk ${DISK} --part 1 --label "Arch${KERNEL}" --loader EFI/Arch/${KERNEL}.efi --verbose
efibootmgr --create --disk ${DISK} --part 1 --label "Arch${KERNEL}-fallback" --loader EFI/Arch/${KERNEL}-fallback.efi --verbose
echo -e "All set!"

echo -ne "
-------------------------------------------------------------------------
               Enabling (and Theming) Login Display Manager
-------------------------------------------------------------------------
"
if [[ ${DESKTOP_ENV} == "kde" ]]; then
  KCM_CONF="${HOME}/ArchTitus/configs/default.conf"
  mkdir -p /etc/sddm.conf.d/
  cp -rfv ${KCM_CONF} /etc/sddm.conf.d/
  systemctl enable sddm.service
  
elif [[ "${DESKTOP_ENV}" == "gnome" ]]; then
  systemctl enable gdm.service

elif [[ "${DESKTOP_ENV}" == "lxde" ]]; then
  systemctl enable lxdm.service

elif [[ "${DESKTOP_ENV}" == "openbox" ]]; then
  systemctl enable lightdm.service
  if [[ "${INSTALL_TYPE}" == "FULL" ]]; then
    # Set default lightdm-webkit2-greeter theme to Litarvan
    sed -i 's/^webkit_theme\s*=\s*\(.*\)/webkit_theme = litarvan #\1/g' /etc/lightdm/lightdm-webkit2-greeter.conf
    # Set default lightdm greeter to lightdm-webkit2-greeter
    sed -i 's/#greeter-session=example.*/greeter-session=lightdm-webkit2-greeter/g' /etc/lightdm/lightdm.conf
  fi

else
  if [[ ! "${DESKTOP_ENV}" == "server"  || ! "${DESKTOP_ENV}" == "kde"  ]]; then
  sudo pacman -S --noconfirm --needed lightdm lightdm-gtk-greeter
  systemctl enable lightdm.service
  fi
fi

echo -ne "
-------------------------------------------------------------------------
                    Enabling Essential Services
-------------------------------------------------------------------------
"
#systemctl enable cups.service
#echo "  Cups enabled"
#ntpd -qg
#systemctl enable ntpd.service
#echo "  NTP enabled"
#systemctl disable dhcpcd.service
#echo "  DHCP disabled"
#systemctl stop dhcpcd.service
#echo "  DHCP stopped"
systemctl enable NetworkManager.service
echo "  NetworkManager enabled"
systemctl enable bluetooth
echo "  Bluetooth enabled"
systemctl enable avahi-daemon.service
echo "  Avahi enabled"
systemctl enable reflector.timer
echo "  Auto update mirros enabled - reflector"
systemctl enable power-profiles-daemon.service
echo "  Enable power-profiles-daemon'

    
echo -ne "
-------------------------------------------------------------------------
                    Setting custom tweaks
-------------------------------------------------------------------------
"
echo -e '"Number lines\nset number\n"Highlight matching brackets\nset showmatch\n"Highlight search result\nset hlsearch' >> /usr/share/vim/vim90/defaults.vim
echo "  Activate Vim tweaks like syntax and number lines"
sysctl vm.swappiness=10
echo "vm.swappiness=10" > /etc/sysctl.d/99-swappiness.conf
echo "  Set system to a lower swappiness with value 10"

YAKU_HERE=$(pacman -Qs yakuake)
if [[ ! -z ${YAKU_HERE} ]]; then
mkdir -p /home/${USERNAME}/.local/share/yakuake/kns_skins/BreezeDarkCompact/
cp -rfv ${HOME}/ArchTitus/configs/BreezeDarkCompact /home/${USERNAME}/.local/share/yakuake/kns_skins/
mkdir -p /home/${USERNAME}/.config/
cp -fv ${HOME}/ArchTitus/configs/yakuakerc /home/${USERNAME}/.config/
mkdir -p /home/$USERNAME/.config/autostart
cp -fv ${HOME}/ArchTitus/configs/org.kde.yakuake.desktop /home/${USERNAME}/.config/autostart
echo "  Let autostart yakuake and set Breeze Dark Compact theme"
fi

sudo chown -R $USERNAME:$USERNAME /home/$USERNAME/.config /home/$USERNAME/.local
echo "  Assigning user $USERNAME ownership to .config and .locale"

cp -rfv ${HOME}/ArchTitus/configs/Aritim-Dark-Rounded-Blur /home/$USERNAME/.local/share/plasma/desktoptheme/Aritim-Dark-Rounded-Blur
cp -rfv ${HOME}/ArchTitus/configs/Aritim-Dark-Flat-Blur /home/$USERNAME/.local/share/plasma/desktoptheme/Aritim-Dark-Flat-Blur

ATLOCALE=$(cat /etc/locale.gen | grep -i '#de_AT.UTF-8')
if [[ ! "${ATLOCALE}" == "de_AT.UTF-8" ]]; then
   echo -e ' \
   Section "InputClass"\n\
        Identifier "system-keyboard"\n\
        MatchIsKeyboard "on"\n\
        Option "XkbLayout" "de"' > /etc/X11/xorg.conf.d/00-keyboard.conf
   #localectl --no-ask-password set-x11-keymap at#"" && localectl --no-ask-password set-x11-keymap at
   else
   localectl set-keymap "" && sudo localectl set-keymap ${KEYMAP}
fi
echo "  Set X.org keymap layout"

echo -ne "
-------------------------------------------------------------------------
                    Cleaning
-------------------------------------------------------------------------
"
# Remove no password sudo rights
sed -i 's/^%wheel ALL=(ALL) NOPASSWD: ALL/# %wheel ALL=(ALL) NOPASSWD: ALL/' /etc/sudoers
sed -i 's/^%wheel ALL=(ALL:ALL) NOPASSWD: ALL/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers
# Add sudo rights
sed -i 's/^# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /etc/sudoers
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

#rm -r $HOME/ArchTitus
#rm -r /home/${USERNAME}/ArchTitus

# Replace in the same state
cd $pwd
