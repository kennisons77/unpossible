# Makefile — Unpossible 2
# Skills and loop commands for the unpossible2 project.
# Run from the monorepo root: make -f projects/unpossible2/Makefile <target>
# Or from this directory: make <target>

PROJECT_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
LOOP := $(PROJECT_DIR)../../loop.sh
AGENT ?= kiro
SKILL = @cd $(PROJECT_DIR) && $(AGENT) -- "$(shell cat $(PROJECT_DIR)

.PHONY: help \
        docker-build up down restart logs console shell \
        db-create db-migrate db-setup db-reset \
        build plan build1 plan1 reflect research \
        interview prd spec review server-ops \
        start

COMPOSE := docker compose -f $(PROJECT_DIR)infra/docker-compose.yml

help:
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

# --- Rails server ---
docker-build:
	$(COMPOSE) build rails

up:
	$(COMPOSE) up -d

down:
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
	@cd $(PROJECT_DIR) && $(LOOP)

plan:
	@cd $(PROJECT_DIR) && $(LOOP) plan

build1:
	@cd $(PROJECT_DIR) && $(LOOP) 1

plan1:
	@cd $(PROJECT_DIR) && $(LOOP) plan 1

reflect:
	@cd $(PROJECT_DIR) && $(LOOP) reflect

research:
	@cd $(PROJECT_DIR) && $(LOOP) research

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

