# AGENTS.md

## Project Intent
- `psh` means Prompt Shell: a small Unix/POSIX-style inline CLI tool.
- CLI shape should be Cobra-style subcommands; first command is `psh run`.
- `psh run` eagerly treats all remaining argv as the prompt, e.g. `psh run clean up docker`.
- `psh run` reads stdin when no prompt args are supplied, e.g. `echo "clean up docker" | psh run`.
- If argv does not match a known command, treat all argv as an implicit `run` prompt, e.g. `psh clean up docker`.
- The tool should return the shell command to run, then require user approval before execution.
- Preserve normal CLI behavior expectations: stdin/stdout composition, scriptability, and minimal surprise for shell users.

## Current Repo State
- Current entrypoint is `bin/psh.sh`.
- This repo currently has no manifests, tests, build config, or lockfiles.
- Do not invent build/test/lint commands until the relevant executable config exists.
- When adding the first implementation, also add the exact verification commands here.

## Verification
- Syntax check: `sh -n bin/psh.sh`.
- Runtime dependency check: `command -v gum && command -v curl && command -v jq`.
- Dependency check without API key or config: `XDG_CONFIG_HOME=$(mktemp -d) bin/psh.sh run clean up docker` exits 2 with `psh: API key is required; run \`psh setup\` or set provider API key env var`.
- Smoke checks with OpenAI access: `OPENAI_API_KEY=... bin/psh.sh run clean up docker`, `OPENAI_API_KEY=... bin/psh.sh clean up docker`, and `printf %s "clean up docker" | OPENAI_API_KEY=... bin/psh.sh run` verify prompt ingestion and command generation.
- Smoke check with Fireworks access: `PSH_PROVIDER=fireworks FIREWORKS_API_KEY=... bin/psh.sh run clean up docker` verifies Fireworks command generation.
- Smoke check with Codex access: `PSH_PROVIDER=codex bin/psh.sh run clean up docker` verifies local Codex command generation when `codex` is installed.

## Agent skills

### Issue tracker

Issues and PRDs are tracked in GitHub Issues using the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

The repo uses the default five-label triage vocabulary. See `docs/agents/triage-labels.md`.

### Domain docs

This repo uses a single-context domain docs layout. See `docs/agents/domain.md`.
