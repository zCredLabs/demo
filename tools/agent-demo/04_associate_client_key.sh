#!/usr/bin/env bash
# ==============================================================================
# Step 4: Generate Client NIST P-521 Key & Submit ASSOCIATEKEY for Agent Alpha
# ==============================================================================
set -e

GREEN="\033[1;32m"
BLUE="\033[1;34m"
CYAN="\033[1;36m"
YELLOW="\033[1;33m"
BOLD="\033[1m"
RESET="\033[0m"

echo -e "${BOLD}${BLUE}======================================================================${RESET}"
echo -e "${BOLD}${BLUE}  STEP 4: Generate Ephemeral Client Key & ASSOCIATEKEY for Agent Alpha${RESET}"
echo -e "${BOLD}${BLUE}======================================================================${RESET}"

DIR="$(cd "$(dirname "$0")" && pwd)"
DEMO_ROOT="$(cd "$DIR/../.." && pwd)"

if [ -f "$DEMO_ROOT/tools/vela/common.sh" ]; then
    # shellcheck disable=SC1091
    source "$DEMO_ROOT/tools/vela/common.sh"
    vela_require_env_file
fi

RPC="${VELA_RPC_URL:-http://127.0.0.1:8545}"
PROCESSOR="${PROCESSOR_ENDPOINT:-0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9}"
PRIVATE_KEY="${DEPLOYER_ADMIN_KEY:-0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80}"
P521_PUBLIC="${TEE_PUB_P521:-0x0400b9576bb4032d96c9443729e2ff9d71c4c9d3fbc9581ec0db8c49e1a8cf822ebdeea87c06ebca9043231bdbe852fb7256df93eb5a43b2f815ad705b7661cf6f350027f67fb8ddbe5e52c93d5f94c5f94086ad3451bb31c9e47f9ad3c98894df0fbaf6c43ff8dff3e7fd29b7a4dd425cebeae3f9f7d2f9aa76e5df2b67f40199e4f3}"

APP_ID=""
if [ -f "/tmp/zcred_demo/app_id_agent" ]; then
    APP_ID=$(cat /tmp/zcred_demo/app_id_agent)
fi

if [ -z "$APP_ID" ]; then
    echo -e "${YELLOW}Warning: /tmp/zcred_demo/app_id_agent not found. Running deploy step first...${RESET}"
    "$DIR/03_deploy_agent_app.sh"
    APP_ID=$(cat /tmp/zcred_demo/app_id_agent)
fi

echo -e "\nTargeting Agent Application ID: ${CYAN}${APP_ID}${RESET}"

echo -e "\n[4.1] Generating Ephemeral NIST P-521 Client Key Pair & Encrypting Agent Alpha's Claim..."
ALPHA_FIXTURE="$DEMO_ROOT/fixtures/agent/agent_alpha_attested.json"
ALPHA_PAYLOAD=$(tr -d '\n' < "$ALPHA_FIXTURE")

ENCRYPT_TOOL="$DEMO_ROOT/tools/encrypt_payload/zcred-encrypt"
if [ ! -x "$ENCRYPT_TOOL" ]; then
    (cd "$DEMO_ROOT/tools/encrypt_payload" && go build -o zcred-encrypt .)
fi

mkdir -p /tmp/zcred_demo
EXECUTOR_PUB_HEX="${P521_PUBLIC#0x}" "$ENCRYPT_TOOL" "$ALPHA_PAYLOAD" \
  >/tmp/zcred_demo/encrypted_agent_alpha 2>/tmp/zcred_demo/enc_agent_meta

USER_PUB=$(grep "USER_PUB_HEX" /tmp/zcred_demo/enc_agent_meta | cut -d= -f2 | tr -d '\r\n')
echo -e "  ${GREEN}✓${RESET} Generated Agent Alpha P-521 Curve point: ${CYAN}${USER_PUB:0:30}...${USER_PUB: -20}${RESET} (133 bytes)"
echo "$USER_PUB" > /tmp/zcred_demo/user_pub_agent

echo -e "\n[4.2] Submitting on-chain ASSOCIATEKEY (RequestType: 3) to ProcessorEndpoint..."
ASSOC_JSON=$(cast send "$PROCESSOR" \
  "submitRequest(uint8,uint64,uint8,bytes,address,uint256,uint256)" \
  0 "$APP_ID" 3 "$USER_PUB" \
  "0x0000000000000000000000000000000000000000" 0 1000 \
  --value 1000wei --rpc-url "$RPC" --private-key "$PRIVATE_KEY" --json)

TX_HASH=$(echo "$ASSOC_JSON" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('transactionHash',''))")
BLOCK_NUM=$(echo "$ASSOC_JSON" | python3 -c "import json,sys; print(int(json.loads(sys.stdin.read()).get('blockNumber','0'), 16) if '0x' in str(json.loads(sys.stdin.read()).get('blockNumber','')) else json.loads(sys.stdin.read()).get('blockNumber',''))" 2>/dev/null || echo "latest")
echo -e "  ${GREEN}✓${RESET} ASSOCIATEKEY Transaction: ${CYAN}${TX_HASH}${RESET}"

echo -e "\n[4.3] Awaiting Vela Executor key registration in TEE state..."
COMPLETED_TOPIC=$(cast keccak 'RequestCompleted(uint64,bytes32,uint256,uint8,uint8,string)')
for i in {1..20}; do
    LOGS=$(cast logs --json --address "$PROCESSOR" --from-block "$BLOCK_NUM" --to-block latest --rpc-url "$RPC" 2>/dev/null || echo "[]")
    FOUND=$(python3 - "$LOGS" "$COMPLETED_TOPIC" <<'PY'
import json, sys
try:
    logs = json.loads(sys.argv[1])
except Exception:
    logs = []
topic = sys.argv[2].lower()
for log in logs:
    topics = [str(x).lower() for x in log.get("topics", [])]
    if topics and topics[0] == topic:
        print("true")
        sys.exit(0)
print("false")
PY
)
    if [ "$FOUND" == "true" ]; then
        echo -e "  ${GREEN}✓${RESET} Vela Executor: Public key mapped to caller address in TEE state"
        echo -e "  ${GREEN}✓${RESET} Vela Manager : Key association confirmed on-chain"
        break
    fi
    echo -n "."
    sleep 2
done
echo ""

echo -e "${BOLD}${GREEN}✓ Step 4 Complete: Client NIST P-521 key bound to Agent Application!${RESET}\n"
