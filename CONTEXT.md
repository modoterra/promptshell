# Context

## Glossary

- **Prompt Shell**: The `psh` CLI. It translates a natural-language shell task into a generated shell command, shows that command, and requires approval before interactive execution.
- **Prompt**: The natural-language shell task supplied through argv or stdin.
- **Run**: The `psh run` flow, including explicit `run`, implicit `run`, prompt intake, command generation, command display, approval, and execution.
- **Provider**: A model-backed command generator such as OpenAI, Fireworks, or Codex.
- **Generated command**: The shell command returned from a provider result. In non-interactive mode this is the only successful stdout output.
- **Model result**: The structured provider result after raw model content is normalized into a command, clarification question, or invalid result.
- **Command risk**: Provider-supplied advisory metadata for a generated command. Valid values are `safe`, `needs_approval`, and `destructive`; unknown values normalize to `needs_approval`.
- **Command explanation**: Provider-supplied advisory text shown with elevated-risk commands in interactive mode. It must not appear in successful non-interactive stdout.
- **AI review notice**: The interactive reminder that a generated command came from AI and must be reviewed before running.
- **Think content**: Model reasoning text from `<think>` blocks. It may be shown in debug-oriented interactive output, but must not contaminate the generated command output.
- **Think panel**: The styled interactive panel used to display think content during verbose output. It is separated from adjacent terminal segments by one blank line.
- **Clarification**: A provider result that asks the user for more information before a generated command can be produced. Clarification may offer choices or fall back to freeform input.
- **Approval**: The explicit user decision to run a generated command. Declining approval exits non-zero and must not execute the command.
- **Interactive mode**: A controlling `/dev/tty` is available. A prompt may still come from piped stdin while approval and other terminal segments use `/dev/tty`.
- **Non-interactive mode**: No controlling `/dev/tty` is available. `psh` generates and prints the generated command only; it does not execute.
- **ANSI terminal UI**: Prompt Shell's direct terminal interaction in interactive mode. It uses ANSI styling and POSIX terminal input for setup, model choice, clarification, command display, and approval without an external terminal UI dependency.
