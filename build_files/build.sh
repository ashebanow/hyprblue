#!/bin/bash

set -ouex pipefail

RELEASE="$(rpm -E %fedora)"

# if true, sddm will be installed as the display manager.
# NOTE: NOT FULLY IMPLEMENTED AND UNTESTED, DO NOT USE YET
USE_SDDM=FALSE

#######################################################################
# Setup Repositories
#######################################################################

# NOTE: RPMFusion repos are available by default
# NOTE: chrome .repo file is installed in the Containerfile prior
# to running this script.

dnf5 -y copr enable solopasha/hyprland
dnf5 -y copr enable erikreider/SwayNotificationCenter     # for swaync
dnf5 -y copr enable errornointernet/packages
dnf5 -y copr enable tofik/sway
# dnf5 -y copr enable pgdev/ghostty
dnf5 -y copr enable heus-sueh/packages                    # for matugen/swww, needed by hyprpanel
# dnf5 config-manager setopt copr:copr.fedorainfracloud.org:heus-sueh:packages.priority=200

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
  aylurs-gtk-shell2
  blueman
  bluez
  bluez-tools
  brightnessctl
  btop
  cava
  cliphist
  # egl-wayland
  eog
  gnome-bluetooth
  grim
  grimblast
  gvfs
  hyprpanel
  inxi
  kvantum
  # lib32-nvidia-utils
  libgtop2
  matugen
  mpv
  # mpv-mpris
  network-manager-applet
  nodejs
  # nvidia-dkms
  # nvidia-utils
  nwg-look
  pamixer
  pavucontrol
  playerctl
  # power-profiles-daemon
  python3-pyquery
  qalculate-gtk
  qt5ct
  qt6ct
  rofi-wayland
  slurp
  swappy
  swaync
  swww
  tumbler
  upower
  wallust
  waybar
  wget2
  wireplumber
  wl-clipboard
  wlogout
  wlr-randr
  xarchiver
  xdg-desktop-portal-gtk
  xdg-desktop-portal-hyprland
  yad
)

# Hyprland ecosystem packages
HYPR_PKGS=(
  hyprland
  hyprcursor
  hyprpaper
  hyprpicker
  hypridle
  hyprlock
  xdg-desktop-portal-hyprland
  hyprsysteminfo
  hyprsunset
  hyprpolkitagent
  hyprland-qt-support
  hyprutils
)

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

# bitwarden and chrome are installed as flatpaks.
LAYERED_APPS=(
  # ghostty is broken in Fedora 42 right now
  # ghostty
  kitty
  kitty-terminfo

  thunar
  thunar-volman
  thunar-archive-plugin
)

# we do all package installs in one rpm-ostree command
# so that we create minimal layers in the final image
dnf5 install -y \
  ${FONTS[@]} \
  ${HYPR_DEPS[@]} \
  ${HYPR_PKGS[@]} \
  ${SDDM_PACKAGES[@]} \
  ${LAYERED_APPS[@]}

#######################################################################
### Disable repositeories so they aren't cluttering up the final image

dnf5 -y copr disable solopasha/hyprland
dnf5 -y copr disable erikreider/SwayNotificationCenter
dnf5 -y copr disable errornointernet/packages
dnf5 -y copr disable tofik/sway
# dnf5 -y copr disable pgdev/ghostty
dnf5 -y copr disable heus-sueh/packages

#######################################################################
### Enable Services

# Setting Thunar as the default file manager
# TODO: these need to be run at first boot, not during build
# xdg-mime default thunar.desktop inode/directory
# xdg-mime default thunar.desktop application/x-wayland-gnome-saved-search

if [[ $USE_SDDM == TRUE ]]; then
  for login_manager in lightdm gdm lxdm lxdm-gtk3; do
    if sudo dnf list installed "$login_manager" &>>/dev/null; then
      sudo systemctl disable "$login_manager" 2>&1 | tee -a "$LOG"
    fi
  done
  systemctl set-default graphical.target
  systemctl enable sddm.service
fi
