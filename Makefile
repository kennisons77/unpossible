# Makefile — Unpossible 2
# Skills and loop commands for the unpossible2 project.
# Run from the monorepo root: make -f projects/unpossible2/Makefile <target>
# Or from this directory: make <target>

PROJECT_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
LOOP := $(PROJECT_DIR)../../loop.sh
AGENT ?= kiro

.PHONY: help \
        build plan build1 plan1 reflect research \
        grill-me write-a-prd prd-to-tasks tdd improve-codebase-architecture

help:
	@echo "Loop commands:"
	@echo "  make build           Build loop, unlimited iterations"
	@echo "  make plan            Plan loop, unlimited iterations"
	@echo "  make build1          Build loop, 1 iteration"
	@echo "  make plan1           Plan loop, 1 iteration"
	@echo "  make reflect         Reflect loop"
	@echo "  make research        Research loop"
	@echo ""
	@echo "Skills (interactive — run with agent, no loop):"
	@echo "  make grill-me                      Relentless design interview before committing to code"
	@echo "  make write-a-prd                   Turn a grilled idea into a spec file"
	@echo "  make prd-to-tasks                  Break a PRD into vertical-slice tasks"
	@echo "  make tdd                           Red-green-refactor build loop"
	@echo "  make improve-codebase-architecture Find shallow modules, propose deepening candidates"

# Loop targets
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

# Skill targets — load the skill file and invoke the agent
grill-me:
	@cd $(PROJECT_DIR) && $(AGENT) --print "$(shell cat $(PROJECT_DIR)specs/skills/grill-me.md)"

write-a-prd:
	@cd $(PROJECT_DIR) && $(AGENT) --print "$(shell cat $(PROJECT_DIR)specs/skills/write-a-prd.md)"

prd-to-tasks:
	@cd $(PROJECT_DIR) && $(AGENT) --print "$(shell cat $(PROJECT_DIR)specs/skills/prd-to-tasks.md)"

tdd:
	@cd $(PROJECT_DIR) && $(AGENT) --print "$(shell cat $(PROJECT_DIR)specs/skills/tdd.md)"

improve-codebase-architecture:
	@cd $(PROJECT_DIR) && $(AGENT) --print "$(shell cat $(PROJECT_DIR)specs/skills/improve-codebase-architecture.md)"
