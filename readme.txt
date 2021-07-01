sudo apt-get install --assume-yes ssh debootstrap squashfs-tools xorriso grub-pc-bin grub-efi-amd64-bin mtools

head -c 3145728 /dev/urandom > /dev/sda; sync 
(echo o;echo w) | fdisk /dev/sda

# /dev/sdb1 All Linux filesystem
(echo n;echo ;echo ;echo ;echo ;echo a;echo w) | fdisk /dev/sda

# Formatting the partitions
mkfs.ext4 /dev/sda1

# Mount partition
mount /dev/sda1 /mnt

# Create a directory where we will store all of the files
mkdir -p /mnt/LIVE_BOOT

# Install base system
debootstrap --variant=minbase --arch amd64 ceres /mnt/LIVE_BOOT/chroot http://deb.devuan.org/merged/ 

deb http://deb.devuan.org/merged ceres main 
deb http://deb.devuan.org/merged beowulf main non-free contrib


# Enter the new system
sudo chroot /mnt/LIVE_BOOT/chroot

packagelist=(
  # basic
  linux-image-amd64 grub2 cryptsetup lvm2 live-boot sudo sysv-rc-conf ssh neovim 
  # Window manager
  bspwm sxhkd xserver-xorg-core xinit xinput x11-utils x11-xserver-utils xterm polybar rofi
  # Terminal tools 
  debootstrap arch-install-scripts git wget man-db htop inetutils-ping
  # Network
  network-manager network-manager-gnome iwd 
  # Fonts
  fonts-font-awesome
  # Locale
  locales
  # Multimedia
  firefox flameshot sxiv
  # Firmware
  firmware-linux-nonfree
)

DEBIAN_FRONTEND=noninteractive apt --assume-yes install ${packagelist[@]}

# Delete modem manager
apt-get --assume-yes purge modemmanager

# clean apt downloaded archives
apt clean

# root password
echo -e "toor\ntoor" | passwd root

# default shell bash
chsh -s /bin/bash root

# Set the time zone and a system clock
ln -sf /usr/share/zoneinfo/Europe/Moscow /etc/localtime
hwclock --systohc --utc

# Set default locale
echo -e "en_US.UTF-8 UTF-8\nru_RU.UTF-8 UTF-8" >> /etc/locale.gen

# Update current locale
locale-gen

# Set the host
cat << EOF > /etc/hosts
127.0.0.1    localhost
::1          localhost
127.0.1.1    devuan.localdomain devuan
EOF

# dotfiles
git clone --depth=1 https://github.com/t1mron/devuan_live-cd $HOME/git/devuan_live-cd
cp -r $HOME/git/devuan_live-cd/. $HOME/ && rm -rf $HOME/{root,.git,LICENSE,README.md,readme.txt}
cp -r $HOME/git/devuan_live-cd/root/. /

# exit the chroot environmen
exit

# Create directories that will contain files for our live environment files and scratch files
mkdir -p /mnt/LIVE_BOOT/{scratch,image/live}

# Compress the chroot environment into a Squash filesystem
mksquashfs \
    /mnt/LIVE_BOOT/chroot \
    /mnt/LIVE_BOOT/image/live/filesystem.squashfs \
    -e boot

# Copy the kernel and initramfs from inside the chroot to the live directory
cp /mnt/LIVE_BOOT/chroot/boot/vmlinuz-* \
    /mnt/LIVE_BOOT/image/vmlinuz && \
cp /mnt/LIVE_BOOT/chroot/boot/initrd.img-* \
    /mnt/LIVE_BOOT/image/initrd

# Create a menu configuration file for grub
cat <<'EOF' >/mnt/LIVE_BOOT/scratch/grub.cfg

insmod all_video

search --set=root --file /DEVUAN_CUSTOM

set default="0"
set timeout=30

menuentry "Devuan Live" {
    linux /vmlinuz boot=live quiet nomodeset
    initrd /initrd
}
EOF

touch /mnt/LIVE_BOOT/image/DEVUAN_CUSTOM

# Create a grub BIOS image
grub-mkstandalone \
    --format=x86_64-efi \
    --output=/mnt/LIVE_BOOT/scratch/bootx64.efi \
    --locales="" \
    --fonts="" \
    "boot/grub/grub.cfg=/mnt/LIVE_BOOT/scratch/grub.cfg"

#  Create a FAT16 UEFI boot disk image containing the EFI bootloader
(cd /mnt/LIVE_BOOT/scratch && \
    dd if=/dev/zero of=efiboot.img bs=1M count=10 && \
    mkfs.vfat efiboot.img && \
    mmd -i efiboot.img efi efi/boot && \
    mcopy -i efiboot.img ./bootx64.efi ::efi/boot/
)

# Create a grub BIOS image
grub-mkstandalone \
    --format=i386-pc \
    --output=/mnt/LIVE_BOOT/scratch/core.img \
    --install-modules="linux normal iso9660 biosdisk memdisk search tar ls" \
    --modules="linux normal iso9660 biosdisk search" \
    --locales="" \
    --fonts="" \
    "boot/grub/grub.cfg=/mnt/LIVE_BOOT/scratch/grub.cfg"

# Use cat to combine a bootable Grub cdboot.img bootloader with our boot image
cat \
    /usr/lib/grub/i386-pc/cdboot.img \
    /mnt/LIVE_BOOT/scratch/core.img \
> /mnt/LIVE_BOOT/scratch/bios.img

# Generate the ISO file.
xorriso \
    -as mkisofs \
    -iso-level 3 \
    -full-iso9660-filenames \
    -volid "DEVUAN_CUSTOM" \
    -eltorito-boot \
        boot/grub/bios.img \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        --eltorito-catalog boot/grub/boot.cat \
    --grub2-boot-info \
    --grub2-mbr /usr/lib/grub/i386-pc/boot_hybrid.img \
    -eltorito-alt-boot \
        -e EFI/efiboot.img \
        -no-emul-boot \
    -append_partition 2 0xef /mnt/LIVE_BOOT/scratch/efiboot.img \
    -output "/mnt/LIVE_BOOT/devuan-custom.iso" \
    -graft-points \
        "/mnt/LIVE_BOOT/image" \
        /boot/grub/bios.img=/mnt/LIVE_BOOT/scratch/bios.img \
        /EFI/efiboot.img=/mnt/LIVE_BOOT/scratch/efiboot.img

# Reboot into the new system, don't forget to remove the usb
reboot
