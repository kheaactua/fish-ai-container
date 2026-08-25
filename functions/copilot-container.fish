function copilot-container --description "Run GitHub Copilot CLI in container"
    # Copilot uses OAuth from gh auth login, not PATs
    # No need to set GH_TOKEN - it uses ~/.config/gh/ OAuth tokens

    # Container ships a fixed `developer` user (UID/GID 1000) regardless of host username
    set -l CONTAINER_HOME "/home/developer"

    # Define Copilot-specific mounts
    set -l copilot_mounts \
        $HOME/.config/github-copilot:$CONTAINER_HOME/.config/github-copilot \
        $HOME/.copilot:$CONTAINER_HOME/.copilot

    __container_launcher "ai-copilot:latest" "copilot" --agent-mounts $copilot_mounts -- $argv
end
