# copilot-instructions.md

This file provides guidance to copilot agents on github.

## Repository Overview

HyprBlue is a variant of Bluefin that adds a comprehensive Hyprland desktop environment installation along with Google Chrome and 1Password pre-installed. It's built on top of the bootc framework and uses Just as its primary build tool.

## Architecture

### Core Components

1. **Container Image Build System**
   - Uses bootc (Boot Container) framework for creating custom OCI images
   - Builds on top of Bluefin/Fedora base images
   - Container signing is mandatory for security

2. **Package Management**
   - Uses dnf5 for package management
   - Incorporates multiple Copr repositories for specialized packages
   - Organizes packages into distinct groups:
     - Hyprland core packages
     - Hyprland dependencies
     - Niri (alternative Wayland compositor)
     - Font packages
     - Additional system applications

### Build Process

The build process is structured in layers:

1. Repository setup (Copr repos)
2. Package installation (fonts, Hyprland, dependencies)
3. System configuration
4. Service enablement

## Common Commands

### Building Images

```bash
# Build the container image
just build

# Build specific image types
just build-qcow2     # Build QCOW2 virtual machine image
just build-raw       # Build RAW virtual machine image
just build-iso       # Build ISO image

# Rebuild images (includes container rebuild)
just rebuild-qcow2
just rebuild-raw
just rebuild-iso
```

### Running Virtual Machines

```bash
# Run VM from QCOW2 image (default)
just run-vm

# Run specific image types
just run-vm-qcow2
just run-vm-raw
just run-vm-iso

# Run VM with systemd-vmspawn
just spawn-vm rebuild=0 type=qcow2 ram=6G
```

### Development Commands

```bash
# Code Quality
just lint           # Run shellcheck on bash scripts
just format         # Run shfmt on bash scripts

# Cleanup
just clean          # Clean build artifacts
```

### Repository Management

Two-phase installation process is required:

1. First phase (unsigned):

```bash
just -f /tmp/hyprblue-justfile rebase-unsigned
```

2. Second phase (after reboot):

```bash
just -f /tmp/hyprblue-justfile rebase-signed
```

## Working with Hyprland

The default Hyprland setup is minimal. After installation:

1. Do not select Hyprland from the login screen after the first reboot
2. Ensure basic Hyprland setup is complete before customizing
3. For dotfiles setup:
   - Consider using JaKooLit's or ml4w.com dotfiles as reference
   - Install in Arch VM first to get package dependencies
   - Copy necessary config files to your system

## Development Guidelines

1. Container images must be signed using cosign for security
2. Follow the quality checks before committing:
   - Run `just lint` to verify shell scripts
   - Run `just format` to maintain consistent formatting
3. Always test built images using `just run-vm` before pushing changes
4. When adding new packages:
   - Add them to appropriate groups in build.sh
   - Verify Copr repository availability
   - Test installation in both build and runtime phases
