#!/usr/bin/env bash
# Shared, environment-driven helpers for the Vela integration runners.
# This file deliberately refuses to invent live endpoints or contract addresses.

set -euo pipefail

VELA_ROOT="${VELA_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

if [[ -f "$VELA_ROOT/vela-starterkit/dockerfiles/docker-compose.yml" ]]; then
  VELA_STARTERKIT_DIR="$VELA_ROOT/vela-starterkit/dockerfiles"
elif [[ -f "$VELA_ROOT/../vela-starterkit/dockerfiles/docker-compose.yml" ]]; then
  VELA_STARTERKIT_DIR="$VELA_ROOT/../vela-starterkit/dockerfiles"
else
  VELA_STARTERKIT_DIR="$VELA_ROOT/vela-starterkit/dockerfiles"
fi

VELA_COMPOSE_FILE="${VELA_COMPOSE_FILE:-$VELA_STARTERKIT_DIR/docker-compose.yml}"
VELA_ENV_FILE="${VELA_ENV_FILE:-$VELA_STARTERKIT_DIR/.env}"
VELA_COMPOSE_PROJECT="${VELA_COMPOSE_PROJECT:-zcred-vela}"
VELA_RPC_URL="${VELA_RPC_URL:-http://127.0.0.1:8545}"
VELA_AUTHORITY_URL="${VELA_AUTHORITY_URL:-http://127.0.0.1:8081}"

vela_die() {
  echo "[vela] ERROR: $*" >&2
  exit 1
}

vela_require_tools() {
  local tool
  for tool in "$@"; do
    command -v "$tool" >/dev/null 2>&1 || vela_die "required command not found: $tool"
  done
}

vela_require_env_file() {
  [[ -f "$VELA_ENV_FILE" ]] || vela_die "Vela env file not found: $VELA_ENV_FILE (copy .env.dev to .env first)"
  # The starter kit file is shell-compatible KEY='value' configuration.
  # shellcheck disable=SC1090
  source "$VELA_ENV_FILE"
}

vela_compose() {
  docker compose --project-name "$VELA_COMPOSE_PROJECT" --env-file "$VELA_ENV_FILE" \
    --file "$VELA_COMPOSE_FILE" "$@"
}

vela_require_docker() {
  vela_require_tools docker curl cast forge cargo pnpm python3
  docker info >/dev/null 2>&1 || vela_die "Docker daemon is not reachable; start Docker Desktop/Linux Docker before running the Vela stack"
}

vela_wait_rpc() {
  local attempts="${1:-60}"
  local i
  for ((i = 1; i <= attempts; i++)); do
    if cast chain-id --rpc-url "$VELA_RPC_URL" >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  vela_die "Vela RPC did not become ready: $VELA_RPC_URL"
}

vela_wait_http() {
  local url="$1"
  local attempts="${2:-60}"
  local i
  for ((i = 1; i <= attempts; i++)); do
    local status
    status="$(curl --silent --show-error --output /dev/null --write-out '%{http_code}' "$url" || true)"
    if [[ "$status" =~ ^[234][0-9][0-9]$ || "$status" =~ ^4[0-9][0-9]$ ]]; then
      return 0
    fi
    sleep 2
  done
  vela_die "Vela HTTP endpoint did not become ready: $url"
}

vela_container_id() {
  local service="$1"
  vela_compose ps -q "$service" | head -n 1
}

vela_container_running() {
  local service="$1"
  local id
  id="$(vela_container_id "$service")"
  [[ -n "$id" ]] && [[ "$(docker inspect -f '{{.State.Status}}' "$id" 2>/dev/null || true)" == "running" ]]
}

# Read a file from the deploy-data volume through a running manager container.
# This avoids relying on Docker's host-side volume mount path, which differs by OS.
vela_read_deploy_data() {
  local manager_id
  manager_id="$(vela_container_id manager)"
  [[ -n "$manager_id" ]] || return 0
  docker exec "$manager_id" sh -lc 'find /deploy-data -maxdepth 2 -type f -print -exec sh -c '\''echo ---$1; cat "$1"'\'' sh {} \;' 2>/dev/null || true
}

# Resolve a Vela contract address from an explicit variable first, then from the
# starter-kit deploy output. The variable name is intentionally caller supplied.
vela_resolve_address() {
  local variable_name="$1"
  local key_pattern="$2"
  local explicit="${!variable_name:-}"
  if [[ -n "$explicit" && "$explicit" != "0x0000000000000000000000000000000000000000" ]]; then
    printf '%s\n' "$explicit"
    return 0
  fi

  local dump
  dump="$(vela_read_deploy_data)"
  if [[ -n "$dump" ]]; then
    local resolved
    resolved="$(python3 - "$key_pattern" "$dump" <<'PY'
import re
import sys

pattern = re.compile(sys.argv[1], re.I)
text = sys.argv[2]
for match in re.finditer(r'0x[0-9a-fA-F]{40}', text):
    candidate = match.group(0)
    # The surrounding text check is deliberately conservative; callers still
    # need to verify bytecode before using the address.
    start = max(0, match.start() - 100)
    if pattern.search(text[start:match.end()]):
        print(candidate)
        break
PY
)"
    if [[ -n "$resolved" ]]; then
      printf '%s\n' "$resolved"
      return 0
    fi
  fi

  return 1
}

vela_first_live_candidate() {
  local candidate
  for candidate in "$@"; do
    if [[ -n "$(cast code "$candidate" --rpc-url "$VELA_RPC_URL" 2>/dev/null | tr -d '[:space:]')" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

vela_tx_hash() {
  python3 -c 'import json,sys; print(json.load(sys.stdin).get("transactionHash", ""))'
}

vela_receipt_block() {
  cast receipt "$1" --rpc-url "$VELA_RPC_URL" --json | python3 -c 'import json,sys; print(json.load(sys.stdin)["blockNumber"])'
}

vela_log_field() {
  # Usage: vela_log_field <logs-json> <python expression over log>
  # Kept as a small helper for scripts that need custom event decoding.
  local logs_json="$1"
  local expression="$2"
  python3 -c "import json,sys; logs=json.loads(sys.argv[1]); print($expression)" "$logs_json"
}

vela_assert_address() {
  local name="$1"
  local address="$2"
  [[ "$address" =~ ^0x[0-9a-fA-F]{40}$ ]] || vela_die "$name is not an EVM address: $address"
  local code
  code="$(cast code "$address" --rpc-url "$VELA_RPC_URL" 2>/dev/null | tr -d '[:space:]')"
  [[ -n "$code" && "$code" != "0x" ]] || vela_die "$name has no bytecode on $VELA_RPC_URL: $address"
}
