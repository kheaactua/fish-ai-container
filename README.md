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

### Option 1: Fisher (Recommended)

```fish
fisher install kheaactua/fish-ai-containers
```

### Option 2: Manual Installation

```fish
# Clone the repository
git clone https://github.com/kheaactua/fish-ai-containers.git ~/fish-ai-containers

# Symlink the files (updates automatically when you git pull)
ln -s ~/fish-ai-containers/conf.d/container-launcher.fish \
      ~/.config/fish/conf.d/container-launcher.fish
ln -s ~/fish-ai-containers/functions/goose-container.fish \
      ~/.config/fish/functions/goose-container.fish
ln -s ~/fish-ai-containers/functions/copilot-container.fish \
      ~/.config/fish/functions/copilot-container.fish

# Reload fish
exec fish
```

### Option 3: Direct Copy

```fish
# Copy files to your fish config
mkdir -p ~/.config/fish/{conf.d,functions}
cp ~/fish-ai-containers/conf.d/container-launcher.fish \
   ~/.config/fish/conf.d/
cp ~/fish-ai-containers/functions/*.fish \
   ~/.config/fish/functions/

# Reload fish
exec fish
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

## Contributing

Contributions welcome! Please open issues or PRs on [GitHub](https://github.com/kheaactua/fish-ai-containers).

## License

MIT License - See LICENSE file for details.
