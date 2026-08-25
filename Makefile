SHELL := /usr/bin/env bash

.PHONY: lint test test-docker

lint:
	@find . -path './.git' -prune -o -type f \( -path './subcommands/*' -o -path './tests/run' -o -path './tests/docker-run' -o -name commands -o -name common-functions -o -name config -o -name fdb-entrypoint -o -name functions -o -name help-functions -o -name install -o -name 'post-*' -o -name 'pre-*' -o -name service-list \) -print0 | xargs -0 -n1 bash -n
	@if command -v shellcheck >/dev/null; then \
		find . -path './.git' -prune -o -type f \( -path './subcommands/*' -o -path './tests/run' -o -path './tests/docker-run' -o -name commands -o -name common-functions -o -name config -o -name fdb-entrypoint -o -name functions -o -name help-functions -o -name install -o -name 'post-*' -o -name 'pre-*' -o -name service-list \) -print0 | xargs -0 shellcheck -x -e SC1090,SC1091; \
	else \
		echo 'shellcheck not installed; skipping'; \
	fi

test: lint
	@tests/run

test-docker: lint
	@tests/docker-run
