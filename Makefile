# Makefile for the unpossible template (sandbox-friendly)
# Adds sandbox-aware targets (sb-*) which run the loop inside a running Docker sandbox.
# This variant removes the unsupported '--' token from `docker sandbox exec` invocations
# so the command is passed directly to the container runtime.

SANDBOX ?= claude-unpossible

.PHONY: build plan build1 plan1 help \
        sb-build sb-plan sb-build1 sb-plan1 sb-shell

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
	@echo ""
	@echo "Examples:"
	@echo "  make sb-build N=10                # run 10 iterations inside sandbox"
	@echo "  make sb-plan SANDBOX=my-sandbox   # run plan mode in 'my-sandbox'"

# Local (host) targets
build:
	@./loop.sh $(if $(N),$(N),)

plan:
	@./loop.sh plan $(N)

build1:
	@./loop.sh 1

plan1:
	@./loop.sh plan 1

# Sandbox-aware targets: run commands inside a running docker sandbox
# NOTE: removed '--' token so the runtime receives the correct command to run.
sb-build:
	@docker sandbox exec -it $(SANDBOX) ./loop.sh $(if $(N),$(N),)

sb-plan:
	@docker sandbox exec -it $(SANDBOX) ./loop.sh plan $(N)

sb-build1:
	@docker sandbox exec -it $(SANDBOX) ./loop.sh 1

sb-plan1:
	@docker sandbox exec -it $(SANDBOX) ./loop.sh plan 1

# Open an interactive shell inside the sandbox (useful for debugging / manual runs)
sb-shell:
	@docker sandbox exec -it $(SANDBOX) bash || docker sandbox exec -it $(SANDBOX) sh
