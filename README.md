# zCred Demo & Judge Evaluation Hub

Interactive dApp frontend and turnkey evaluation testbed for **zCred**: Confidential Undercollateralized Lending & Credit Attestations powered by **Horizen Vela CCE** (Confidential Compute Environment).

---

## ⚡ Quickstart for Judges & Evaluators

You can evaluate zCred in two ways: through the **Interactive Web UI** or the **Automated End-to-End Terminal Demo**.

### 1. Interactive Web Application
Launch the frontend dashboard to simulate borrower flows, live encryption, and enclave proof generation:

```bash
pnpm install
pnpm dev
```
Open [http://localhost:5174](http://localhost:5174) in your browser.

---

### 2. Automated End-to-End TEE Demos (Vela Devnet)

Ensure your Horizen Vela Docker stack is running (from `vela-starterkit/dockerfiles` or run with `--start`):

```bash
# Run the canonical RiskX DeFi Undercollateralized Lending pipeline
pnpm demo:defi
# or directly:
./tools/run_defi_demo.sh
```

#### What `run_defi_demo.sh` verifies:
1. **[1/8] Environment Check**: Confirms Horizen Vela v0.2.0 containers are healthy.
2. **[2/8] WASM Artifact Verification**: Uses pre-compiled `artifacts/zcred_kernel.wasm` (or builds from Rust source).
3. **[3/8] Authority Service Upload**: Uploads guest WASM and asserts SHA-256 measurement.
4. **[4/8] Smart Contract Deployment**: Deploys `TeeAuthenticator`, `ZcredRegistry`, `VelaZcredTrigger`, and `MockCreditLendingPool`.
5. **[5/8] Vela Enclave App Deployment**: Dispatches `DEPLOYAPP` transaction to `ProcessorEndpoint`.
6. **[6/8] Ephemeral Client Key Association**: Dispatches `ASSOCIATEKEY` (NIST P-521 ephemeral public key).
7. **[7/8] Confidential Inference**: Encrypts Alice's bank statement via AES-GCM and submits `PROCESS` request.
8. **[8/8] Settlement & DeFi Borrow**: Verifies Tier 1 AAA attestation emitted by Vela, deposits collateral into MockCreditLendingPool, and draws an undercollateralized loan on-chain!

---

## 📂 Repository Structure

```text
zcred-demo/
├── artifacts/                  # Pre-compiled binaries for zero-friction evaluation
│   ├── zcred_kernel.wasm       # Compiled Vela TEE guest module (SHA-256 verified)
│   └── contracts/              # Pre-compiled ABIs and bytecodes
├── fixtures/                   # Deterministic test payloads
│   ├── alice_plaid_bank_data.json   # High liquidity / low liabilities -> Tier 1 (Score 780)
│   ├── bob_subprime_bank_data.json  # High overdrafts -> Tier 3 (Score 520)
│   ├── agent/                       # Autonomous AI agent attestation vectors
│   └── compliance/                  # Accredited investor KYC credentials
├── tools/                      # Automated Vela evaluation orchestrators
│   ├── run_defi_demo.sh        # Canonical 8-step DeFi undercollateralized lending demo
│   ├── run_agent_demo.sh       # ERC-8004 autonomous agent verification demo
│   ├── run_compliance_demo.sh  # Compliant dark-pool demo
│   ├── encrypt_payload/        # Client-side AES-GCM payload encryption CLI
│   ├── vela/common.sh          # Reusable RPC & container assertion utilities
├── src/                        # Vite + TypeScript + Viem frontend application
```

---

## 🔗 Related Repositories

- [zcred-kernel](https://github.com/zCredLabs/zcred-kernel): Pure Rust/WASM guest runtime executed inside Horizen Vela Wasmtime enclave.
- [contracts](https://github.com/zCredLabs/contracts): Foundry smart contracts, `TeeAuthenticator`, `ZcredRegistry`, and `VelaZcredTrigger`.
- [zcred-sdk](https://github.com/zCredLabs/zcred-sdk): TypeScript client SDK for integrating confidential credit scoring into external dApps.
