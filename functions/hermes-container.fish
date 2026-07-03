function hermes-container --description "Run Hermes AI agent in container"
    # TODO: Add hermes-specific environment variables here if needed
    # Example:
    # set -x HERMES_API_KEY "$HERMES_API_KEY"

    __container_launcher "ai-hermes:latest" "hermes" $argv

    # Clean up exported variables if any
end
