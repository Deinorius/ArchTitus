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
sed -i 's/#default_options=""/default_efi_image="\/efi\/EFI\/Arch\/${KERNEL}.efi"\ndefault_options="--splash \/usr\/share\/systemd\/bootctl\/splash-arch.bmp"/' /etc/mkinitcpio.d/$KERNEL.preset
sed -i 's/fallback_options="-S autodetect"/fallback_efi_image="\/efi\/EFI\/Arch\/${KERNEL}-fallback.efi"\nfallback_options="-S autodetect --splash \/usr\/share\/systemd\/bootctl\/splash-arch.bmp"/' /etc/mkinitcpio.d/$KERNEL.preset
#sed -i 's/^#default_efi_image/default_efi_image/' /etc/mkinitcpio.d/${KERNEL}.preset

echo -e "Kernel command line..."

if [[ "${FS}" == "luks" ]]; then
    sed -i 's/HOOKS=(base systemd \(.*block\) /&sd-encrypt/' /etc/mkinitcpio.conf # create sd-encrypt after block hook
    LUKS_NAME="blkid -o value -s UUID ${DISK}"
    echo "rd.luks.name=$LUKS_NAME=cryptroot" > /etc/kernel/cmdline
    echo "rootflags=subvol=@ root=${DISK}" >> /etc/kernel/cmdline
fi

if [[ "${FS}" == "btrfs" ]]; then
    LUKS_NAME="blkid -o value -s UUID ${DISK}"
    echo "root=UUID=${DISK}" > /etc/kernel/cmdline
    echo "rootflags=subvol=@ root=${DISK}" >> /etc/kernel/cmdline
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
  echo [Theme] >>  /etc/sddm.conf
  echo Current=Breeze >> /etc/sddm.conf
  cp -r /usr/lib/sddm/sddm.conf.d/ /etc/
  echo "[THEME]" >> /etc/sddm.conf.d/default.conf
  echo "Current=breeze" >> /etc/sddm.conf.d/default.conf
  systemctl enable sddm.service
  sed -n '/'$INSTALL_TYPE'/q;p' $HOME/ArchTitus/pkg-files/kde.txt | while read line
  do
    if [[ ${line} == '--END OF MINIMAL INSTALL--' ]]; then
      # If selected installation type is FULL, skip the --END OF THE MINIMAL INSTALLATION-- line
      continue
    fi
    cp -r ${HOME}/ArchTitus/config/yakuake-skin/ /home/${USERNAME}/.local/share/yakuake/kns_skins/BreezeDarkCompact/
    sed -i 's/^Skin=/Skin=BreezeDarkCompact/' /home/${USERNAME}/.config/yakuakerc
  done
  
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
systemctl enable --now reflector.timer
echo "  Auto update mirros enabled - reflector"

echo -ne "
-------------------------------------------------------------------------
                    Setting custom tweaks
-------------------------------------------------------------------------
"
echo -e """Syntax highlighting\nsyntax on\n""Number lines\nset number\n""Autocomplete\nset wildmenu\n""Highlight matching brackets\nset showmatch\n""Search tweaks\nset incsearch\nset hlsearch\n" > /etc/vimrc
echo "  Set Vim tweaks - Syntax highlighting, number lines, etc"
sysctl vm.swappiness=10
echo "vm.swappiness=10" >> /etc/sysctl.conf
echo "  Set system to a lower swappiness with value 10"
localectl set-x11-keymap ${KEYMAP}
echo "  Set X.org keymap layout"


echo -ne "
-------------------------------------------------------------------------
                    bash/zsh: Setting all plugins
-------------------------------------------------------------------------
"
if [[ ${SHELL} == "bash" ]]; then
   cp -rfv ${HOME}/ArchTitus/configs/etc/skel/.bashrc /etc/skel/.bashrc
   cp -rfv ${HOME}/ArchTitus/configs/etc/.bashrc /home/${USERNAME}/fancy-bash-prompt.bashrc
fi

if [[ ${SHELL} == "zsh" ]]; then
   pacman -S --noconfirm --needed zsh zsh-autosuggestions zsh-completions zsh-history-substring-search zsh-syntax-highlighting zsh-powerlevel10k nerd-fonts-noto-sans-mono grml-zsh-config
   chsh -s $/usr/bin/zsh
   #git clone https://github.com/Chrysostomus/manjaro-zsh-config
   #no idea, what to do next
fi


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

rm -r $HOME/ArchTitus
rm -r /home/${USERNAME}/ArchTitus

# Replace in the same state
cd $pwd
