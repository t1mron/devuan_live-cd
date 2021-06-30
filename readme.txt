# create usb os
sudo apt install ssh debootstrap arch-install-scripts

head -c 3145728 /dev/urandom > /dev/sda; sync 
(echo o;echo w) | fdisk /dev/sda

# /dev/sdb1 All Linux filesystem
(echo n;echo ;echo ;echo ;echo ;echo a;echo w) | fdisk /dev/sda

# Formatting the partitions
mkfs.ext4 /dev/sda1

# Mount partition
mount /dev/sda1 /mnt

# Install base system
debootstrap --variant=minbase --arch amd64 ceres /mnt http://deb.devuan.org/merged/ 

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Enter the new system
arch-chroot /mnt /bin/bash

packagelist=(
  # basic
  linux-image-amd64 grub2 sudo sysv-rc-conf network-manager network-manager-gnome iwd ssh neovim 
  # Window manager
  bspwm sxhkd xserver-xorg-core xinit xinput x11-utils x11-xserver-utils xterm polybar rofi
  # Terminal tools 
  git debootstrap arch-install-scripts man-db htop wget curl inetutils-ping
  # Locale
  locales console-setup
  # Multimedia
  firefox flameshot sxiv
)

DEBIAN_FRONTEND=noninteractive apt install ${packagelist[@]}

# clean apt downloaded archives
apt clean

# root password
passwd root

# default shell bash
chsh -s /bin/bash root

# Set the time zone and a system clock
ln -sf /usr/share/zoneinfo/Europe/Moscow /etc/localtime
hwclock --systohc --utc

# Set default locale (?!!!! double input)
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

# Setup grub
sed -i "s|^GRUB_TIMEOUT=.*|GRUB_TIMEOUT=1|" /etc/default/grub

# Install grub and create configuration
grub-install --root-directory=/ --boot-directory=/boot /dev/sda
grub-mkconfig -o /boot/grub/grub.cfg

# exit the chroot environmen
exit

# Reboot into the new system, don't forget to remove the usb
reboot
