# Fish Shell Plugin - AI Containers

Fish shell plugin for launching AI coding assistants (Goose, GitHub Copilot) in isolated containers.

## Features

- 🐚 **Simple commands**: `goose-container`, `copilot-container`
- 🔒 **Secure by default**: Credentials mounted read-only
- 🔄 **Git integration**: Automatic git root detection
- 📦 **Extensible**: Easy to add new AI tools
- 🎣 **Work hooks**: Custom mounts and environment for your organization

## Prerequisites

1. **Container image** from [containerized-ai-tools](https://github.com/kheaactua/containerized-ai-tools)
   ```bash
   git clone https://github.com/kheaactua/containerized-ai-tools.git
   cd containerized-ai-tools/docker
   ./build.sh
   ```

2. **Podman or Docker** installed
   ```bash
   # Ubuntu/Debian
   sudo apt install podman
   ```

3. **Fish shell**
   ```bash
   # Ubuntu/Debian
   sudo apt install fish
   ```

## Installation

Install with Fisher:

```fish
fisher install kheaactua/fish-ai-container
```

## Usage

### Goose

```fish
# Start interactive session in current directory
goose-container

# Pass arguments to goose
goose-container --help
goose-container session --profile coding
goose-container run "explain this codebase"

# Drop into bash shell for debugging
goose-container bash
```

### GitHub Copilot

The launcher passes `GH_TOKEN` to the container when it is set. Otherwise,
`GITHUB_TOKEN` takes precedence; if neither is set, the launcher uses
`WORK_GITHUB_TOKEN` as `GH_TOKEN`. GitHub CLI environment tokens override its
stored accounts. A token must have the access needed for the commands you run.

The host keyring is not forwarded: mounting `~/.config/gh` alone does not make
keyring-backed credentials available in the container. Environment tokens are
available to processes in the container and may be visible through container
inspection; do not enable verbose logging of token values or use untrusted
containers. No token is written to a new credentials file by this launcher.

```fish
# Use Copilot commands
copilot-container suggest "write a unit test"
copilot-container explain "what does this function do?"

# Drop into shell
copilot-container bash
```

## How It Works

The plugin provides a generic `__container_launcher` function that:

1. **Detects git repositories** and mounts the root (not just pwd)
2. **Mounts credentials read-only**:
   - `~/.gitconfig`, `~/.netrc` (git)
   - `~/.ssh/` (SSH keys and config)
   - SSH agent socket for key access
3. **Mounts tool configs** read-write:
   - `~/.config/goose/` (Goose settings)
   - `~/.config/gh/` (GitHub Copilot auth)
4. **Preserves user permissions** with `--userns=keep-id`
5. **Provides host networking** for API access
6. **Creates unique tmpdirs** per session

### What Gets Mounted

**Automatic mounts:**
- Current working directory or git root → `/workspace`
- `~/.config/goose` → `~/.config/goose` (rw)
- `~/.config/gh` → `~/.config/gh` (ro, for Copilot)
- `~/.gitconfig` → `~/.gitconfig` (ro)
- `~/.ssh/` → `~/.ssh/` (ro)
- `$SSH_AUTH_SOCK` → `/run/host-services/ssh-auth.sock`

**Conditional mounts** (if they exist):
- `~/.netrc`
- `~/.git-credentials`
- `~/.config/wireshark`

**Custom mounts** (via hooks):
- See "Work-Specific Customization" below

## Customization

### Work-Specific Hooks

Add custom mounts and environment variables for your organization:

```fish
# ~/.config/fish/config.fish or ~/.config/fish/conf.d/work.fish

function container-work-env-vars --description "Custom env vars for work containers"
    # Return environment variables as VAR=value
    echo "JFROG_TOKEN=$JFROG_TOKEN"
    echo "INTERNAL_API_URL=https://api.internal.example.com"
    echo "COMPANY_PROXY=$HTTP_PROXY"
end

function container-work-mounts --description "Custom mounts for work containers"
    # Return mount specifications as host:container[:ro]
    echo "$HOME/work/certs:/certs:ro"
    echo "$HOME/work/tools:/opt/tools:ro"
    echo "$HOME/.company-config:/home/(whoami)/.company-config:ro"
end
```

### Adding New AI Tools

Create a new function following the pattern:

```fish
# ~/.config/fish/functions/my-tool-container.fish

function my-tool-container --description "Run my-tool in container"
    # Set tool-specific environment if needed
    set -x MY_TOOL_CONFIG "$HOME/.config/my-tool"
    set -x MY_TOOL_API_KEY "$MY_TOOL_API_KEY"

    # Launch with the generic launcher
    __container_launcher "ai-ubuntu:latest" "my-tool" $argv

    # Clean up environment
    set -e MY_TOOL_CONFIG
    set -e MY_TOOL_API_KEY
end
```

### Target access (QNX and AOSP)

The AI base image includes `adb`, `picocom`, and `audit2allow` (from `policycoreutils-python-utils`). Rebuild the base and your agent image to get these tools; existing containers do not gain them automatically. Network ADB uses the launcher's existing host networking and needs no USB passthrough:

```fish
adb connect android.local:5555
adb -s android.local:5555 shell
```

The launcher automatically passes `/dev/ttyUSB1` into new containers when it exists. If absent, it prints a notice and starts without serial access. Confirm that this is the target console before opening it:

```fish
copilot-container
# Inside the container:
picocom -b 115200 /dev/ttyUSB1
```

To override the default, set `CONTAINER_SERIAL_DEVICE` to another device or a confirmed `/dev/serial/by-id/` path before launching. An invalid explicit override stops launch rather than silently selecting another device. Podman resolves the host symlink and exposes the device at the supplied path inside the container. Relaunch after unplugging/replugging a device that changes its device number.

The launcher checks host read/write access, passes only the selected device with `--device`, and uses `--group-add keep-groups` to retain host supplemental-group access. For serial-enabled containers it explicitly selects `--runtime crun`, even if Podman defaults to runc. Install **crun on the host** if unavailable; it is not a package needed inside the image. Without serial passthrough, the default runtime is unchanged. The host user must already have the device's actual group access (often `dialout`, `tty`, or `plugdev`); do not change permissions broadly or use a privileged container. A host security policy can still deny access and must be diagnosed separately.

After updating the launcher, source `conf.d/container-launcher.fish` in the host fish shell and start a new container. Existing containers retain their original settings. Diagnose the affected container with `podman inspect --format '{{json .HostConfig.GroupAdd}} {{json .HostConfig.Devices}}' CONTAINER_NAME`: empty arrays mean it was launched without these serial options. Device ownership shown as `65534:65534` inside a rootless container can be normal; do not change ownership to fix unmapped IDs.

Only one process can own the serial console, across host and container. This setting does not claim the device or evict an existing session. Leave picocom locking enabled. To stop passing serial devices into new containers:

```fish
set -gx CONTAINER_SERIAL_DEVICE none
```

Use `set -e CONTAINER_SERIAL_DEVICE` to restore automatic `/dev/ttyUSB1` selection.

SSH mounts and agent forwarding are unchanged. These options do not expose USB ADB devices, install any CAN tools, or control the target.

### Intrepid CAN devices through host servd

Run Intrepid's `servd` on the Linux host, not in each container. A host trace of
`ics.find_devices()` showed successful TCP connections to `127.0.0.1:26741` and
`127.0.0.1:40017`. These are observed endpoints, not a guaranteed fixed port list.
The launcher's existing `--network host` lets clients reach those loopback
endpoints without socket mounts, USB passthrough, or privileged mode.
Host networking reduces network isolation; keep servd on loopback rather than
exposing it to the LAN.

The base image pins `python-ics==1!26.3.9`, which uses servd. Any separate
Python environment that accesses CAN devices through servd should use a
servd-based `python-ics` release (`>=1!26.3.9`), not an older direct-USB client.
Rebuild the base and agent images, reload the launcher, and create a new container.
Start `servd` on the host before using CAN tools. No container device-group
membership is needed for loopback TCP access; the host service needs USB access.
The existing serial-console options are independent and remain unchanged.

Inside a newly launched container, verify with the interpreter used by the tool:

```bash
python -c 'import importlib.metadata as m, ics; print(m.version("python-ics")); print(ics.find_devices())'
```

Confirm that the ValueCAN is listed before running CAN tools. This plugin does
not install CAN utilities or Python packages. Do not mount the host Python venv
as a substitute for installing compatible dependencies in the image.

### Debugging

Enable verbose output to see what's happening:

```fish
set -x CONTAINER_VERBOSE 1
goose-container bash

# You'll see:
# - All environment variables being passed
# - All mount points
# - Full podman command
```

## Available Functions

### User Commands

- **`goose-container [args...]`** - Run Goose in a container
- **`copilot-container [args...]`** - Run GitHub Copilot CLI in a container

### Internal Helpers

These are used by the tool wrappers. You can use them to build custom commands:

- **`__container_launcher IMAGE TOOL_CMD [args...]`** - Generic container launcher
- **`__container_print_verbose [message...]`** - Conditional verbose logging
- **`__container_mount_files [host:container[:ro]...]`** - Mount files if they exist
- **`__container_mount_directories [host:container[:ro]...]`** - Mount dirs and track paths
- **`__container_mount_workdir WORK_DIR [explicit_mounts...]`** - Smart workspace mounting
- **`__container_build_command IMAGE WORK_DIR TOOL_CMD [args...]`** - Build final command

## Troubleshooting

### `goose-container: command not found`

**Solution**: Reload fish config
```fish
exec fish
# Or
source ~/.config/fish/config.fish
```

### Permission Denied Errors

**Problem**: Files created by container have wrong ownership

**Solution**: Rebuild the container image with your UID/GID:
```bash
cd ~/containerized-ai-tools/docker
./build.sh  # Automatically detects your IDs
```

### SSH Agent Not Working

**Problem**: `ssh-add -l` shows error in container

**Solution**: Ensure SSH agent is running on host:
```fish
echo $SSH_AUTH_SOCK
# If empty:
eval (ssh-agent -c)
ssh-add ~/.ssh/id_ed25519
```

### Git Not Finding Repository

**Problem**: Goose can't see git repository

**Solution**: Make sure you're inside a git repo:
```bash
git rev-parse --show-toplevel
# Should show the repo root
```

Enable verbose mode to see what's mounted:
```fish
set -x CONTAINER_VERBOSE 1
goose-container bash
```

### Mount Conflicts

**Problem**: Custom mount overrides automatic mount

**Solution**: The launcher tracks explicit mounts and skips duplicates. Check verbose output:
```fish
set -x CONTAINER_VERBOSE 1
goose-container bash
# Look for "Explicit mount detected" messages
```

## Examples

### Basic Workflow

```fish
# Navigate to your project
cd ~/my-project

# Start Goose
goose-container
# Goose can see entire git repo, use your SSH keys, access git config

# Or run specific commands
goose-container run "analyze this codebase and suggest improvements"
```

### Using with GitHub Copilot

```fish
cd ~/my-project

# Get suggestions
copilot-container suggest "add error handling to this function"

# Get explanations
copilot-container explain "how does this algorithm work?"
```

### Debugging Container Environment

```fish
# Drop into shell to inspect
goose-container bash

# Inside container:
pwd                    # Current working directory
ls -la ~/.ssh/         # SSH keys (read-only)
ssh-add -l            # Verify agent access
git config --list      # See git configuration
env | grep -i api      # Check API keys
```

## Configuration

### Environment Variables

**User-configurable:**
- `CONTAINER_VERBOSE=1` - Enable debug output showing all mounts and environment

**Automatically passed through:**
- `SSH_AUTH_SOCK` - SSH agent socket
- `*_API_KEY`, `*_TOKEN` - API credentials
- `HTTP_PROXY`, `HTTPS_PROXY`, `NO_PROXY` - Proxy settings
- `GOOSE_*` - Goose configuration

## Security Notes

- ✅ SSH keys mounted read-only (agent can use but not modify)
- ✅ Git credentials mounted read-only
- ✅ User namespace preserves UID/GID
- ✅ Unique tmpdir per container
- ⚠️ Workspace mounted read-write (AI can modify code)
- ⚠️ Host network mode (full network access)

## Related Projects

- [containerized-ai-tools](https://github.com/kheaactua/containerized-ai-tools) - Container images for AI tools
- [Goose](https://github.com/block/goose) - AI coding agent
- [Fisher](https://github.com/jorgebucaran/fisher) - Fish plugin manager

## Development

### Pre-commit Hooks

This repository uses pre-commit hooks for code quality:

```bash
# Install pre-commit
pip install pre-commit

# Install hooks
pre-commit install

# Run manually on all files
pre-commit run --all-files
```

**Hooks enabled:**
- **fish syntax-check** - Fish shell syntax validation
- **markdownlint** - Markdown formatting
- **gitleaks** - Secret scanning
- **detect-secrets** - Additional secret detection

### Updating Secrets Baseline

If you intentionally add content that looks like a secret (example tokens, test data):

```bash
detect-secrets scan > .secrets.baseline
git add .secrets.baseline
```

### Testing Changes

Since Fish doesn't have great unit testing, manually test:

```fish
# Install locally
fisher install ~/fish-ai-container

# Test basic functionality
goose-container bash
copilot-container --version

# Test with verbose mode
set -x CONTAINER_VERBOSE 1
goose-container bash
```

## Contributing

Contributions welcome! Please open issues or PRs on [GitHub](https://github.com/kheaactua/fish-ai-container).

**Before submitting:**
- Ensure pre-commit hooks pass
- Test all user-facing functions
- Update documentation
- Follow Fish shell idioms

## License

MIT License - See LICENSE file for details.
