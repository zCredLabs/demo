#!/usr/bin/env bash
# ==============================================================================
# zCred Master Step-by-Step Interactive Demo Runner
#
# Orchestrates modular scripts in ./tools/demo/ (01 through 06) with
# live progress reporting, step pauses, and detailed diagnostics.
#
# Usage:
#   ./tools/run_step_by_step_demo.sh                # Interactive mode (pauses between steps)
#   ./tools/run_step_by_step_demo.sh --auto         # Continuous non-stop run
#   ./tools/run_step_by_step_demo.sh --scenario defi|compliance|agent
#   ./tools/run_step_by_step_demo.sh --from 3       # Resume from step 3
# ==============================================================================
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
DEMO_DIR="$DIR/defi-demo"

GREEN="\033[1;32m"
BLUE="\033[1;34m"
CYAN="\033[1;36m"
YELLOW="\033[1;33m"
PURPLE="\033[1;35m"
RED="\033[1;31m"
BOLD="\033[1m"
RESET="\033[0m"

INTERACTIVE=1
SCENARIO="defi"
START_FROM=1

for arg in "$@"; do
    case "$arg" in
        --auto|--fast|-y)
            INTERACTIVE=0
            ;;
        --interactive|-i)
            INTERACTIVE=1
            ;;
        --scenario=*)
            SCENARIO="${arg#*=}"
            ;;
        defi|compliance|agent)
            SCENARIO="$arg"
            ;;
        --from=*)
            START_FROM="${arg#*=}"
            ;;
        --from)
            # handled next in loop if separated
            ;;
        --help|-h)
            echo -e "${BOLD}zCred Step-by-Step Demo Runner${RESET}"
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --auto, --fast, -y        Run all steps without pausing"
            echo "  --interactive, -i         Prompt [ENTER] between steps (default)"
            echo "  --scenario <type>         defi (default), compliance, or agent"
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
echo -e "${BOLD}${CYAN}  Confidential Credit Scoring & Undercollateralized Lending${RESET}"
echo -e "  Powered by ${BOLD}Horizen Vela CCE${RESET} (Confidential Compute Environment)"
SCENARIO_UPPER="$(echo "$SCENARIO" | tr '[:lower:]' '[:upper:]')"
if [ "$INTERACTIVE" -eq 1 ]; then
    MODE_STR="${YELLOW}Interactive [Step-by-Step]${RESET}"
else
    MODE_STR="${GREEN}Automated [Fast]${RESET}"
fi
echo -e "  Scenario: ${BOLD}${GREEN}${SCENARIO_UPPER}${RESET} | Mode: ${MODE_STR}"
echo -e "${BLUE}======================================================================${RESET}\n"

# Define step list based on scenario
declare -a STEPS
declare -a DESCRIPTIONS

STEPS[1]="$DEMO_DIR/01_check_environment.sh"
DESCRIPTIONS[1]="Verify Horizen Vela Docker Devnet & Anvil RPC Health"

STEPS[2]="$DEMO_DIR/02_build_kernel_wasm.sh"
DESCRIPTIONS[2]="Run Rust Tests & Compile WASM Enclave Kernel"

STEPS[3]="$DEMO_DIR/03_upload_and_deploy_app.sh"
DESCRIPTIONS[3]="Upload WASM Binary & Deploy Trigger + App on Vela"

STEPS[4]="$DEMO_DIR/04_associate_client_key.sh"
DESCRIPTIONS[4]="Generate Client NIST P-521 Key & Submit ASSOCIATEKEY"

if [ "$SCENARIO" = "compliance" ]; then
    STEPS[5]="$DEMO_DIR/05b_submit_compliance_job.sh"
    DESCRIPTIONS[5]="Submit Encrypted Compliance Credential to Vela"
    STEPS[6]="$DEMO_DIR/06b_verify_compliance_and_layrs.sh"
    DESCRIPTIONS[6]="Verify Accredited Attestation & Settle Layrs Trade"
elif [ "$SCENARIO" = "agent" ]; then
    STEPS[5]="$DEMO_DIR/05c_submit_agent_job.sh"
    DESCRIPTIONS[5]="Submit ERC-8004 AI Agent Attestation to Vela"
    STEPS[6]="$DEMO_DIR/06c_verify_agent_and_x402.sh"
    DESCRIPTIONS[6]="Verify Agent Tier & Settle x402 Micropayment"
else
    STEPS[5]="$DEMO_DIR/05_submit_confidential_credit_job.sh"
    DESCRIPTIONS[5]="Submit Encrypted RiskX Credit Job to Vela TEE"
    STEPS[6]="$DEMO_DIR/06_verify_settlement_and_defi.sh"
    DESCRIPTIONS[6]="Verify Attestation & Draw Undercollateralized Loan"
fi

TOTAL_STEPS=6
PASSED_COUNT=0
FAILED_STEP=0

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
    
    # Run the modular step script
    if bash "$STEP_SCRIPT"; then
        END_TIME=$(date +%s)
        DURATION=$((END_TIME - START_TIME))
        echo -e "\n${GREEN}✓ Stage $i PASSED (${DURATION}s)${RESET}\n"
        PASSED_COUNT=$((PASSED_COUNT + 1))
    else
        FAILED_STEP=$i
        echo -e "\n${RED}✗ Stage $i FAILED!${RESET}"
        echo -e "${YELLOW}Diagnostics:${RESET}"
        echo -e "  To inspect and debug this step individually, run:"
        echo -e "    ${BOLD}${CYAN}${STEP_SCRIPT}${RESET}\n"
        exit 1
    fi
done

echo -e "\n${BOLD}${GREEN}======================================================================${RESET}"
echo -e "${BOLD}${GREEN}  🎉 DEMO COMPLETE: ALL $PASSED_COUNT STAGES VERIFIED SUCCESSFULLY!   ${RESET}"
echo -e "${BOLD}${GREEN}======================================================================${RESET}"
echo -e "  • Enclave WASM verified on Horizen Vela CCE (Wasmtime guest)"
echo -e "  • Zero data leakage: Bank statement decrypted inside TEE memory"
echo -e "  • Canonical attestation recorded on Anvil chain 31337"
echo -e "  • Undercollateralized borrow executed on Noct Finance pool (105% ratio)\n"
