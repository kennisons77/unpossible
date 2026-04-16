# Makefile — Unpossible
# Skills and loop commands for the unpossible project.
# Run from the monorepo root: make -f projects/unpossible/Makefile <target>
# Or from this directory: make <target>

PROJECT_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
ROOT_DIR := $(PROJECT_DIR)
SANDBOX = kiro-unpossible # TODO: make agent-agnostic — sandbox name is Kiro-specific
SANDBOX_WORKDIR = 'unpossible'
LOOP := $(ROOT_DIR)loop.sh
ACTIVE_PROJECT_FILE := $(ROOT_DIR)ACTIVE_PROJECT
ENV_FILE := $(ROOT_DIR).env
AGENT ?= kiro
MODEL ?=
SKILL = @cd $(PROJECT_DIR) && $(AGENT) -- "$(shell cat $(PROJECT_DIR)

.PHONY: help \
        docker-build up down restart logs console shell \
        db-create db-migrate db-setup db-reset \
        build plan build1 research \
        sb-interview sb-review review prd spec server-ops \
        start config status activate test sandbox

COMPOSE := docker compose -f $(PROJECT_DIR)infra/docker-compose.yml
COMPOSE_TEST := docker compose -f $(PROJECT_DIR)infra/docker-compose.test.yml

help:
	@echo "Config & runner:"
	@echo "  make status          Show active project, agent, model, env"
	@echo "  make activate        Set this project as ACTIVE_PROJECT"
	@echo "  make config          Show runner config (agent, model, env vars)"
	@echo "  make config AGENT=claude MODEL=opus   Set agent and model for this session"
	@echo "  make test            Run test suite via docker compose"
	@echo "  make sandbox         Launch Kiro CLI in a Docker sandbox"
	@echo ""
	@echo "Rails server:"
	@echo "  make up              Start rails + postgres (detached)"
	@echo "  make down            Stop all services"
	@echo "  make restart         Restart rails service"
	@echo "  make logs            Tail rails logs"
	@echo "  make activity        Show git log with activity notes"
	@echo "  make console         Open rails console"
	@echo "  make db-create       Create database"
	@echo "  make db-migrate      Run pending migrations"
	@echo "  make db-setup        Create + migrate + seed"
	@echo "  make db-reset        Drop + create + migrate + seed"
	@echo "  make docker-build    Build the rails image"
	@echo "  make shell           Open bash in rails container"
	@echo ""
	@echo "Workflow:"
	@echo "  make start           Orient, research if needed, gap-fill spec, plan (1 iteration)"
	@echo ""
	@echo "Loop commands:"
	@echo "  make build           Build loop, unlimited iterations"
	@echo "  make plan            Plan loop, unlimited iterations"
	@echo "  make build1          Build loop, 1 iteration"
	@echo "  make research ID=<n> Research loop, then re-plan to integrate findings"
	@echo "                       (omit ID to research all pending spikes)"
	@echo "  make review          Review loop, 1 iteration (analyse codebase, propose beats)"
	@echo ""
	@echo "Sandbox commands:"
	@echo "  make sb-interview    Interactive interview in sandbox (persistent context)"
	@echo "  make sb-review       Interactive code review in sandbox (discuss changes, decide direction)"
	@echo ""
	@echo "Skills:"
	@echo "  make prd             Produce or update a PRD"
	@echo "  make spec            Produce or update spec files for a PRD"
	@echo "  make server-ops      Operate on a server"

# --- Config & runner ---
status:
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "Project:  unpossible"
	@printf "Active:   "; if [ -f "$(ACTIVE_PROJECT_FILE)" ] && [ "$$(cat '$(ACTIVE_PROJECT_FILE)' | tr -d '[:space:]')" = "unpossible" ]; then echo "yes ✓"; else echo "no (active: $$(cat '$(ACTIVE_PROJECT_FILE)' 2>/dev/null || echo 'unset'))"; fi
	@echo "Agent:    $(AGENT)"
	@echo "Model:    $(or $(MODEL),(agent default))"
	@echo "Loop:     $(LOOP)"
	@echo "Compose:  $(COMPOSE)"
	@printf "Docker:   "; docker info --format '{{.ServerVersion}}' 2>/dev/null || echo "not running"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

activate:
	@echo "unpossible" > "$(ACTIVE_PROJECT_FILE)"
	@echo "ACTIVE_PROJECT set to unpossible"

config:
	@echo "━━━ Runner Config ━━━"
	@echo "AGENT=$(AGENT)"
	@echo "MODEL=$(or $(MODEL),(agent default))"
	@echo ""
	@echo "━━━ Environment (.env) ━━━"
	@if [ -f "$(ENV_FILE)" ]; then grep -v '^#' "$(ENV_FILE)" | grep -v '^$$' | sed 's/=.*/=***/' ; else echo ".env not found — copy .env.example"; fi
	@echo ""
	@echo "Override per-command:  make build AGENT=claude MODEL=opus"
	@echo "Override for session:  export AGENT=claude MODEL=opus"

test:
	$(COMPOSE_TEST) build
	$(COMPOSE_TEST) run --rm test

# TODO: make agent-agnostic — `docker sandbox run kiro` is Kiro-specific
sandbox:
	docker sandbox run kiro

# --- Rails server ---
docker-build:
	$(COMPOSE) build rails

up:
	$(COMPOSE) up -d --build

down:
	$(COMPOSE) down

restart:
	$(COMPOSE) restart rails

logs:
	$(COMPOSE) logs -f rails

activity:
	@git log --notes --format='%C(yellow)%h %C(cyan)%ai %C(reset)%s%n%N' | head -100

console:
	$(COMPOSE) exec rails bundle exec rails console

shell:
	$(COMPOSE) exec rails bash

db-create:
	$(COMPOSE) exec rails bundle exec rails db:create

db-migrate:
	$(COMPOSE) exec rails bundle exec rails db:migrate

db-setup:
	$(COMPOSE) exec rails bundle exec rails db:setup

db-reset:
	$(COMPOSE) exec rails bundle exec rails db:reset

# --- Workflow ---

# Start a feature: orient the agent, check for prior research, gap-fill the spec,
# then run one plan iteration so you can review the beats before committing to a full run.
start:
	@echo "==> Reading orientation files..."
	@cat $(PROJECT_DIR)specs/README.md
	@cat $(PROJECT_DIR)AGENTS.md
	@echo ""
	@echo "==> Checking for prior research and gap-filling spec..."
	@cd $(PROJECT_DIR) && $(AGENT) -- "$(shell cat $(PROJECT_DIR)specs/skills/tools/research.md)\n\n$(shell cat $(PROJECT_DIR)specs/skills/workflows/spec.md)"
	@echo ""
	@echo "==> Running plan (1 iteration) — review beats before running make plan or make build..."
	@cd $(PROJECT_DIR) && $(LOOP) plan 1

# --- Loop targets ---
build:
	@cd $(ROOT_DIR) && AGENT=$(AGENT) MODEL=$(MODEL) $(LOOP)

plan:
	@cd $(ROOT_DIR) && AGENT=$(AGENT) MODEL=$(MODEL) $(LOOP) plan

build1:
	@cd $(ROOT_DIR) && AGENT=$(AGENT) MODEL=$(MODEL) $(LOOP) 1

research:
	@if [ -n "$(ID)" ]; then \
		cd $(ROOT_DIR) && AGENT=$(AGENT) MODEL=$(MODEL) $(LOOP) research $(ID); \
	else \
		SPIKE_IDS=$$(grep -E '^\- \[ \] [0-9].*\[SPIKE\]' $(ROOT_DIR)IMPLEMENTATION_PLAN.md \
			| sed 's/^- \[ \] \([0-9][0-9.]*\).*/\1/'); \
		if [ -z "$$SPIKE_IDS" ]; then \
			echo "No pending spikes found in IMPLEMENTATION_PLAN.md"; exit 0; \
		fi; \
		echo "Pending spikes: $$SPIKE_IDS"; \
		for id in $$SPIKE_IDS; do \
			echo "==> Researching spike $$id..."; \
			cd $(ROOT_DIR) && AGENT=$(AGENT) MODEL=$(MODEL) $(LOOP) research $$id || true; \
		done; \
	fi
	@echo "==> Re-planning to integrate research findings..."
	@cd $(ROOT_DIR) && AGENT=$(AGENT) MODEL=$(MODEL) $(LOOP) plan

review:
	@cd $(ROOT_DIR) && AGENT=$(AGENT) MODEL=$(MODEL) $(LOOP) review

# --- Skill targets ---
prd:
	@cd $(PROJECT_DIR) && $(AGENT) -- "$(shell cat $(PROJECT_DIR)specs/skills/workflows/prd.md)"

spec:
	@cd $(PROJECT_DIR) && $(AGENT) -- "$(shell cat $(PROJECT_DIR)specs/skills/workflows/spec.md)"

server-ops:
	@cd $(PROJECT_DIR) && $(AGENT) -- "$(shell cat $(PROJECT_DIR)specs/skills/workflows/server-ops.md)"


# --- Sandbox Commands ---
# TODO: make agent-agnostic — sbx and kiro-cli are Kiro-specific
sb-run:
	@sbx run $(SANDBOX)

# TODO: make agent-agnostic — kiro-cli chat --agent is Kiro-specific
sb-interview:
	@sbx run $(SANDBOX) -- kiro-cli chat --agent interview

# TODO: make agent-agnostic — kiro-cli chat --agent is Kiro-specific
sb-review:
	@sbx run $(SANDBOX) -- kiro-cli chat --agent review
