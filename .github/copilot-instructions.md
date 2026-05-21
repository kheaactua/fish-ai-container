# GitHub Copilot Instructions for Fish AI Containers

## Project Overview

This Fish shell plugin provides commands for launching AI coding assistants (Goose, GitHub Copilot CLI) in isolated containers. It handles credential mounting, git integration, user permissions, and extensibility hooks.

**Core Goals:**
- **Simplicity**: Single command to launch AI tools in containers
- **Security**: Read-only credential mounts, SSH agent forwarding
- **Smart defaults**: Auto-detect git repos, mount appropriate directories
- **Extensibility**: Work hooks for organization-specific customization

## Technology Stack

### Primary Technologies
- **Fish Shell 3.0+**: Modern shell with better scripting than bash
- **Podman/Docker**: Container runtime (commands work with either)
- **Bash**: Container entrypoint (not used in plugin itself)

### Fish Shell Specifics
- **Function files**: Each user-facing function in `functions/`
- **Config files**: Initialization and helpers in `conf.d/`
- **Auto-loading**: Functions in `functions/` load on first use
- **Universal variables**: Cross-session state (used by Fisher)

## Code Structure

```
fish-ai-containers/
├── README.md                           # User documentation
├── INSTALL.md                          # Installation guide
├── LICENSE                             # MIT license
├── fisher_plugin                       # Fisher plugin manifest
├── .github/
│   └── copilot-instructions.md        # This file
├── conf.d/
│   └── container-launcher.fish        # Core launcher + helpers
└── functions/
    ├── goose-container.fish           # Goose wrapper
    └── copilot-container.fish         # Copilot wrapper
```

## Code Patterns and Conventions

### Fish Function Naming

#### Public Commands (in `functions/`)
```fish
function tool-container --description "Run tool in container"
    # User-facing command
    # Naming: {tool-name}-container
end
```

#### Internal Helpers (in `conf.d/`)
```fish
function __container_helper --description "Internal helper"
    # Double underscore prefix = internal/private
    # Not shown in `functions` list by default
end
```

#### Work Hooks (user-defined)
```fish
function container-work-mounts
    # User provides in their ~/.config/fish/
    # Returns additional mounts
end

function container-work-env-vars
    # User provides in their ~/.config/fish/
    # Returns additional environment variables
end
```

### Function Template for New Tools

Create `functions/newtool-container.fish`:

```fish
function newtool-container --description "Run newtool in container"
    # 1. Set tool-specific environment variables
    set -x NEWTOOL_CONFIG "$HOME/.config/newtool"
    set -x NEWTOOL_API_KEY "$NEWTOOL_API_KEY"

    # 2. Launch via generic launcher
    __container_launcher "ai-ubuntu:latest" "newtool" $argv

    # 3. Clean up environment
    set -e NEWTOOL_CONFIG
    set -e NEWTOOL_API_KEY
end
```

**Key points:**
- Use `set -x` to export environment variables
- Use `set -e` to clean up after (prevents pollution)
- Pass `$argv` to forward all arguments
- Use `__container_launcher` for consistency

### Mount Specification Format

```fish
# Format: "host_path:container_path[:ro]"
# ro = read-only (optional, highly recommended for credentials)

"$HOME/.ssh:$HOME/.ssh:ro"           # Read-only SSH keys
"$HOME/.config/tool:/config"         # Tool config (read-write)
"/data/certs:/certs:ro"              # Certificates
```

### Container Launcher Architecture

The `__container_launcher` function flow:

```
1. __container_print_verbose       # Debug logging
2. __container_mount_files          # Conditional file mounts
3. __container_mount_directories    # Conditional directory mounts
4. __container_mount_workdir        # Git-aware workspace mounting
5. container-work-mounts (hook)     # User-provided mounts
6. container-work-env-vars (hook)   # User-provided env vars
7. __container_build_command        # Assemble final podman command
8. Execute podman run               # Launch container
```

### Array Building Pattern

Fish uses arrays naturally. Build commands incrementally:

```fish
set -l cmd "podman" "run"
set -a cmd "--rm" "-it"                    # Append flags
set -a cmd "--userns=keep-id"
set -a cmd "-v" "$HOME/.ssh:$HOME/.ssh:ro"  # Append mount

# Execute
$cmd "ai-ubuntu:latest" "bash"
```

### Conditional Mount Pattern

Only mount if file/directory exists:

```fish
function __container_mount_files
    for spec in $argv
        set -l parts (string split ":" -- $spec)
        set -l host_path $parts[1]

        if test -f $host_path  # Check file exists
            set -a mounts "-v" "$spec"
        else
            __container_print_verbose "Skipping mount (not found): $host_path"
        end
    end

    echo $mounts  # Return via stdout
end
```

### Duplicate Detection Pattern

Track explicit mounts to avoid conflicts:

```fish
set -l explicit_mount_paths
for mount in $explicit_mounts
    set -l parts (string split ":" -- $mount)
    set -a explicit_mount_paths $parts[2]  # Container path
end

# Later, check before auto-mounting
if not contains -- "/workspace" $explicit_mount_paths
    # Safe to auto-mount workspace
end
```

## Security Requirements

### Critical: Read-Only Credential Mounts

**ALWAYS** mount credentials as read-only:

```fish
# ✅ CORRECT - Read-only credentials
"-v" "$HOME/.ssh:$HOME/.ssh:ro"
"-v" "$HOME/.gitconfig:$HOME/.gitconfig:ro"
"-v" "$HOME/.netrc:$HOME/.netrc:ro"

# ❌ WRONG - Credentials writable by container
"-v" "$HOME/.ssh:$HOME/.ssh"
```

### SSH Agent Forwarding

**NEVER** copy SSH keys. Use agent forwarding:

```fish
# ✅ CORRECT - Forward agent socket
if set -q SSH_AUTH_SOCK
    set -a cmd "-v" "$SSH_AUTH_SOCK:/run/host-services/ssh-auth.sock"
    set -a cmd "-e" "SSH_AUTH_SOCK=/run/host-services/ssh-auth.sock"
end

# ❌ WRONG - Copying private keys
# Don't do this!
```

### User Namespace Mapping

Preserve file ownership with `--userns=keep-id`:

```fish
set -a cmd "--userns=keep-id"
# Files created in container will match host UID/GID
```

### Unique Temporary Directories

Avoid tmpdir collisions between sessions:

```fish
set -l tmpdir_suffix (random)
set -a cmd "--tmpfs" "/tmp:exec,uid=(id -u),gid=(id -g)"
# Each container gets isolated tmpdir
```

## Testing Approach

### Manual Testing

Fish doesn't have a great unit test framework. Test manually:

#### 1. Function Loading Test
```fish
# Install plugin
fisher install ~/fish-ai-containers

# Check functions loaded
functions | grep container
# Should show: goose-container, copilot-container
# Should NOT show: __container_* (private functions)

# Check private functions exist
type __container_launcher
# Should show function definition
```

#### 2. Basic Launch Test
```fish
cd ~/test-project
goose-container bash
# Should drop into container bash

# Inside container:
pwd              # Should be /workspace (mounted from host)
ls -la ~/.ssh/   # Should show SSH keys (read-only)
ssh-add -l       # Should show keys from agent
git config --list # Should show host git config
```

#### 3. Mount Test
```fish
set -x CONTAINER_VERBOSE 1
goose-container bash
# Should print:
# - All mounts being added
# - Environment variables
# - Final podman command
```

#### 4. Git Detection Test
```fish
cd ~/git-repo
set -x CONTAINER_VERBOSE 1
goose-container bash
# Should detect git root and mount it as /workspace

cd ~/git-repo/deep/nested/dir
goose-container bash
# Should still mount git root, not just nested dir
```

#### 5. Work Hook Test
```fish
# Add to ~/.config/fish/conf.d/work.fish
function container-work-mounts
    echo "$HOME/work/certs:/certs:ro"
end

goose-container bash
# Inside container:
ls /certs  # Should show work certs
```

#### 6. Argument Passing Test
```fish
goose-container --version
goose-container --help
goose-container run "test command"
# All arguments should pass through correctly
```

## Common Pitfalls

### 1. Variable Scope

**Problem**: Variables don't persist across functions

**Wrong**:
```fish
function helper
    set mounts "-v" "/path:/path"  # Lost when function returns
end

function main
    helper
    echo $mounts  # Empty!
end
```

**Correct**:
```fish
function helper
    set -l mounts "-v" "/path:/path"
    echo $mounts  # Return via stdout
end

function main
    set -l mounts (helper)  # Capture output
    echo $mounts
end
```

### 2. Quoting in Arrays

**Problem**: Arguments with spaces break

**Wrong**:
```fish
set cmd podman run -v "$HOME/.ssh:$HOME/.ssh:ro"
# This creates 2 array elements instead of 1 for the -v argument
```

**Correct**:
```fish
set cmd podman run
set -a cmd "-v" "$HOME/.ssh:$HOME/.ssh:ro"
# -v and path are separate array elements
```

### 3. String Splitting

**Problem**: `string split` behavior with missing delimiter

```fish
set spec "$HOME/.ssh:$HOME/.ssh:ro"
set parts (string split ":" -- $spec)
echo $parts[1]  # Host path
echo $parts[2]  # Container path
echo $parts[3]  # "ro" or empty

# ✅ Always check array length before accessing
if test (count $parts) -ge 3
    set mode $parts[3]
end
```

### 4. Test Operators

Use correct test operators:

```fish
# Files
test -f $path    # File exists
test -d $path    # Directory exists
test -e $path    # Exists (file or dir)

# Variables
set -q VAR       # Variable is set
test -n "$VAR"   # Variable is non-empty

# Strings
test "$a" = "$b"  # String equality (use = not ==)

# Numbers
test $a -eq $b    # Numeric equality
```

### 5. Function Return Values

Fish functions don't `return` values like bash. Use stdout:

```fish
# ❌ WRONG - return doesn't work like this
function get_path
    return "$HOME/.ssh"  # This sets exit code, not return value
end

# ✅ CORRECT - echo to return
function get_path
    echo "$HOME/.ssh"
end

set path (get_path)  # Capture stdout
```

### 6. Verbose Logging

Gate debug output properly:

```fish
function __container_print_verbose
    if set -q CONTAINER_VERBOSE  # Check if variable is set
        echo "🐛 $argv" >&2      # Print to stderr
    end
end
```

### 7. Fisher Plugin Manifest

`fisher_plugin` must list files with correct paths:

```
conf.d/container-launcher.fish
functions/goose-container.fish
functions/copilot-container.fish
```

**Not**:
```
# ❌ WRONG - no fish/ prefix
fish/conf.d/container-launcher.fish
```

## Contribution Guidelines

### Adding New Tool Wrappers

1. Create `functions/{tool}-container.fish`
2. Follow the template pattern
3. Add to `fisher_plugin` manifest
4. Update README with tool description
5. Test manually (all 6 tests above)

### Modifying Core Launcher

- **Maintain backward compatibility** - don't break existing work hooks
- **Preserve security defaults** - read-only credentials
- **Test all tool wrappers** - changes affect goose, copilot, etc.
- **Update documentation** - README and this file

### Documentation

- **README.md**: User-facing (how to install and use)
- **INSTALL.md**: Installation details
- **This file**: Developer/AI guidance (patterns and implementation)

## Integration with Container Images

This plugin expects container images from [containerized-ai-tools](https://github.com/kheaactua/containerized-ai-tools).

**Required image features:**
- Non-root user matching host UID/GID
- Tools in PATH (`goose`, `gh copilot`, etc.)
- SSH, git, curl available
- Supports `--userns=keep-id`

**Image naming convention:**
- Default: `ai-ubuntu:latest`
- Can override per tool wrapper

## AI Assistant Guidance

When working on this codebase:

1. **Use Fish idioms**: Arrays, string split, test operators
2. **Security first**: Read-only credential mounts, SSH agent forwarding
3. **Return via stdout**: Functions communicate through echo
4. **Scope correctly**: Use `-l` for local, `-x` for export, `-e` to unset
5. **Test manually**: No automated tests, verify by running
6. **Document patterns**: Update this file when adding new patterns

When suggesting changes:
- Show Fish-specific syntax (not bash)
- Explain security implications
- Provide before/after examples
- Consider existing tool wrappers will break if launcher changes
