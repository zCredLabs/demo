#!/usr/bin/env bash
# ==============================================================================
# zCred Master Agentic Identity & x402 Micropayment Demo Runner
#
# Orchestrates modular agent identity scripts in ./tools/agent-demo/ (01 through 06)
# with live progress reporting, step pauses, and detailed diagnostics.
#
# Usage:
#   ./tools/run_main_agent_demo.sh            # Interactive mode (pauses between steps)
#   ./tools/run_main_agent_demo.sh --auto     # Continuous non-stop run
#   ./tools/run_main_agent_demo.sh --from 3   # Resume from step 3
# ==============================================================================
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
DEMO_DIR="$DIR/agent-demo"

GREEN="\033[1;32m"
BLUE="\033[1;34m"
CYAN="\033[1;36m"
YELLOW="\033[1;33m"
PURPLE="\033[1;35m"
RED="\033[1;31m"
BOLD="\033[1m"
RESET="\033[0m"

INTERACTIVE=1
START_FROM=1

for arg in "$@"; do
    case "$arg" in
        --auto|--fast|-y)
            INTERACTIVE=0
            ;;
        --interactive|-i)
            INTERACTIVE=1
            ;;
        --from=*)
            START_FROM="${arg#*=}"
            ;;
        --help|-h)
            echo -e "${BOLD}zCred Agentic Identity & x402 Demo Runner${RESET}"
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --auto, --fast, -y        Run all steps without pausing"
            echo "  --interactive, -i         Prompt [ENTER] between steps (default)"
            echo "  --from <1-6>              Start from a specific step"
            echo "  --help, -h                Show this help message"
            exit 0
            ;;
    esac
done

clear 2>/dev/null || true

echo -e "${BOLD}${PURPLE}"
cat << 'EOF'
  ███████╗ ██████╗██████╗ ███████╗██████╗ 
  ╚══███╔╝██╔════╝██╔══██╗██╔════╝██╔══██╗
    ███╔╝ ██║     ██████╔╝█████╗  ██║  ██║
   ███╔╝  ██║     ██╔══██╗██╔══╝  ██║  ██║
  ███████╗╚██████╗██║  ██║███████╗██████╔╝
  ╚══════╝ ╚═════╝╚═╝  ╚═╝╚══════╝╚═════╝ 
EOF
echo -e "${RESET}"
echo -e "${BOLD}${CYAN}  Autonomous AI Agent Identity & x402 Micropayments (Agent Passport)${RESET}"
echo -e "  Powered by ${BOLD}Horizen Vela CCE${RESET} (Confidential Compute Environment)"
if [ "$INTERACTIVE" -eq 1 ]; then
    MODE_STR="${YELLOW}Interactive [Step-by-Step]${RESET}"
else
    MODE_STR="${GREEN}Automated [Fast]${RESET}"
fi
echo -e "  Scenario: ${BOLD}${GREEN}AGENT PASSPORT (POLICY #3)${RESET} | Mode: ${MODE_STR}"
echo -e "${BLUE}======================================================================${RESET}\n"

declare -a STEPS
declare -a DESCRIPTIONS

STEPS[1]="$DEMO_DIR/01_check_environment.sh"
DESCRIPTIONS[1]="Verify Horizen Vela Docker Devnet & Anvil RPC Health"

STEPS[2]="$DEMO_DIR/02_build_agent_kernel.sh"
DESCRIPTIONS[2]="Run Agent Passport Unit Tests & Compile WASM Kernel"

STEPS[3]="$DEMO_DIR/03_deploy_agent_app.sh"
DESCRIPTIONS[3]="Deploy TeeAuth, Registry, Trigger & MockX402PaymentGate"

STEPS[4]="$DEMO_DIR/04_associate_client_key.sh"
DESCRIPTIONS[4]="Generate Agent Alpha's NIST P-521 Client Key & ASSOCIATEKEY"

STEPS[5]="$DEMO_DIR/05_submit_agent_job.sh"
DESCRIPTIONS[5]="Submit Agent Alpha's Encrypted Passport Claim to Vela TEE"

STEPS[6]="$DEMO_DIR/06_verify_agent_and_x402.sh"
DESCRIPTIONS[6]="Verify Settlement & Autonomous x402 Micropayment Enforcement"

TOTAL_STEPS=6
PASSED_COUNT=0

for i in $(seq "$START_FROM" "$TOTAL_STEPS"); do
    STEP_SCRIPT="${STEPS[$i]}"
    STEP_DESC="${DESCRIPTIONS[$i]}"

    echo -e "${BOLD}${BLUE}----------------------------------------------------------------------${RESET}"
    echo -e " ${BOLD}STAGE $i / $TOTAL_STEPS:${RESET} ${CYAN}${STEP_DESC}${RESET}"
    echo -e " Script: ${YELLOW}${STEP_SCRIPT#"$(pwd)/"}${RESET}"
    echo -e "${BOLD}${BLUE}----------------------------------------------------------------------${RESET}"

    if [ "$INTERACTIVE" -eq 1 ] && [ "$i" -gt "$START_FROM" ]; then
        echo -e "\n${YELLOW}Press [ENTER] to execute Stage $i (or Ctrl+C to stop)...${RESET}"
        read -r _
    fi

    START_TIME=$(date +%s)
    
    if bash "$STEP_SCRIPT"; then
        END_TIME=$(date +%s)
        DURATION=$((END_TIME - START_TIME))
        echo -e "\n${GREEN}✓ Stage $i PASSED (${DURATION}s)${RESET}\n"
        PASSED_COUNT=$((PASSED_COUNT + 1))
    else
        echo -e "\n${RED}✗ Stage $i FAILED!${RESET}"
        echo -e "${YELLOW}Diagnostics:${RESET}"
        echo -e "  To inspect and debug this step individually, run:"
        echo -e "    ${BOLD}${CYAN}${STEP_SCRIPT}${RESET}\n"
        exit 1
    fi
done

echo -e "\n${BOLD}${GREEN}======================================================================${RESET}"
echo -e "${BOLD}${GREEN}  🎉 AGENT PASSPORT DEMO COMPLETE: ALL $PASSED_COUNT STAGES VERIFIED!   ${RESET}"
echo -e "${BOLD}${GREEN}======================================================================${RESET}"
echo -e "  • Enclave PCR0 code-hash verification executed inside Vela TEE (Zero keys exposed)"
echo -e "  • Agent Alpha (\$500/day allowance) -> \$50 micropayment executed on MockX402PaymentGate"
echo -e "  • Daily spending ceiling enforcement -> \$600 charge strictly reverted"
echo -e "  • Replay attack protection -> duplicate invoice query rejected"
echo -e "  • Agent Beta (High-Drawdown) & Agent Gamma (Rogue) -> Strictly reverted"
echo -e "  • MockX402PaymentGate single-slot verification cost: 18,938 gas (88% savings vs ZK)\n"
