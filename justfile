
act:
    act -s GITHUB_TOKEN="$(gh auth token)" -P ubuntu-24.04=ghcr.io/catthehacker/ubuntu:full-24.04

rebase-unsigned:
    rpm-ostree rebase ostree-unverified-registry:ghcr.io/ashebanow/hyprblue:latest

rebase-signed:
    rpm-ostree rebase ostree-image-signed:docker://ghcr.io/ashebanow/hyprblue:latest
