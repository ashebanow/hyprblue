#!/bin/bash

set -ouex pipefail

RELEASE="$(rpm -E %fedora)"

log() {
	echo "=== $* ==="
}

# if true, sddm will be installed as the display manager.
# NOTE: NOT FULLY IMPLEMENTED AND UNTESTED, DO NOT USE YET
USE_SDDM=FALSE

#######################################################################
# Setup Repositories
#######################################################################

# Preference order: official Fedora repos > upstream-blessed COPR > other COPRs.
#
# These used to be COPR-only and are now in Fedora $RELEASE proper, so their
# COPRs were dropped:
#
#   SwayNotificationCenter -> fedora updates (was erikreider/SwayNotificationCenter)
#   niri                   -> fedora updates (was yalter/niri)
#   xwayland-satellite     -> fedora        (was ulysg/xwayland-satellite)
#   swaylock/wlogout/swappy/waybar/cava -> fedora (was tofik/sway)
#   matugen                -> lionheartp   (was heus-sueh/packages, 2.4.1 vs 4.1.0)
#   swww                   -> lionheartp's awww fork (see HYPR_DEPS below)
#
# heus-sueh/packages and tofik/sway contributed exactly zero packages to the
# last build, so they are gone too.
log "Enable Copr repos..."
COPR_REPOS=(
	errornointernet/packages # wallust
	leloubil/wl-clip-persist # not packaged anywhere else
	lionheartp/Hyprland      # Hyprland stack; fixes https://github.com/solopasha/hyprlandRPM/issues/49
	scottames/ghostty        # the COPR ghostty.org recommends
	solopasha/hyprland       # ONLY for hyprpanel/ags, see the restriction below
)
for repo in "${COPR_REPOS[@]}"; do
	# Try to enable the repo, but don't fail the build if it doesn't support this Fedora version
	if ! dnf5 -y copr enable "$repo" 2>&1; then
		log "Warning: Failed to enable COPR repo $repo (may not support Fedora $RELEASE)"
	fi
done

# hyprpanel and aylurs-gtk-shell2 exist only in solopasha/hyprland, but that
# repo also ships a full (Fedora 44-broken) Hyprland stack that would outrank
# lionheartp's. So allow only the hyprpanel/ags/astal packages from it.
# appmenu-glib-translator is in the list because astal-libs needs it and it,
# too, is solopasha-only.
#
# solopasha/hyprland publishes NO fedora-44 chroot (only fedora-rawhide, whose
# rpms are fc43 builds). `dnf5 copr enable` therefore fails with "Chroot not
# found in the given Copr project (fedora-44-x86_64)". That is expected on
# Fedora $RELEASE and is not fatal: hyprpanel/aylurs-gtk-shell2 simply cannot
# be installed, and the critical-package check below is told to expect their
# absence. Do not force these in from rawhide -- they are Qt 6.9 builds and
# would reintroduce the Qt 6.10 conflict documented in the README.
log "Restricting solopasha/hyprland to the hyprpanel/ags stack..."
SOLOPASHA_REPO="copr:copr.fedorainfracloud.org:solopasha:hyprland"
SOLOPASHA_UNAVAILABLE=FALSE
SOLOPASHA_PKGS="hyprpanel,aylurs-gtk-shell2,astal,astal-gjs,astal-io,astal-libs,astal-gtk4,appmenu-glib-translator"
# Repo ids are printed with the "copr:" prefix by `dnf5 repo list`, but the
# spelling has varied across dnf5 versions, so match on the distinctive tail and
# use whatever id dnf5 actually reports.
SOLOPASHA_REPO_ID="$(dnf5 repo list --all 2>/dev/null \
	| grep -oE '[^[:space:]]*copr[^[:space:]]*solopasha[^[:space:]]*' \
	| sed 's/\.repo$//' | head -n1)"
if [[ -n "$SOLOPASHA_REPO_ID" ]]; then
	log "Found solopasha repo id: ${SOLOPASHA_REPO_ID}"
	# an unrestricted solopasha would shadow lionheartp's Hyprland, so a failure
	# here has to be fatal rather than merely noisy
	if ! dnf5 config-manager setopt "${SOLOPASHA_REPO_ID}.includepkgs=${SOLOPASHA_PKGS}"; then
		log "ERROR: could not restrict ${SOLOPASHA_REPO_ID}; refusing to build"
		exit 1
	fi
else
	# No solopasha chroot for this Fedora release. This is the expected state on
	# Fedora 44, so downgrade the packages that live only there instead of
	# failing the build, and let the sanity check below verify the rest.
	log "Note: ${SOLOPASHA_REPO} has no Fedora ${RELEASE} chroot; dropping hyprpanel/aylurs-gtk-shell2"
	SOLOPASHA_UNAVAILABLE=TRUE
fi

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
	awww # swww fork from lionheartp; the real swww is unbuilt on f44
	tumbler
	upower
	wallust
	waybar
	wget2
	# wireplumber is added conditionally above: requesting it unconditionally
	# conflicts with bazzite's terra-wireplumber and aborts the transaction.
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

	# ghostty still isn't in Fedora, but scottames/ghostty (which ghostty.org
	# points at) has current builds, so it's back.
	ghostty

	kitty
	kitty-terminfo

	Thunar # yes, Fedora really capitalizes this one
	thunar-volman
	thunar-archive-plugin
)

# we do all package installs in one rpm-ostree command
# so that we create minimal layers in the final image

# Bazzite ships terra-wireplumber, which Provides pipewire-session-manager and
# Conflicts with plain wireplumber. Requesting "wireplumber" by name therefore
# aborts the whole dnf transaction on bazzite-based variants (bluefin already
# has plain wireplumber installed, so it never noticed). Only request it when a
# session manager isn't already present, and ask by capability so terra's
# provider can satisfy the request. This has to run *after* HYPR_DEPS is
# declared, otherwise the append lands on an unset array and is discarded.
if rpm -q wireplumber >/dev/null 2>&1; then
	log "wireplumber already installed; leaving it alone"
elif rpm -q --whatprovides pipewire-session-manager >/dev/null 2>&1; then
	log "pipewire-session-manager already provided; leaving it alone"
else
	log "No session manager present; requesting pipewire-session-manager"
	HYPR_DEPS+=(pipewire-session-manager)
fi

log "Installing packages using dnf5..."
dnf5 install --setopt=install_weak_deps=False --skip-unavailable -y \
	"${FONTS[@]}" \
	"${HYPR_DEPS[@]}" \
	"${HYPR_PKGS[@]}" \
	"${NIRI_PKGS[@]}" \
	"${SDDM_PACKAGES[@]}" \
	"${ADDITIONAL_SYSTEM_APPS[@]}"

#######################################################################
### Sanity check
###
### --skip-unavailable means a renamed or dropped package silently vanishes
### instead of failing the build. That is exactly how hyprpanel and
### aylurs-gtk-shell2 went missing from every variant for a while, so assert
### the things this image exists for actually landed.
###
### hyprpanel/aylurs-gtk-shell2 are exempt when solopasha has no chroot for
### this Fedora release, since then they are genuinely unobtainable and their
### absence is already logged above rather than silently swallowed.

log "Verifying critical packages..."
CRITICAL_PKGS=(
	ghostty
	hyprland
	niri
	waybar
	xwayland-satellite
)
if [[ "${SOLOPASHA_UNAVAILABLE:-FALSE}" != TRUE ]]; then
	CRITICAL_PKGS+=(aylurs-gtk-shell2 hyprpanel)
fi
MISSING_PKGS=()
for pkg in "${CRITICAL_PKGS[@]}"; do
	rpm -q "$pkg" >/dev/null 2>&1 || MISSING_PKGS+=("$pkg")
done
if [[ ${#MISSING_PKGS[@]} -gt 0 ]]; then
	log "ERROR: critical packages missing from image: ${MISSING_PKGS[*]}"
	exit 1
fi

#######################################################################
### Disable repositeories so they aren't cluttering up the final image

log "Disable Copr repos to get rid of clutter..."
for repo in "${COPR_REPOS[@]}"; do
	# a repo that failed to enable above can't be disabled, so don't let that
	# take down the whole build
	if ! dnf5 -y copr disable "$repo" 2>&1; then
		log "Warning: Failed to disable COPR repo $repo"
	fi
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
