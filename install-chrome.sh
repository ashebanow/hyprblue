#!/usr/bin/env sh

# This file taken from https://github.com/chris-short/blue-falcon-os/blob/01d7425c68d99dcadf2114d740996ffa1e86a807/build_files/google-chrome.sh under Apache 2.0 license.

set -ouex pipefail

echo "Installing Google Chrome"

# On libostree systems, /opt is a symlink to /var/opt,
# which actually only exists on the live system. /var is
# a separate mutable, stateful FS that's overlaid onto
# the ostree rootfs. Therefore we need to install it into
# /usr/lib/1Password instead, and dynamically create a
# symbolic link /opt/1Password => /usr/lib/1Password upon
# boot.

# Prepare staging directory
mkdir -p /var/opt # -p just in case it exists
# for some reason...

# Setup repo
cat << EOF > /etc/yum.repos.d/google-chrome.repo
[google-chrome]
name=Google Chrome Stable
baseurl=http://dl.google.com/linux/chrome/rpm/stable/\$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://dl.google.com/linux/linux_signing_key.pub
EOF

# Import signing key
rpm --import https://dl.google.com/linux/linux_signing_key.pub

# Prepare Chrome groups
# I hardcode GIDs and cross fingers that nothing else steps on them.
# These numbers _should_ be okay under normal use, but
# if there's a more specific range that I should use here
# please submit a PR!

# Specifically, GID must be > 1000, and absolutely must not
# conflict with any real groups on the deployed system.
# Normal user group GIDs on Fedora are sequential starting
# at 1000, so let's skip ahead and set to something higher.
GID_CHROME="1800"
groupadd -g ${GID_CHROME} google-chrome

# Now let's install the packages.
rpm-ostree install -y google-chrome-stable

# This places the Google Chrome contents in an image safe location
# mv /var/opt/google-chrome-stable /usr/lib/google-chrome-stable # move this over here

# Register path symlink
# We do this via tmpfiles.d so that it is created by the live system.
cat >/usr/lib/tmpfiles.d/google-chrome.conf <<EOF
L  /opt/google-chrome-stable  -  -  -  -  /usr/lib/google-chrome-stable
EOF

# Clean up the yum repo (updates are baked into new images)
rm /etc/yum.repos.d/google-chrome.repo -f
