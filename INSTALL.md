# Quick Installation Guide

## Option 1: Fisher (Recommended)

If you use [Fisher](https://github.com/jorgebucaran/fisher):

```fish
# Install from local directory (development)
fisher install ~/goose-in-podman-example/fish

# For private repos, Fisher doesn't work well. Use local installation:
# git clone git@github.com:ford-personal/mruss100.goose-in-podman-example.git ~/tmp/goose-in-podman-example
# fisher install ~/tmp/goose-in-podman-example
#
# Once repo is public:
# fisher install ford-personal/mruss100.goose-in-podman-example
```

## Option 2: Manual Symlink

```fish
# Create symlink (updates automatically when you pull changes)
ln -sf ~/goose-in-podman-example/fish/conf.d/container-launcher.fish \
       ~/.config/fish/conf.d/container-launcher.fish

# Reload fish
source ~/.config/fish/config.fish
```

## Option 3: Manual Copy

```fish
# Copy the file (requires manual updates)
cp ~/goose-in-podman-example/fish/conf.d/container-launcher.fish \
   ~/.config/fish/conf.d/

# Reload fish
source ~/.config/fish/config.fish
```

## Verify Installation

```fish
# Check if functions are available
functions | grep -E "(goose-container|copilot-container)"

# Should show:
# __container_build_command
# __container_launcher
# __container_mount_directories
# __container_mount_files
# __container_mount_workdir
# __container_print_verbose
# copilot-container
# goose-container
# goose-podman
```

## Build the Container Image

```fish
cd ~/goose-in-podman-example/docker
./build.sh

# Or manually if you need custom UID/GID
podman build \
  --build-arg LOCAL_UID=(id -u) \
  --build-arg LOCAL_GID=(id -g) \
  --build-arg LOCAL_USERNAME=(whoami) \
  -t ai-ubuntu:latest .
```

## First Run

```fish
# Drop into a shell to verify everything works
goose-container bash

# Inside container:
# - Check git: git --version
# - Check tools: rg --version, fd --version
# - Check mounts: ls -la ~/.config/goose
# - Check SSH: ssh-add -l
# - Exit: exit

# Start goose
goose-container
```

## Uninstall

### Fisher
```fish
fisher remove goose-in-podman-example
```

### Manual
```fish
rm ~/.config/fish/conf.d/container-launcher.fish
source ~/.config/fish/config.fish
```
