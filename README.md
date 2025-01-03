# HyprBlue

# Purpose

HyprBlue is a variant of [Bluefin](https://projectbluefin.io/) that comes with
a pretty complete Hyprland install, in addition to Gnome. It also has Google
Chrome and 1Password preinstalled, because they don't work together right if
they aren't both in the base image.

# How to Use

1. Install bluefin-dx or bluefin-nvidia-dx from ISO. Set up LUKS/TPM/Secure Boot as needed.

2. Run the following command (or, alternatively, check out this repo and run the
just commands locally):

    ```bash
    curl https://raw.githubusercontent.com/ashebanow/hyprblue/master/justfile \
        > /tmp/hyprblue-justfile
    just -f /tmp/hyprblue-justfile rebase-unsigned
    ```

3. Reboot your computer.

4. Run the following command:

    ```bash
    if ! -f /tmp/hyprblue-justfile; then
        curl https://raw.githubusercontent.com/ashebanow/hyprblue/master/justfile \
            > /tmp/hyprblue-justfile
    fi
    just -f /tmp/hyprblue-justfile rebase-unsigned
    ```
5. Reboot your computer again, but do **NOT** select Hyprland from the login screen.

6. At this point, you should have the default, very very basic Hyprland setup. Now is the time to install your favorite dotfiles. If you don't have a working Hyprland setup of your own, I recommend taking a look at [JaKoolit's](https://github.com/JaKooLit/Hyprland-Dots) dotfiles or those at [ml4w.com](ml4w.com). Right now the easiest way to get those working is to install them into an Arch VM, where they will install all the needed packages along with the dotfiles. Then copy the necessary config files to this system.

    NOTE: I do plan on building a script that will do this copying/setup for you at some point.
