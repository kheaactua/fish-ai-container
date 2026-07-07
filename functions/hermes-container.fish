function hermes-container --description "Run Hermes AI agent in container"
    # Hermes stores both code and data in ~/.hermes/
    # The installation (hermes-agent/) must stay in the container
    # But we want to persist user data (sessions, logs, skills, configs) on the host
    # Solution: Mount individual data subdirectories, leaving hermes-agent/ in container

    set -l CONTAINER_HOME "/home/"(whoami)
    set -l HERMES_HOME "$HOME/.hermes"

    # Initialize Hermes data directory structure
    # Check and create each required path individually to handle partial initialization

    # Define all required paths up front
    set -l required_dirs sessions logs skills cron pairing hooks image_cache audio_cache memories
    set -l required_files .env config.yaml SOUL.md
    set -l needs_init false

    # Check if any DIRECTORIES are missing
    for dir in $required_dirs
        if not test -d "$HERMES_HOME/$dir"
            set needs_init true
            break
        end
    end

    # Check if any FILES are missing (only if not already flagged)
    if test "$needs_init" = false
        for file in $required_files
            if not test -f "$HERMES_HOME/$file"
                set needs_init true
                break
            end
        end
    end

    # Create ALL missing paths (this runs BEFORE launcher is called)
    if test "$needs_init" = true
        echo "📦 Initializing Hermes data directory at $HERMES_HOME"

        # Create each subdirectory individually
        for dir in $required_dirs
            if not test -d "$HERMES_HOME/$dir"
                mkdir -p "$HERMES_HOME/$dir"
                echo "  ✓ Created $dir/"
            end
        end

        # Create each config file individually
        if not test -f "$HERMES_HOME/.env"
            touch "$HERMES_HOME/.env"
            chmod 600 "$HERMES_HOME/.env"
            echo "  ✓ Created .env (add API keys here)"
        end

        if not test -f "$HERMES_HOME/config.yaml"
            touch "$HERMES_HOME/config.yaml"
            echo "  ✓ Created config.yaml"
        end

        if not test -f "$HERMES_HOME/SOUL.md"
            # Create a minimal SOUL.md similar to what Hermes installer creates
            echo "You are Hermes Agent, an intelligent AI assistant created by Nous Research. You are helpful, knowledgeable, and direct." > "$HERMES_HOME/SOUL.md"
            echo "  ✓ Created SOUL.md (personality file)"
        end

        echo "  ✓ Hermes data directory initialized"
        echo ""
    end

    # Define Hermes-specific mounts for data persistence
    # We mount individual subdirectories to avoid shadowing the hermes-agent installation
    # Host: ~/.hermes/sessions → Container: ~/.hermes/sessions (leaves ~/.hermes/hermes-agent intact)
    set -l hermes_mounts \
        $HOME/.hermes/sessions:$CONTAINER_HOME/.hermes/sessions \
        $HOME/.hermes/logs:$CONTAINER_HOME/.hermes/logs \
        $HOME/.hermes/skills:$CONTAINER_HOME/.hermes/skills \
        $HOME/.hermes/cron:$CONTAINER_HOME/.hermes/cron \
        $HOME/.hermes/pairing:$CONTAINER_HOME/.hermes/pairing \
        $HOME/.hermes/hooks:$CONTAINER_HOME/.hermes/hooks \
        $HOME/.hermes/image_cache:$CONTAINER_HOME/.hermes/image_cache \
        $HOME/.hermes/audio_cache:$CONTAINER_HOME/.hermes/audio_cache \
        $HOME/.hermes/memories:$CONTAINER_HOME/.hermes/memories \
        $HOME/.hermes/.env:$CONTAINER_HOME/.hermes/.env \
        $HOME/.hermes/config.yaml:$CONTAINER_HOME/.hermes/config.yaml \
        $HOME/.hermes/SOUL.md:$CONTAINER_HOME/.hermes/SOUL.md

    __container_launcher "ai-hermes:latest" "hermes" --agent-mounts $hermes_mounts -- $argv
end
