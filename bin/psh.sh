#!/bin/sh

set -eu

verbosity=0

usage() {
  printf 'usage: psh [-v|-vv|-vvv] run PROMPT...\n'
  printf '       printf %%s "PROMPT" | psh [-v|-vv|-vvv] run\n'
  printf '       psh [-v|-vv|-vvv] setup\n'
  printf '       psh [-v|-vv|-vvv] setup model\n'
}

config_file() {
  printf '%s/psh/config.json\n' "${XDG_CONFIG_HOME:-$HOME/.config}"
}

require_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    printf 'psh: jq is required\n' >&2
    exit 2
  fi
}

require_gum() {
  if ! command -v gum >/dev/null 2>&1; then
    printf 'psh: gum is required\n' >&2
    exit 2
  fi
}

spinner_title() {
  seed=$(date +%s 2>/dev/null || printf 0)
  index=$(((seed + $$) % 12))

  case $index in
    0) printf 'Thinking...' ;;
    1) printf 'Pondering...' ;;
    2) printf 'Reasoning...' ;;
    3) printf 'Translating...' ;;
    4) printf 'Composing...' ;;
    5) printf 'Distilling...' ;;
    6) printf 'Weighing...' ;;
    7) printf 'Shaping...' ;;
    8) printf 'Resolving...' ;;
    9) printf 'Drafting...' ;;
    10) printf 'Inspecting...' ;;
    *) printf 'Summoning...' ;;
  esac
}

gum_spin() {
  title=$1
  shift

  gum spin \
    --title "$title" \
    -s dot \
    --padding '1 0 0 1' \
    --spinner.foreground 212 \
    --title.foreground 252 \
    -- "$@"
}

debug_enabled() {
  [ "$verbosity" -ge "$1" ]
}

debug_log() {
  level=$1
  shift

  if debug_enabled "$level"; then
    if have_tty && command -v gum >/dev/null 2>&1; then
      gum log --level debug --prefix psh "$*" >&2
    else
      printf 'psh debug: %s\n' "$*" >&2
    fi
  fi
}

debug_panel() {
  level=$1
  title=$2
  value=$3

  if debug_enabled "$level"; then

    if have_tty && command -v gum >/dev/null 2>&1; then
      gum log --level debug --prefix psh "$title" >&2
      printf '%s\n' "$value" | gum style \
        --background 235 \
        --foreground 252 \
        --padding '1 2' \
        --margin '0 0 1 0' \
        --width 100 >&2
    else
      printf '\npsh debug: %s\n' "$title" >&2
      printf '%s\n' "$value" | while IFS= read -r line; do
        printf '  %s\n' "$line" >&2
      done
    fi
  fi
}

debug_json_panel() {
  level=$1
  title=$2
  value=$3

  if debug_enabled "$level"; then
    formatted=$(printf '%s\n' "$value" | jq . 2>/dev/null || printf '<invalid json>')

    debug_panel "$level" "$title" "$formatted"
  fi
}

debug_json_file_panel() {
  level=$1
  title=$2
  file=$3

  if debug_enabled "$level"; then
    formatted=$(jq . "$file" 2>/dev/null || printf '<invalid json>')

    debug_panel "$level" "$title" "$formatted"
  fi
}

debug_model_content() {
  level=$1
  content=$2

  if debug_enabled "$level"; then
    think=$(printf '%s\n' "$content" | jq -Rrs -r 'capture("(?s)<think>\\n?(?<think>.*?)\\n?</think>")?.think // empty')
    without_think=$(printf '%s\n' "$content" | jq -Rrs -r 'gsub("(?s)<think>.*?</think>"; "") | sub("^\\s+"; "") | sub("\\s+$"; "")')

    if [ -n "$think" ]; then
      debug_log 1 'model returned a think block'
      debug_panel "$level" '<think>' "$think"
    fi

    if [ -n "$without_think" ]; then
      debug_panel "$level" 'Model content' "$without_think"
    fi
  fi
}

debug_messages() {
  request=$1

  if debug_enabled 2; then
    printf '%s\n' "$request" | jq -r '.messages[] | @base64' | while IFS= read -r encoded; do
      role=$(printf '%s\n' "$encoded" | jq -rR '@base64d | fromjson | .role')
      message=$(printf '%s\n' "$encoded" | jq -rR '@base64d | fromjson | .content')

      if have_tty && command -v gum >/dev/null 2>&1; then
        gum log --level debug --prefix psh "message role=$role" >&2
        gum join --vertical \
          "role $role" \
          "message $message" | gum style \
            --background 235 \
            --foreground 252 \
            --padding '1 2' \
            --margin '0 0 1 0' \
            --width 100 >&2
      else
        printf '\npsh debug: message\n' >&2
        printf '  role %s\n' "$role" >&2
        printf '%s\n' "$message" | while IFS= read -r line; do
          printf '  message %s\n' "$line" >&2
        done
      fi
    done
  fi
}

log_info() {
  message=$1

  if have_tty && command -v gum >/dev/null 2>&1; then
    gum log --level info --prefix psh "$message"
  else
    printf 'psh: %s\n' "$message"
  fi
}

log_error() {
  message=$1

  if have_tty && command -v gum >/dev/null 2>&1; then
    gum log --level error --prefix psh "$message" >&2
  else
    printf 'psh: %s\n' "$message" >&2
  fi
}

display_command() {
  command_text=$1

  if have_tty; then
    require_gum
    gum style \
      --background 235 \
      --foreground 252 \
      --padding '1 2' \
      --margin '1 0 1 1' \
      "$command_text"
  else
    printf '%s\n' "$command_text"
  fi
}

have_tty() {
  : 2>/dev/null </dev/tty
}

config_value() {
  file=$(config_file)
  key=$1

  if [ -f "$file" ]; then
    jq -r --arg key "$key" '.[$key] // empty' "$file"
  fi
}

prompt_value() {
  label=$1
  default=${2:-}

  gum input --placeholder "$label" --value "$default"
}

prompt_secret() {
  label=$1

  gum input --password --placeholder "$label"
}

prompt_model() {
  provider=$1
  default=$2

  case $provider in
    openai)
      model_choice=$(gum choose --selected "$default" --header 'Model' \
        gpt-4.1-mini \
        gpt-4.1 \
        gpt-4o-mini \
        gpt-4o \
        o4-mini \
        Custom)

      if [ "$model_choice" = Custom ]; then
        prompt_value 'Model' "$default"
      else
        printf '%s\n' "$model_choice"
      fi
      ;;
    fireworks)
      model_choice=$(gum choose --selected "$default" --header 'Model' \
        accounts/fireworks/models/deepseek-v3p1 \
        accounts/fireworks/models/deepseek-r1 \
        accounts/fireworks/models/llama-v3p1-405b-instruct \
        accounts/fireworks/models/llama-v3p1-70b-instruct \
        accounts/fireworks/models/qwen2p5-coder-32b-instruct \
        Custom)

      if [ "$model_choice" = Custom ]; then
        prompt_value 'Model' "$default"
      else
        printf '%s\n' "$model_choice"
      fi
      ;;
    codex)
      printf '%s\n' codex
      ;;
    *)
      prompt_value 'Model' "$default"
      ;;
  esac

}

setup() {
  require_jq
  require_gum

  if ! have_tty; then
    printf 'psh: setup requires an interactive terminal\n' >&2
    exit 2
  fi

  existing_provider=$(config_value provider)
  existing_model=$(config_value model)
  existing_api_key=$(config_value api_key)

  case $existing_provider in
    openai)
      provider_default=OpenAI
      ;;
    fireworks)
      provider_default=Fireworks
      ;;
    codex)
      provider_default=Codex
      ;;
    *)
      provider_default=OpenAI
      ;;
  esac

  if command -v codex >/dev/null 2>&1; then
    provider_choice=$(gum choose --selected "$provider_default" --header 'Provider' OpenAI Fireworks Codex)
  else
    provider_choice=$(gum choose --selected "$provider_default" --header 'Provider' OpenAI Fireworks)
  fi

  case $provider_choice in
    1|openai|OpenAI|OPENAI)
      provider=openai
      default_model=gpt-4.1-mini
      ;;
    2|fireworks|Fireworks|FIREWORKS)
      provider=fireworks
      default_model=accounts/fireworks/models/deepseek-v3p1
      ;;
    3|codex|Codex|CODEX)
      provider=codex
      default_model=codex
      ;;
    *)
      printf 'psh: unsupported provider: %s\n' "$provider_choice" >&2
      exit 2
      ;;
  esac

  if [ "$provider" = "$existing_provider" ] && [ -n "$existing_model" ]; then
    default_model=$existing_model
  fi

  model=$(prompt_model "$provider" "$default_model")
  if [ "$provider" = codex ]; then
    api_key=
  elif [ -n "$existing_api_key" ]; then
    api_key=$(prompt_secret 'API key [leave blank to keep existing]')
    api_key=${api_key:-$existing_api_key}
  else
    api_key=$(prompt_secret 'API key')
  fi

  if [ -z "$model" ]; then
    printf 'psh: model is required\n' >&2
    exit 2
  fi

  if [ "$provider" != codex ] && [ -z "$api_key" ]; then
    printf 'psh: API key is required\n' >&2
    exit 2
  fi

  file=$(config_file)
  dir=${file%/*}

  mkdir -p "$dir"
  jq -n \
    --arg provider "$provider" \
    --arg model "$model" \
    --arg api_key "$api_key" \
    '{provider: $provider, model: $model, api_key: $api_key}' >"$file"
  chmod 600 "$file"

  log_info "saved config to $file"
}

setup_model() {
  require_jq
  require_gum

  if ! have_tty; then
    printf 'psh: setup model requires an interactive terminal\n' >&2
    exit 2
  fi

  existing_provider=$(config_value provider)
  existing_model=$(config_value model)
  existing_api_key=$(config_value api_key)

  if [ -z "$existing_provider" ] || { [ "$existing_provider" != codex ] && [ -z "$existing_api_key" ]; }; then
    printf 'psh: run `psh setup` before changing only the model\n' >&2
    exit 2
  fi

  case $existing_provider in
    openai)
      default_model=${existing_model:-gpt-4.1-mini}
      ;;
    fireworks)
      default_model=${existing_model:-accounts/fireworks/models/deepseek-v3p1}
      ;;
    codex)
      default_model=codex
      ;;
    *)
      printf 'psh: unsupported provider in config: %s\n' "$existing_provider" >&2
      exit 2
      ;;
  esac

  model=$(prompt_model "$existing_provider" "$default_model")

  if [ -z "$model" ]; then
    printf 'psh: model is required\n' >&2
    exit 2
  fi

  file=$(config_file)
  dir=${file%/*}

  mkdir -p "$dir"
  jq -n \
    --arg provider "$existing_provider" \
    --arg model "$model" \
    --arg api_key "$existing_api_key" \
    '{provider: $provider, model: $model, api_key: $api_key}' >"$file"
  chmod 600 "$file"

  log_info "saved model to $file"
}

generate_command() {
  require_jq

  provider=${PSH_PROVIDER:-$(config_value provider)}
  provider=${provider:-openai}

  case $provider in
    openai)
      model=${OPENAI_MODEL:-${PSH_MODEL:-$(config_value model)}}
      model=${model:-gpt-4.1-mini}
      api_key=${OPENAI_API_KEY:-${PSH_API_KEY:-$(config_value api_key)}}
      url=https://api.openai.com/v1/chat/completions
      ;;
    fireworks)
      model=${FIREWORKS_MODEL:-${PSH_MODEL:-$(config_value model)}}
      model=${model:-accounts/fireworks/models/deepseek-v3p1}
      api_key=${FIREWORKS_API_KEY:-${PSH_API_KEY:-$(config_value api_key)}}
      url=https://api.fireworks.ai/inference/v1/chat/completions
      ;;
    codex)
      if ! command -v codex >/dev/null 2>&1; then
        printf 'psh: codex is required for the codex provider\n' >&2
        exit 2
      fi

      model=codex
      api_key=
      url=codex
      ;;
    *)
      printf 'psh: unsupported provider: %s\n' "$provider" >&2
      exit 2
      ;;
  esac

  if [ "$provider" != codex ] && ! command -v curl >/dev/null 2>&1; then
    printf 'psh: curl is required\n' >&2
    exit 2
  fi

  if [ "$provider" != codex ] && [ -z "$api_key" ]; then
    printf 'psh: API key is required; run `psh setup` or set provider API key env var\n' >&2
    exit 2
  fi

  debug_log 1 "configuration provider=$provider model=$model url=$url"

  system='You translate a natural-language shell task into a POSIX shell command. Respond with only valid compact JSON and no Markdown, prose, code fences, or thinking tags. Do not output <think> content. If the request is clear and safe, return {"type":"command","command":"..."}. If the request is ambiguous, return {"type":"question","question":"...","options":["...","..."]}. Question responses must include 2 to 5 concise options. Do not include a Custom option; the CLI adds that. Prefer safe, composable commands.'
  attempts=0

  while :; do
    attempts=$((attempts + 1))

    if [ "$attempts" -gt 3 ]; then
      printf 'psh: too many clarification rounds\n' >&2
      exit 1
    fi

    if [ "$provider" = codex ]; then
      response=$(generate_codex_response "$system" "$prompt")
    else
      response=$(generate_response "$url" "$api_key" "$model" "$system" "$prompt")
    fi
    type=$(printf '%s\n' "$response" | jq -r '.type // empty')
    debug_log 1 "structured response type=$type"
    debug_json_panel 2 'Structured response' "$response"

    case $type in
      command)
        printf '%s\n' "$response" | jq -r '.command // empty'
        return
        ;;
      question)
        question=$(printf '%s\n' "$response" | jq -r '.question // empty')

        if [ -z "$question" ]; then
          printf 'psh: generated clarification is missing a question\n' >&2
          exit 1
        fi

        if ! have_tty; then
          log_error "clarification required: $question"
          printf '%s\n' "$response" | jq -r '.options[]? | "psh: option: " + . ' >&2
          exit 2
        fi

        require_gum
        options=$(printf '%s\n' "$response" | jq -r '.options[]?')

        if [ -z "$options" ]; then
          answer=$(prompt_value "$question")
        else
          choice=$(printf '%s\nCustom\n' "$options" | gum choose --header "$question")
          if [ "$choice" = Custom ]; then
            answer=$(prompt_value 'Answer')
          else
            answer=$choice
          fi
        fi

        if [ -z "$answer" ]; then
          printf 'psh: clarification answer is required\n' >&2
          exit 2
        fi

        prompt=$(printf '%s\n\nClarification: %s\nAnswer: %s' "$prompt" "$question" "$answer")
        ;;
      *)
        printf 'psh: generated invalid structured response\n' >&2
        exit 1
        ;;
    esac
  done
}

generate_response() {
  url=$1
  api_key=$2
  model=$3
  system=$4
  prompt=$5

  request=$(jq -n \
    --arg model "$model" \
    --arg system "$system" \
    --arg prompt "$prompt" \
    '{model: $model, messages: [{role: "system", content: $system}, {role: "user", content: $prompt}], temperature: 0}')
  debug_log 1 "request model=$model"
  debug_messages "$request"
  debug_json_panel 3 'Request JSON' "$request"

  response_file=$(mktemp)
  trap 'rm -f "$response_file"' EXIT HUP INT TERM

  if have_tty; then
    require_gum
    gum_spin "$(spinner_title)" \
      curl -fsS "$url" \
        -H "Authorization: Bearer $api_key" \
        -H 'Content-Type: application/json' \
        -d "$request" \
        -o "$response_file"
  else
    curl -fsS "$url" \
      -H "Authorization: Bearer $api_key" \
      -H 'Content-Type: application/json' \
      -d "$request" \
      -o "$response_file"
  fi

  content=$(jq -r '.choices[0].message.content // empty' "$response_file")
  debug_log 1 'api response received'
  debug_json_file_panel 3 'API response JSON' "$response_file"
  debug_model_content 2 "$content"
  rm -f "$response_file"
  trap - EXIT HUP INT TERM

  extract_structured_json "$content"
}

generate_codex_response() {
  system=$1
  prompt=$2

  codex_prompt=$(jq -nr \
    --arg system "$system" \
    --arg prompt "$prompt" \
    '$system + "\n\nUser request:\n" + $prompt')

  debug_log 1 'request provider=codex'

  response_file=$(mktemp)
  trap 'rm -f "$response_file"' EXIT HUP INT TERM

  if have_tty; then
    require_gum
    gum_spin "$(spinner_title)" \
      sh -c 'codex exec --json "$1" >"$2"' sh "$codex_prompt" "$response_file"
  else
    codex exec --json "$codex_prompt" >"$response_file"
  fi

  debug_log 1 'codex response received'
  debug_panel 3 'Codex JSONL' "$(while IFS= read -r line; do printf '%s\n' "$line"; done <"$response_file")"

  content=$(jq -Rrs -r '
    split("\n")
    | [map(select(length > 0) | fromjson?)[]
      | select(.type == "item.completed" and .item.type == "agent_message")
      | .item.text]
    | last // empty
  ' "$response_file")

  if [ -z "$content" ]; then
    content=$(jq -Rrs -r 'sub("\\s+$"; "")' "$response_file")
  fi

  debug_model_content 2 "$content"
  rm -f "$response_file"
  trap - EXIT HUP INT TERM

  extract_structured_json "$content"
}

extract_structured_json() {
  content=$1

  if parsed=$(printf '%s\n' "$content" | jq -c . 2>/dev/null); then
    debug_log 1 'structured parse=direct'
    printf '%s\n' "$parsed"
    return
  fi

  parsed=$(printf '%s\n' "$content" | jq -Rrs -c '
    gsub("(?s)<think>.*?</think>"; "")
    | capture("(?s)(?<json>\\{.*\\})")?.json
    | fromjson
  ' 2>/dev/null || true)

  if [ -n "$parsed" ]; then
    debug_log 1 'structured parse=extracted'
    printf '%s\n' "$parsed"
    return
  fi

  debug_log 1 'structured parse=invalid'
  debug_model_content 2 "$content"

  printf 'psh: model returned invalid structured response\n' >&2
  exit 1
}

approve_and_run() {
  generated_command=$1

  display_command "$generated_command"

  if ! have_tty; then
    exit 0
  fi

  require_gum

  if gum confirm 'Run this command?' --padding '0' --affirmative 'Run' --negative 'Cancel'; then
    sh -c "$generated_command"
    exit $?
  fi

  log_error 'not run'
  exit 1
}

while [ "$#" -gt 0 ]; do
  case $1 in
    -v)
      if [ "$verbosity" -lt 1 ]; then
        verbosity=1
      fi
      shift
      ;;
    -vv)
      if [ "$verbosity" -lt 2 ]; then
        verbosity=2
      fi
      shift
      ;;
    -vvv)
      verbosity=3
      shift
      ;;
    --)
      shift
      break
      ;;
    *)
      break
      ;;
  esac
done

if [ "$#" -eq 0 ]; then
  usage >&2
  exit 2
fi

command=$1
if [ "$command" = run ] || [ "$command" = setup ] || [ "$command" = help ] || [ "$command" = -h ] || [ "$command" = --help ]; then
  shift
else
  command=run
fi

case "$command" in
  run)
    if [ "$#" -gt 0 ]; then
      prompt=$*
    elif [ ! -t 0 ]; then
      prompt=$(cat)
    else
      usage >&2
      exit 2
    fi
    ;;
  setup)
    if [ "$#" -eq 1 ] && [ "$1" = model ]; then
      setup_model
      exit 0
    fi

    if [ "$#" -gt 0 ]; then
      usage >&2
      exit 2
    fi

    setup
    exit 0
    ;;
  -h|--help|help)
    usage
    exit 0
    ;;
esac

if [ -z "$prompt" ]; then
  printf 'psh: empty prompt\n' >&2
  exit 2
fi

generated_command=$(generate_command)

if [ -z "$generated_command" ]; then
  printf 'psh: empty generated command\n' >&2
  exit 1
fi

approve_and_run "$generated_command"
