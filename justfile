# default recipe to display help information
default:
    @just --list

# test our githib actions to build image
act:
    act -s GITHUB_TOKEN="$(gh auth token)" -P ubuntu-24.04=ghcr.io/catthehacker/ubuntu:full-24.04

# first, unsigned rebasing step. Reboot afterwards.
rebase-unsigned:
    rpm-ostree rebase ostree-unverified-registry:docker://ghcr.io/ashebanow/hyprblue:latest

# second and final signed rebasing step. Reboot afterwards.
rebase-signed:
    rpm-ostree rebase ostree-image-signed:docker://ghcr.io/ashebanow/hyprblue:latest
