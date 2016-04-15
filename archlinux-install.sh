#!/usr/bin/env bash
# Written by esc, wuputah
# 2015-12-26

##### Bootstrap Script #####

## Turn comments into literal programming, including output during execution.
function reporter() {
    message="$1"
    shift
    echo
    echo "${message}"
    for (( i=0; i<${#message}; i++ )); do
        echo -n '-'
    done
    echo
}

reporter "Confirming internet connection"
if [[ ! $(curl -Is http://www.google.com/ | head -n 1) =~ "200 OK" ]]; then
  echo "Your Internet seems broken. Press Ctrl-C to abort or enter to continue."
  read
else
  echo "Connection successful"
fi

reporter "Making 2 partitions on the disk -- boot and root"
parted -s /dev/sda mktable msdos
parted -s /dev/sda mkpart primary 0% 100m
parted -s /dev/sda mkpart primary 100m 100%

reporter "Making filesystems"
mkfs.ext2 /dev/sda1  # /boot
mkfs.btrfs /dev/sda2 # /

reporter "Setting up /mnt"
mount /dev/sda2 /mnt
mkdir /mnt/boot
mount /dev/sda1 /mnt/boot

reporter "Ranking pacman mirrors"
mv /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.orig
rankmirrors -n 6 /etc/pacman.d/mirrorlist.orig >/etc/pacman.d/mirrorlist

reporter "Installing base packages (take a coffee break if you have slow internet)"
pacman -Syy
pacstrap /mnt base base-devel

reporter "Installing system"
arch-chroot /mnt pacman --noconfirm -S syslinux

# copy ranked mirrorlist over
cp /etc/pacman.d/mirrorlist* /mnt/etc/pacman.d

# generate fstab
genfstab -p /mnt >>/mnt/etc/fstab

# todo: enable logging in the chroot
reporter "Chroot-ing into /mnt"
arch-chroot /mnt /bin/bash <<END_OF_CHROOT

# set initial hostname
# todo: pass $1 == hostname

# todo: parse arguments to set these variables

##### Bootstrap Variables #####

# User information
username=eric
username_passwd=login1
hostname="archlinux-$(date -I)"

# User config information
dotfiles_repo=https://github.com/ericcrosson/dotfiles.git
dotfiles_destination=dotfiles
dotfiles_branch=master
stow_list='bash bin emacs fzf gdb git htop python ruby screen ssh urxvt vim xbindkeys zsh'

# Programs to install
category_utils='htop tree sshfs emacs screen acpi lm_sensors vim dialog'
category_internet='openssh chromium{,-pepper-flash} uzbl-tabbed'
category_media='vlc'
category_shell='rsync zsh git powertop stow rxvt-unicode wget linux-headers'
category_dev='cmake make gcc'
category_compression='dtrx p7zip unrar'
category_install="${category_internet} ${category_compression} ${category_utils} ${category_media} ${category_shell} ${category_dev}"

##### Behavior Variables #####
git_clone_flags='--recursive --depth 1' # quiet?


echo "${hostname}" >/etc/hostname

# set initial timezone to America/Chicago
ln -s /usr/share/zoneinfo/America/Chicago /etc/localtime

# set initial locale
locale >/etc/locale.conf
echo "en_US.UTF-8 UTF-8" >>/etc/locale.gen
echo "en_US ISO-8859-1" >>/etc/locale.gen
locale-gen

# todo: make modifications to mkinitcpio.conf
mkinitcpio -p linux

# install syslinux bootloader
syslinux-install_update -i -a -m

# todo: abstract update functionality -- current scheme doesn't make sense twice
# Shorten syslinux boot delay
sed 's/Timeout.*/Timeout 5/' < /boot/syslinux/syslinux.cfg > /boot/syslinux/syslinux.cfg.new
mv /boot/syslinux/syslinux.cfg.new /boot/syslinux/syslinux.cfg

# Update syslinux config with correct root disk
sed 's/root=.*/root=\/dev\/sda2 ro/' < /boot/syslinux/syslinux.cfg > /boot/syslinux/syslinux.cfg.new
mv /boot/syslinux/syslinux.cfg.new /boot/syslinux/syslinux.cfg

# Install yaourt
cat <<EOF >> /etc/pacman.conf

[archlinuxfr]
SigLevel = Never
Server = http://repo.archlinux.fr/\\$arch
EOF
pacman --noconfirm -Sy yaourt

# Congure yaourt
cat <<EOF >> /etc/yaourtrc

# esc's customizations
NOCONFIRM=1
UP_NOCONFIRM=1
BUILD_NOCONFIRM=1
EDITFILES=0
NOENTER=1
USECOLOR=1
EOF

# Install general packages
for apps in ${categories_install}; do
    yaourt --noconfirm -S ${apps}
done

# Install python tools
pacman --noconfirm -S python-setuptools
easy_install pip
pip install virtualenv{,wrapper}

# Install pacmatic
yaourt --noconfirm -S pacmatic
# todo: configure pacmatic

# set root password to "root"
echo root:root | chpasswd

# Creating and configuring user ${username}
useradd -rms $(which zsh) ${username}
for group in power, wheel; do
    gpasswd -a ${username} ${goup}
done

# Set ${username} password to "${username_passwd}"
echo ${username}:${username_passwd} | chpasswd

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
git checkout ${dotfiles_branch}

# Stow personal configs
for app in ${stow_list}; do
    stow ${app}
done

# Generate user RSA keys
ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa
END_OF_USER_SHELL

# todo: if school laptop install, clone classes and other workspace repos
END_OF_CHROOT

# unmount
umount /mnt/{boot,}

echo "Done! Unmount the CD image from the VM, then type 'reboot'."

# todo: abstract this report with a method to register created users
echo -e "User summary:"
echo -e "\tUser:\t\tPassword:"
echo -e "=========================="
echo -e "\troot\t\troot"
echo -e "\t${username}\t\t${username_passwd}"
echo -e
echo -e

# todo:
echo -e "Host summary:"
echo -e "============="
