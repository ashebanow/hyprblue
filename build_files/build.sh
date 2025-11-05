#!/bin/bash

set -ouex pipefail

# RELEASE="$(rpm -E %fedora)"

log() {
	echo "=== $* ==="
}

# if true, sddm will be installed as the display manager.
# NOTE: NOT FULLY IMPLEMENTED AND UNTESTED, DO NOT USE YET
USE_SDDM=FALSE

#######################################################################
# Setup Repositories
#######################################################################

log "Enable Copr repos..."
COPR_REPOS=(
	erikreider/SwayNotificationCenter # for swaync
	errornointernet/packages
	heus-sueh/packages                # for matugen/swww, needed by hyprpanel
	leloubil/wl-clip-persist
	# pgdev/ghostty
	solopasha/hyprland
	tofik/sway
	ulysg/xwayland-satellite
	yalter/niri
)
for repo in "${COPR_REPOS[@]}"; do
	# Try to enable the repo, but don't fail the build if it doesn't support this Fedora version
	if ! dnf5 -y copr enable "$repo" 2>&1; then
		log "Warning: Failed to enable COPR repo $repo (may not support Fedora $RELEASE)"
	fi
done

# log "Enable terra repositories..."
# Bazzite disabled this for some reason so lets re-enable it again
# dnf5 config-manager setopt terra.enabled=1 terra-extras.enabled=1

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
	fuzzel
	gnome-bluetooth
	grim
	grimblast
	gvfs
	hyprpanel
	inxi
	kvantum
	# lib32-nvidia-utils
	libgtop2
	mako
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
	wl-clip-persist
	wlogout
	wlr-randr
	xarchiver
	xdg-desktop-portal-gtk
	xdg-desktop-portal-hyprland
	xwayland-satellite
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
	hyprshot
	xdg-desktop-portal-hyprland
	hyprsunset
	hyprutils
)

# Detect if we're on Bazzite (has KDE/Qt 6.10) or Bluefin (has GNOME/Qt 6.9)
# These Qt-dependent packages only work on Bluefin currently due to Qt version mismatch
if ! grep -qi "bazzite" /usr/lib/os-release 2>/dev/null; then
	# Only add Qt-dependent packages on Bluefin
	HYPR_PKGS+=(
		hyprsysteminfo
		hyprpolkitagent
		hyprland-qt-support
	)
fi

# Niri and its dependencies from its default config.
# commented out packages are already referenced in this file, OR they
# are prebundled inside our parent image.
NIRI_PKGS=(
	niri
	swaylock
	# alacritty
	# brightnessctl
	# fuzzel
	# mako
	# waybar
	# xwayland-satellite
	# gnome-keyring
	# wireplumber
	# xdg-desktop-portal-gnome
	# xdg-desktop-portal-gtk
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

# chrome etc are installed as flatpaks. We generally prefer that
# for most things with GUIs, and homebrew for CLI apps. This list is
# only special GUI apps that need to be installed at the system level.
ADDITIONAL_SYSTEM_APPS=(
	alacritty

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
log "Installing packages using dnf5..."
dnf5 install --setopt=install_weak_deps=False -y \
	"${FONTS[@]}" \
	"${HYPR_DEPS[@]}" \
	"${HYPR_PKGS[@]}" \
	"${NIRI_PKGS[@]}" \
	"${SDDM_PACKAGES[@]}" \
	"${ADDITIONAL_SYSTEM_APPS[@]}"

#######################################################################
### Disable repositeories so they aren't cluttering up the final image

log "Disable Copr repos to get rid of clutter..."
for repo in "${COPR_REPOS[@]}"; do
	dnf5 -y copr disable "$repo"
done

#######################################################################
### Enable Services

# TODO: these need to be run at first boot, not during image build

# Setting Thunar as the default file manager
# xdg-mime default thunar.desktop inode/directory
# xdg-mime default thunar.desktop application/x-wayland-gnome-saved-search

if [[ $USE_SDDM == TRUE ]]; then
	log "Installing sddm...."
	for login_manager in lightdm gdm lxdm lxdm-gtk3; do
		if sudo dnf list installed "$login_manager" &>>/dev/null; then
			sudo systemctl disable "$login_manager" 2>&1 | tee -a "$LOG"
		fi
	done
	systemctl set-default graphical.target
	systemctl enable sddm.service
fi
