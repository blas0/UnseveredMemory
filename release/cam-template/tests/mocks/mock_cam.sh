#!/bin/bash
# Mock CAM CLI for Testing
# Version: 2.1.0
# Provides a lightweight mock of CAM operations without requiring full Python setup

# Mock database location
MOCK_CAM_DB="${MOCK_CAM_DB:-$HOME/.claude/.mock-cam-db}"

# Initialize mock database
mock_cam_init() {
  mkdir -p "$MOCK_CAM_DB"

  # Create mock embeddings file
  echo "[]" > "$MOCK_CAM_DB/embeddings.json"

  # Create mock annotations file
  echo "[]" > "$MOCK_CAM_DB/annotations.json"

  # Create mock relationships file
  echo "[]" > "$MOCK_CAM_DB/relationships.json"
}

# Mock query command
mock_cam_query() {
  local query_text="$1"
  local limit="${2:-5}"

  # Return mock results based on query
  cat <<EOF
CAM Query Results (Mock)
Query: "$query_text"

[0.87] Similar pattern found in authentication module
- Location: src/auth/login.py
- Context: Implemented JWT authentication with refresh tokens
- Tags: authentication, security, jwt

[0.72] Related configuration in settings
- Location: config/auth.yaml
- Context: Authentication service configuration
- Tags: config, authentication

[0.65] Previous bug fix in auth flow
- Location: src/auth/middleware.py
- Context: Fixed token validation edge case
- Tags: bugfix, authentication
EOF
}

# Mock annotate command
mock_cam_annotate() {
  local title="$1"
  local content="$2"
  local tags="${3:-}"

  # Generate mock embedding ID
  local embedding_id=$(cat /dev/urandom | LC_ALL=C tr -dc 'a-f0-9' | fold -w 16 | head -n 1)

  # Add to mock database
  local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  local entry=$(jq -n \
    --arg id "$embedding_id" \
    --arg title "$title" \
    --arg content "$content" \
    --arg tags "$tags" \
    --arg ts "$timestamp" \
    '{
      id: $id,
      title: $title,
      content: $content,
      tags: $tags,
      timestamp: $ts
    }')

  # Append to embeddings file
  local embeddings=$(cat "$MOCK_CAM_DB/embeddings.json" 2>/dev/null || echo "[]")
  embeddings=$(echo "$embeddings" | jq --argjson entry "$entry" '. += [$entry]')
  echo "$embeddings" > "$MOCK_CAM_DB/embeddings.json"

  echo "[v] Embedded: $title (ID: $embedding_id)"
}

# Mock stats command
mock_cam_stats() {
  local embeddings_count=$(cat "$MOCK_CAM_DB/embeddings.json" 2>/dev/null | jq '. | length' || echo "0")
  local annotations_count=$(cat "$MOCK_CAM_DB/annotations.json" 2>/dev/null | jq '. | length' || echo "0")

  jq -n \
    --argjson emb "$embeddings_count" \
    --argjson ann "$annotations_count" \
    '{
      total_embeddings: $emb,
      total_annotations: $ann,
      storage_size: "156KB",
      last_update: "2024-01-15T10:30:00Z"
    }'
}

# Mock ingest command
mock_cam_ingest() {
  local file_path="$1"
  local file_type="${2:-code}"

  if [ ! -f "$file_path" ]; then
    echo "Error: File not found: $file_path"
    return 1
  fi

  # Generate mock embedding ID
  local embedding_id=$(cat /dev/urandom | LC_ALL=C tr -dc 'a-f0-9' | fold -w 16 | head -n 1)

  echo "[v] Ingested: $(basename "$file_path") -> $embedding_id"
}

# Mock relate command
mock_cam_relate() {
  local source_id="$1"
  local target_id="$2"
  local rel_type="$3"
  local strength="${4:-0.8}"

  echo "[v] Relationship created: $source_id --[$rel_type ($strength)]--> $target_id"
}

# Mock graph build command
mock_cam_graph_build() {
  cat <<EOF
{
  "edges_created": {
    "temporal": 15,
    "semantic": 8,
    "causal": 3,
    "total": 26
  },
  "nodes": 42,
  "status": "success"
}
EOF
}

# Mock store-session command
mock_cam_store_session() {
  local session_id="$1"
  local session_data="$2"

  echo "[v] Session stored: ${session_id:0:8}"
}

# Mock find-doc command
mock_cam_find_doc() {
  local file_path="$1"

  # Return a mock document ID
  echo "doc-$(cat /dev/urandom | LC_ALL=C tr -dc 'a-f0-9' | fold -w 16 | head -n 1)"
}

# Main CLI handler
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  # Ensure mock database exists
  if [ ! -d "$MOCK_CAM_DB" ]; then
    mock_cam_init
  fi

  COMMAND="${1:-}"

  case "$COMMAND" in
    query)
      mock_cam_query "$2" "$3"
      ;;
    note)
      mock_cam_annotate "$2" "$3" "$4"
      ;;
    stats)
      mock_cam_stats
      ;;
    ingest)
      mock_cam_ingest "$2" "$3"
      ;;
    relate)
      mock_cam_relate "$2" "$3" "$4" "$5"
      ;;
    graph)
      if [ "$2" = "build" ]; then
        mock_cam_graph_build
      fi
      ;;
    store-session)
      mock_cam_store_session "$2" "$3"
      ;;
    find-doc)
      mock_cam_find_doc "$2"
      ;;
    init)
      mock_cam_init
      echo "Mock CAM initialized at $MOCK_CAM_DB"
      ;;
    clear)
      rm -rf "$MOCK_CAM_DB"
      echo "Mock CAM cleared"
      ;;
    *)
      echo "Mock CAM CLI - Testing Interface"
      echo "Usage: $0 {query|note|stats|ingest|relate|graph|store-session|find-doc|init|clear}"
      exit 1
      ;;
  esac
fi

# Export functions
export -f mock_cam_init
export -f mock_cam_query
export -f mock_cam_annotate
export -f mock_cam_stats
export -f mock_cam_ingest
export -f mock_cam_relate
export -f mock_cam_graph_build
export -f mock_cam_store_session
export -f mock_cam_find_doc
