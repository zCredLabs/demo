// SPDX-License-Identifier: MIT
import { keccak256, encodePacked } from "viem";
import { p521 } from "@noble/curves/p521";
import { bytesToHex } from "@noble/hashes/utils";

import { PolicyType, Persona } from "./types";
import {
  PERSONAS_RISKX,
  PERSONAS_COMPLIANCE,
  PERSONAS_AGENT,
  NETWORKS,
} from "./data/personas";

import { HeaderComponent } from "./components/Header";
import { ScenarioBarComponent } from "./components/ScenarioBar";
import { PipelineTrackerComponent } from "./components/PipelineTracker";
import { TelemetryViewComponent } from "./components/TelemetryView";

// --- State ---
let currentPolicy: PolicyType = "riskx";
let currentPersona: Persona = PERSONAS_RISKX.alice;
let currentNetwork: "local" | "sepolia" = "local";
let isRunning = false;

// --- Helper Functions ---
function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
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

// --- Initialize Components ---
const tracker = new PipelineTrackerComponent();
const telemetry = new TelemetryViewComponent();

const scenarioBar = new ScenarioBarComponent({
  onProfileSelect: (personaId: string) => {
    if (isRunning) return;
    if (currentPolicy === "riskx") {
      currentPersona = PERSONAS_RISKX[personaId as "alice" | "bob"];
    } else if (currentPolicy === "compliance") {
      currentPersona = PERSONAS_COMPLIANCE[personaId as "carol" | "erin" | "dave"];
    } else {
      currentPersona = PERSONAS_AGENT[personaId as "alpha" | "beta" | "gamma"];
    }
    telemetry.renderClaim(currentPersona, (label) => tracker.setStep5Label(label));
    runPipeline();
  },
});

const header = new HeaderComponent({
  onPolicyChange: (policy: PolicyType) => {
    if (isRunning) return;
    currentPolicy = policy;
    scenarioBar.showPolicyProfiles(policy);

    if (policy === "riskx") currentPersona = PERSONAS_RISKX.alice;
    if (policy === "compliance") currentPersona = PERSONAS_COMPLIANCE.carol;
    if (policy === "agent") currentPersona = PERSONAS_AGENT.alpha;

    telemetry.renderClaim(currentPersona, (label) => tracker.setStep5Label(label));
    runPipeline();
  },
  onNetworkChange: (network: "local" | "sepolia") => {
    if (isRunning) return;
    currentNetwork = network;
    runPipeline();
  },
  onRunPipeline: () => {
    runPipeline();
  },
});

// --- Pipeline Execution ---
async function runPipeline() {
  if (isRunning) return;
  isRunning = true;
  header.setRunningState(true);
  tracker.reset();

  // Step 1: Claim Ingestion
  tracker.setStep(1);
  await sleep(300);

  // Step 2: P-521 ECDH & AAD Binding
  tracker.setStep(2);
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
  const policyId =
    currentPersona.type === "riskx" ? 1 : currentPersona.type === "compliance" ? 2 : 3;

  const dappDomain =
    currentPersona.type === "riskx"
      ? "lending.protocol.eth"
      : currentPersona.type === "compliance"
      ? "darkpool.trade.eth"
      : "agent-gateway.internal";

  const alternateDomain =
    currentPersona.type === "agent"
      ? "lending.protocol.eth"
      : currentPersona.type === "riskx"
      ? "darkpool.trade.eth"
      : "lending.protocol.eth";

  const aadHex = computeAad(1, policyId, chainId, registryAddr, nonceHex, dappDomain);

  const ctBytes = new Uint8Array(
    currentPersona.type === "riskx" ? 280 : currentPersona.type === "compliance" ? 320 : 360
  );
  crypto.getRandomValues(ctBytes);
  const ctHex = `0x${bytesToHex(ctBytes)}`;

  telemetry.updateEnvelope(ephemeralPubHex, ivHex, nonceHex, aadHex, ctHex);
  await sleep(350);

  // Step 3: Enclave In-Guest Execution
  tracker.setStep(3);

  const execEcdh = document.getElementById("exec-ecdh");
  if (execEcdh) execEcdh.classList.add("active");
  await sleep(200);

  const execAad = document.getElementById("exec-aad");
  if (execAad) execAad.classList.add("active");
  await sleep(200);

  const execPolicy = document.getElementById("exec-policy");
  if (execPolicy) {
    execPolicy.classList.add("active");
  }
  await sleep(250);

  const execZeroize = document.getElementById("exec-zeroize");
  if (execZeroize) execZeroize.classList.add("active");
  await sleep(180);

  const execSign = document.getElementById("exec-sign");
  if (execSign) execSign.classList.add("active");
  await sleep(200);

  // Step 4: Attestation Output Generation
  tracker.setStep(4);
  const primaryNullifier = computeNullifier(currentPersona.secretByte, policyId, dappDomain);
  const secondaryNullifier = computeNullifier(currentPersona.secretByte, policyId, alternateDomain);

  const expiryEpoch =
    Math.floor(Date.now() / 1000) + (currentPersona.type === "agent" ? 86400 * 90 : 86400 * 30);
  let customDataHex = "0x0000000000000000000000000000000000000000000000000000000000000000" as `0x${string}`;
  let statusByte = 0;
  let policyDisplayName = "";
  let tierLabel = "";
  let tierClass = "";

  if (currentPersona.type === "riskx") {
    statusByte = currentPersona.tier;
    policyDisplayName = "3. PolicyDispatcher::dispatch(0x01) -> ConfidentialCredit Evaluated";
    tierLabel = currentPersona.tierLabel;
    tierClass = `tier-${currentPersona.tier}`;
    const ltvBuf = new Uint8Array(32);
    const view = new DataView(ltvBuf.buffer);
    view.setUint16(0, currentPersona.ltvBps, false);
    customDataHex = `0x${bytesToHex(ltvBuf)}` as `0x${string}`;
  } else if (currentPersona.type === "compliance") {
    statusByte = currentPersona.statusCode;
    policyDisplayName = "3. PolicyDispatcher::dispatch(0x02) -> InstitutionalCompliance Evaluated";
    tierLabel = currentPersona.statusLabel;
    tierClass = currentPersona.isSanctioned
      ? "status-sanctioned"
      : currentPersona.isAccredited
      ? "status-accredited"
      : "status-retail";
    const bitBuf = new Uint8Array(32);
    if (currentPersona.isAccredited) bitBuf[0] = 0x01;
    customDataHex = `0x${bytesToHex(bitBuf)}` as `0x${string}`;
  } else {
    // Policy 3: Agent Passport
    statusByte = currentPersona.statusCode;
    policyDisplayName = "3. PolicyDispatcher::dispatch(0x03) -> AgentPassport Evaluated";
    tierLabel = currentPersona.statusLabel;
    tierClass = currentPersona.isAttested
      ? "status-agent-attested"
      : currentPersona.isRestricted
      ? "status-agent-restricted"
      : "status-agent-rogue";

    const buf = new Uint8Array(32);
    const view = new DataView(buf.buffer);
    view.setBigUint64(18, BigInt(currentPersona.isRogue ? 0 : currentPersona.dailyAllowanceUsd), false);
    view.setUint16(26, currentPersona.flags, false);
    view.setUint32(28, currentPersona.isRogue ? 0 : currentPersona.claim.max_drawdown_bps, false);
    customDataHex = `0x${bytesToHex(buf)}` as `0x${string}`;
  }

  const mockDigest = keccak256(
    encodePacked(["bytes32", "uint8", "bytes32"], [primaryNullifier, statusByte, customDataHex])
  );
  const mockSig = `0x${mockDigest.slice(2, 66)}${mockDigest.slice(2, 66)}1b` as `0x${string}`;

  telemetry.updateEnclaveOutput(
    policyDisplayName,
    tierLabel,
    tierClass,
    primaryNullifier,
    customDataHex,
    `${expiryEpoch} (${new Date(expiryEpoch * 1000).toLocaleDateString()})`,
    mockDigest,
    mockSig
  );

  await sleep(350);

  // Step 5: EVM Settlement & Protocol Verification
  tracker.setStep(5);
  const txBytes = new Uint8Array(32);
  crypto.getRandomValues(txBytes);
  const txHash = `0x${bytesToHex(txBytes)}`;

  telemetry.updateSettlementReceipt(net, txHash);
  telemetry.updatePartnerGates(currentPersona);

  // Cross-Domain Privacy Audit Output
  telemetry.updateAudit(
    `Primary Domain (${dappDomain}) Nullifier:`,
    primaryNullifier,
    `Secondary Domain (${alternateDomain}) Nullifier:`,
    secondaryNullifier,
    currentPersona.type === "agent"
      ? `isValid: false (Cryptographically uncorrelatable across API gateways!)`
      : `isValid: false (Clean zero state across domains!)`
  );

  document.querySelectorAll(".step-item").forEach((s) => s.classList.add("completed"));

  header.setRunningState(false);
  isRunning = false;
}

// Initial Boot
telemetry.renderClaim(currentPersona, (label) => tracker.setStep5Label(label));
runPipeline();
