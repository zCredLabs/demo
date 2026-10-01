#!/usr/bin/env bash
#
# Zcred Demo 1: RiskX -> Vela CCE -> ZcredRegistry -> lending gate
#
# This is the canonical integration runner. It uses the Vela v0.2.0 native
# ASSOCIATEKEY + PROCESS protocol; it does not call the registry directly to
# fake an enclave result. The local starter kit is an emulated TEE (Docker
# executor), not AWS Nitro hardware.
#
# START_VELA=1 ./tools/run_defi_demo.sh --reset
# VELA_ENV_FILE=/path/to/.env VELA_PROCESSOR_ENDPOINT=0x... ./tools/run_defi_demo.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/tools/vela/common.sh"

START_VELA="${START_VELA:-0}"
RESET="0"
STEP_BY_STEP="0"
for arg in "$@"; do
  case "$arg" in
    --start) START_VELA=1 ;;
    --reset) RESET=1 ;;
    --step-by-step|--pause) STEP_BY_STEP=1 ;;
    --help|-h)
      sed -n '2,25p' "$0"
      exit 0
      ;;
    *) vela_die "unknown option: $arg" ;;
  esac
done

TMP_DIR="${ZCRED_DEMO_DIR:-${TMPDIR:-/tmp}/zcred_defi_demo}"
mkdir -p "$TMP_DIR"

pause() {
  [[ "$STEP_BY_STEP" == "1" ]] || return 0
  read -r -p "Press ENTER to continue... " _
}

log_step() {
  printf '\n\033[1;36m[%s]\033[0m %s\n' "$1" "$2"
}

if [[ ! -f "$VELA_ENV_FILE" ]]; then
  if [[ -f "${VELA_STARTERKIT_DIR:-}/.env.dev" ]]; then
    cp "$VELA_STARTERKIT_DIR/.env.dev" "$VELA_ENV_FILE"
    echo "Created local Vela configuration at $VELA_ENV_FILE"
  elif [[ -f "$ROOT/vela-starterkit/dockerfiles/.env.dev" ]]; then
    cp "$ROOT/vela-starterkit/dockerfiles/.env.dev" "$VELA_ENV_FILE"
    echo "Created local Vela configuration at $VELA_ENV_FILE"
  fi
fi
vela_require_env_file
vela_require_tools curl cast forge python3 shasum xxd

if [[ "$START_VELA" == "1" ]]; then
  log_step "1/8" "Starting the Vela v0.2.0 Docker stack"
  vela_require_docker
  if [[ "$RESET" == "1" ]]; then
    vela_compose down --volumes --remove-orphans
  fi
  vela_compose up -d
else
  log_step "1/8" "Checking the already-running Vela Docker stack"
  vela_require_docker
fi

vela_wait_rpc 90
vela_wait_http "$VELA_AUTHORITY_URL/" 90
CHAIN_ID="$(cast chain-id --rpc-url "$VELA_RPC_URL")"
[[ "$CHAIN_ID" == "31337" ]] || vela_die "local demo requires Vela Anvil chain 31337, got $CHAIN_ID"
echo "RPC: $VELA_RPC_URL (chain $CHAIN_ID)"

# The starter kit writes addresses to deploy-data. Explicit variables are
# preferred; the two candidates below are only the published v0.2.0 local
# starter-kit addresses and are verified with eth_getCode before use.
PROCESSOR="${VELA_PROCESSOR_ENDPOINT:-${CHAIN_PROCESSOR_ADDRESS:-}}"
if [[ -z "$PROCESSOR" || "$PROCESSOR" == "0x0000000000000000000000000000000000000000" ]]; then
  PROCESSOR="$(vela_resolve_address VELA_PROCESSOR_ENDPOINT 'processor|endpoint' || true)"
fi
if [[ -z "$PROCESSOR" ]]; then
  PROCESSOR="$(vela_first_live_candidate \
    0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9 \
    0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9 || true)"
fi
[[ -n "$PROCESSOR" ]] || vela_die "cannot resolve ProcessorEndpoint; set VELA_PROCESSOR_ENDPOINT explicitly"

TEE_AUTH="${VELA_TEE_AUTHENTICATOR:-${CHAIN_TEEAUTHENTICATOR_ADDRESS:-}}"
if [[ -z "$TEE_AUTH" || "$TEE_AUTH" == "0x0000000000000000000000000000000000000000" ]]; then
  TEE_AUTH="$(vela_resolve_address VELA_TEE_AUTHENTICATOR 'tee.?auth|authenticator' || true)"
fi
if [[ -z "$TEE_AUTH" ]]; then
  TEE_AUTH="$(vela_first_live_candidate \
    0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0 \
    0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0 || true)"
fi
[[ -n "$TEE_AUTH" ]] || vela_die "cannot resolve Vela TeeAuthenticator; set VELA_TEE_AUTHENTICATOR explicitly"

DEPLOYER_KEY="${DEPLOYER_PRIVATE_KEY:?DEPLOYER_PRIVATE_KEY is required in VELA_ENV_FILE}"
DEPLOYER="${DEPLOYER_ADMIN:?DEPLOYER_ADMIN is required in VELA_ENV_FILE}"
SIGNER_KEY="${EXECUTOR_FIXED_SIGNING_KEY:?EXECUTOR_FIXED_SIGNING_KEY is required for the local emulator}"
P521_KEY="${EXECUTOR_FIXED_COMMUNICATION_KEY:?EXECUTOR_FIXED_COMMUNICATION_KEY is required for the local emulator}"
P521_PUBLIC="${TEE_PUB_P521:?TEE_PUB_P521 is required for native Vela encryption}"
SIGNER_ADDRESS="${TEE_SIGNER_ADDRESS:?TEE_SIGNER_ADDRESS is required for the local emulator}"

vela_assert_address "ProcessorEndpoint" "$PROCESSOR"
vela_assert_address "TeeAuthenticator" "$TEE_AUTH"
cast call "$PROCESSOR" "isAllowedDeployer(address)(bool)" "$DEPLOYER" --rpc-url "$VELA_RPC_URL" | grep -qi true \
  || vela_die "$DEPLOYER is not allowed to submit Vela deploy requests"

log_step "2/8" "Locating and verifying the WASM guest"
WASM=""
if [[ -f "$ROOT/zcred-kernel/Cargo.toml" && -x "$(command -v cargo 2>/dev/null)" ]]; then
  echo "Building WASM from kernel source ($ROOT/zcred-kernel)..."
  cargo test --manifest-path "$ROOT/zcred-kernel/Cargo.toml" --quiet
  cargo build --manifest-path "$ROOT/zcred-kernel/Cargo.toml" --target wasm32-unknown-unknown --release --lib --quiet
  WASM="$ROOT/zcred-kernel/target/wasm32-unknown-unknown/release/zcred_kernel.wasm"
elif [[ -f "$ROOT/../zcred-kernel/Cargo.toml" && -x "$(command -v cargo 2>/dev/null)" ]]; then
  echo "Building WASM from parent kernel source ($ROOT/../zcred-kernel)..."
  cargo test --manifest-path "$ROOT/../zcred-kernel/Cargo.toml" --quiet
  cargo build --manifest-path "$ROOT/../zcred-kernel/Cargo.toml" --target wasm32-unknown-unknown --release --lib --quiet
  WASM="$ROOT/../zcred-kernel/target/wasm32-unknown-unknown/release/zcred_kernel.wasm"
elif [[ -f "$ROOT/artifacts/zcred_kernel.wasm" ]]; then
  echo "Using pre-built kernel artifact ($ROOT/artifacts/zcred_kernel.wasm)..."
  WASM="$ROOT/artifacts/zcred_kernel.wasm"
elif [[ -f "$ROOT/../zcred-kernel/target/wasm32-unknown-unknown/release/zcred_kernel.wasm" ]]; then
  WASM="$ROOT/../zcred-kernel/target/wasm32-unknown-unknown/release/zcred_kernel.wasm"
fi
[[ -n "$WASM" && -f "$WASM" ]] || vela_die "WASM artifact was not found (looked for source in zcred-kernel and pre-built in artifacts/)"
WASM_SHA="$(shasum -a 256 "$WASM" | awk '{print $1}')"
WASM_SIZE="$(wc -c < "$WASM" | tr -d ' ')"
echo "WASM: $WASM ($WASM_SIZE bytes, sha256:$WASM_SHA)"
pause

log_step "3/8" "Uploading the exact WASM artifact to Authority Service"
UPLOAD_RESPONSE="$(curl --fail --silent --show-error -X POST -F "wasm=@$WASM" "$VELA_AUTHORITY_URL/deploy/upload")"
echo "$UPLOAD_RESPONSE" | tee "$TMP_DIR/upload.json"
# Do not continue if Authority Service returned a different measurement.
UPLOAD_SHA="$(python3 - "$UPLOAD_RESPONSE" <<'PY'
import json, sys
try:
    value = json.loads(sys.argv[1])
except Exception:
    value = {}
print(value.get("wasmSha256", value.get("sha256", "")))
PY
)"
if [[ -n "$UPLOAD_SHA" ]]; then
  UPLOAD_SHA="${UPLOAD_SHA#0x}"
  UPLOAD_SHA_LOWER="$(echo "$UPLOAD_SHA" | tr '[:upper:]' '[:lower:]')"
  WASM_SHA_LOWER="$(echo "$WASM_SHA" | tr '[:upper:]' '[:lower:]')"
  [[ "$UPLOAD_SHA_LOWER" == "$WASM_SHA_LOWER" ]] || vela_die "Authority Service hash mismatch: uploaded $UPLOAD_SHA, local $WASM_SHA"
fi
pause

# Deploy a registry and trigger that point at the *actual* Vela contracts.
deploy_contract() {
  local contract="$1"
  shift
  local contracts_dir="$ROOT/contracts"
  if [[ -d "$ROOT/zcred-contracts" ]]; then
    contracts_dir="$ROOT/zcred-contracts"
  elif [[ -d "$ROOT/../zcred-contracts" ]]; then
    contracts_dir="$ROOT/../zcred-contracts"
  fi
  local rel_path="src/${contract}.sol"
  if [[ ! -f "$contracts_dir/$rel_path" && -f "$contracts_dir/src/mocks/${contract}.sol" ]]; then
    rel_path="src/mocks/${contract}.sol"
  fi
  local result address
  if [[ $# -gt 0 ]]; then
    result="$(forge create --root "$contracts_dir" --broadcast --json \
      --rpc-url "$VELA_RPC_URL" --private-key "$DEPLOYER_KEY" \
      "${rel_path}:${contract}" --constructor-args "$@")"
  else
    result="$(forge create --root "$contracts_dir" --broadcast --json \
      --rpc-url "$VELA_RPC_URL" --private-key "$DEPLOYER_KEY" \
      "${rel_path}:${contract}")"
  fi
  address="$(python3 - "$result" <<'PY'
import json, sys
value = json.loads(sys.argv[1])
print(value.get("deployedTo", value.get("deployed_to", "")))
PY
)"
  [[ "$address" =~ ^0x[0-9a-fA-F]{40}$ ]] || vela_die "failed to deploy $contract: $result"
  printf '%s\n' "$address"
}

log_step "4/8" "Deploying Zcred registry, Vela trigger, and demo lending gate"
AUTH="$(deploy_contract TeeAuthenticator "$DEPLOYER" false "$SIGNER_ADDRESS")"
REGISTRY="$(deploy_contract ZcredRegistry "$AUTH")"
TRIGGER="$(deploy_contract VelaZcredTrigger "$PROCESSOR" "$REGISTRY" "$DEPLOYER")"
NOCT="$(deploy_contract MockNoctLendingPool "$REGISTRY")"
vela_assert_address "TeeAuthenticator" "$AUTH"
vela_assert_address "ZcredRegistry" "$REGISTRY"
vela_assert_address "VelaZcredTrigger" "$TRIGGER"
vela_assert_address "Demo lending gate" "$NOCT"
echo "TeeAuthenticator: $AUTH"
echo "ZcredRegistry: $REGISTRY"
echo "VelaZcredTrigger: $TRIGGER"
echo "Demo lending gate: $NOCT"
pause

log_step "5/8" "Submitting a Vela DEPLOYAPP request with local-only key material"
# In this Docker emulator the guest state contains the fixed executor keys so
# the custom app event can be signed. This descriptor must never be used on a
# public network: its values are visible in the on-chain deploy payload.
NOW="$(date +%s)"
DESCRIPTOR="$(python3 - "$WASM_SHA" "$CHAIN_ID" "$REGISTRY" "$P521_KEY" "$SIGNER_KEY" "$NOW" <<'PY'
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
)"
DESCRIPTOR_HEX="0x$(printf '%s' "$DESCRIPTOR" | xxd -p -c 100000)"
AVAILABLE_SLOTS=$(cast call "$PROCESSOR" "availableDeploySlots()(uint256)" --rpc-url "$VELA_RPC_URL" 2>/dev/null || echo "10")
if [ "${AVAILABLE_SLOTS:-0}" -le 1 ]; then
  CURRENT_MAX=$(cast call "$PROCESSOR" "maxNumOfApplications()(uint256)" --rpc-url "$VELA_RPC_URL" 2>/dev/null || echo "10")
  NEW_MAX=$(( CURRENT_MAX + 50 ))
  vela_log "deploy slots low (${AVAILABLE_SLOTS} remaining), expanding maxNumOfApplications to ${NEW_MAX}"
  cast send "$PROCESSOR" "updateMaxNumOfApplications(uint256)" "$NEW_MAX" \
    --rpc-url "$VELA_RPC_URL" --private-key "$DEPLOYER_KEY" >/dev/null 2>&1 || true
fi

FEE="${FEE:-1000}"
DEPLOY_JSON="$(cast send "$PROCESSOR" \
  "submitDeployRequestWithTrigger(uint8,bytes,address)" 0 "$DESCRIPTOR_HEX" "$TRIGGER" \
  --value "$FEE" --rpc-url "$VELA_RPC_URL" --private-key "$DEPLOYER_KEY" --json)"
DEPLOY_TX="$(printf '%s' "$DEPLOY_JSON" | vela_tx_hash)"
[[ -n "$DEPLOY_TX" ]] || vela_die "deploy transaction hash missing: $DEPLOY_JSON"
DEPLOY_BLOCK="$(vela_receipt_block "$DEPLOY_TX")"
DEPLOY_SUBMITTED_TOPIC="$(cast keccak 'DeployRequestSubmitted(uint64,bytes32,address)')"
DEPLOY_RECEIPT="$(cast receipt "$DEPLOY_TX" --rpc-url "$VELA_RPC_URL" --json)"
APP_ID="$(python3 - "$DEPLOY_RECEIPT" "$DEPLOY_SUBMITTED_TOPIC" <<'PY'
import json, sys
receipt, topic = json.loads(sys.argv[1]), sys.argv[2].lower()
for log in receipt.get("logs", []):
    topics = [str(x).lower() for x in log.get("topics", [])]
    if topics and topics[0] == topic and len(topics) > 1:
        print(str(int(topics[1], 16)))
        break
PY
)"
[[ -n "$APP_ID" ]] || vela_die "could not decode application id from DeployRequestSubmitted"
echo "DEPLOYAPP tx: $DEPLOY_TX"
echo "Vela application id: $APP_ID"

# Wait for Manager -> Executor -> stateUpdate, and fail on an on-chain error.
wait_for_completion() {
  local topic="$1" request_topic="$2" label="$3" from_block="$4"
  local i logs status
  for ((i = 1; i <= 90; i++)); do
    logs="$(cast logs --json --address "$PROCESSOR" --from-block "$from_block" --to-block latest 2>/dev/null || echo '[]')"
    status="$(python3 - "$logs" "$topic" "$request_topic" "$APP_ID" <<'PY'
import json, sys
logs = json.loads(sys.argv[1]); completion = sys.argv[2].lower(); request_id = sys.argv[3].lower(); app_id = int(sys.argv[4])
for log in logs:
    topics = [str(x).lower() for x in log.get("topics", [])]
    if len(topics) < 2 or topics[0] != completion or int(topics[1], 16) != app_id:
        continue
    # For RequestCompleted the request id is indexed topic[2]. For deploy it
    # is not indexed and is the first word of data; both cases are supported.
    if len(topics) > 2 and topics[2] != request_id:
        continue
    data = str(log.get("data", "0x"))[2:]
    words = [data[i:i+64] for i in range(0, len(data), 64)]
    # Deploy completion has a non-indexed requestId: fee, status are words
    # 1 and 2. Normal completion indexes requestId: fee, status are words
    # 0 and 1.
    status_word = 2 if len(topics) == 2 else 1
    if len(words) > status_word:
        print(str(int(words[status_word], 16)))
    else:
        print("unknown")
    break
PY
)"
    if [[ "$status" == "0" ]]; then echo "$label completed"; return 0; fi
    if [[ "$status" =~ ^[1-9] ]]; then vela_die "$label failed on-chain (status/error): $status"; fi
    sleep 2
  done
  vela_die "$label did not complete; inspect: vela_compose logs manager executor"
}

DEPLOY_COMPLETED_TOPIC="$(cast keccak 'DeployRequestCompleted(uint64,bytes32,uint256,uint8,uint8,string)')"
# The deploy request id is the first non-indexed word in DeployRequestSubmitted.
DEPLOY_REQUEST_ID="$(python3 - "$DEPLOY_RECEIPT" "$DEPLOY_SUBMITTED_TOPIC" <<'PY'
import json, sys
receipt, topic = json.loads(sys.argv[1]), sys.argv[2].lower()
for log in receipt.get("logs", []):
    topics = [str(x).lower() for x in log.get("topics", [])]
    if topics and topics[0] == topic:
        print(str(log.get("data", "0x"))[0:66])
        break
PY
)"
wait_for_completion "$DEPLOY_COMPLETED_TOPIC" "$DEPLOY_REQUEST_ID" "DEPLOYAPP" "$DEPLOY_BLOCK"
pause

log_step "6/8" "Registering the client P-521 key with Vela"
if [[ ! -x "$ROOT/tools/encrypt_payload/zcred-encrypt" ]]; then
  (cd "$ROOT/tools/encrypt_payload" && go build -o zcred-encrypt .)
fi
RISKX_PAYLOAD="$(python3 - "$NOW" <<'PY'
import json, sys
now = int(sys.argv[1])
print(json.dumps({
  "user_secret": [171] * 32,
  "liquid_net_worth_usd": 75000,
  "consecutive_monthly_inflows": 12,
  "annual_inflow_usd": 120000,
  "total_liabilities_usd": 20000,
  "successful_repayments": 5,
  "total_historical_loans": 5,
  "liquidation_count": 0,
  "overdraft_count": 0,
  "policyId": 1,
  "dappDomain": "lending.protocol.eth",
  "now": now,
}, separators=(",", ":")))
PY
)"
EXECUTOR_PUB_HEX="${P521_PUBLIC#0x}" "$ROOT/tools/encrypt_payload/zcred-encrypt" "$RISKX_PAYLOAD" \
  >"$TMP_DIR/encrypted_payload" 2>"$TMP_DIR/encryption_meta"
USER_PUB="$(awk -F= '/^USER_PUB_HEX=/{print $2}' "$TMP_DIR/encryption_meta" | tr -d '\r\n')"
ENCRYPTED="$(cat "$TMP_DIR/encrypted_payload")"
[[ "${#USER_PUB}" -eq 268 && "$USER_PUB" == 0x* ]] || vela_die "native Vela client public key is not 133 bytes"
ASSOC_JSON="$(cast send "$PROCESSOR" \
  "submitRequest(uint8,uint64,uint8,bytes,address,uint256,uint256)" 0 "$APP_ID" 3 "$USER_PUB" \
  0x0000000000000000000000000000000000000000 0 "$FEE" \
  --value "$FEE" --rpc-url "$VELA_RPC_URL" --private-key "$DEPLOYER_KEY" --json)"
ASSOC_TX="$(printf '%s' "$ASSOC_JSON" | vela_tx_hash)"
ASSOC_BLOCK="$(vela_receipt_block "$ASSOC_TX")"
ASSOC_TOPIC="$(cast keccak 'RequestSubmitted(uint64,bytes32,address,address)')"
ASSOC_REQUEST_ID="$(python3 - "$ASSOC_JSON" "$ASSOC_TOPIC" <<'PY'
import json, sys
receipt = json.loads(sys.argv[1])
for log in receipt.get("logs", []):
    topics = [str(x).lower() for x in log.get("topics", [])]
    if topics and topics[0] == sys.argv[2].lower() and len(topics) > 2:
        print(topics[2])
        break
PY
)"
[[ -n "$ASSOC_REQUEST_ID" ]] || vela_die "could not decode ASSOCIATEKEY request id"
ASSOC_COMPLETED_TOPIC="$(cast keccak 'RequestCompleted(uint64,bytes32,uint256,uint8,uint8,string)')"
wait_for_completion "$ASSOC_COMPLETED_TOPIC" "$ASSOC_REQUEST_ID" "ASSOCIATEKEY" "$ASSOC_BLOCK"
echo "ASSOCIATEKEY tx: $ASSOC_TX"
pause

log_step "7/8" "Submitting the encrypted RiskX PROCESS request to Vela"
PROCESS_HEX="$(cat "$TMP_DIR/encrypted_payload" | tr -d '\r\n')"
if [[ "$PROCESS_HEX" != 0x* ]]; then
  PROCESS_HEX="0x$PROCESS_HEX"
fi
PROCESS_JSON="$(cast send "$PROCESSOR" \
  "submitRequest(uint8,uint64,uint8,bytes,address,uint256,uint256)" 0 "$APP_ID" 1 "$PROCESS_HEX" \
  0x0000000000000000000000000000000000000000 0 "$FEE" \
  --value "$FEE" --rpc-url "$VELA_RPC_URL" --private-key "$DEPLOYER_KEY" --json)"
PROCESS_TX="$(printf '%s' "$PROCESS_JSON" | vela_tx_hash)"
PROCESS_BLOCK="$(vela_receipt_block "$PROCESS_TX")"
PROCESS_REQUEST_ID="$(python3 - "$PROCESS_JSON" "$ASSOC_TOPIC" <<'PY'
import json, sys
receipt = json.loads(sys.argv[1])
for log in receipt.get("logs", []):
    topics = [str(x).lower() for x in log.get("topics", [])]
    if topics and topics[0] == sys.argv[2].lower() and len(topics) > 2:
        print(topics[2])
        break
PY
)"
[[ -n "$PROCESS_REQUEST_ID" ]] || vela_die "could not decode PROCESS request id"
wait_for_completion "$ASSOC_COMPLETED_TOPIC" "$PROCESS_REQUEST_ID" "PROCESS" "$PROCESS_BLOCK"
echo "PROCESS tx: $PROCESS_TX"
pause

log_step "8/8" "Verifying the attestation and exercising the lending gate"
if [[ -d "$ROOT/zcred-sdk" ]]; then
  NULLIFIER="$(USER_SECRET_JSON='[171,171,171,171,171,171,171,171,171,171,171,171,171,171,171,171,171,171,171,171,171,171,171,171,171,171,171,171,171,171,171,171]' \
    POLICY_ID=1 DAPP_DOMAIN=lending.protocol.eth \
    pnpm --dir "$ROOT/zcred-sdk" exec tsx src/deriveNullifierCli.ts)"
elif [[ -d "$ROOT/../zcred-sdk" ]]; then
  NULLIFIER="$(USER_SECRET_JSON='[171,171,171,171,171,171,171,171,171,171,171,171,171,171,171,171,171,171,171,171,171,171,171,171,171,171,171,171,171,171,171,171]' \
    POLICY_ID=1 DAPP_DOMAIN=lending.protocol.eth \
    pnpm --dir "$ROOT/../zcred-sdk" exec tsx src/deriveNullifierCli.ts)"
else
  # Native fallback via cast keccak: keccak256(user_secret || policy_id || dapp_domain)
  SECRET_HEX="abababababababababababababababababababababababababababababababab"
  DOMAIN_HEX="$(printf '%s' "lending.protocol.eth" | xxd -p | tr -d '\r\n')"
  NULLIFIER="$(cast keccak "0x${SECRET_HEX}01${DOMAIN_HEX}")"
fi
ATTESTATION="$(cast call "$REGISTRY" "getAttestation(uint8,bytes32)(bool,uint8,bytes32,uint64)" \
  1 "$NULLIFIER" --rpc-url "$VELA_RPC_URL")"
echo "Registry: $REGISTRY"
echo "Nullifier: $NULLIFIER"
echo "$ATTESTATION"
echo "$ATTESTATION" | head -n 1 | grep -qi true || vela_die "attestation was not recorded by Vela trigger"

echo "Depositing 1.0 ETH collateral into Noct Finance pool..."
cast send "$NOCT" "depositCollateral()" --value 1000000000000000000 \
  --rpc-url "$VELA_RPC_URL" --private-key "$DEPLOYER_KEY" >/dev/null

TERMS="$(cast call "$NOCT" "getBorrowingTerms(address,bytes32)(uint256,uint8,uint256)" \
  "$DEPLOYER" "$NULLIFIER" --rpc-url "$VELA_RPC_URL")"
MAX_BORROW="$(printf '%s\n' "$TERMS" | sed -n '1p' | awk '{print $1}')"
TIER="$(printf '%s\n' "$TERMS" | sed -n '2p' | awk '{print $1}')"
RATIO="$(printf '%s\n' "$TERMS" | sed -n '3p' | awk '{print $1}')"
echo "Lending terms: tier=$TIER maxBorrow=$MAX_BORROW wei (0.952 ETH) collateralBps=$RATIO (105% Collateral Drag)"

# Draw 0.90 ETH loan (would fail under 140% traditional DeFi, succeeds under 105% Zcred tier)
BORROW_AMOUNT="900000000000000000"
echo "Drawing undercollateralized loan: 0.90 ETH against 1.0 ETH collateral..."
BORROW_JSON="$(cast send "$NOCT" "borrow(bytes32,uint256)" "$NULLIFIER" "$BORROW_AMOUNT" \
  --rpc-url "$VELA_RPC_URL" --private-key "$DEPLOYER_KEY" --json)"
echo "Borrow tx: $(printf '%s' "$BORROW_JSON" | vela_tx_hash)"

echo
printf '\033[1;32m%s\033[0m\n' 'DEFI DEMO PASSED: native Vela protocol -> WASM -> AppEvent -> ZcredRegistry -> lending gate'
echo 'Execution mode: Vela Docker emulator (not AWS Nitro hardware)'
echo 'For Nitro/testnet use the production runbook; never reuse the local fixed-key descriptor.'
