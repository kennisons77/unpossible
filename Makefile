# Makefile for the unpossible template (sandbox-friendly)
# Contains:
# - local targets: build / plan / build1 / plan1 (run loop.sh on the host)
# - sandbox targets: sb-build / sb-plan / sb-build1 / sb-plan1 / sb-shell
# - helpers: sb-inspect (discover mounts) and sb-sync (tar-copy repo into sandbox)
#
# Notes:
# - SANDBOX: name of the running sandbox (default: "claude")
# - SANDBOX_WORKDIR: path inside the sandbox where the project should live.
#   By default it's /workspace/<repo-basename> but override if your sandbox mounts elsewhere.
#
# Usage examples:
#   make build
#   make plan N=1
#   make sb-build SANDBOX=my-sandbox SANDBOX_WORKDIR=/workspace/unpossible N=5
#   make sb-shell SANDBOX=my-sandbox SANDBOX_WORKDIR=/workspace/unpossible
#   make sb-sync SANDBOX=my-sandbox SANDBOX_WORKDIR=/workspace/unpossible
#
# Caution: `sb-sync` will overwrite files in the target directory inside the sandbox.

SANDBOX ?= claude
# Default workdir inside the sandbox: /workspace/<repo-basename>
SANDBOX_WORKDIR ?= /workspace/$(notdir $(CURDIR))

.PHONY: help build plan build1 plan1 \
        sb-build sb-plan sb-build1 sb-plan1 sb-shell sb-inspect sb-sync

# Default target: print usage
help:
	@echo "Usage:"
	@echo "  make build           Build mode, unlimited iterations (local)"
	@echo "  make plan            Plan mode, unlimited iterations (local)"
	@echo "  make build N=20      Build mode, max N iterations (local)"
	@echo "  make plan N=5        Plan mode, max N iterations (local)"
	@echo "  make build1          Build mode, exactly 1 iteration (local)"
	@echo "  make plan1           Plan mode, exactly 1 iteration (local)"
	@echo ""
	@echo "Sandbox-aware targets (run inside a running docker sandbox):"
	@echo "  make sb-build        Build mode inside sandbox ($(SANDBOX))"
	@echo "  make sb-plan         Plan mode inside sandbox ($(SANDBOX))"
	@echo "  make sb-build1       Single-iteration build inside sandbox"
	@echo "  make sb-plan1        Single-iteration plan inside sandbox"
	@echo "  make sb-shell        Open an interactive shell inside sandbox ($(SANDBOX))"
	@echo "  make sb-inspect      Probe common paths inside sandbox to discover mount location"
	@echo "  make sb-sync         Sync (tar) the current repo into the sandbox workdir (overwrites files)"
	@echo ""
	@echo "Defaults: SANDBOX=$(SANDBOX), SANDBOX_WORKDIR=$(SANDBOX_WORKDIR)"
	@echo "Examples:"
	@echo "  make sb-build N=10                              # run 10 iterations inside sandbox"
	@echo "  make sb-plan SANDBOX=my-sandbox                 # run plan mode in 'my-sandbox'"
	@echo "  make sb-shell SANDBOX=my-sandbox                # open shell in sandbox"
	@echo "  make sb-sync SANDBOX=my-sandbox                 # copy repo into sandbox workdir"

# Local (host) targets - run the loop script on the host
build:
	@./loop.sh $(if $(N),$(N),)

plan:
	@./loop.sh plan $(N)

build1:
	@./loop.sh 1

plan1:
	@./loop.sh plan 1

# -----------------------
# Sandbox-aware targets
# -----------------------
# These run the same commands inside a running sandbox and ensure the process starts
# in $(SANDBOX_WORKDIR) inside the sandbox. Override SANDBOX_WORKDIR if your project
# is mounted elsewhere in the sandbox container/VM.
#
# Note: Some sandboxes expect a slightly different exec syntax. If your sandbox CLI
# differs, override the commands on the command-line or edit these targets.

sb-build:
	@docker sandbox exec -it $(SANDBOX) sh -lc 'cd "$(SANDBOX_WORKDIR)" && ./loop.sh $(if $(N),$(N),)'

sb-plan:
	@docker sandbox exec -it $(SANDBOX) sh -lc 'cd "$(SANDBOX_WORKDIR)" && ./loop.sh plan $(N)'

sb-build1:
	@docker sandbox exec -it $(SANDBOX) sh -lc 'cd "$(SANDBOX_WORKDIR)" && ./loop.sh 1'

sb-plan1:
	@docker sandbox exec -it $(SANDBOX) sh -lc 'cd "$(SANDBOX_WORKDIR)" && ./loop.sh plan 1'

# Open an interactive shell inside the sandbox and `cd` into the project folder.
# Tries bash first, then falls back to sh.
sb-shell:
	@docker sandbox exec -it $(SANDBOX) sh -lc 'cd "$(SANDBOX_WORKDIR)" && (bash || sh)'

# Inspect likely mount points and basic runtime info inside the sandbox.
# Useful to discover where the project is mounted when mounts are not automatic.
sb-inspect:
	@echo "Inspecting sandbox '$(SANDBOX)' (probing common paths)..."
	@docker sandbox exec -it $(SANDBOX) sh -lc 'echo "SANDBOX_WORKDIR (desired): $(SANDBOX_WORKDIR)"; echo "---- /workspace ----"; ls -la /workspace || true; echo "---- /home ----"; ls -la /home || true; echo "---- /root ----"; ls -la /root || true; echo "---- pwd & user ----"; pwd; whoami; echo "---- find repo basename: $(notdir $(CURDIR)) ----"; find / -maxdepth 3 -type d -name "$(notdir $(CURDIR))" 2>/dev/null || true'

# Sync (tar) the local repo into the sandbox workdir.
# CAUTION: this will overwrite files in the target directory inside the sandbox.
# Excludes common large/ignored directories to reduce transfer size.
sb-sync:
	@echo "Syncing local repo into sandbox '$(SANDBOX)' -> '$(SANDBOX_WORKDIR)' (this may overwrite files inside the sandbox)"
	@tar -C "$(CURDIR)" --exclude='.git' --exclude='node_modules' --exclude='tmp' --exclude='log' --exclude='coverage' --exclude='.venv' -cf - . | docker sandbox exec -i $(SANDBOX) sh -lc 'mkdir -p "$(SANDBOX_WORKDIR)" && tar -C "$(SANDBOX_WORKDIR)" -xvf -'

# End of Makefile
