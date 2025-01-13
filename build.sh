#!/bin/bash

set -ouex pipefail

RELEASE="$(rpm -E %fedora)"

# if true, the binaries needed for nwg-shell will be installed.
# Includes all of sway, though only swaync is used.
# NOTE: NOT FULLY IMPLEMENTED AND UNTESTED, DO NOT USE YET
USE_NWG_SHELL=FALSE

# if true, sddm will be installed as the display manager.
# NOTE: NOT FULLY IMPLEMENTED AND UNTESTED, DO NOT USE YET
USE_SDDM=FALSE

#######################################################################
# Setup Repositories
#######################################################################

# NOTE: RPMFusion repos are available by default
# NOTE: chrome .repo file is installed in the Containerfile prior
# to running this script.

curl https://copr.fedorainfracloud.org/coprs/solopasha/hyprland/repo/fedora-${RELEASE}/solopasha-hyprland-fedora-${RELEASE}.repo \
 -o /etc/yum.repos.d/solopasha-hyprland.repo

curl https://copr.fedorainfracloud.org/coprs/erikreider/SwayNotificationCenter/repo/fedora-${RELEASE}/erikreider-SwayNotificationCenter-fedora-${RELEASE}.repo \
 -o /etc/yum.repos.d/erikreider-SwayNotificationCenter.repo

curl https://copr.fedorainfracloud.org/coprs/errornointernet/packages/repo/fedora-${RELEASE}/errornointernet-packages-fedora-${RELEASE}.repo \
 -o /etc/yum.repos.d/errornointernet-packages.repo

curl https://copr.fedorainfracloud.org/coprs/tofik/sway/repo/fedora-${RELEASE}/tofik-sway-fedora-${RELEASE}.repo \
 -o /etc/yum.repos.d/tofik-sway.repo

if [[ $USE_NWG_SHELL == TRUE ]]; then
  curl https://copr.fedorainfracloud.org/coprs/tofik/nwg-shell/repo/fedora-${RELEASE}/tofik-nwg-shell-fedora-${RELEASE}.repo \
  -o /etc/yum.repos.d/tofik-nwg-shell.repo

  curl https://copr.fedorainfracloud.org/coprs/mochaa/gtk-session-lock/repo/fedora-${RELEASE}/mochaa-gtk-session-lock-fedora-${RELEASE}.repo \
  -o /etc/yum.repos.d/mochaa-gtk-session-lock.repo
fi

# Install 1password repo.
rpm --import https://downloads.1password.com/linux/keys/1password.asc
echo -e "[1password]\nname=1Password Stable Channel\nbaseurl=https://downloads.1password.com/linux/rpm/stable/\$basearch\nenabled=1\ngpgcheck=1\nrepo_gpgcheck=1\ngpgkey=\"https://downloads.1password.com/linux/keys/1password.asc\"" > /etc/yum.repos.d/1password.repo
# rpm-ostree refresh-md --force


#######################################################################
## Install Packages
#######################################################################

# Note that these fedora font packages are preinstalled in the
# bluefin-dx image, along with the SymbolsNerdFont which doesn't
# have an associated fedora package:
#
#   adobe-source-code-pro-fonts
#   google-droid-sans-fonts
#   google-noto-sans-cjk-fonts
#   google-noto-color-emoji-fonts
#   jetbrains-mono-fonts
#
# Because the nerd font symbols are mapped correctly, we can get
# nerd font characters anywhere.
FONTS=(
  fira-code-fonts
  fontawesome-fonts-all
  google-noto-emoji-fonts
)

# Hyprland dependencies to be installed, based on
# https://github.com/JaKooLit/Fedora-Hyprland/ with additions
# from ml4w and other sources.
HYPR_DEPS=(
  aquamarine
  blueman
  bluez-tools
  brightnessctl
  btop
  cava
  cliphist
  eog
  fastfetch
  grim
  inxi
  kvantum
  mpv
#   mpv-mpris
  nwg-look
  pamixer
  pavucontrol
  playerctl
  python3-pyquery
  qalculate-gtk
  qt5ct
  qt6-qtsvg
  qt6ct
  slurp
  SwayNotificationCenter
  swww
  tumbler
  wallust
  wget2
  wl-clipboard
  wlr-randr
  xarchiver
  yad
)

# Hyprland ecosystem packages
HYPR_PKGS=(
  hyprcursor
  hyprland
  hypridle
  hyprlock
  network-manager-applet
  rofi-wayland
  swappy
  swaync
  waybar
  wlogout
  xdg-desktop-portal-hyprland
  xdg-desktop-portal-gtk
)

# See https://github.com/nwg-piotr/nwg-shell/blob/main/install/fedora-ostree.sh
NWG_SHELL_PKGS=()
if [[ $USE_NWG_SHELL == TRUE ]]; then
  NWG_SHELL_PKGS=(
    nwg-shell
    gtklock
  )
fi

# SDDM not set up properly yet, so this is just a placeholder.
# For now you'll have to invoke Hyprland from the command line.
SDDM_PACKAGES=()
if [[ $USE_SDDM == TRUE ]]; then
  SDDM_PACKAGES=(
    sddm
    sddm-breeze
    sddm-kcm
    qt6-qt5compat
  )
fi

# 1password* and chrome are here because the browser<->extension
# link in 1password doesn't work if either app is a flatpak.
LAYERED_APPS=(
  1password
  1password-cli
#   google-chrome-stable
  kitty
  kitty-terminfo
  thunar
  thunar-volman
  thunar-archive-plugin
)

# we do all package installs in one rpm-ostree command
# so that we create minimal layers in the final image
rpm-ostree install \
  ${FONTS[@]} \
  ${HYPR_DEPS[@]} \
  ${HYPR_PKGS[@]} \
  ${SDDM_PACKAGES[@]} \
  ${NWG_SHELL_PKGS[@]} \
  ${LAYERED_APPS[@]}

https://www.google.com/chrome/next-steps.html?statcb=0&installdataindex=empty&defaultbrowser=0#


#######################################################################
### Enable Services

# Setting Thunar as the default file manager
xdg-mime default thunar.desktop inode/directory
xdg-mime default thunar.desktop application/x-wayland-gnome-saved-search

# systemctl enable bluetooth.service

if [[ $USE_SDDM == TRUE ]]; then
    for login_manager in lightdm gdm lxdm lxdm-gtk3; do
    if sudo dnf list installed "$login_manager" &>> /dev/null; then
      sudo systemctl disable "$login_manager" 2>&1 | tee -a "$LOG"
    fi
    done
  systemctl set-default graphical.target
  systemctl enable sddm.service
fi
