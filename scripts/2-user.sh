#!/usr/bin/env bash
#github-action genshdoc
#
# @file User
# @brief User customizations and AUR package installation.
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

Installing AUR Softwares
"
source $HOME/ArchTitus/configs/setup.conf

echo -ne "
-------------------------------------------------------------------------
                    bash/zsh: Setting all plugins
-------------------------------------------------------------------------
"
sudo cp -Tfv ${HOME}/ArchTitus/configs/etc/skel/bashrc /etc/skel/.bashrc
cp -Tfv ${HOME}/ArchTitus/configs/bashrc /home/${USERNAME}/fancy-bash-prompt.bashrc

if [[ ${SHELL} == "zsh" ]]; then
   cd ~
   sudo pacman -S --noconfirm --needed zsh zsh-autosuggestions zsh-completions zsh-history-substring-search zsh-syntax-highlighting zsh-theme-powerlevel10k
   git clone https://aur.archlinux.org/nerd-fonts-noto-sans-mono.git && cd nerd-fonts-noto-sans-mono && makepkg -si --noconfirm
   cd ~ && rm -r nerd-fonts-noto-sans-mono
   git clone https://github.com/Deinorius/deino-zshconf && cd deino-zshconf && makepkg -si --noconfirm
   cd ~ && rm -r deino-zshconf
   sudo chsh -s $/bin/zsh

elif [[ ${SHELL} == "zsh-Titusprofile" ]]; then
   cd ~
   mkdir "/home/$USERNAME/.cache"
   touch "/home/$USERNAME/.cache/zshhistory"
   git clone "https://github.com/ChrisTitusTech/zsh"
   git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/powerlevel10k
   ln -s "~/zsh/.zshrc" ~/.zshrc
fi

sed -n '/'$INSTALL_TYPE'/q;p' ~/ArchTitus/pkg-files/${DESKTOP_ENV}.txt | while read line
do
  if [[ ${line} == '--END OF MINIMAL INSTALL--' ]]
  then
    # If selected installation type is FULL, skip the --END OF THE MINIMAL INSTALLATION-- line
    continue
  fi
  echo "INSTALLING: ${line}"
  sudo pacman -S --noconfirm --needed ${line}
done


if [[ $AUR_HELPER == pamac ]]; then
  sudo pacman -S --noconfirm --needed cmake meson vala libhandy libnotify asciidoc
  cd ~
  git clone "https://gitlab.manjaro.org/applications/$AUR_HELPER.git"
  cd ~/$AUR_HELPER
  meson setup --prefix=/usr --sysconfdir=/etc --buildtype=release ~/$AUR_HELPER-build
  meson compile
  meson install
  sudo pacman -Rs --noconfirm cmake libnotify meson vala asciidoc
  sudo rm -r pamac*
  # sed $INSTALL_TYPE is using install type to check for MINIMAL installation, if it's true, stop
  # stop the script and move on, not installing any more packages below that line
  sed -n '/'$INSTALL_TYPE'/q;p' ~/ArchTitus/pkg-files/aur-pkgs.txt | while read line
  do
    if [[ ${line} == '--END OF MINIMAL INSTALL--' ]]; then
      # If selected installation type is FULL, skip the --END OF THE MINIMAL INSTALLATION-- line
      continue
    fi
    echo "INSTALLING: ${line}"
    $AUR_HELPER install --no-confirm ${line}
  done
fi

if [[ ! $AUR_HELPER == none || ! $AUR_HELPER == pamac ]]; then
  cd ~
  git clone "https://aur.archlinux.org/$AUR_HELPER.git"
  cd ~/$AUR_HELPER
  makepkg -si --noconfirm
  # sed $INSTALL_TYPE is using install type to check for MINIMAL installation, if it's true, stop
  # stop the script and move on, not installing any more packages below that line
  sed -n '/'$INSTALL_TYPE'/q;p' ~/ArchTitus/pkg-files/aur-pkgs.txt | while read line
  do
    if [[ ${line} == '--END OF MINIMAL INSTALL--' ]]; then
      # If selected installation type is FULL, skip the --END OF THE MINIMAL INSTALLATION-- line
      continue
    fi
    echo "INSTALLING: ${line}"
      $AUR_HELPER -S --noconfirm --needed ${line}
  done
fi

export PATH=$PATH:~/.local/bin

# Theming DE if user chose FULL installation
if [[ $DESKTOP_ENV == "kde" ]]; then
  cp -r ~/ArchTitus/configs/.config/* ~/.config/
  cd ~
  git clone https://aur.archlinux.org/konsave.git
  cd konsave && makepkg -si --noconfirm
  konsave -i ~/ArchTitus/configs/kde.knsv
  sleep 1
  konsave -a kde
elif [[ $DESKTOP_ENV == "openbox" ]]; then
  cd ~
  git clone https://github.com/stojshic/dotfiles-openbox
  ./dotfiles-openbox/install-titus.sh
fi


echo -ne "
-------------------------------------------------------------------------
                    SYSTEM READY FOR 3-post-setup.sh
-------------------------------------------------------------------------
"
exit
