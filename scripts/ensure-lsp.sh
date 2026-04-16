#!/bin/bash
# Ensure LSP servers are available for code intelligence.
# Called by agentSpawn hook — installs only if missing.

if ! command -v ruby-lsp &>/dev/null && command -v gem &>/dev/null; then
    gem install ruby-lsp --no-document 2>/dev/null
fi

if ! command -v gopls &>/dev/null && command -v go &>/dev/null; then
    go install golang.org/x/tools/gopls@latest 2>/dev/null
fi
