#!/usr/bin/env bash
# ==============================================================================
# Zcred Confidential Decisions — Demo 3: Agent Passport & x402 Micropayments
#
# Runs the complete end-to-end integration for Policy #3:
#   Stage 1: Verify Agent Passport Policy & Cryptographic Tests (Rust Kernel)
#   Stage 2: Submit Encrypted Agent Identity Claim to Vela TEE
#   Stage 3: Verify On-Chain x402 Micropayment Gate & Spend Cap Settlement
#   Stage 4: Verify SDK Integration & Cross-Domain Privacy Audit
#
# Flags:
#   --step-by-step, -s : Pauses and prompts before each stage (ideal for videos)
#   --help, -h         : Displays usage instructions
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

if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    echo "Usage: ./tools/run_agent_demo.sh [--step-by-step]"
    echo ""
    echo "Options:"
    echo "  --step-by-step, -s   Pause between stages with a prompt (ideal for live video narration)"
    echo "  --help, -h          Show this help message"
    exit 0
fi

echo -e "${BOLD}${PURPLE}"
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║          ZCRED × HORIZEN VELA: DEMO 3 — AGENT PASSPORT               ║"
# shellcheck disable=SC2028
echo "║          Autonomous AI Agent Identity & x402 Micropayments           ║"
echo "║   PCR0 Code Hash • Developer Spending Allowance • x402 Payment Gate  ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo -e "${RESET}"

if [ "$STEP_BY_STEP" = true ]; then
    echo -e "${YELLOW}Mode: Step-by-Step (Press ENTER to proceed through each stage)${RESET}\n"
else
    echo -e "${CYAN}Mode: Automated Continuous (Run with --step-by-step to pause for video recording)${RESET}\n"
fi

pause_prompt() {
    local stage_name="$1"
    if [ "$STEP_BY_STEP" = true ]; then
        echo -e "${YELLOW}▶ [Ready for: ${stage_name}] Press [ENTER] to execute...${RESET}"
        read -r
    fi
}

# --- Stage 1 ---
pause_prompt "Stage 1: Verify Agent Passport Rust Kernel Unit & Cryptographic Tests"
echo -e "\n${BOLD}${BLUE}Checking Rust Kernel Policy #3 Execution (zcred_kernel)...${RESET}"
cargo test --manifest-path zcred-kernel/Cargo.toml --test agent_tests -- --nocapture

# --- Stage 2 ---
pause_prompt "Stage 2: Submit Encrypted Agent Passport Claim to Vela TEE"
./tools/demo/05c_submit_agent_job.sh

# --- Stage 3 ---
pause_prompt "Stage 3: Verify x402 Micropayment Gate & On-Chain Settlement"
./tools/demo/06c_verify_agent_and_x402.sh

# --- Stage 4 ---
pause_prompt "Stage 4: Run @zcred/sdk Integration Test Suite"
echo -e "\n${BOLD}${BLUE}Verifying @zcred/sdk Integration Suite (Test 11 Agent Passport)...${RESET}"
pnpm --dir zcred-sdk test

echo -e "${BOLD}${GREEN}"
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║              DEMO 3 (AGENT PASSPORT) COMPLETE!                       ║"
echo "║                                                                      ║"
echo "║  • Agent Alpha (\$500/d) -> PCR0 Verified & \$50 Micropayment Granted  ║"
echo "║  • Spend Ceiling Enforcement -> \$600 Charge Strictly Reverted        ║"
echo "║  • Agent Beta (High-Freq) -> Blocked Due to 25% Drawdown Limit       ║"
echo "║  • Agent Gamma (Rogue) -> Rejected (Unrecognized Binary PCR0 Hash)   ║"
echo "║  • Single-Slot Read Gas Cost: 18,938 gas (< 26k Target)              ║"
echo "║  • Unlinkable Machine Passports Across API Gateways Verified         ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo -e "${RESET}"
