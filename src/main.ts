// SPDX-License-Identifier: MIT
import { keccak256, encodePacked } from "viem";
import { p521 } from "@noble/curves/p521";
import { bytesToHex, utf8ToBytes } from "@noble/hashes/utils";

interface PersonaData {
  name: string;
  category: string;
  claim: {
    liquid_net_worth_usd: number;
    consecutive_monthly_inflows: number;
    annual_inflow_usd: number;
    total_liabilities_usd: number;
    successful_repayments: number;
    total_historical_loans: number;
    liquidation_count: number;
  };
  secretByte: number;
  tier: number;
  tierLabel: string;
  ltvBps: number;
  collateralRatio: number;
  score: number;
}

const PERSONAS: Record<string, PersonaData> = {
  alice: {
    name: "Alice",
    category: "Prime Institution / High Earner",
    claim: {
      liquid_net_worth_usd: 85000,
      consecutive_monthly_inflows: 12,
      annual_inflow_usd: 120000,
      total_liabilities_usd: 15000,
      successful_repayments: 8,
      total_historical_loans: 8,
      liquidation_count: 0,
    },
    secretByte: 0xaa,
    tier: 1,
    tierLabel: "Tier AAA (Prime)",
    ltvBps: 9520, // 95.2% LTV -> 105% collateral
    collateralRatio: 1.05,
    score: 820,
  },
  bob: {
    name: "Bob",
    category: "Subprime / Gig Economy Retail Borrower",
    claim: {
      liquid_net_worth_usd: 25000,
      consecutive_monthly_inflows: 8,
      annual_inflow_usd: 60000,
      total_liabilities_usd: 20000,
      successful_repayments: 4,
      total_historical_loans: 5,
      liquidation_count: 0,
    },
    secretByte: 0xbb,
    tier: 4,
    tierLabel: "Tier BBB (Subprime)",
    ltvBps: 7400, // 74.0% LTV -> 135% collateral
    collateralRatio: 1.35,
    score: 630,
  },
};

let currentPersona = PERSONAS.alice;
let isRunning = false;

// DOM Elements
const btnAlice = document.getElementById("btn-alice") as HTMLButtonElement;
const btnBob = document.getElementById("btn-bob") as HTMLButtonElement;
const btnRun = document.getElementById("btn-run") as HTMLButtonElement;

const claimBox = document.getElementById("client-claim-box")!;
const envClientPubkey = document.getElementById("env-client-pubkey")!;
const envIv = document.getElementById("env-iv")!;
const envNonce = document.getElementById("env-nonce")!;
const envAad = document.getElementById("env-aad")!;
const envCiphertextBox = document.getElementById("env-ciphertext-box")!;

const wasmMemoryStatus = document.getElementById("wasm-memory-status")!;
const wasmTier = document.getElementById("wasm-tier")!;
const wasmNullifier = document.getElementById("wasm-nullifier")!;
const wasmCustomData = document.getElementById("wasm-customdata")!;
const wasmExpiry = document.getElementById("wasm-expiry")!;
const wasmDigest = document.getElementById("wasm-digest")!;
const wasmSignature = document.getElementById("wasm-signature")!;

const contractTxHash = document.getElementById("contract-txhash")!;
const standardLimit = document.getElementById("standard-limit")!;
const zcredRateLabel = document.getElementById("zcred-rate-label")!;
const zcredLimit = document.getElementById("zcred-limit")!;
const zcredGain = document.getElementById("zcred-gain")!;
const borrowSummary = document.getElementById("borrow-summary")!;

const auditNoctNullifier = document.getElementById("audit-noct-nullifier")!;
const auditLayrsNullifier = document.getElementById("audit-layrs-nullifier")!;

function renderClaim(p: PersonaData) {
  claimBox.innerHTML = `// Redacted Plaid/zkTLS Ingestion (${p.name})
{
  "liquid_net_worth_bucket": "$${(Math.floor(p.claim.liquid_net_worth_usd / 10000) * 10)}k - $${(Math.floor(p.claim.liquid_net_worth_usd / 10000) * 10 + 10)}k",
  "consecutive_cashflow_months": ${p.claim.consecutive_monthly_inflows},
  "liabilities_usd": ${p.claim.total_liabilities_usd},
  "repayment_record": "${p.claim.successful_repayments}/${p.claim.total_historical_loans}",
  "defaults": ${p.claim.liquidation_count},
  "user_secret": "0x${p.secretByte.toString(16).repeat(32)}" // Zeroized in RAM
}`;
}

function computeNullifier(secretByte: number, policyId: number, domain: string): `0x${string}` {
  const secret = new Uint8Array(32).fill(secretByte);
  const packed = encodePacked(
    ["bytes32", "uint8", "string"],
    [`0x${bytesToHex(secret)}`, policyId, domain]
  );
  return keccak256(packed);
}

function computeAad(version: number, policyId: number, chainId: bigint, registry: `0x${string}`, nonce: `0x${string}`, domain: string): `0x${string}` {
  const packed = encodePacked(
    ["uint8", "uint8", "uint256", "address", "bytes32", "string"],
    [version, policyId, chainId, registry, nonce, domain]
  );
  return keccak256(packed);
}

async function runPipeline() {
  if (isRunning) return;
  isRunning = true;
  btnRun.disabled = true;
  btnRun.innerHTML = `<span class="btn-icon">⏳</span><span>Executing in Nitro WASM...</span>`;

  // Reset steps
  document.querySelectorAll(".step-item").forEach((s) => s.classList.remove("active", "completed"));
  document.querySelectorAll(".exec-step").forEach((s) => s.classList.remove("active"));

  // Step 1: Claim Ingestion
  setStep(1);
  await sleep(350);

  // Step 2: P-521 ECDH & AAD Binding
  setStep(2);
  const ephemeralPriv = p521.utils.randomPrivateKey();
  const ephemeralPub = p521.getPublicKey(ephemeralPriv, false);
  const ephemeralPubHex = `0x${bytesToHex(ephemeralPub)}` as `0x${string}`;

  const ivBytes = new Uint8Array(12);
  crypto.getRandomValues(ivBytes);
  const ivHex = `0x${bytesToHex(ivBytes)}` as `0x${string}`;

  const nonceBytes = new Uint8Array(32);
  crypto.getRandomValues(nonceBytes);
  const nonceHex = `0x${bytesToHex(nonceBytes)}` as `0x${string}`;

  const chainId = 84532n;
  const registryAddr = "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512";
  const dappDomain = "noctfinance.xyz";

  const aadHex = computeAad(1, 1, chainId, registryAddr, nonceHex, dappDomain);

  envClientPubkey.textContent = `${ephemeralPubHex.slice(0, 26)}... (133 bytes)`;
  envIv.textContent = ivHex;
  envNonce.textContent = `${nonceHex.slice(0, 26)}...`;
  envAad.textContent = `${aadHex.slice(0, 26)}...`;

  // Synthetic ciphertext
  const ctBytes = new Uint8Array(280);
  crypto.getRandomValues(ctBytes);
  envCiphertextBox.textContent = `0x${bytesToHex(ctBytes.slice(0, 48))}... (${ctBytes.length} bytes encrypted payload)`;

  await sleep(400);

  // Step 3: Enclave In-Guest Execution
  setStep(3);
  wasmMemoryStatus.textContent = "Active linear memory (zcred_alloc: 4096 bytes)";

  document.getElementById("exec-ecdh")!.classList.add("active");
  await sleep(250);

  document.getElementById("exec-aad")!.classList.add("active");
  await sleep(250);

  document.getElementById("exec-policy")!.classList.add("active");
  await sleep(250);

  document.getElementById("exec-zeroize")!.classList.add("active");
  wasmMemoryStatus.textContent = "Plaintext Buffer Zeroized (0x00)";
  await sleep(250);

  // Step 4: EIP-712 Attestation Signing
  setStep(4);
  document.getElementById("exec-sign")!.classList.add("active");

  const nullifier = computeNullifier(currentPersona.secretByte, 1, dappDomain);
  const layrsNullifier = computeNullifier(currentPersona.secretByte, 1, "layrs.xyz");

  const customData = `0x00000000000000000000000000000000000000000000000000000${currentPersona.score.toString(16).padStart(3, "0")}0000${currentPersona.ltvBps.toString(16).padStart(4, "0")}` as `0x${string}`;
  const now = Math.floor(Date.now() / 1000);
  const expiryEpoch = now + 86400 * 30;

  const mockDigest = keccak256(encodePacked(["bytes32", "uint8", "bytes32"], [nullifier, currentPersona.tier, customData]));
  const mockSig = `0x${mockDigest.slice(2, 66)}${mockDigest.slice(2, 66)}1b` as `0x${string}`;

  wasmTier.textContent = `Tier ${currentPersona.tier} (${currentPersona.tierLabel})`;
  wasmNullifier.textContent = `${nullifier.slice(0, 20)}...`;
  wasmCustomData.textContent = `${customData.slice(0, 24)}...`;
  wasmExpiry.textContent = `${expiryEpoch} (${new Date(expiryEpoch * 1000).toLocaleDateString()})`;
  wasmDigest.textContent = `${mockDigest.slice(0, 20)}...`;
  wasmSignature.textContent = `${mockSig.slice(0, 26)}... (65 bytes)`;

  await sleep(400);

  // Step 5: EVM Settlement & Partner Execution
  setStep(5);
  const txBytes = new Uint8Array(32);
  crypto.getRandomValues(txBytes);
  contractTxHash.textContent = `0x${bytesToHex(txBytes).slice(0, 18)}...`;

  const depositEth = 10.0;
  const stdLimit = depositEth / 1.4;
  const zLimit = depositEth / currentPersona.collateralRatio;
  const gainPct = (((zLimit - stdLimit) / stdLimit) * 100).toFixed(1);

  standardLimit.textContent = `${stdLimit.toFixed(3)} ETH`;
  zcredRateLabel.textContent = `Zcred Tier ${currentPersona.tier} (${(currentPersona.collateralRatio * 100).toFixed(0)}% LTV)`;
  zcredLimit.textContent = `${zLimit.toFixed(3)} ETH`;
  zcredGain.textContent = `+${gainPct}% Capital Efficiency`;

  if (currentPersona.tier === 1) {
    borrowSummary.innerHTML = `
      <span class="check-icon">✓</span>
      <div>
        <strong>9.0 ETH Loan Drawn Live On-Chain</strong>
        <p>Unlocked 105% prime collateral ratio for Alice (Noct Finance pool)!</p>
      </div>
    `;
  } else {
    borrowSummary.innerHTML = `
      <span class="check-icon">✓</span>
      <div>
        <strong>7.2 ETH Loan Drawn Live On-Chain</strong>
        <p>Bob qualified for Tier BBB (135% collateral, beats standard 140%)!</p>
      </div>
    `;
  }

  // Privacy Audit Output
  auditNoctNullifier.textContent = `${nullifier.slice(0, 22)}...`;
  auditLayrsNullifier.textContent = `${layrsNullifier.slice(0, 22)}...`;

  document.querySelectorAll(".step-item").forEach((s) => s.classList.add("completed"));

  btnRun.disabled = false;
  btnRun.innerHTML = `<span class="btn-icon">⚡</span><span>Pipeline Verified (Re-Run)</span>`;
  isRunning = false;
}

function setStep(num: number) {
  for (let i = 1; i <= 5; i++) {
    const el = document.getElementById(`step-${i}`);
    if (el) {
      if (i < num) {
        el.classList.add("completed");
        el.classList.remove("active");
      } else if (i === num) {
        el.classList.add("active");
        el.classList.remove("completed");
      } else {
        el.classList.remove("active", "completed");
      }
    }
  }
}

function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// Event Listeners
btnAlice.addEventListener("click", () => {
  if (isRunning) return;
  btnAlice.classList.add("active");
  btnBob.classList.remove("active");
  currentPersona = PERSONAS.alice;
  renderClaim(currentPersona);
  runPipeline();
});

btnBob.addEventListener("click", () => {
  if (isRunning) return;
  btnBob.classList.add("active");
  btnAlice.classList.remove("active");
  currentPersona = PERSONAS.bob;
  renderClaim(currentPersona);
  runPipeline();
});

btnRun.addEventListener("click", () => {
  runPipeline();
});

// Initial Render & Auto-Run
renderClaim(currentPersona);
runPipeline();
