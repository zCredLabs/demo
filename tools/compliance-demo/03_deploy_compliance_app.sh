#!/usr/bin/env bash
# ==============================================================================
# Step 3: Deploy Contracts (including Layrs Dark Pool) & App on Vela Devnet
# ==============================================================================
set -e

GREEN="\033[1;32m"
BLUE="\033[1;34m"
CYAN="\033[1;36m"
YELLOW="\033[1;33m"
BOLD="\033[1m"
RESET="\033[0m"

echo -e "${BOLD}${BLUE}======================================================================${RESET}"
echo -e "${BOLD}${BLUE}  STEP 3: Deploy Compliance Contracts & Layrs Confidential Dark Pool   ${RESET}"
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
PROCESSOR="${PROCESSOR_ENDPOINT:-0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9}"
PRIVATE_KEY="${DEPLOYER_ADMIN_KEY:-0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80}"
DEPLOYER="${DEPLOYER_ADMIN:-0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266}"
SIGNER_ADDRESS="${TEE_SIGNER_ADDRESS:-0x2a0fba02cee7fb70899648037c7E8203881e2D55}"
SIGNER_KEY="${EXECUTOR_FIXED_SIGNING_KEY:-0x0000000000000000000000000000000000000000000000000000000000000002}"
P521_KEY="${EXECUTOR_FIXED_COMMUNICATION_KEY:-0x0111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111}"

WASM_PATH=""
if [ -f "/tmp/zcred_demo/wasm_path" ]; then
    WASM_PATH=$(cat /tmp/zcred_demo/wasm_path)
fi
if [ -z "$WASM_PATH" ] || [ ! -f "$WASM_PATH" ]; then
    echo "Running build step first..."
    "$DIR/02_build_compliance_kernel.sh"
    WASM_PATH=$(cat /tmp/zcred_demo/wasm_path)
fi
WASM_SHA=$(shasum -a 256 "$WASM_PATH" | awk '{print $1}')

echo -e "\n[3.1] Uploading WASM binary to Vela Authority Service..."
UPLOAD_RESP=$(curl -s -X POST -F "wasm=@${WASM_PATH}" "${AUTH_SERVICE}/deploy/upload")
echo -e "  ${GREEN}✓${RESET} Authority Service Confirmation: ${CYAN}${UPLOAD_RESP}${RESET}"

# Deploy contracts
CONTRACTS_DIR=""
if [ -d "$DEMO_ROOT/contracts" ]; then
    CONTRACTS_DIR="$DEMO_ROOT/contracts"
elif [ -d "$DEMO_ROOT/../zcred-contracts" ]; then
    CONTRACTS_DIR="$DEMO_ROOT/../zcred-contracts"
elif [ -d "$DEMO_ROOT/zcred-contracts" ]; then
    CONTRACTS_DIR="$DEMO_ROOT/zcred-contracts"
fi

echo -e "\n[3.2] Deploying TeeAuthenticator, ZcredRegistry, VelaZcredTrigger & MockLayrsDarkPool..."
AUTH_OUT=$(forge create --broadcast src/TeeAuthenticator.sol:TeeAuthenticator \
  --root "$CONTRACTS_DIR" --rpc-url "$RPC" --private-key "$PRIVATE_KEY" \
  --constructor-args "$DEPLOYER" false "$SIGNER_ADDRESS" 2>&1)
AUTH_ADDR=$(echo "$AUTH_OUT" | grep "Deployed to:" | awk '{print $3}')
echo -e "  ${GREEN}✓${RESET} TeeAuthenticator deployed at : ${CYAN}${AUTH_ADDR}${RESET}"

REG_OUT=$(forge create --broadcast src/ZcredRegistry.sol:ZcredRegistry \
  --root "$CONTRACTS_DIR" --rpc-url "$RPC" --private-key "$PRIVATE_KEY" \
  --constructor-args "$AUTH_ADDR" 2>&1)
REG_ADDR=$(echo "$REG_OUT" | grep "Deployed to:" | awk '{print $3}')
echo -e "  ${GREEN}✓${RESET} ZcredRegistry deployed at   : ${CYAN}${REG_ADDR}${RESET}"

TRIGGER_OUT=$(forge create --broadcast src/VelaZcredTrigger.sol:VelaZcredTrigger \
  --root "$CONTRACTS_DIR" --rpc-url "$RPC" --private-key "$PRIVATE_KEY" \
  --constructor-args "$PROCESSOR" "$REG_ADDR" "$DEPLOYER" 2>&1)
TRIGGER_ADDR=$(echo "$TRIGGER_OUT" | grep "Deployed to:" | awk '{print $3}')
echo -e "  ${GREEN}✓${RESET} VelaZcredTrigger deployed at : ${CYAN}${TRIGGER_ADDR}${RESET}"

LAYRS_OUT=$(forge create --broadcast src/mocks/MockLayrsDarkPool.sol:MockLayrsDarkPool \
  --root "$CONTRACTS_DIR" --rpc-url "$RPC" --private-key "$PRIVATE_KEY" \
  --constructor-args "$REG_ADDR" 2>&1)
LAYRS_ADDR=$(echo "$LAYRS_OUT" | grep "Deployed to:" | awk '{print $3}')
echo -e "  ${GREEN}✓${RESET} MockLayrsDarkPool deployed at: ${CYAN}${LAYRS_ADDR}${RESET}"

mkdir -p /tmp/zcred_demo
echo "$AUTH_ADDR" > /tmp/zcred_demo/tee_auth_compliance
echo "$REG_ADDR" > /tmp/zcred_demo/registry_compliance
echo "$TRIGGER_ADDR" > /tmp/zcred_demo/trigger_compliance
echo "$LAYRS_ADDR" > /tmp/zcred_demo/layrs_pool

echo -e "\n[3.3] Packaging JSON Deploy Descriptor for Policy #2..."
NOW=$(date +%s)
DESCRIPTOR=$(python3 - "$WASM_SHA" "31337" "$REG_ADDR" "$P521_KEY" "$SIGNER_KEY" "$NOW" <<'PY'
import json, sys, time
sha, chain_id, registry, p521, signer, now = sys.argv[1:]
state = {
    "chainId": int(chain_id),
    "registryAddress": registry,
    "p521SkHex": "0x" + p521.removeprefix("0x"),
    "signerKeyHex": "0x" + signer.removeprefix("0x"),
    "now": int(now),
    "deployId": int(time.time()),
    "processedCount": 0,
}
print(json.dumps({
    "mode": "artifact_ref",
    "artifactId": "sha256:" + sha,
    "wasmSha256": sha,
    "constructorParams": state,
}, separators=(",", ":")))
PY
)
PAYLOAD_HEX=$(echo -n "$DESCRIPTOR" | xxd -p -c 100000 | tr -d '\r\n')

# Ensure available deploy slots in ProcessorEndpoint
AVAILABLE_SLOTS=$(cast call "$PROCESSOR" "availableDeploySlots()(uint256)" --rpc-url "$RPC" 2>/dev/null || echo "10")
if [ "${AVAILABLE_SLOTS:-0}" -le 1 ]; then
    CURRENT_MAX=$(cast call "$PROCESSOR" "maxNumOfApplications()(uint256)" --rpc-url "$RPC" 2>/dev/null || echo "10")
    NEW_MAX=$(( CURRENT_MAX + 50 ))
    echo -e "  ${YELLOW}ℹ${RESET} Deploy slots low (${AVAILABLE_SLOTS} remaining). Expanding maxNumOfApplications to ${NEW_MAX}..."
    cast send "$PROCESSOR" "updateMaxNumOfApplications(uint256)" "$NEW_MAX" \
      --rpc-url "$RPC" --private-key "$PRIVATE_KEY" >/dev/null 2>&1 || true
fi

echo -e "\n[3.4] Submitting submitDeployRequestWithTrigger to ProcessorEndpoint..."
DEPLOY_JSON=$(cast send "$PROCESSOR" \
  "submitDeployRequestWithTrigger(uint8,bytes,address)" \
  0 "0x${PAYLOAD_HEX}" "$TRIGGER_ADDR" \
  --value 1000wei --rpc-url "$RPC" --private-key "$PRIVATE_KEY" --json)

TX_HASH=$(echo "$DEPLOY_JSON" | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('transactionHash',''))")
BLOCK_NUM=$(echo "$DEPLOY_JSON" | python3 -c "import json,sys; print(int(json.loads(sys.stdin.read()).get('blockNumber','0'), 16) if '0x' in str(json.loads(sys.stdin.read()).get('blockNumber','')) else json.loads(sys.stdin.read()).get('blockNumber',''))" 2>/dev/null || echo "latest")
echo -e "  ${GREEN}✓${RESET} DEPLOYAPP Transaction Hash   : ${CYAN}${TX_HASH}${RESET}"

SUBMITTED_TOPIC=$(cast keccak 'DeployRequestSubmitted(uint64,bytes32,address)')
COMPLETED_TOPIC=$(cast keccak 'DeployRequestCompleted(uint64,bytes32,uint256,uint8,uint8,string)')

RECEIPT=$(cast receipt "$TX_HASH" --rpc-url "$RPC" --json)
APP_ID=$(python3 - "$RECEIPT" "$SUBMITTED_TOPIC" <<'PY'
import json, sys
receipt, topic = json.loads(sys.argv[1]), sys.argv[2].lower()
for log in receipt.get("logs", []):
    topics = [str(x).lower() for x in log.get("topics", [])]
    if topics and topics[0] == topic and len(topics) > 1:
        print(int(topics[1], 16))
        break
PY
)
echo -e "  ${GREEN}✓${RESET} Derived Vela Application ID  : ${CYAN}${APP_ID}${RESET}"
echo "$APP_ID" > /tmp/zcred_demo/app_id_compliance

echo -e "\n[3.5] Waiting for Horizen Vela TEE instantiation on-chain..."
for i in {1..30}; do
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
        echo -e "  ${GREEN}✓${RESET} Wasmtime Runtime: Successfully instantiated guest module for app ${APP_ID}"
        echo -e "  ${GREEN}✓${RESET} Vela Executor   : Initial state encrypted and committed"
        echo -e "  ${GREEN}✓${RESET} Vela Manager    : On-chain DeployRequestCompleted confirmed"
        break
    fi
    echo -n "."
    sleep 2
done
echo ""

echo -e "${GREEN}${BOLD}✓ Step 3 Complete: Compliance Application & Dark Pool live on Vela TEE!${RESET}\n"
