#!/usr/bin/env bash
# ==============================================================================
# zCred Master Compliance & RWA Interactive Demo Runner
#
# Orchestrates modular compliance scripts in ./tools/compliance-demo/ (01 through 06)
# with live progress reporting, step pauses, and detailed diagnostics.
#
# Usage:
#   ./tools/run_main_compliance_demo.sh            # Interactive mode (pauses between steps)
#   ./tools/run_main_compliance_demo.sh --auto     # Continuous non-stop run
#   ./tools/run_main_compliance_demo.sh --from 3   # Resume from step 3
# ==============================================================================
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
DEMO_DIR="$DIR/compliance-demo"

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
            echo -e "${BOLD}zCred Compliance & RWA Demo Runner${RESET}"
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
echo -e "${BOLD}${CYAN}  Institutional Compliance Shield & Confidential Dark Pool (RWA)${RESET}"
echo -e "  Powered by ${BOLD}Horizen Vela CCE${RESET} (Confidential Compute Environment)"
if [ "$INTERACTIVE" -eq 1 ]; then
    MODE_STR="${YELLOW}Interactive [Step-by-Step]${RESET}"
else
    MODE_STR="${GREEN}Automated [Fast]${RESET}"
fi
echo -e "  Scenario: ${BOLD}${GREEN}COMPLIANCE SHIELD (POLICY #2)${RESET} | Mode: ${MODE_STR}"
echo -e "${BLUE}======================================================================${RESET}\n"

declare -a STEPS
declare -a DESCRIPTIONS

STEPS[1]="$DEMO_DIR/01_check_environment.sh"
DESCRIPTIONS[1]="Verify Horizen Vela Docker Devnet & Anvil RPC Health"

STEPS[2]="$DEMO_DIR/02_build_compliance_kernel.sh"
DESCRIPTIONS[2]="Run Compliance Shield Unit Tests & Compile WASM Kernel"

STEPS[3]="$DEMO_DIR/03_deploy_compliance_app.sh"
DESCRIPTIONS[3]="Deploy TeeAuth, Registry, Trigger & MockLayrsDarkPool"

STEPS[4]="$DEMO_DIR/04_associate_client_key.sh"
DESCRIPTIONS[4]="Generate Carol's NIST P-521 Client Key & ASSOCIATEKEY"

STEPS[5]="$DEMO_DIR/05_submit_compliance_job.sh"
DESCRIPTIONS[5]="Submit Carol's Encrypted Compliance Claim to Vela TEE"

STEPS[6]="$DEMO_DIR/06_verify_compliance_and_layrs.sh"
DESCRIPTIONS[6]="Verify Attestation & Layrs Dark Pool Spot vs RWA Gating"

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
echo -e "${BOLD}${GREEN}  🎉 COMPLIANCE DEMO COMPLETE: ALL $PASSED_COUNT STAGES VERIFIED!      ${RESET}"
echo -e "${BOLD}${GREEN}======================================================================${RESET}"
echo -e "  • Enclave OFAC SDN list matching executed inside Vela TEE (Zero PII leaked)"
echo -e "  • Carol (\$2.5M Accredited) -> Spot & Institutional RWA Trading Granted"
echo -e "  • Erin (\$50k Retail) -> Spot Granted, Institutional RWA Reverted"
echo -e "  • Dave (OFAC SDN Hit) -> Complete Reversion / Blacklisted"
echo -e "  • Layrs Dark Pool single-slot verification cost: 22,252 gas (92% savings vs ZK)\n"
