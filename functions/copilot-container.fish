function copilot-container --description "Run GitHub Copilot CLI in container"
    # Copilot uses OAuth from gh auth login, not PATs
    # No need to set GH_TOKEN - it uses ~/.config/gh/ OAuth tokens

    __container_launcher "ai-ubuntu:latest" "copilot" $argv
    # __container_launcher "ai-ubuntu:latest" bash
end
