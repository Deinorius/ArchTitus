#!/usr/bin/env bash
#-------------------------------------------------------------------------
#   █████╗ ██████╗  ██████╗██╗  ██╗████████╗██╗████████╗██╗   ██╗███████╗
#  ██╔══██╗██╔══██╗██╔════╝██║  ██║╚══██╔══╝██║╚══██╔══╝██║   ██║██╔════╝
#  ███████║██████╔╝██║     ███████║   ██║   ██║   ██║   ██║   ██║███████╗
#  ██╔══██║██╔══██╗██║     ██╔══██║   ██║   ██║   ██║   ██║   ██║╚════██║
#  ██║  ██║██║  ██║╚██████╗██║  ██║   ██║   ██║   ██║   ╚██████╔╝███████║
#  ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝   ╚═╝   ╚═╝   ╚═╝    ╚═════╝ ╚══════╝
#-------------------------------------------------------------------------
#github-action genshdoc
#
# @file Preinstall
# @brief Contains the steps necessary to configure and pacstrap the install to selected drive. 
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
-------------------------------------------------------------------------

Setting up mirrors for optimal download
"
source $CONFIGS_DIR/setup.conf
#iso=$(curl -4 ifconfig.co/country-iso)
timedatectl set-ntp true
pacman -S --noconfirm archlinux-keyring #update keyrings to latest to prevent packages failing to install
pacman -S --noconfirm --needed pacman-contrib terminus-font
#setfont ter-v22b
sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf
pacman -S --noconfirm --needed reflector rsync grub
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
echo -ne "
-------------------------------------------------------------------------
                    Setting up $iso mirrors for faster downloads
-------------------------------------------------------------------------
"
reflector -a 48 -c 'Austria' -f 5 -l 20 --sort rate --save /etc/pacman.d/mirrorlist
mkdir /mnt &>/dev/null # Hiding error message if any
echo -ne "
-------------------------------------------------------------------------
                    Installing Prerequisites
-------------------------------------------------------------------------
"
pacman -S --noconfirm --needed gptfdisk btrfs-progs glibc
echo -ne "
-------------------------------------------------------------------------
                    Formating Disk
-------------------------------------------------------------------------
"
umount -A --recursive /mnt # make sure everything is unmounted before we start
# disk prep
sgdisk -Z ${DISK} # zap all on disk
sgdisk -o ${DISK} # new gpt disk 2048 alignment | sgdisk -a 2048

# create partitions
#sgdisk -n 1::+1M --typecode=1:EF02 --change-name=1:'BIOSBOOT' ${DISK} # partition 1 (BIOS Boot Partition)
sgdisk -n 1::+550M --typecode=1:EF00 --change-name=1:'EFIBOOT' ${DISK} # partition 2 (UEFI Boot Partition)
#if [[ "${FS}" == "luks" ]]; then
#    sgdisk -n 2::-0 --typecode=2:8309 --change-name=2:'ARCHlinux' ${DISK} # partition 3 (Root), default start, remaining
#else
sgdisk -n 2::-0 --typecode=2:8300 --change-name=2:'Archlinux' ${DISK} # partition 3 (Root), default start, remaining
#fi
if [[ ! -d "/sys/firmware/efi" ]]; then # Checking for bios system
    sgdisk -A 1:set:2 ${DISK}
fi
partprobe ${DISK} # reread partition table to ensure it is correct

# make filesystems
echo -ne "
-------------------------------------------------------------------------
                    Creating Filesystems
-------------------------------------------------------------------------
"
# @description Creates the btrfs subvolumes. 
createsubvolumes () {
    btrfs su cr /mnt/@ # to be mounted at /
    btrfs su cr /mnt/@snapshots # to be mounted at /.snapshots
    btrfs su cr /mnt/@home # to be mounted at /home
    btrfs su cr /mnt/@srv # to be mounted at /srv
    btrfs su cr /mnt/@swap # to be mounted at /swap
    btrfs su cr /mnt/@var_abs # to be mounted at /var/abs
    btrfs su cr /mnt/@var_cache_pacmanPkg # to be mounted at /var/cache/pacman/pkg
    btrfs su cr /mnt/@var_lib_containers # /var/lib/containers
    btrfs su cr /mnt/@var_lib_libvirtImages # to be mounted at /var/log
    btrfs su cr /mnt/@var_log # to be mounted at /var/log
    btrfs su cr /mnt/@var_tmp # to be mounted at /var/tmp
}

# @description Mount all btrfs subvolumes after root has been mounted.
mountallsubvol () {
    mount -m -o ${MOUNT_OPTIONS},subvol=@snapshots ${partition2} /mnt/.snapshots
    mount -m -o ${MOUNT_OPTIONS},subvol=@home ${partition2} /mnt/home
    mount -m -o ${MOUNT_OPTIONS},subvol=@srv ${partition2} /mnt/srv
    mount -m -o ${MOUNT_OPTIONS},subvol=@swap ${partition2} /mnt/swap
    mount -m -o ${MOUNT_OPTIONS},subvol=@var_abs ${partition2} /mnt/var/abs
    mount -m -o ${MOUNT_OPTIONS},subvol=@var_cache_pacmanPkg ${partition2} /mnt/var/cache/pacman/pkg
    mount -m -o ${MOUNT_OPTIONS},subvol=@var_lib_containers /dev/mapper/cryptroot/mnt/var/lib/containers
    mount -m -o ${MOUNT_OPTIONS},subvol=@var_lib_libvirtImages ${partition2} /mnt/var/lib/libvirt/images
    mount -m -o ${MOUNT_OPTIONS},subvol=@var_log ${partition2} /mnt/var/log
    mount -m -o ${MOUNT_OPTIONS},subvol=@var_tmp ${partition2} /mnt/var/tmp
}

# @description BTRFS subvolulme creation and mounting. 
subvolumesetup () {
# create nonroot subvolumes
    createsubvolumes     
# unmount root to remount with subvolume 
    umount /mnt
# mount @ subvolume
    mount -o ${MOUNT_OPTIONS},subvol=@ ${partition2} /mnt
# mount subvolumes
    mountallsubvol
}

if [[ "${DISK}" =~ "nvme" ]]; then
    partition1=${DISK}p1
    partition2=${DISK}p2
else
    partition1=${DISK}1
    partition2=${DISK}2
fi

if [[ "${FS}" == "btrfs" ]]; then
    mkfs.vfat -F32 -n "EFIBOOT" ${partition1}
    mkfs.btrfs -L ARCHlinux ${partition2} -f
    mount -t btrfs ${partition2} /mnt
    subvolumesetup
elif [[ "${FS}" == "ext4" ]]; then
    mkfs.vfat -F32 -n "EFIBOOT" ${partition1}
    mkfs.ext4 -L ARCHlinux ${partition2}
    mount -t ext4 ${partition2} /mnt
elif [[ "${FS}" == "luks" ]]; then
    mkfs.vfat -F32 -n "EFIBOOT" ${partition1}
# enter luks password to cryptsetup and format root partition
    echo -n "${LUKS_PASSWORD}" | cryptsetup -y -v luksFormat ${partition2} -
# open luks container and ROOT will be place holder 
    echo -n "${LUKS_PASSWORD}" | cryptsetup open ${partition2} ROOT -
# now format that container
    mkfs.btrfs -L ARCHlinux ${partition2}
# create subvolumes for btrfs
    mount -t btrfs ${partition2} /mnt
    subvolumesetup
# store uuid of encrypted partition for grub
    echo ENCRYPTED_PARTITION_UUID=$(blkid -s UUID -o value ${partition2}) >> $CONFIGS_DIR/setup.conf
fi

# mount target
mkdir -p /mnt/efi
mount -t vfat -L EFIBOOT /mnt/efi

if ! grep -qs '/mnt' /proc/mounts; then
    echo "Drive is not mounted can not continue"
    echo "Rebooting in 3 Seconds ..." && sleep 1
    echo "Rebooting in 2 Seconds ..." && sleep 1
    echo "Rebooting in 1 Second ..." && sleep 1
    reboot now
fi
echo -ne "
-------------------------------------------------------------------------
                    Arch Install on Main Drive
-------------------------------------------------------------------------
"
pacstrap /mnt base base-devel ${KERNEL} linux-firmware archlinux-keyring mkinitcpio libnewt btrfs-progs sof-firmware alsa-ucm-conf networkmanager iwd dkms ${KERNEL}-headers vim wget --noconfirm --needed
echo "keyserver hkp://keyserver.ubuntu.com" >> /mnt/etc/pacman.d/gnupg/gpg.conf
cp -R ${SCRIPT_DIR} /mnt/root/ArchTitus
cp /etc/pacman.d/mirrorlist /mnt/etc/pacman.d/mirrorlist

genfstab -U /mnt >> /mnt/etc/fstab
echo " 
  Generated /etc/fstab:
"
cat /mnt/etc/fstab
echo -ne "
-------------------------------------------------------------------------
                    GRUB BIOS Bootloader Install & Check
-------------------------------------------------------------------------
"
if [[ ! -d "/sys/firmware/efi" ]]; then
    grub-install --boot-directory=/mnt/boot ISK}
else
    pacstrap /mnt efibootmgr --noconfirm --needed
    sed -i '52 s/.*/HOOKS="base systemd keyboard autodetect sd-vconsole modconf block filesystems fsck"/' /mnt/etc/mkinitcpio.conf
fi
echo -ne "
-------------------------------------------------------------------------
                    Setting up swap nonetheless for hibernation
-------------------------------------------------------------------------
"
TOTAL_MEM=$(cat /proc/meminfo | grep -i 'memtotal' | grep -o '[[:digit:]]*')
    truncate -s 0 /mnt/swap/swapfile # make a dir that we can apply NOCOW to to make it btrfs-friendly.
    chattr +C /mnt/swap/swapfile # apply NOCOW, btrfs needs that, deactivates compression as well.
    fallocate -l ${TOTAL_MEM}K /mnt/swap/swapfile # Allocate the file with the same size as there is memory.
    chmod 600 /mnt/swap/swapfile # set permissions.
    chown root /mnt/swap/swapfile
    mkswap /mnt/swap/swapfile
    swapon /mnt/swap/swapfile
    # The line below is written to /mnt/ but doesn't contain /mnt/, since it's just / for the system itself.
    echo "# /swap/swapfile" >> /mnt/etc/fstab
    echo "/swap/swapfile   none	swap	defaults	0	0" >> /mnt/etc/fstab # Add swap to fstab, so it KEEPS working after installation.
echo -ne "
-------------------------------------------------------------------------
                    SYSTEM READY FOR 1-setup.sh
-------------------------------------------------------------------------
"
