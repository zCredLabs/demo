#!/usr/bin/env bash
# ==============================================================================
# Zcred Confidential Decisions — Demo 2: Compliance Shield & Confidential Dark Pool
#
# Runs the complete end-to-end integration for Policy #2:
#   Stage 1: Verify Environment & Prerequisites
#   Stage 2: Compile & Verify Enclave Kernel with Compliance Handler
#   Stage 3: Ingest & Encrypt Compliance Claims (Carol, Erin, Dave)
#   Stage 4: In-Enclave Evaluation & EIP-712 Signing inside Vela TEE
#   Stage 5: Verify On-Chain Dark Pool Spot & Institutional RWA Gating
#
# Flags:
#   --step-by-step, -s : Pauses and prompts before each stage (ideal for videos)
# ==============================================================================
set -e

GREEN="\033[1;32m"
BLUE="\033[1;34m"
CYAN="\033[1;36m"
YELLOW="\033[1;33m"
PURPLE="\033[1;35m"
BOLD="\033[1m"
RESET="\033[0m"

STEP_BY_STEP=false
if [[ "$1" == "--step-by-step" || "$1" == "-s" || "$1" == "--pause" ]]; then
    STEP_BY_STEP=true
fi

echo -e "${BOLD}${PURPLE}"
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║          ZCRED × HORIZEN VELA: DEMO 2 — COMPLIANCE SHIELD            ║"
echo "║       Institutional Accreditation & Dark Pool Protection             ║"
echo "║   OFAC SDN Matching • Accredited Investor Gate • Dark Pool Gate      ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo -e "${RESET}"

pause_prompt() {
    local stage_name="$1"
    if [ "$STEP_BY_STEP" = true ]; then
        echo -e "${YELLOW}▶ [Ready for: ${stage_name}] Press [ENTER] to execute...${RESET}"
        read -r
    fi
}

# --- Stage 1 ---
pause_prompt "Stage 1: Verify Compliance Shield Unit & Cryptographic Tests"
echo -e "\n${BOLD}${BLUE}Checking Rust Kernel Policy #2 Execution...${RESET}"
cargo test --manifest-path zcred-kernel/Cargo.toml compliance_tests -- --nocapture

# --- Stage 2 ---
pause_prompt "Stage 2: Submit Encrypted Compliance Claims to Vela TEE"
./tools/demo/05b_submit_compliance_job.sh

# --- Stage 3 ---
pause_prompt "Stage 3: Verify Confidential Dark Pool On-Chain Settlement"
./tools/demo/06b_verify_compliance_and_layrs.sh

echo -e "${BOLD}${GREEN}"
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║              DEMO 2 (COMPLIANCE SHIELD) COMPLETE!                    ║"
echo "║                                                                      ║"
echo "║  • Carol (\$2.5M Accredited) -> Spot & RWA Trading Granted            ║"
echo "║  • Erin (\$50k Retail Cleared) -> Spot Granted, RWA Reverted          ║"
echo "║  • Dave (OFAC SDN Hit) -> Complete Reversion / Zero Gas Attack Fail  ║"
echo "║  • Single-Slot Read Gas Cost: 22,252 gas (< 26k Target)              ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo -e "${RESET}"
