// SPDX-License-Identifier: MIT
import { keccak256, encodePacked } from "viem";
import { p521 } from "@noble/curves/p521";
import { bytesToHex } from "@noble/hashes/utils";

// --- Types ---
interface RiskXPersona {
  type: "riskx";
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
  name: string;
  category: string;
  claim: {
    legal_name_hash: `0x${string}`;
    nationality_iso: string;
    residence_iso: string;
    liquid_net_worth_usd: number;
    annual_income_usd: number;
  };
  secretByte: number;
  status: number;
  statusLabel: string;
  statusClass: "status-accredited" | "status-retail" | "status-sanctioned";
  flags: number; // bit0: passed_ofac, bit1: is_accredited, bit2: blocked_jurisdiction
  canSpot: boolean;
  canRwa: boolean;
  calloutGranted: boolean;
  calloutTitle: string;
  calloutMessage: string;
}

type Persona = RiskXPersona | CompliancePersona;

// --- Personas ---
const PERSONAS_RISKX: Record<string, RiskXPersona> = {
  alice: {
    type: "riskx",
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

const PERSONAS_COMPLIANCE: Record<string, CompliancePersona> = {
  carol: {
    type: "compliance",
    name: "Carol",
    category: "Accredited Institutional Trader (US, $2.5M Net Worth)",
    claim: {
      legal_name_hash: "0xca40100000000000000000000000000000000000000000000000000000000001",
      nationality_iso: "USA",
      residence_iso: "USA",
      liquid_net_worth_usd: 2500000,
      annual_income_usd: 450000,
    },
    secretByte: 0xcc,
    status: 1,
    statusLabel: "Status 1: Accredited Cleared",
    statusClass: "status-accredited",
    flags: 0x0003, // bit0 (passed_ofac) | bit1 (is_accredited)
    canSpot: true,
    canRwa: true,
    calloutGranted: true,
    calloutTitle: "Institutional Accreditation Confirmed",
    calloutMessage: "Carol ($2.5M Net Worth) passes OFAC screening and is accredited under SEC Rule 506(c). Both Spot and RWA dark pool gates are unlocked!",
  },
  erin: {
    type: "compliance",
    name: "Erin",
    category: "Retail Cleared Trader (UK, $50k Net Worth)",
    claim: {
      legal_name_hash: "0xe410000000000000000000000000000000000000000000000000000000000002",
      nationality_iso: "GBR",
      residence_iso: "GBR",
      liquid_net_worth_usd: 50000,
      annual_income_usd: 80000,
    },
    secretByte: 0xee,
    status: 2,
    statusLabel: "Status 2: Retail Cleared",
    statusClass: "status-retail",
    flags: 0x0001, // bit0 (passed_ofac)
    canSpot: true,
    canRwa: false,
    calloutGranted: false,
    calloutTitle: "Accreditation Required for RWA Book",
    calloutMessage: "Erin passes OFAC screening for spot trading, but is gated from institutional RWA orderbooks (requires $1M+ net worth or $200k+ income).",
  },
  dave: {
    type: "compliance",
    name: "Dave",
    category: "Sanctioned Entity (Matches OFAC SDN Specimen)",
    claim: {
      legal_name_hash: "0xda7e000000000000000000000000000000000000000000000000000000000001",
      nationality_iso: "RUS",
      residence_iso: "CYP",
      liquid_net_worth_usd: 5000000,
      annual_income_usd: 800000,
    },
    secretByte: 0xdd,
    status: 99,
    statusLabel: "Status 99: SANCTIONED / BLOCKED",
    statusClass: "status-sanctioned",
    flags: 0x0000, // zero flags
    canSpot: false,
    canRwa: false,
    calloutGranted: false,
    calloutTitle: "On-Chain Trade Gate Reverted",
    calloutMessage: "Dave matches the global OFAC SDN hash database inside the enclave. MockLayrsDarkPool rejects trade with TraderSanctionedOrInvalid(99)!",
  },
};

// --- State ---
let currentPolicyId: 1 | 2 = 1;
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
    name: "Local Anvil Devnet (84532)",
    registry: "0x5FbDB2315678afecb367f032d93F642f64180aa3",
    trigger: "0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9",
    settler: "Direct Viem / MockTeeAuth",
    hasTrigger: false,
    gasLabel: "110,410 gas (Cold Store)",
  },
  sepolia: {
    name: "Base Sepolia Testnet (84532)",
    registry: "0x3fa8362b7Eb3660f1C89b355e4565Ab68e1E1466",
    trigger: "0xD580819D6DFBAfb5e38732d1b3454984194185BB",
    settler: "VelaZcredTrigger Adapter",
    hasTrigger: true,
    gasLabel: "121,795 gas (Trigger Settlement)",
  },
};

// --- DOM Elements ---
const btnPolicyRiskX = document.getElementById("btn-policy-riskx") as HTMLButtonElement;
const btnPolicyCompliance = document.getElementById("btn-policy-compliance") as HTMLButtonElement;

const personasRiskXContainer = document.getElementById("personas-riskx")!;
const personasComplianceContainer = document.getElementById("personas-compliance")!;

const btnAlice = document.getElementById("btn-alice") as HTMLButtonElement;
const btnBob = document.getElementById("btn-bob") as HTMLButtonElement;
const btnCarol = document.getElementById("btn-carol") as HTMLButtonElement;
const btnErin = document.getElementById("btn-erin") as HTMLButtonElement;
const btnDave = document.getElementById("btn-dave") as HTMLButtonElement;

const btnNetLocal = document.getElementById("btn-net-local") as HTMLButtonElement;
const btnNetSepolia = document.getElementById("btn-net-sepolia") as HTMLButtonElement;
const btnRun = document.getElementById("btn-run") as HTMLButtonElement;

// Tracker Labels
const step1Label = document.getElementById("step-1-label")!;
const step3Label = document.getElementById("step-3-label")!;
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

// Partner Cards
const partnerCardNoct = document.getElementById("partner-card-noct")!;
const partnerCardLayrs = document.getElementById("partner-card-layrs")!;

// Noct Card Elements
const standardLimit = document.getElementById("standard-limit")!;
const zcredRateLabel = document.getElementById("zcred-rate-label")!;
const zcredLimit = document.getElementById("zcred-limit")!;
const zcredGain = document.getElementById("zcred-gain")!;
const borrowSummary = document.getElementById("borrow-summary")!;

// Layrs Card Elements
const layrsSpotBadge = document.getElementById("layrs-spot-badge")!;
const layrsSpotHash = document.getElementById("layrs-spot-hash")!;
const layrsSpotGas = document.getElementById("layrs-spot-gas")!;
const layrsRwaBadge = document.getElementById("layrs-rwa-badge")!;
const layrsRwaHash = document.getElementById("layrs-rwa-hash")!;
const layrsRwaGas = document.getElementById("layrs-rwa-gas")!;
const layrsCallout = document.getElementById("layrs-callout")!;
const layrsCalloutIcon = document.getElementById("layrs-callout-icon")!;
const layrsCalloutText = document.getElementById("layrs-callout-text")!;

// Privacy Audit
const auditLabelPrimary = document.getElementById("audit-label-primary")!;
const auditLabelSecondary = document.getElementById("audit-label-secondary")!;
const auditNoctNullifier = document.getElementById("audit-noct-nullifier")!;
const auditLayrsNullifier = document.getElementById("audit-layrs-nullifier")!;
const auditStatus = document.getElementById("audit-status")!;

// --- Helper Functions ---
function renderClaim(p: Persona) {
  if (p.type === "riskx") {
    clientClaimLabel.textContent = `Redacted In-Memory Financial Claim (Client RAM Only - ${p.name})`;
    clientClaimBox.innerHTML = `// Redacted Plaid/zkTLS Ingestion (${p.name})
{
  "liquid_net_worth_bucket": "$${Math.floor(p.claim.liquid_net_worth_usd / 10000) * 10}k - ${Math.floor(p.claim.liquid_net_worth_usd / 10000) * 10 + 10}k",
  "consecutive_cashflow_months": ${p.claim.consecutive_monthly_inflows},
  "liabilities_usd": ${p.claim.total_liabilities_usd},
  "repayment_record": "${p.claim.successful_repayments}/${p.claim.total_historical_loans}",
  "defaults": ${p.claim.liquidation_count},
  "user_secret": "0x${p.secretByte.toString(16).repeat(32)}" // Zeroized in RAM
}`;
  } else {
    clientClaimLabel.textContent = `Redacted Identity & Asset Credentials (Client RAM Only - ${p.name})`;
    clientClaimBox.innerHTML = `// Redacted Brokerage/ID Ingestion (${p.name})
{
  "legal_name_hash": "${p.claim.legal_name_hash.slice(0, 18)}...",
  "nationality_iso": "${p.claim.nationality_iso}",
  "residence_iso": "${p.claim.residence_iso}",
  "liquid_net_worth_usd": $${p.claim.liquid_net_worth_usd.toLocaleString()},
  "annual_income_usd": $${p.claim.annual_income_usd.toLocaleString()},
  "user_secret": "0x${p.secretByte.toString(16).repeat(32)}" // Zeroized in RAM
}`;
  }
}

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

// --- Pipeline Execution ---
async function runPipeline() {
  if (isRunning) return;
  isRunning = true;
  btnRun.disabled = true;
  btnRun.innerHTML = `<span class="btn-icon">⏳</span><span>Evaluating in WASM Coprocessor...</span>`;

  // Reset steps
  document.querySelectorAll(".step-item").forEach((s) => s.classList.remove("active", "completed"));
  document.querySelectorAll(".exec-step").forEach((s) => s.classList.remove("active"));

  const isRiskX = currentPolicyId === 1;
  const primaryDomain = isRiskX ? "noctfinance.xyz" : "layrs.xyz";
  const secondaryDomain = isRiskX ? "layrs.xyz" : "noctfinance.xyz";

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

  const aadHex = computeAad(1, currentPolicyId, chainId, registryAddr, nonceHex, primaryDomain);

  envPolicy.textContent = isRiskX ? "0x01 (RiskX)" : "0x02 (ComplianceShield)";
  envDomain.textContent = primaryDomain;
  envClientPubkey.textContent = `${ephemeralPubHex.slice(0, 26)}... (133 bytes)`;
  envIv.textContent = ivHex;
  envNonce.textContent = `${nonceHex.slice(0, 26)}...`;
  envAad.textContent = `${aadHex.slice(0, 26)}...`;

  const ctLength = isRiskX ? 280 : 350;
  const ctBytes = new Uint8Array(ctLength);
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

  if (isRiskX) {
    execPolicyText.textContent = "3. PolicyDispatcher::dispatch(0x01) -> RiskX Evaluated";
  } else {
    execPolicyText.textContent = "3. PolicyDispatcher::dispatch(0x02) -> OFAC SDN Table Matching & Net Worth Check";
  }
  document.getElementById("exec-policy")!.classList.add("active");
  await sleep(250);

  document.getElementById("exec-zeroize")!.classList.add("active");
  wasmMemoryStatus.textContent = "Plaintext Buffer Zeroized (0x00)";
  await sleep(250);

  // Step 4: EIP-712 Attestation Signing
  setStep(4);
  document.getElementById("exec-sign")!.classList.add("active");

  const primaryNullifier = computeNullifier(currentPersona.secretByte, currentPolicyId, primaryDomain);
  const secondaryNullifier = computeNullifier(currentPersona.secretByte, currentPolicyId, secondaryDomain);

  const now = Math.floor(Date.now() / 1000);
  let customDataHex: `0x${string}`;
  let expiryEpoch: number;
  let tierOrStatusNum: number;

  if (currentPersona.type === "riskx") {
    decisionLabel.textContent = "Assigned Tier:";
    customdataLabel.textContent = "LTV Custom Data:";
    tierOrStatusNum = currentPersona.tier;
    customDataHex = `0x00000000000000000000000000000000000000000000000000000${currentPersona.score.toString(16).padStart(3, "0")}0000${currentPersona.ltvBps.toString(16).padStart(4, "0")}` as `0x${string}`;
    expiryEpoch = now + 86400 * 30; // 30 days

    wasmTier.className = "field-v tag-tier";
    wasmTier.textContent = `Tier ${currentPersona.tier} (${currentPersona.tierLabel})`;
  } else {
    decisionLabel.textContent = "Compliance Status:";
    customdataLabel.textContent = "Flags & Jurisdiction:";
    tierOrStatusNum = currentPersona.status;
    customDataHex = `0x000000000000000000000000000000000000000000000001${currentPersona.flags.toString(16).padStart(4, "0")}00000000` as `0x${string}`;
    expiryEpoch = now + 86400 * 365; // 365 days

    wasmTier.className = `field-v tag-tier ${currentPersona.statusClass}`;
    wasmTier.textContent = currentPersona.statusLabel;
  }

  const mockDigest = keccak256(
    encodePacked(
      ["bytes32", "uint8", "bytes32"],
      [primaryNullifier, tierOrStatusNum, customDataHex]
    )
  );
  const mockSig = `0x${mockDigest.slice(2, 66)}${mockDigest.slice(2, 66)}1b` as `0x${string}`;

  wasmNullifier.textContent = `${primaryNullifier.slice(0, 20)}...`;
  wasmCustomData.textContent = `${customDataHex.slice(0, 24)}...`;
  wasmExpiry.textContent = `${expiryEpoch} (${new Date(expiryEpoch * 1000).toLocaleDateString()})`;
  wasmDigest.textContent = `${mockDigest.slice(0, 20)}...`;
  wasmSignature.textContent = `${mockSig.slice(0, 26)}... (65 bytes)`;

  await sleep(400);

  // Step 5: EVM Settlement & Partner Execution
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

  // Render Partner Card
  if (currentPersona.type === "riskx") {
    partnerCardNoct.style.display = "block";
    partnerCardLayrs.style.display = "none";

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
  } else {
    partnerCardNoct.style.display = "none";
    partnerCardLayrs.style.display = "block";

    // Spot Order Gate
    if (currentPersona.canSpot) {
      layrsSpotBadge.className = "gate-badge gate-granted";
      layrsSpotBadge.textContent = "✅ GRANTED";
      const spotBytes = new Uint8Array(32);
      crypto.getRandomValues(spotBytes);
      layrsSpotHash.textContent = `0x${bytesToHex(spotBytes).slice(0, 18)}...`;
      layrsSpotGas.textContent = "57,904 gas";
    } else {
      layrsSpotBadge.className = "gate-badge gate-blocked";
      layrsSpotBadge.textContent = "❌ BLOCKED";
      layrsSpotHash.textContent = "REVERT: TraderSanctionedOrInvalid(99)";
      layrsSpotGas.textContent = "0 gas (Reverted)";
    }

    // Institutional RWA Order Gate
    if (currentPersona.canRwa) {
      layrsRwaBadge.className = "gate-badge gate-granted";
      layrsRwaBadge.textContent = "✅ GRANTED";
      const rwaBytes = new Uint8Array(32);
      crypto.getRandomValues(rwaBytes);
      layrsRwaHash.textContent = `0x${bytesToHex(rwaBytes).slice(0, 18)}...`;
      layrsRwaGas.textContent = "57,939 gas";
    } else {
      layrsRwaBadge.className = "gate-badge gate-blocked";
      layrsRwaBadge.textContent = "❌ BLOCKED";
      layrsRwaHash.textContent = currentPersona.status === 99 
        ? "REVERT: TraderSanctionedOrInvalid(99)"
        : "REVERT: AccreditationRequired(status 2)";
      layrsRwaGas.textContent = "0 gas (Reverted)";
    }

    // Callout box
    layrsCallout.className = `gate-callout ${currentPersona.calloutGranted ? "callout-granted" : "callout-blocked"}`;
    layrsCalloutIcon.textContent = currentPersona.calloutGranted ? "✓" : "⚠";
    layrsCalloutText.innerHTML = `
      <strong>${currentPersona.calloutTitle}</strong>
      <p>${currentPersona.calloutMessage}</p>
    `;
  }

  // Privacy Audit Output
  auditLabelPrimary.textContent = `${primaryDomain} nullifier:`;
  auditLabelSecondary.textContent = `${secondaryDomain} nullifier:`;
  auditNoctNullifier.textContent = `${primaryNullifier.slice(0, 22)}...`;
  auditLayrsNullifier.textContent = `${secondaryNullifier.slice(0, 22)}...`;
  auditStatus.textContent = `isValid: false (Clean zero state across domains!)`;

  document.querySelectorAll(".step-item").forEach((s) => s.classList.add("completed"));

  btnRun.disabled = false;
  btnRun.innerHTML = `<span class="btn-icon">⚡</span><span>Pipeline Verified (Re-Run)</span>`;
  isRunning = false;
}

// --- Policy & Persona Switching Logic ---
function switchPolicy(policyId: 1 | 2) {
  if (isRunning || currentPolicyId === policyId) return;
  currentPolicyId = policyId;

  if (policyId === 1) {
    btnPolicyRiskX.classList.add("active");
    btnPolicyCompliance.classList.remove("active");

    personasRiskXContainer.style.display = "flex";
    personasComplianceContainer.style.display = "none";

    step1Label.textContent = "zkTLS Claim Ingestion";
    step3Label.textContent = "In-Guest WASM Decrypt";
    step5Label.textContent = "Noct 105% Settlement";

    // Default to Alice
    btnAlice.classList.add("active");
    btnBob.classList.remove("active");
    currentPersona = PERSONAS_RISKX.alice;
  } else {
    btnPolicyCompliance.classList.add("active");
    btnPolicyRiskX.classList.remove("active");

    personasRiskXContainer.style.display = "none";
    personasComplianceContainer.style.display = "flex";

    step1Label.textContent = "Brokerage / ID Ingestion";
    step3Label.textContent = "In-Guest OFAC & Accredited";
    step5Label.textContent = "Layrs Dark Pool Order";

    // Default to Carol
    btnCarol.classList.add("active");
    btnErin.classList.remove("active");
    btnDave.classList.remove("active");
    currentPersona = PERSONAS_COMPLIANCE.carol;
  }

  renderClaim(currentPersona);
  runPipeline();
}

// --- Event Listeners ---
btnPolicyRiskX.addEventListener("click", () => switchPolicy(1));
btnPolicyCompliance.addEventListener("click", () => switchPolicy(2));

// Policy 1 Buttons
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

// Policy 2 Buttons
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

// Network Toggle
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
