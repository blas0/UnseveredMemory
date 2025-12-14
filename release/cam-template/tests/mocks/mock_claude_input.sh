#!/bin/bash
# Mock Claude Code Hook Input Generator
# Version: 2.1.0
# Generates sample JSON input for testing hooks

generate_session_start_input() {
  local session_id="${1:-test-session-12345678}"
  local cwd="${2:-/Users/test/project}"

  jq -n \
    --arg session_id "$session_id" \
    --arg cwd "$cwd" \
    '{
      session_id: $session_id,
      cwd: $cwd,
      hook: "SessionStart"
    }'
}

generate_user_prompt_input() {
  local prompt="$1"
  local session_id="${2:-test-session-12345678}"
  local cwd="${3:-/Users/test/project}"

  jq -n \
    --arg prompt "$prompt" \
    --arg session_id "$session_id" \
    --arg cwd "$cwd" \
    '{
      prompt: $prompt,
      user_prompt: $prompt,
      session_id: $session_id,
      cwd: $cwd,
      hook: "UserPromptSubmit"
    }'
}

generate_pre_tool_use_input() {
  local tool_name="$1"
  local tool_input="$2"
  local session_id="${3:-test-session-12345678}"
  local cwd="${4:-/Users/test/project}"

  jq -n \
    --arg tool_name "$tool_name" \
    --argjson tool_input "$tool_input" \
    --arg session_id "$session_id" \
    --arg cwd "$cwd" \
    '{
      tool_name: $tool_name,
      tool_input: $tool_input,
      session_id: $session_id,
      cwd: $cwd,
      hook: "PreToolUse"
    }'
}

generate_post_tool_use_input() {
  local tool_name="$1"
  local tool_input="$2"
  local success="${3:-true}"
  local session_id="${4:-test-session-12345678}"
  local cwd="${5:-/Users/test/project}"

  jq -n \
    --arg tool_name "$tool_name" \
    --argjson tool_input "$tool_input" \
    --arg success "$success" \
    --arg session_id "$session_id" \
    --arg cwd "$cwd" \
    '{
      tool_name: $tool_name,
      tool_input: $tool_input,
      tool_response: {
        success: ($success == "true")
      },
      session_id: $session_id,
      cwd: $cwd,
      hook: "PostToolUse"
    }'
}

generate_permission_request_input() {
  local command="$1"
  local reason="${2:-Test permission request}"
  local session_id="${3:-test-session-12345678}"
  local cwd="${4:-/Users/test/project}"

  jq -n \
    --arg command "$command" \
    --arg reason "$reason" \
    --arg session_id "$session_id" \
    --arg cwd "$cwd" \
    '{
      command: $command,
      reason: $reason,
      session_id: $session_id,
      cwd: $cwd,
      hook: "PermissionRequest"
    }'
}

generate_subagent_stop_input() {
  local task_description="$1"
  local findings="${2:-Completed successfully}"
  local session_id="${3:-test-session-12345678}"
  local cwd="${4:-/Users/test/project}"

  jq -n \
    --arg task "$task_description" \
    --arg findings "$findings" \
    --arg session_id "$session_id" \
    --arg cwd "$cwd" \
    '{
      task_description: $task,
      findings: $findings,
      session_id: $session_id,
      cwd: $cwd,
      hook: "SubagentStop"
    }'
}

generate_pre_compact_input() {
  local session_id="${1:-test-session-12345678}"
  local cwd="${2:-/Users/test/project}"

  jq -n \
    --arg session_id "$session_id" \
    --arg cwd "$cwd" \
    '{
      session_id: $session_id,
      cwd: $cwd,
      hook: "PreCompact"
    }'
}

generate_session_end_input() {
  local session_id="${1:-test-session-12345678}"
  local cwd="${2:-/Users/test/project}"

  jq -n \
    --arg session_id "$session_id" \
    --arg cwd "$cwd" \
    '{
      session_id: $session_id,
      cwd: $cwd,
      hook: "SessionEnd"
    }'
}

# Tool input generators
generate_edit_tool_input() {
  local file_path="$1"
  local old_string="${2:-old content}"
  local new_string="${3:-new content}"

  jq -n \
    --arg file_path "$file_path" \
    --arg old "$old_string" \
    --arg new "$new_string" \
    '{
      file_path: $file_path,
      old_string: $old,
      new_string: $new
    }'
}

generate_write_tool_input() {
  local file_path="$1"
  local content="${2:-test content}"

  jq -n \
    --arg file_path "$file_path" \
    --arg content "$content" \
    '{
      file_path: $file_path,
      content: $content
    }'
}

generate_bash_tool_input() {
  local command="$1"

  jq -n \
    --arg command "$command" \
    '{
      command: $command
    }'
}

generate_read_tool_input() {
  local file_path="$1"

  jq -n \
    --arg file_path "$file_path" \
    '{
      file_path: $file_path
    }'
}

# CLI interface
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  COMMAND="${1:-}"

  case "$COMMAND" in
    session-start)
      generate_session_start_input "$2" "$3"
      ;;
    user-prompt)
      generate_user_prompt_input "$2" "$3" "$4"
      ;;
    pre-tool-use)
      generate_pre_tool_use_input "$2" "$3" "$4" "$5"
      ;;
    post-tool-use)
      generate_post_tool_use_input "$2" "$3" "$4" "$5" "$6"
      ;;
    permission-request)
      generate_permission_request_input "$2" "$3" "$4" "$5"
      ;;
    subagent-stop)
      generate_subagent_stop_input "$2" "$3" "$4" "$5"
      ;;
    pre-compact)
      generate_pre_compact_input "$2" "$3"
      ;;
    session-end)
      generate_session_end_input "$2" "$3"
      ;;
    edit-input)
      generate_edit_tool_input "$2" "$3" "$4"
      ;;
    write-input)
      generate_write_tool_input "$2" "$3"
      ;;
    bash-input)
      generate_bash_tool_input "$2"
      ;;
    read-input)
      generate_read_tool_input "$2"
      ;;
    *)
      echo "Usage: $0 {session-start|user-prompt|pre-tool-use|post-tool-use|permission-request|subagent-stop|pre-compact|session-end|edit-input|write-input|bash-input|read-input}"
      exit 1
      ;;
  esac
fi

# Export functions
export -f generate_session_start_input
export -f generate_user_prompt_input
export -f generate_pre_tool_use_input
export -f generate_post_tool_use_input
export -f generate_permission_request_input
export -f generate_subagent_stop_input
export -f generate_pre_compact_input
export -f generate_session_end_input
export -f generate_edit_tool_input
export -f generate_write_tool_input
export -f generate_bash_tool_input
export -f generate_read_tool_input
