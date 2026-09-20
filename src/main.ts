// SPDX-License-Identifier: MIT
import { keccak256, encodePacked } from "viem";
import { p521 } from "@noble/curves/p521";
import { bytesToHex } from "@noble/hashes/utils";

// --- Types ---
type PolicyType = "riskx" | "compliance";

interface RiskXPersona {
  type: "riskx";
  id: "alice" | "bob";
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

interface CompliancePersona {
  type: "compliance";
  id: "carol" | "erin" | "dave";
  name: string;
  category: string;
  claim: {
    jurisdiction_code: string;
    liquid_net_worth_usd: number;
    annual_income_usd: number;
    is_politically_exposed: boolean;
    identity_hash: string;
  };
  secretByte: number;
  statusCode: number;
  statusLabel: string;
  isAccredited: boolean;
  isSanctioned: boolean;
  spotAllowed: boolean;
  rwaAllowed: boolean;
}

type Persona = RiskXPersona | CompliancePersona;

const PERSONAS_RISKX: Record<"alice" | "bob", RiskXPersona> = {
  alice: {
    type: "riskx",
    id: "alice",
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
    type: "riskx",
    id: "bob",
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

const PERSONAS_COMPLIANCE: Record<"carol" | "erin" | "dave", CompliancePersona> = {
  carol: {
    type: "compliance",
    id: "carol",
    name: "Carol",
    category: "Accredited Institutional Trader (US, $2.5M Net Worth)",
    claim: {
      jurisdiction_code: "US",
      liquid_net_worth_usd: 2500000,
      annual_income_usd: 400000,
      is_politically_exposed: false,
      identity_hash: "0x3f7a1c8b9d0e2f4a5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a",
    },
    secretByte: 0xcc,
    statusCode: 1,
    statusLabel: "Status 1: Passed Accredited",
    isAccredited: true,
    isSanctioned: false,
    spotAllowed: true,
    rwaAllowed: true,
  },
  erin: {
    type: "compliance",
    id: "erin",
    name: "Erin",
    category: "Retail Cleared Trader (UK, $50k Net Worth)",
    claim: {
      jurisdiction_code: "GB",
      liquid_net_worth_usd: 50000,
      annual_income_usd: 65000,
      is_politically_exposed: false,
      identity_hash: "0x8e2b9c0d1f3a4e5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b",
    },
    secretByte: 0xee,
    statusCode: 2,
    statusLabel: "Status 2: Passed Retail",
    isAccredited: false,
    isSanctioned: false,
    spotAllowed: true,
    rwaAllowed: false,
  },
  dave: {
    type: "compliance",
    id: "dave",
    name: "Dave",
    category: "Sanctioned Entity (Matches OFAC SDN Specimen)",
    claim: {
      jurisdiction_code: "KP",
      liquid_net_worth_usd: 10000000,
      annual_income_usd: 0,
      is_politically_exposed: false,
      identity_hash: "0x1111111111111111111111111111111111111111111111111111111111111111",
    },
    secretByte: 0xdd,
    statusCode: 99,
    statusLabel: "Status 99: TraderSanctionedOrInvalid",
    isAccredited: false,
    isSanctioned: true,
    spotAllowed: false,
    rwaAllowed: false,
  },
};

let currentPolicy: PolicyType = "riskx";
let currentPersona: Persona = PERSONAS_RISKX.alice;
let currentNetwork: "local" | "sepolia" = "local";
let isRunning = false;

interface NetworkSettings {
  name: string;
  registry: `0x${string}`;
  trigger: `0x${string}`;
  settler: string;
  hasTrigger: boolean;
  gasLabel: string;
}

const NETWORKS: Record<"local" | "sepolia", NetworkSettings> = {
  local: {
    name: "Horizen Vela Local Devnet (31337)",
    registry: "0xE6E340D132b5f46d1e472DebcD681B2aBc16e57E",
    trigger: "0x1291Be112d480055DaFd8a610b7d1e203891C274",
    settler: "VelaZcredTrigger Adapter",
    hasTrigger: true,
    gasLabel: "121,795 gas (Trigger Settlement)",
  },
  sepolia: {
    name: "Base Sepolia Testnet (84532)",
    registry: "0xD27e6A8e297177C4Cb284b5C7E2Ccf8d9C69C11a",
    trigger: "0x3Fe19C2a0E5060D587F483e3366eb73A5757e623",
    settler: "VelaZcredTrigger Adapter",
    hasTrigger: true,
    gasLabel: "121,795 gas (Trigger Settlement)",
  },
};

// DOM Elements - Navigation & Policy Switching
const btnPolicyRiskx = document.getElementById("btn-policy-riskx") as HTMLButtonElement;
const btnPolicyCompliance = document.getElementById("btn-policy-compliance") as HTMLButtonElement;
const personasRiskxGroup = document.getElementById("personas-riskx") as HTMLDivElement;
const personasComplianceGroup = document.getElementById("personas-compliance") as HTMLDivElement;

// Policy 1 Persona Buttons
const btnAlice = document.getElementById("btn-alice") as HTMLButtonElement;
const btnBob = document.getElementById("btn-bob") as HTMLButtonElement;

// Policy 2 Persona Buttons
const btnCarol = document.getElementById("btn-carol") as HTMLButtonElement;
const btnErin = document.getElementById("btn-erin") as HTMLButtonElement;
const btnDave = document.getElementById("btn-dave") as HTMLButtonElement;

// Networks & Run Button
const btnNetLocal = document.getElementById("btn-net-local") as HTMLButtonElement;
const btnNetSepolia = document.getElementById("btn-net-sepolia") as HTMLButtonElement;
const btnRun = document.getElementById("btn-run") as HTMLButtonElement;

// Progress Tracker Labels
const step5Label = document.getElementById("step-5-label")!;

// Column 1 Elements
const clientClaimLabel = document.getElementById("client-claim-label")!;
const clientClaimBox = document.getElementById("client-claim-box")!;
const envPolicy = document.getElementById("env-policy")!;
const envDomain = document.getElementById("env-domain")!;
const envClientPubkey = document.getElementById("env-client-pubkey")!;
const envIv = document.getElementById("env-iv")!;
const envNonce = document.getElementById("env-nonce")!;
const envAad = document.getElementById("env-aad")!;
const envCiphertextBox = document.getElementById("env-ciphertext-box")!;

// Column 2 Elements
const wasmMemoryStatus = document.getElementById("wasm-memory-status")!;
const execPolicyText = document.getElementById("exec-policy-text")!;
const decisionLabel = document.getElementById("decision-label")!;
const wasmTier = document.getElementById("wasm-tier")!;
const wasmNullifier = document.getElementById("wasm-nullifier")!;
const customdataLabel = document.getElementById("customdata-label")!;
const wasmCustomData = document.getElementById("wasm-customdata")!;
const wasmExpiry = document.getElementById("wasm-expiry")!;
const wasmDigest = document.getElementById("wasm-digest")!;
const wasmSignature = document.getElementById("wasm-signature")!;

// Column 3 Elements
const contractNetwork = document.getElementById("contract-network")!;
const contractSettler = document.getElementById("contract-settler")!;
const rowTrigger = document.getElementById("row-trigger")!;
const contractTrigger = document.getElementById("contract-trigger")!;
const contractRegistry = document.getElementById("contract-registry")!;
const contractTxHash = document.getElementById("contract-txhash")!;
const contractGas = document.getElementById("contract-gas")!;

// Partner Card 1 (RiskX)
const partnerCardNoct = document.getElementById("partner-card-noct") as HTMLDivElement;
const standardLimit = document.getElementById("standard-limit")!;
const zcredRateLabel = document.getElementById("zcred-rate-label")!;
const zcredLimit = document.getElementById("zcred-limit")!;
const zcredGain = document.getElementById("zcred-gain")!;
const borrowSummary = document.getElementById("borrow-summary")!;

// Partner Card 2 (Compliance Shield)
const partnerCardLayrs = document.getElementById("partner-card-layrs") as HTMLDivElement;
const layrsSpotBadge = document.getElementById("layrs-spot-badge")!;
const layrsSpotReceipt = document.getElementById("layrs-spot-receipt")!;
const layrsSpotHash = document.getElementById("layrs-spot-hash")!;
const layrsSpotGas = document.getElementById("layrs-spot-gas")!;
const layrsRwaBadge = document.getElementById("layrs-rwa-badge")!;
const layrsRwaReceipt = document.getElementById("layrs-rwa-receipt")!;
const layrsRwaHash = document.getElementById("layrs-rwa-hash")!;
const layrsRwaGas = document.getElementById("layrs-rwa-gas")!;
const layrsCallout = document.getElementById("layrs-callout")!;
const layrsCalloutIcon = document.getElementById("layrs-callout-icon")!;
const layrsCalloutText = document.getElementById("layrs-callout-text")!;

// Privacy Audit Elements
const auditLabelPrimary = document.getElementById("audit-label-primary")!;
const auditLabelSecondary = document.getElementById("audit-label-secondary")!;
const auditNoctNullifier = document.getElementById("audit-noct-nullifier")!;
const auditLayrsNullifier = document.getElementById("audit-layrs-nullifier")!;
const auditStatus = document.getElementById("audit-status")!;

// --- Helper Cryptography Functions ---
function computeNullifier(secretByte: number, policyId: number, domain: string): `0x${string}` {
  const secret = new Uint8Array(32).fill(secretByte);
  const packed = encodePacked(
    ["bytes32", "uint8", "string"],
    [`0x${bytesToHex(secret)}`, policyId, domain]
  );
  return keccak256(packed);
}

function computeAad(
  version: number,
  policyId: number,
  chainId: bigint,
  registry: `0x${string}`,
  nonce: `0x${string}`,
  domain: string
): `0x${string}` {
  const packed = encodePacked(
    ["uint8", "uint8", "uint256", "address", "bytes32", "string"],
    [version, policyId, chainId, registry, nonce, domain]
  );
  return keccak256(packed);
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

// --- Render Claim View ---
function renderClaim(p: Persona) {
  if (p.type === "riskx") {
    step5Label.textContent = "Undercollateralized Settlement";
    partnerCardNoct.style.display = "block";
    partnerCardLayrs.style.display = "none";
    decisionLabel.textContent = "Assigned Tier:";
    customdataLabel.textContent = "LTV Custom Data:";
    envPolicy.textContent = "0x01 (RiskX)";
    envDomain.textContent = "noctfinance.xyz";

    clientClaimLabel.textContent = `Redacted In-Memory Financial Claim (Client RAM Only - ${p.name})`;
    clientClaimBox.innerHTML = `// Redacted Financial Claim (${p.name} - ${p.category})
{
  "liquid_net_worth_bucket": "$${Math.floor(p.claim.liquid_net_worth_usd / 10000) * 10}k - ${Math.floor(p.claim.liquid_net_worth_usd / 10000) * 10 + 10}k",
  "consecutive_cashflow_months": ${p.claim.consecutive_monthly_inflows},
  "liabilities_usd": ${p.claim.total_liabilities_usd},
  "repayment_record": "${p.claim.successful_repayments}/${p.claim.total_historical_loans}",
  "defaults": ${p.claim.liquidation_count},
  "user_secret": "0x${p.secretByte.toString(16).repeat(32)}" // Zeroized in RAM
}`;
  } else {
    step5Label.textContent = "Institutional Settlement";
    partnerCardNoct.style.display = "none";
    partnerCardLayrs.style.display = "block";
    decisionLabel.textContent = "Compliance Status:";
    customdataLabel.textContent = "Accreditation Bitmask:";
    envPolicy.textContent = "0x02 (Compliance Shield)";
    envDomain.textContent = "darkpool.institutional.internal";

    clientClaimLabel.textContent = `Redacted Identity & OFAC Attestation (Client RAM Only - ${p.name})`;
    clientClaimBox.innerHTML = `// Confidential Compliance Ingestion (${p.name} - ${p.category})
{
  "jurisdiction_code": "${p.claim.jurisdiction_code}",
  "net_worth_tier": "$${p.claim.liquid_net_worth_usd >= 1000000 ? (p.claim.liquid_net_worth_usd / 1000000).toFixed(1) + "M+" : (p.claim.liquid_net_worth_usd / 1000).toFixed(0) + "k"}",
  "annual_inflow_tier": "$${(p.claim.annual_income_usd / 1000).toFixed(0)}k",
  "pep_flag": ${p.claim.is_politically_exposed},
  "ofac_identity_hash": "${p.claim.identity_hash.slice(0, 18)}...",
  "user_secret": "0x${p.secretByte.toString(16).repeat(32)}" // Zeroized in RAM
}`;
  }
}

// --- Pipeline Execution ---
async function runPipeline() {
  if (isRunning) return;
  isRunning = true;
  btnRun.disabled = true;
  btnRun.innerHTML = `<span class="btn-icon">⏳</span><span>Evaluating in Nitro Coprocessor...</span>`;

  // Reset progress steps
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

  const net = NETWORKS[currentNetwork];
  const chainId = 84532n;
  const registryAddr = net.registry;
  const policyId = currentPersona.type === "riskx" ? 1 : 2;
  const dappDomain = currentPersona.type === "riskx" ? "noctfinance.xyz" : "darkpool.institutional.internal";
  const alternateDomain = currentPersona.type === "riskx" ? "darkpool.institutional.internal" : "noctfinance.xyz";

  const aadHex = computeAad(1, policyId, chainId, registryAddr, nonceHex, dappDomain);

  envClientPubkey.textContent = `${ephemeralPubHex.slice(0, 26)}... (133 bytes)`;
  envIv.textContent = ivHex;
  envNonce.textContent = `${nonceHex.slice(0, 26)}...`;
  envAad.textContent = `${aadHex.slice(0, 26)}...`;

  const ctBytes = new Uint8Array(currentPersona.type === "riskx" ? 280 : 320);
  crypto.getRandomValues(ctBytes);
  envCiphertextBox.textContent = `0x${bytesToHex(ctBytes.slice(0, 48))}... (${ctBytes.length} bytes encrypted payload)`;

  await sleep(400);

  // Step 3: Enclave In-Guest Execution
  setStep(3);
  wasmMemoryStatus.textContent = "Active linear memory (zcred_alloc: 4096 bytes)";

  const execEcdh = document.getElementById("exec-ecdh");
  if (execEcdh) execEcdh.classList.add("active");
  await sleep(250);

  const execAad = document.getElementById("exec-aad");
  if (execAad) execAad.classList.add("active");
  await sleep(250);

  const execPolicy = document.getElementById("exec-policy");
  if (execPolicy) {
    execPolicy.classList.add("active");
    if (currentPersona.type === "riskx") {
      execPolicyText.textContent = "3. PolicyDispatcher::dispatch(0x01) -> RiskX Evaluated";
    } else {
      execPolicyText.textContent = "3. PolicyDispatcher::dispatch(0x02) -> ComplianceShield Evaluated";
    }
  }
  await sleep(300);

  const execZeroize = document.getElementById("exec-zeroize");
  if (execZeroize) execZeroize.classList.add("active");
  await sleep(200);

  const execSign = document.getElementById("exec-sign");
  if (execSign) execSign.classList.add("active");
  await sleep(250);

  // Step 4: Attestation Output Generation
  setStep(4);
  const primaryNullifier = computeNullifier(currentPersona.secretByte, policyId, dappDomain);
  const secondaryNullifier = computeNullifier(currentPersona.secretByte, policyId, alternateDomain);

  const expiryEpoch = Math.floor(Date.now() / 1000) + 86400 * 30; // 30 days
  let customDataHex = "0x0000000000000000000000000000000000000000000000000000000000000000" as `0x${string}`;
  let statusByte = 0;

  if (currentPersona.type === "riskx") {
    statusByte = currentPersona.tier;
    const ltvBuf = new Uint8Array(32);
    const view = new DataView(ltvBuf.buffer);
    view.setUint16(0, currentPersona.ltvBps, false); // Big endian
    customDataHex = `0x${bytesToHex(ltvBuf)}` as `0x${string}`;
    wasmTier.textContent = currentPersona.tierLabel;
    wasmTier.className = `field-v tag-tier tier-${currentPersona.tier}`;
  } else {
    statusByte = currentPersona.statusCode;
    const bitBuf = new Uint8Array(32);
    if (currentPersona.isAccredited) bitBuf[0] = 0x01; // Accredited bitmask
    customDataHex = `0x${bytesToHex(bitBuf)}` as `0x${string}`;
    wasmTier.textContent = currentPersona.statusLabel;
    wasmTier.className = `field-v tag-tier ${currentPersona.isSanctioned ? "tier-sanctioned" : "tier-approved"}`;
  }

  const mockDigest = keccak256(
    encodePacked(["bytes32", "uint8", "bytes32"], [primaryNullifier, statusByte, customDataHex])
  );
  const mockSig = `0x${mockDigest.slice(2, 66)}${mockDigest.slice(2, 66)}1b` as `0x${string}`;

  wasmNullifier.textContent = `${primaryNullifier.slice(0, 20)}...`;
  wasmCustomData.textContent = `${customDataHex.slice(0, 24)}...`;
  wasmExpiry.textContent = `${expiryEpoch} (${new Date(expiryEpoch * 1000).toLocaleDateString()})`;
  wasmDigest.textContent = `${mockDigest.slice(0, 20)}...`;
  wasmSignature.textContent = `${mockSig.slice(0, 26)}... (65 bytes)`;

  await sleep(400);

  // Step 5: EVM Settlement & Protocol Verification
  setStep(5);
  const txBytes = new Uint8Array(32);
  crypto.getRandomValues(txBytes);
  contractTxHash.textContent = `0x${bytesToHex(txBytes).slice(0, 18)}...`;
  contractNetwork.textContent = net.name;
  contractSettler.textContent = net.settler;
  contractRegistry.textContent = `${net.registry.slice(0, 10)}...${net.registry.slice(-6)}`;
  contractGas.textContent = net.gasLabel;

  if (net.hasTrigger) {
    rowTrigger.style.display = "flex";
    contractTrigger.textContent = `${net.trigger.slice(0, 10)}...${net.trigger.slice(-6)}`;
  } else {
    rowTrigger.style.display = "none";
  }

  if (currentPersona.type === "riskx") {
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
          <p>Unlocked 105% prime collateral ratio for ${currentPersona.name}!</p>
        </div>
      `;
    } else {
      borrowSummary.innerHTML = `
        <span class="check-icon">✓</span>
        <div>
          <strong>7.2 ETH Loan Drawn Live On-Chain</strong>
          <p>${currentPersona.name} qualified for Tier BBB (135% collateral, beats standard 140%)!</p>
        </div>
      `;
    }
  } else {
    // Policy 2: Compliance Shield Gating
    const spotHash = `0x${bytesToHex(crypto.getRandomValues(new Uint8Array(32))).slice(0, 16)}...`;
    const rwaHash = `0x${bytesToHex(crypto.getRandomValues(new Uint8Array(32))).slice(0, 16)}...`;

    if (currentPersona.spotAllowed) {
      layrsSpotBadge.textContent = "✅ GRANTED";
      layrsSpotBadge.className = "gate-badge gate-granted";
      layrsSpotReceipt.style.display = "flex";
      layrsSpotHash.textContent = spotHash;
      layrsSpotGas.textContent = "57,904 gas";
    } else {
      layrsSpotBadge.textContent = "❌ BLOCKED";
      layrsSpotBadge.className = "gate-badge gate-blocked";
      layrsSpotReceipt.style.display = "none";
    }

    if (currentPersona.rwaAllowed) {
      layrsRwaBadge.textContent = "✅ GRANTED";
      layrsRwaBadge.className = "gate-badge gate-granted";
      layrsRwaReceipt.style.display = "flex";
      layrsRwaHash.textContent = rwaHash;
      layrsRwaGas.textContent = "57,939 gas";
    } else {
      layrsRwaBadge.textContent = "❌ BLOCKED";
      layrsRwaBadge.className = "gate-badge gate-blocked";
      layrsRwaReceipt.style.display = "none";
    }

    if (currentPersona.isSanctioned) {
      layrsCallout.className = "gate-callout callout-blocked";
      layrsCalloutIcon.textContent = "🚫";
      layrsCalloutText.innerHTML = `
        <strong>Sanctioned Trader Rejected (Error 99)</strong>
        <p>${currentPersona.name} triggered OFAC SDN collision. All orders rejected at zero gas!</p>
      `;
    } else if (currentPersona.isAccredited) {
      layrsCallout.className = "gate-callout callout-granted";
      layrsCalloutIcon.textContent = "✓";
      layrsCalloutText.innerHTML = `
        <strong>Institutional Accreditation Verified</strong>
        <p>${currentPersona.name} ($2.5M Net Worth) is cleared for both Spot and Institutional Dark Pool trading!</p>
      `;
    } else {
      layrsCallout.className = "gate-callout callout-warning";
      layrsCalloutIcon.textContent = "⚠️";
      layrsCalloutText.innerHTML = `
        <strong>Retail KYC Cleared / RWA Restricted</strong>
        <p>${currentPersona.name} is cleared for Spot Trading, but blocked from Institutional RWA (requires accredited status).</p>
      `;
    }
  }

  // Cross-Domain Privacy Audit Output
  auditLabelPrimary.textContent = `${dappDomain} nullifier:`;
  auditLabelSecondary.textContent = `${alternateDomain} nullifier:`;
  auditNoctNullifier.textContent = `${primaryNullifier.slice(0, 22)}...`;
  auditLayrsNullifier.textContent = `${secondaryNullifier.slice(0, 22)}...`;
  auditStatus.textContent = `isValid: false (Clean zero state across domains!)`;

  document.querySelectorAll(".step-item").forEach((s) => s.classList.add("completed"));

  btnRun.disabled = false;
  btnRun.innerHTML = `<span class="btn-icon">⚡</span><span>Pipeline Verified (Re-Run)</span>`;
  isRunning = false;
}

// --- Event Listeners ---

// Policy Switching
btnPolicyRiskx.addEventListener("click", () => {
  if (isRunning) return;
  currentPolicy = "riskx";
  btnPolicyRiskx.classList.add("active");
  btnPolicyCompliance.classList.remove("active");
  personasRiskxGroup.style.display = "flex";
  personasComplianceGroup.style.display = "none";
  currentPersona = PERSONAS_RISKX.alice;
  btnAlice.classList.add("active");
  btnBob.classList.remove("active");
  renderClaim(currentPersona);
  runPipeline();
});

btnPolicyCompliance.addEventListener("click", () => {
  if (isRunning) return;
  currentPolicy = "compliance";
  btnPolicyCompliance.classList.add("active");
  btnPolicyRiskx.classList.remove("active");
  personasRiskxGroup.style.display = "none";
  personasComplianceGroup.style.display = "flex";
  currentPersona = PERSONAS_COMPLIANCE.carol;
  btnCarol.classList.add("active");
  btnErin.classList.remove("active");
  btnDave.classList.remove("active");
  renderClaim(currentPersona);
  runPipeline();
});

// Persona Switching (RiskX)
btnAlice.addEventListener("click", () => {
  if (isRunning) return;
  btnAlice.classList.add("active");
  btnBob.classList.remove("active");
  currentPersona = PERSONAS_RISKX.alice;
  renderClaim(currentPersona);
  runPipeline();
});

btnBob.addEventListener("click", () => {
  if (isRunning) return;
  btnBob.classList.add("active");
  btnAlice.classList.remove("active");
  currentPersona = PERSONAS_RISKX.bob;
  renderClaim(currentPersona);
  runPipeline();
});

// Persona Switching (Compliance)
btnCarol.addEventListener("click", () => {
  if (isRunning) return;
  btnCarol.classList.add("active");
  btnErin.classList.remove("active");
  btnDave.classList.remove("active");
  currentPersona = PERSONAS_COMPLIANCE.carol;
  renderClaim(currentPersona);
  runPipeline();
});

btnErin.addEventListener("click", () => {
  if (isRunning) return;
  btnErin.classList.add("active");
  btnCarol.classList.remove("active");
  btnDave.classList.remove("active");
  currentPersona = PERSONAS_COMPLIANCE.erin;
  renderClaim(currentPersona);
  runPipeline();
});

btnDave.addEventListener("click", () => {
  if (isRunning) return;
  btnDave.classList.add("active");
  btnCarol.classList.remove("active");
  btnErin.classList.remove("active");
  currentPersona = PERSONAS_COMPLIANCE.dave;
  renderClaim(currentPersona);
  runPipeline();
});

// Network Switching
btnNetLocal.addEventListener("click", () => {
  if (isRunning) return;
  btnNetLocal.classList.add("active");
  btnNetSepolia.classList.remove("active");
  currentNetwork = "local";
  runPipeline();
});

btnNetSepolia.addEventListener("click", () => {
  if (isRunning) return;
  btnNetSepolia.classList.add("active");
  btnNetLocal.classList.remove("active");
  currentNetwork = "sepolia";
  runPipeline();
});

// Run Button
btnRun.addEventListener("click", () => {
  runPipeline();
});

// Initial Render & Auto-Run
renderClaim(currentPersona);
runPipeline();
