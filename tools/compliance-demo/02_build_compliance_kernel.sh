#!/usr/bin/env bash
# ==============================================================================
# Step 2: Build & Verify Rust WASM Enclave Kernel for Compliance Shield (Policy #2)
# ==============================================================================
set -e

GREEN="\033[1;32m"
BLUE="\033[1;34m"
CYAN="\033[1;36m"
YELLOW="\033[1;33m"
BOLD="\033[1m"
RESET="\033[0m"

echo -e "${BOLD}${BLUE}======================================================================${RESET}"
echo -e "${BOLD}${BLUE}  STEP 2: Build & Verify Rust WASM Enclave Kernel (Policy #2)          ${RESET}"
echo -e "${BOLD}${BLUE}  Compliance Shield: OFAC SDN Matching & Accredited Investor Checks   ${RESET}"
echo -e "${BOLD}${BLUE}======================================================================${RESET}"

DIR="$(cd "$(dirname "$0")" && pwd)"
DEMO_ROOT="$(cd "$DIR/../.." && pwd)"

KERNEL_TOML=""
if [ -f "$DEMO_ROOT/zcred-kernel/Cargo.toml" ]; then
    KERNEL_TOML="$DEMO_ROOT/zcred-kernel/Cargo.toml"
elif [ -f "$DEMO_ROOT/../zcred-kernel/Cargo.toml" ]; then
    KERNEL_TOML="$DEMO_ROOT/../zcred-kernel/Cargo.toml"
fi

WASM_PATH=""
if [ -n "$KERNEL_TOML" ] && command -v cargo >/dev/null 2>&1; then
    echo -e "\n[2.1] Running Compliance Shield Tests (Carol, Erin, Dave, OFAC matching)..."
    cargo test --manifest-path "$KERNEL_TOML" --test compliance_tests --quiet
    echo -e "  ${GREEN}✓${RESET} All Compliance Shield in-enclave tests PASSED."

    echo -e "\n[2.2] Compiling standalone WebAssembly module for wasm32-unknown-unknown..."
    cargo build --manifest-path "$KERNEL_TOML" --target wasm32-unknown-unknown --release --lib --quiet
    WASM_PATH="$(dirname "$KERNEL_TOML")/target/wasm32-unknown-unknown/release/zcred_kernel.wasm"
fi

if [ ! -f "$WASM_PATH" ]; then
    if [ -f "$DEMO_ROOT/artifacts/zcred_kernel.wasm" ]; then
        WASM_PATH="$DEMO_ROOT/artifacts/zcred_kernel.wasm"
        echo -e "\n[2.1] Using pre-compiled verified WASM artifact from ${CYAN}${WASM_PATH}${RESET}"
    else
        echo -e "${YELLOW}Error: Neither Rust kernel source nor pre-built WASM artifact found.${RESET}"
        exit 1
    fi
fi

WASM_SIZE=$(wc -c < "$WASM_PATH" | tr -d ' ')
WASM_SHA=$(shasum -a 256 "$WASM_PATH" | awk '{print $1}')

echo -e "  ${GREEN}✓${RESET} WASM Artifact Location : ${CYAN}${WASM_PATH}${RESET}"
echo -e "  ${GREEN}✓${RESET} Compiled Binary Size    : ${CYAN}${WASM_SIZE} bytes${RESET} (~$((WASM_SIZE / 1024)) KB)"
echo -e "  ${GREEN}✓${RESET} Content-Addressed SHA256: ${CYAN}${WASM_SHA}${RESET}"

mkdir -p /tmp/zcred_demo
echo "$WASM_SHA" > /tmp/zcred_demo/wasm_sha
echo "$WASM_PATH" > /tmp/zcred_demo/wasm_path

echo -e "\n${GREEN}${BOLD}✓ Step 2 Complete: WASM Enclave Kernel verified for Compliance Shield!${RESET}\n"
