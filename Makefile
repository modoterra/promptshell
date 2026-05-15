BATS := node_modules/bats/bin/bats

.PHONY: deps syntax test install-smoke

deps:
	npm install

syntax:
	sh -n bin/psh.sh
	bash -n tests/helpers/psh.bash

test: syntax
	@test -x "$(BATS)" || { printf '%s\n' 'missing Bats runner; run `npm install`' >&2; exit 2; }
	@command -v setsid >/dev/null 2>&1 || { printf '%s\n' 'setsid is required for tests' >&2; exit 2; }
	@command -v script >/dev/null 2>&1 || { printf '%s\n' 'script is required for tests' >&2; exit 2; }
	$(BATS) tests

install-smoke:
	install_dir=$$(mktemp -d) && PSH_INSTALL_DIR=$$install_dir sh bin/psh.sh install && test -x "$$install_dir/psh" && PSH_INSTALL_DIR=$$install_dir "$$install_dir/psh" uninstall && test ! -e "$$install_dir/psh"
