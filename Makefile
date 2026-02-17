.PHONY: help
help:
	@printf "\e[36m%-35s %s\e[0m\n" "Command" "Usage"
	@sed -n -e '/^## /{'\
		-e 's/## //g;'\
		-e 'h;'\
		-e 'n;'\
		-e 's/:.*//g;'\
		-e 'G;'\
		-e 's/\n/ /g;'\
		-e 'p;}' Makefile | awk '{printf "\033[33m%-35s\033[0m%s\n", $$1, substr($$0,length($$1)+1)}'

.PHONY: build
## build docker image
build:
	docker build --build-arg UID=$(shell id -u) --build-arg GID=$(shell id -g) -t wdebug:latest .

BROWSER_DIR := ../browser-claude

.PHONY: create
## create the docker container
create:
	docker run -d -ti --name wdebug --user 1001:1001 \
		--volume './tools:/debug/tools:ro'  \
		--volume './notes:/debug/notes'  \
		--volume './CLAUDE.md:/debug/CLAUDE.md'  \
		--volume './output:/debug/output'  \
		--volume '$(BROWSER_DIR):/debug/browser' \
		--volume '$(HOME)/.claude.json:/home/debug/.claude.json' \
		--volume '$(HOME)/.claude:/home/debug/.claude' \
		 wdebug:latest

.PHONY: delete
## delete the docker container
delete:
	docker rm wdebug

.PHONY: run
## run the container
run:
	docker start -i wdebug
