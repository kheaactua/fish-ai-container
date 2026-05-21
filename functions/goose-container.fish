function goose-container --description "Run goose in container to isolate session from host"
    # Set goose-specific environment variables
    set -x GOOSE_DISABLE_KEYRING 1
    set -x LANGFUSE_ENABLED false

    # Pass through GOOSE_MOIM_MESSAGE_TEXT if it exists
    if set -q GOOSE_MOIM_MESSAGE_TEXT
        set -x GOOSE_MOIM_MESSAGE_TEXT "$GOOSE_MOIM_MESSAGE_TEXT"
    end

    __container_launcher "ai-ubuntu:latest" "goose" $argv
    # __container_launcher "ai-ubuntu:latest" bash

    # Clean up exported variables
    set -e GOOSE_DISABLE_KEYRING
    set -e LANGFUSE_ENABLED
    if set -q GOOSE_MOIM_MESSAGE_TEXT
        set -e GOOSE_MOIM_MESSAGE_TEXT
    end
end
