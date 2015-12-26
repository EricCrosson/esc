#!/usr/bin/env bash
# Written by esc, wuputah
# 2015-12-26

# todo: pass $1 == hostname

# todo: parse arguments to set these variables

##### Bootstrap Variables #####

# User information
username=eric

# User config information
dotfiles_repo=https://github.com/ericcrosson/dotfiles.git
dotfiles_destination=dotfiles
stow_list='bash bin emacs fzf gdb git htop python ruby screen ssh urxvt vim xbindkeys zsh'
stow_list_root=''

# Programs to install htop tree sshfs emacs screen acpi lm_sensors vim dialog
category_internet='openssh chromium{,-pepper-flash} uzbl-tabbed'
category_media='vlc'
category_shell='rsync zsh git powertop stow rxvt-unicode wget linux-headers'
category_dev='cmake make gcc'
category_install="${category_internet} ${category_media} ${category_shell} ${category_dev}"

##### Behavior Variables #####
git_clone_flags='--recursive' # quiet?


##### Bootstrap Script #####

# confirm you can access the internet
if [[ ! $(curl -Is http://www.google.com/ | head -n 1) =~ "200 OK" ]]; then
  echo "Your Internet seems broken. Press Ctrl-C to abort or enter to continue."
  read
fi

# make 2 partitions on the disk.
parted -s /dev/sda mktable msdos
parted -s /dev/sda mkpart primary 0% 100m
parted -s /dev/sda mkpart primary 100m 100%

# make filesystems
mkfs.ext2 /dev/sda1  # /boot
mkfs.btrfs /dev/sda2 # /

# set up /mnt
mount /dev/sda2 /mnt
mkdir /mnt/boot
mount /dev/sda1 /mnt/boot

# rankmirrors to make this faster (though it takes a while)
mv /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.orig
rankmirrors -n 6 /etc/pacman.d/mirrorlist.orig >/etc/pacman.d/mirrorlist
pacman -Syy

# install base packages (take a coffee break if you have slow internet)
pacstrap /mnt base base-devel

# install syslinux
arch-chroot /mnt pacman --noconfirm -S syslinux
# todo: shorten syslinux startup time

# copy ranked mirrorlist over
cp /etc/pacman.d/mirrorlist* /mnt/etc/pacman.d

# generate fstab
genfstab -p /mnt >>/mnt/etc/fstab

# chroot
arch-chroot /mnt /bin/bash <<END_OF_CHROOT

# set initial hostname
echo "archlinux-$(date -I)" >/etc/hostname

# set initial timezone to America/Chicago
ln -s /usr/share/zoneinfo/America/Chicago /etc/localtime

# set initial locale
locale >/etc/locale.conf
echo "en_US.UTF-8 UTF-8" >>/etc/locale.gen
echo "en_US ISO-8859-1" >>/etc/locale.gen
locale-gen

# no modifications to mkinitcpio.conf should be needed
mkinitcpio -p linux

# install syslinux bootloader
syslinux-install_update -i -a -m

# todo: abstract update functionality
# Shorten boot delay
sed 's/Timeout.*/Timeout 5/' < /boot/syslinux/syslinux.cfg > /boot/syslinux/syslinux.cfg.new
mv /boot/syslinux/syslinux.cfg.new /boot/syslinux/syslinux.cfg

# Update syslinux config with correct root disk
sed 's/root=.*/root=\/dev\/sda2 ro/' < /boot/syslinux/syslinux.cfg > /boot/syslinux/syslinux.cfg.new
mv /boot/syslinux/syslinux.cfg.new /boot/syslinux/syslinux.cfg

# Install general packages
for apps in ${categories_install}; do
    pacman --noconfirm -S ${apps}
done

# Install python tools
pacman --noconfirm -S python-setuptools
easy_install pip
pip install virtualenv{,wrapper}

# Install yaourt
cat <<EOF >> /etc/pacman.conf

[archlinuxfr]
SigLevel = Never
Server = http://repo.archlinux.fr/\$arch
EOF
pacman --noconfirm -Sy yaourt

# Congure yaourt
cat <<EOF >> /etc/yaourtrc

# esc's customizations
NOCONFIRM=1
UP_NOCONFIRM=0
BUILD_NOCONFIRM=1
EDITFILES=0
NOENTER=1
EOF

# todo: yaourt dtrx p7zip unrar
# todo: pacmatic

# set root password to "root"
echo root:root | chpasswd

# Creating and configuring user ${username}
useradd -rms $(which zsh) ${username}
for group in power, wheel; do
    gpasswd -a ${username} ${goup}
done

su ${username} <<END_OF_USER_SHELL
cd /home/${username}

# Install Oh-My-Zsh
sh -c "$(curl -fsSL https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"

# Install spacemacs
git clone ${git_clone_flags} https://github.com/syl20bnr/spacemacs.git .emacs.d
rm -rf .emacs.d/private

# Install personal dotfiles
git clone ${git_clone_flags} ${dotfiles_repo} ${dotfiles_destination}
cd ${dotfiles_destination}

# Stow personal configs
for app in ${stow_list}; do
    stow ${app}
done
for app_root in ${stow_list_root}; do
    stow -t / ${app_root}
done

# Generate user RSA keys
ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa
END_OF_USER_SHELL

# todo: set passwd for ${username}
END_OF_CHROOT

# unmount
umount /mnt/{boot,}

echo "Done! Unmount the CD image from the VM, then type 'reboot'."