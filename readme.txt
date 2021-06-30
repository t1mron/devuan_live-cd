# create usb os
sudo apt-get install --assume-yes ssh debootstrap squashfs-tools xorriso grub-pc-bin grub-efi-amd64-bin mtools

# Create a directory where we will store all of the files
mkdir -p $HOME/LIVE_BOOT

# Install base system
debootstrap --variant=minbase --arch amd64 ceres $HOME/LIVE_BOOT/chroot http://deb.devuan.org/merged/ 

# Enter the new system
sudo chroot $HOME/LIVE_BOOT/chroot

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







# Setup grub
sed -i "s|^GRUB_TIMEOUT=.*|GRUB_TIMEOUT=1|" /etc/default/grub

# Install grub and create configuration
grub-install --root-directory=/ --boot-directory=/boot /dev/sda
grub-mkconfig -o /boot/grub/grub.cfg

# exit the chroot environmen
exit

# Reboot into the new system, don't forget to remove the usb
reboot
