#!/usr/bin/env bash
# ==============================================================================
# Step 1: Check Environment & Horizen Vela TEE Stack for Agent Passport Demo
# ==============================================================================
set -e

GREEN="\033[1;32m"
BLUE="\033[1;34m"
CYAN="\033[1;36m"
YELLOW="\033[1;33m"
BOLD="\033[1m"
RESET="\033[0m"

echo -e "${BOLD}${BLUE}======================================================================${RESET}"
echo -e "${BOLD}${BLUE}  STEP 1: Verify Horizen Vela CCE & Agentic Identity Stack            ${RESET}"
echo -e "${BOLD}${BLUE}======================================================================${RESET}"

DIR="$(cd "$(dirname "$0")" && pwd)"
DEMO_ROOT="$(cd "$DIR/../.." && pwd)"

if [ -f "$DEMO_ROOT/tools/vela/common.sh" ]; then
    # shellcheck disable=SC1091
    source "$DEMO_ROOT/tools/vela/common.sh"
    vela_require_env_file
fi

RPC="${VELA_RPC_URL:-http://127.0.0.1:8545}"
AUTH_SERVICE="${VELA_AUTHORITY_URL:-http://127.0.0.1:8081}"

echo -e "\n[1.1] Checking local CLI tool dependencies..."
for cmd in cast forge cargo pnpm python3 curl shasum; do
    if command -v "$cmd" &>/dev/null; then
        echo -e "  ${GREEN}✓${RESET} Found ${BOLD}$cmd${RESET} ($(command -v "$cmd"))"
    else
        echo -e "  ${YELLOW}✗${RESET} Missing ${BOLD}$cmd${RESET}"
        exit 1
    fi
done

echo -e "\n[1.2] Checking local Ethereum RPC (Anvil / Horizen Vela)..."
if curl -s -X POST "$RPC" -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' | grep -q "result"; then
    BLOCK_HEX=$(curl -s -X POST "$RPC" -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' | python3 -c "import json,sys; print(json.loads(sys.stdin.read())['result'])")
    BLOCK_INT=$((BLOCK_HEX))
    echo -e "  ${GREEN}✓${RESET} RPC Endpoint Online at ${CYAN}${RPC}${RESET} (Current Block: ${BOLD}${BLOCK_INT}${RESET})"
else
    echo -e "  ${YELLOW}✗${RESET} RPC not responding at $RPC"
    echo -e "    Please start the Vela Docker stack: (cd vela-starterkit/dockerfiles && docker compose up -d)"
    exit 1
fi

echo -e "\n[1.3] Checking Horizen Vela Authority Service..."
if curl -s "${AUTH_SERVICE}/health" | grep -q -i "ok\|healthy\|true\|status" 2>/dev/null || curl -s -o /dev/null -w "%{http_code}" "${AUTH_SERVICE}" | grep -q "200\|404\|405"; then
    echo -e "  ${GREEN}✓${RESET} Authority Service Online at ${CYAN}${AUTH_SERVICE}${RESET}"
else
    echo -e "  ${YELLOW}✗${RESET} Authority Service not responding at $AUTH_SERVICE"
    echo -e "    Please start the Vela Docker stack: (cd vela-starterkit/dockerfiles && docker compose up -d)"
    exit 1
fi

echo -e "\n[1.4] Checking Docker Containers for Vela CCE Emulation..."
RUNNING_CONTAINERS=$(docker ps --format "{{.Names}}" 2>/dev/null || echo "")
for c in vela-skit-chain vela-skit-executor vela-skit-manager vela-skit-authorityservice; do
    if echo "$RUNNING_CONTAINERS" | grep -q "$c"; then
        echo -e "  ${GREEN}✓${RESET} Container ${CYAN}$c${RESET} is running"
    else
        echo -e "  ${YELLOW}ℹ${RESET} Container ${YELLOW}$c${RESET} is not running (devnet mode active)"
    fi
done

echo -e "\n${BOLD}${GREEN}✓ Step 1 Complete: Environment verified for Agent Passport Demo!${RESET}\n"
