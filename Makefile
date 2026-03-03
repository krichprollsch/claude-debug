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

CONTAINER_NAME ?= wdebug

BROWSER_DIR := ../browser-claude
DEMO_DIR := ../demo-claude
WPT_DIR := ../wpt

.PHONY: create
## create the docker container
create:
	docker run -d -ti --name $(CONTAINER_NAME) --user 1001:1001 \
		--volume './tools:/debug/tools:ro'  \
		--volume './notes:/debug/notes'  \
		--volume './CLAUDE.md:/debug/CLAUDE.md'  \
		--volume './output:/debug/output'  \
		--volume '$(BROWSER_DIR):/debug/browser' \
		--volume '$(DEMO_DIR):/debug/demo' \
		--volume '$(HOME)/.claude.json:/home/debug/.claude.json' \
		--volume '$(HOME)/.claude:/home/debug/.claude' \
		--add-host not-web-platform.test=127.0.0.1 \
		--add-host www.not-web-platform.test=127.0.0.1 \
		--add-host www.www.not-web-platform.test=127.0.0.1 \
		--add-host www1.www.not-web-platform.test=127.0.0.1 \
		--add-host www2.www.not-web-platform.test=127.0.0.1 \
		--add-host xn--lve-6lad.www.not-web-platform.test=127.0.0.1 \
		--add-host xn--n8j6ds53lwwkrqhv28a.www.not-web-platform.test=127.0.0.1 \
		--add-host www1.not-web-platform.test=127.0.0.1 \
		--add-host www.www1.not-web-platform.test=127.0.0.1 \
		--add-host www1.www1.not-web-platform.test=127.0.0.1 \
		--add-host www2.www1.not-web-platform.test=127.0.0.1 \
		--add-host xn--lve-6lad.www1.not-web-platform.test=127.0.0.1 \
		--add-host xn--n8j6ds53lwwkrqhv28a.www1.not-web-platform.test=127.0.0.1 \
		--add-host www2.not-web-platform.test=127.0.0.1 \
		--add-host www.www2.not-web-platform.test=127.0.0.1 \
		--add-host www1.www2.not-web-platform.test=127.0.0.1 \
		--add-host www2.www2.not-web-platform.test=127.0.0.1 \
		--add-host xn--lve-6lad.www2.not-web-platform.test=127.0.0.1 \
		--add-host xn--n8j6ds53lwwkrqhv28a.www2.not-web-platform.test=127.0.0.1 \
		--add-host xn--lve-6lad.not-web-platform.test=127.0.0.1 \
		--add-host www.xn--lve-6lad.not-web-platform.test=127.0.0.1 \
		--add-host www1.xn--lve-6lad.not-web-platform.test=127.0.0.1 \
		--add-host www2.xn--lve-6lad.not-web-platform.test=127.0.0.1 \
		--add-host xn--lve-6lad.xn--lve-6lad.not-web-platform.test=127.0.0.1 \
		--add-host xn--n8j6ds53lwwkrqhv28a.xn--lve-6lad.not-web-platform.test=127.0.0.1 \
		--add-host xn--n8j6ds53lwwkrqhv28a.not-web-platform.test=127.0.0.1 \
		--add-host www.xn--n8j6ds53lwwkrqhv28a.not-web-platform.test=127.0.0.1 \
		--add-host www1.xn--n8j6ds53lwwkrqhv28a.not-web-platform.test=127.0.0.1 \
		--add-host www2.xn--n8j6ds53lwwkrqhv28a.not-web-platform.test=127.0.0.1 \
		--add-host xn--lve-6lad.xn--n8j6ds53lwwkrqhv28a.not-web-platform.test=127.0.0.1 \
		--add-host xn--n8j6ds53lwwkrqhv28a.xn--n8j6ds53lwwkrqhv28a.not-web-platform.test=127.0.0.1 \
		--add-host web-platform.test=127.0.0.1 \
		--add-host www.web-platform.test=127.0.0.1 \
		--add-host www.www.web-platform.test=127.0.0.1 \
		--add-host www1.www.web-platform.test=127.0.0.1 \
		--add-host www2.www.web-platform.test=127.0.0.1 \
		--add-host xn--lve-6lad.www.web-platform.test=127.0.0.1 \
		--add-host xn--n8j6ds53lwwkrqhv28a.www.web-platform.test=127.0.0.1 \
		--add-host www1.web-platform.test=127.0.0.1 \
		--add-host www.www1.web-platform.test=127.0.0.1 \
		--add-host www1.www1.web-platform.test=127.0.0.1 \
		--add-host www2.www1.web-platform.test=127.0.0.1 \
		--add-host xn--lve-6lad.www1.web-platform.test=127.0.0.1 \
		--add-host xn--n8j6ds53lwwkrqhv28a.www1.web-platform.test=127.0.0.1 \
		--add-host www2.web-platform.test=127.0.0.1 \
		--add-host www.www2.web-platform.test=127.0.0.1 \
		--add-host www1.www2.web-platform.test=127.0.0.1 \
		--add-host www2.www2.web-platform.test=127.0.0.1 \
		--add-host xn--lve-6lad.www2.web-platform.test=127.0.0.1 \
		--add-host xn--n8j6ds53lwwkrqhv28a.www2.web-platform.test=127.0.0.1 \
		--add-host xn--lve-6lad.web-platform.test=127.0.0.1 \
		--add-host www.xn--lve-6lad.web-platform.test=127.0.0.1 \
		--add-host www1.xn--lve-6lad.web-platform.test=127.0.0.1 \
		--add-host www2.xn--lve-6lad.web-platform.test=127.0.0.1 \
		--add-host xn--lve-6lad.xn--lve-6lad.web-platform.test=127.0.0.1 \
		--add-host xn--n8j6ds53lwwkrqhv28a.xn--lve-6lad.web-platform.test=127.0.0.1 \
		--add-host xn--n8j6ds53lwwkrqhv28a.web-platform.test=127.0.0.1 \
		--add-host www.xn--n8j6ds53lwwkrqhv28a.web-platform.test=127.0.0.1 \
		--add-host www1.xn--n8j6ds53lwwkrqhv28a.web-platform.test=127.0.0.1 \
		--add-host www2.xn--n8j6ds53lwwkrqhv28a.web-platform.test=127.0.0.1 \
		--add-host xn--lve-6lad.xn--n8j6ds53lwwkrqhv28a.web-platform.test=127.0.0.1 \
		--add-host xn--n8j6ds53lwwkrqhv28a.xn--n8j6ds53lwwkrqhv28a.web-platform.test=127.0.0.1 \
		 wdebug:latest

.PHONY: delete
## delete the docker container
delete:
	docker rm $(CONTAINER_NAME)

.PHONY: run
## run the container
run:
	docker start -i $(CONTAINER_NAME)
