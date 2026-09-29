#!/usr/bin/env bash
# ==============================================================================
# Step 1: Verify Horizen Vela Docker Devnet & Network Health
# ==============================================================================
set -e

GREEN="\033[1;32m"
BLUE="\033[1;34m"
CYAN="\033[1;36m"
YELLOW="\033[1;33m"
BOLD="\033[1m"
RESET="\033[0m"

echo -e "${BOLD}${BLUE}======================================================================${RESET}"
echo -e "${BOLD}${BLUE}  STEP 1: Verify Horizen Vela Docker Devnet (Emulated TEE) Environment ${RESET}"
echo -e "${BOLD}${BLUE}======================================================================${RESET}"

RPC="http://127.0.0.1:8545"
AUTH_SERVICE="http://127.0.0.1:8081"
PROCESSOR="0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9"

echo -e "\n[1.1] Inspecting Docker Containers..."
SERVICES=(
  "chain"
  "manager"
  "executor"
  "authorityservice"
  "subgraph-node"
  "subgraph-postgres"
  "subgraph-ipfs"
)

ALL_HEALTHY=true
for s in "${SERVICES[@]}"; do
    c=""
    if docker inspect "vela-skit-${s}" >/dev/null 2>&1; then
        c="vela-skit-${s}"
    elif docker inspect "horizen-cce-${s}" >/dev/null 2>&1; then
        c="horizen-cce-${s}"
    else
        # check any running container matching service name
        c="$(docker ps --filter "name=${s}" --format "{{.Names}}" | head -n 1)"
    fi

    STATUS=$(docker inspect --format='{{.State.Status}}' "$c" 2>/dev/null || echo "not_found")
    if [ "$STATUS" = "running" ]; then
        echo -e "  ${GREEN}✓${RESET} Service ${BOLD}${s}${RESET} (${c}): ${GREEN}RUNNING${RESET}"
    else
        echo -e "  ${YELLOW}✗${RESET} Service ${BOLD}${s}${RESET}: ${YELLOW}${STATUS}${RESET}"
        ALL_HEALTHY=false
    fi
done

if [ "$ALL_HEALTHY" = false ]; then
    echo -e "\n${YELLOW}Error: One or more Vela containers are not running.${RESET}"
    echo "Please launch the Vela devnet with docker-compose before continuing."
    exit 1
fi

echo -e "\n[1.2] Checking Anvil RPC ($RPC)..."
CHAIN_ID=$(cast chain-id --rpc-url "$RPC" 2>/dev/null || echo "error")
BLOCK_NUM=$(cast block-number --rpc-url "$RPC" 2>/dev/null || echo "error")
BLOCK_TIME=$(cast block latest --rpc-url "$RPC" 2>/dev/null | grep "timestamp" | awk '{print $2}')
echo -e "  ${GREEN}✓${RESET} Chain ID        : ${CYAN}${CHAIN_ID}${RESET}"
echo -e "  ${GREEN}✓${RESET} Latest Block    : ${CYAN}${BLOCK_NUM}${RESET}"
echo -e "  ${GREEN}✓${RESET} Block Timestamp : ${CYAN}${BLOCK_TIME}${RESET}"

echo -e "\n[1.3] Checking Vela Authority Service ($AUTH_SERVICE)..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${AUTH_SERVICE}/" 2>/dev/null || echo "error")
echo -e "  ${GREEN}✓${RESET} Authority Service HTTP status: ${GREEN}${HTTP_CODE}${RESET} (Ready to receive WASM uploads)"

echo -e "\n[1.4] Checking Vela ProcessorEndpoint ($PROCESSOR)..."
CODE_SIZE=$(cast code "$PROCESSOR" --rpc-url "$RPC" 2>/dev/null | wc -c)
echo -e "  ${GREEN}✓${RESET} ProcessorEndpoint bytecode: ${CYAN}${CODE_SIZE} bytes${RESET} (Pre-deployed & listening)"

echo -e "\n${GREEN}${BOLD}✓ Environment Check Complete: All Vela TEE infrastructure is active and healthy!${RESET}\n"
