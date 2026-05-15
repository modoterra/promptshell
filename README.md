# Prompt Shell

`psh` turns a natural-language shell task into one shell command, shows it for review, and asks before running it.

```sh
psh run clean up docker
psh clean up docker
printf %s "clean up docker" | psh run
```

## Install

Install with curl:

```sh
curl -fsSL https://raw.githubusercontent.com/modoterra/promptshell/main/bin/psh.sh | sh -s -- install
```

The `-s` flag tells `sh` to read the downloaded script from stdin and pass `install` to `psh`.

Or with wget:

```sh
wget -qO- https://raw.githubusercontent.com/modoterra/promptshell/main/bin/psh.sh | sh -s -- install
```

By default, the installer writes `psh` to `$HOME/.local/bin`. Override the destination with `PSH_INSTALL_DIR`:

```sh
curl -fsSL https://raw.githubusercontent.com/modoterra/promptshell/main/bin/psh.sh | PSH_INSTALL_DIR=/usr/local/bin sh -s -- install
```

Uninstall the installed `psh` binary:

```sh
psh uninstall
```

## Requirements

- `jq` is required.
- `curl` is required for hosted providers.
- `dd` and `stty` are required for interactive approval.
- `codex` is required only when using `PSH_PROVIDER=codex`.

## Setup

Run the interactive setup flow. It asks for a provider and model, including Codex models when `codex` is installed:

```sh
psh setup
```

Change only the configured model later:

```sh
psh setup model
```

You can also configure providers with environment variables:

```sh
OPENAI_API_KEY=... psh run list large files
PSH_PROVIDER=fireworks FIREWORKS_API_KEY=... psh run list large files
PSH_PROVIDER=codex psh run list large files
PSH_PROVIDER=codex CODEX_MODEL=gpt-5.4 psh run list large files
```

Provider/model environment variables:

- `PSH_PROVIDER`: `openai`, `fireworks`, or `codex`.
- `OPENAI_API_KEY`, `OPENAI_MODEL` for OpenAI.
- `FIREWORKS_API_KEY`, `FIREWORKS_MODEL` for Fireworks.
- `CODEX_MODEL` for Codex. The model is passed to `codex exec` with `-m`.
- `PSH_API_KEY`, `PSH_MODEL` as provider-agnostic fallbacks.

## Usage

Use explicit `run`:

```sh
psh run show ports listening on this machine
```

Or omit `run`; unknown commands are treated as a prompt:

```sh
psh show ports listening on this machine
```

Pipe a prompt through stdin:

```sh
printf %s "show ports listening on this machine" | psh run
```

In an interactive terminal, `psh` previews the generated command and asks for approval. Press `y` to run it. Press Enter, Esc, `n`, or anything else to cancel.

Without a controlling terminal, `psh` prints only the generated command to stdout and does not execute it. This keeps the CLI scriptable:

```sh
command=$(printf %s "show ports listening on this machine" | psh run)
printf '%s\n' "$command"
```

## Safety

Model output is treated as a proposal, not an instruction. Interactive runs show an AI review notice before approval, and higher-risk model results include risk and explanation metadata.

`psh` always requires interactive approval before execution. Non-interactive runs never execute generated commands.

## Development

Install test dependencies:

```sh
npm install
```

Run syntax checks and the Bats integration suite:

```sh
make test
```

Run the local installer smoke check:

```sh
make install-smoke
```

## Community

- Read `CONTRIBUTING.md` before opening a pull request.
- Use GitHub Issues for bugs and feature requests.
- Report security vulnerabilities privately; see `SECURITY.md`.

## License

Prompt Shell is released under the MIT License. See `LICENSE`.
