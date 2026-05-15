BATS := node_modules/bats/bin/bats

.PHONY: deps syntax test install-smoke

deps:
	npm install

syntax:
	sh -n bin/psh.sh
	sh -n install.sh
	bash -n tests/helpers/psh.bash

test: syntax
	@test -x "$(BATS)" || { printf '%s\n' 'missing Bats runner; run `npm install`' >&2; exit 2; }
	@command -v setsid >/dev/null 2>&1 || { printf '%s\n' 'setsid is required for tests' >&2; exit 2; }
	@command -v script >/dev/null 2>&1 || { printf '%s\n' 'script is required for tests' >&2; exit 2; }
	$(BATS) tests

install-smoke:
	PSH_INSTALL_DIR=$$(mktemp -d) sh install.sh
