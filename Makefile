.PHONY: build plan build1 plan1 help

# Default target
help:
	@echo "Usage:"
	@echo "  make build           Build mode, unlimited iterations"
	@echo "  make plan            Plan mode, unlimited iterations"
	@echo "  make build N=20      Build mode, max N iterations"
	@echo "  make plan N=5        Plan mode, max N iterations"
	@echo "  make build1          Build mode, exactly 1 iteration"
	@echo "  make plan1           Plan mode, exactly 1 iteration"

build:
	@./loop.sh $(if $(N),$(N),)

plan:
	@./loop.sh plan $(N)

build1:
	@./loop.sh 1

plan1:
	@./loop.sh plan 1
