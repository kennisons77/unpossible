# Makefile — Unpossible 2
# Skills and loop commands for the unpossible2 project.
# Run from the monorepo root: make -f projects/unpossible2/Makefile <target>
# Or from this directory: make <target>

PROJECT_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
ROOT_DIR := $(PROJECT_DIR)../../
LOOP := $(ROOT_DIR)loop.sh
ACTIVE_PROJECT_FILE := $(ROOT_DIR)ACTIVE_PROJECT
ENV_FILE := $(ROOT_DIR).env
AGENT ?= kiro
MODEL ?=
SKILL = @cd $(PROJECT_DIR) && $(AGENT) -- "$(shell cat $(PROJECT_DIR)

.PHONY: help \
        docker-build up down restart logs console shell \
        db-create db-migrate db-setup db-reset \
        build plan build1 plan1 reflect research \
        interview prd spec review server-ops \
        start config status activate test

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
	@echo "  make console         Open rails console"
	@echo "  make db-create       Create database"
	@echo "  make db-migrate      Run pending migrations"
	@echo "  make db-setup        Create + migrate + seed"
	@echo "  make db-reset        Drop + create + migrate + seed"
	@echo "  make docker-build    Build the rails image"
	@echo "  make shell           Open bash in rails container"
	@echo "  make ledger-export   Export ledger state to ledger/snapshot.yml"
	@echo "  make ledger-import   Import ledger state from snapshot (empty DB only)"
	@echo "  make bulk-export     Export agent runs + knowledge to .data/snapshots/ (not in git)"
	@echo "  make bulk-import     Import agent runs + knowledge from .data/snapshots/"
	@echo ""
	@echo "Workflow:"
	@echo "  make start           Orient, research if needed, gap-fill spec, plan (1 iteration)"
	@echo ""
	@echo "Loop commands:"
	@echo "  make build           Build loop, unlimited iterations"
	@echo "  make plan            Plan loop, unlimited iterations"
	@echo "  make build1          Build loop, 1 iteration"
	@echo "  make plan1           Plan loop, 1 iteration"
	@echo "  make reflect         Reflect loop"
	@echo "  make research        Research loop (./loop.sh research <id>)"
	@echo ""
	@echo "Skills:"
	@echo "  make interview       Reach shared understanding before committing"
	@echo "  make prd             Produce or update a PRD"
	@echo "  make spec            Produce or update spec files for a PRD"
	@echo "  make review          Analyse codebase, propose beats"
	@echo "  make server-ops      Operate on a server"

# --- Config & runner ---
status:
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "Project:  unpossible2"
	@printf "Active:   "; if [ -f "$(ACTIVE_PROJECT_FILE)" ] && [ "$$(cat '$(ACTIVE_PROJECT_FILE)' | tr -d '[:space:]')" = "unpossible2" ]; then echo "yes ✓"; else echo "no (active: $$(cat '$(ACTIVE_PROJECT_FILE)' 2>/dev/null || echo 'unset'))"; fi
	@echo "Agent:    $(AGENT)"
	@echo "Model:    $(or $(MODEL),(agent default))"
	@echo "Loop:     $(LOOP)"
	@echo "Compose:  $(COMPOSE)"
	@printf "Docker:   "; docker info --format '{{.ServerVersion}}' 2>/dev/null || echo "not running"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

activate:
	@echo "unpossible2" > "$(ACTIVE_PROJECT_FILE)"
	@echo "ACTIVE_PROJECT set to unpossible2"

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

sandbox:
	docker sandbox run kiro

# --- Rails server ---
docker-build:
	$(COMPOSE) build rails

up:
	$(COMPOSE) up -d

down:
	@$(COMPOSE) exec rails bundle exec rails ledger:export bulk:export 2>/dev/null || echo "Snapshot skipped (container not running)"
	$(COMPOSE) down

restart:
	$(COMPOSE) restart rails

logs:
	$(COMPOSE) logs -f rails

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

# --- Ledger persistence ---
ledger-export:
	$(COMPOSE) exec rails bundle exec rails ledger:export

ledger-import:
	$(COMPOSE) exec rails bundle exec rails ledger:import

bulk-export:
	$(COMPOSE) exec rails bundle exec rails bulk:export

bulk-import:
	$(COMPOSE) exec rails bundle exec rails bulk:import

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

plan1:
	@cd $(ROOT_DIR) && AGENT=$(AGENT) MODEL=$(MODEL) $(LOOP) plan 1

reflect:
	@cd $(ROOT_DIR) && AGENT=$(AGENT) MODEL=$(MODEL) $(LOOP) reflects

research:
	@cd $(ROOT_DIR) && AGENT=$(AGENT) MODEL=$(MODEL) $(LOOP) research

# --- Skill targets ---
interview:
	@cd $(PROJECT_DIR) && $(AGENT) -- "$(shell cat $(PROJECT_DIR)specs/skills/tools/interview.md)"

prd:
	@cd $(PROJECT_DIR) && $(AGENT) -- "$(shell cat $(PROJECT_DIR)specs/skills/workflows/prd.md)"

spec:
	@cd $(PROJECT_DIR) && $(AGENT) -- "$(shell cat $(PROJECT_DIR)specs/skills/workflows/spec.md)"

review:
	@cd $(PROJECT_DIR) && $(AGENT) -- "$(shell cat $(PROJECT_DIR)specs/skills/workflows/review.md)"

server-ops:
	@cd $(PROJECT_DIR) && $(AGENT) -- "$(shell cat $(PROJECT_DIR)specs/skills/workflows/server-ops.md)"
