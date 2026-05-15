# Contributing

Prompt Shell is a small POSIX-style CLI. Contributions are welcome.

## Getting Started

```sh
git clone https://github.com/modoterra/promptshell.git
cd promptshell
npm install
```

Run locally without installing:

```sh
bin/psh.sh --help
```

## Running Tests

```sh
make test
```

The test suite uses the npm-installed Bats runner at `node_modules/bats/bin/bats`.

Run the installer smoke check:

```sh
make install-smoke
```

## Code Style

- POSIX shell for the CLI, including integrated install/uninstall commands.
- Keep changes small and focused.
- Preserve stdin/stdout composition and scriptability.
- Use `/dev/tty` for interactive-only UI.
- Do not add build or lint commands unless the required config exists.

## Commit Messages

Use Conventional Commits, for example `feat:`, `fix:`, `docs:`, `test:`, or `chore:`.

## Pull Requests

- One concern per PR.
- Tests must pass.
- Keep the diff small.
- Include screenshots or terminal output for interactive UI changes when useful.

## Reporting Bugs

Open an issue: https://github.com/modoterra/promptshell/issues
