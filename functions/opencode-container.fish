function opencode-container --description "Run OpenCode (work build) in container"
    # Container ships a fixed `developer` user (UID/GID 1000) regardless of host username
    set -l CONTAINER_HOME "/home/developer"

    # Share host opencode state with the container:
    #   ~/.config/opencode       - user config, plugins (package.json/node_modules)
    #   ~/.local/share/opencode  - auth.json (work LLM OAuth), opencode.db (sessions), logs
    #   ~/.local/state/opencode  - recent models, prompt history, etc.
    #   ~/.cache/opencode        - model lists, downloaded skills
    # Work managed settings are baked into the image at /etc/opencode/opencode.jsonc.
    # NOTE: avoid running host and container opencode at the same time (shared SQLite DB).
    for dir in $HOME/.config/opencode $HOME/.local/share/opencode $HOME/.local/state/opencode $HOME/.cache/opencode
        test -d $dir; or mkdir -p $dir
    end

    set -l opencode_mounts \
        $HOME/.config/opencode:$CONTAINER_HOME/.config/opencode \
        $HOME/.local/share/opencode:$CONTAINER_HOME/.local/share/opencode \
        $HOME/.local/state/opencode:$CONTAINER_HOME/.local/state/opencode \
        $HOME/.cache/opencode:$CONTAINER_HOME/.cache/opencode

    # Skills opencode discovers from Claude/agents dirs (read-only)
    for skills_dir in .agents/skills .claude/skills
        if test -d $HOME/$skills_dir
            set -a opencode_mounts $HOME/$skills_dir:$CONTAINER_HOME/$skills_dir:ro
        end
    end

    __container_launcher "ai-opencode:latest" "opencode" --agent-mounts $opencode_mounts -- $argv
end
