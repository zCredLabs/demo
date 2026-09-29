// SPDX-License-Identifier: MIT
import { Persona, NetworkConfig } from "../types";

export class TelemetryViewComponent {
  // Column 1
  private clientClaimLabel: HTMLElement;
  private clientClaimBox: HTMLElement;
  private envPolicy: HTMLElement;
  private envDomain: HTMLElement;
  private envClientPubkey: HTMLElement;
  private envIv: HTMLElement;
  private envNonce: HTMLElement;
  private envAad: HTMLElement;
  private envCiphertextBox: HTMLElement;

  // Column 2
  private wasmMemoryStatus: HTMLElement;
  private execPolicyText: HTMLElement;
  private decisionLabel: HTMLElement;
  private wasmTier: HTMLElement;
  private wasmNullifier: HTMLElement;
  private customdataLabel: HTMLElement;
  private wasmCustomData: HTMLElement;
  private wasmExpiry: HTMLElement;
  private wasmDigest: HTMLElement;
  private wasmSignature: HTMLElement;

  // Column 3
  private contractNetwork: HTMLElement;
  private contractSettler: HTMLElement;
  private rowTrigger: HTMLElement;
  private contractTrigger: HTMLElement;
  private contractRegistry: HTMLElement;
  private contractTxHash: HTMLElement;
  private contractGas: HTMLElement;
  private contractReadGas: HTMLElement;

  // Partner Gate 1
  private partnerCardNoct: HTMLElement;
  private standardLimit: HTMLElement;
  private zcredRateLabel: HTMLElement;
  private zcredLimit: HTMLElement;
  private zcredGain: HTMLElement;
  private borrowSummary: HTMLElement;

  // Partner Gate 2
  private partnerCardLayrs: HTMLElement;
  private layrsSpotBadge: HTMLElement;
  private layrsSpotReceipt: HTMLElement;
  private layrsSpotHash: HTMLElement;
  private layrsSpotGas: HTMLElement;
  private layrsRwaBadge: HTMLElement;
  private layrsRwaReceipt: HTMLElement;
  private layrsRwaHash: HTMLElement;
  private layrsRwaGas: HTMLElement;
  private layrsCallout: HTMLElement;
  private layrsCalloutIcon: HTMLElement;
  private layrsCalloutText: HTMLElement;

  // Partner Gate 3
  private partnerCardX402: HTMLElement;
  private x402AuthBadge: HTMLElement;
  private x402DailyAllowance: HTMLElement;
  private x402MaxDrawdown: HTMLElement;
  private pillCodeHash: HTMLElement;
  private pillDevAuth: HTMLElement;
  private pillAllowance: HTMLElement;
  private x402PayBadge: HTMLElement;
  private x402PayReceipt: HTMLElement;
  private x402ReqId: HTMLElement;
  private x402PayGas: HTMLElement;
  private x402CeilingDesc: HTMLElement;
  private x402CeilingBadge: HTMLElement;
  private x402CeilingSub: HTMLElement;
  private x402RevertReason: HTMLElement;
  private x402Callout: HTMLElement;
  private x402CalloutIcon: HTMLElement;
  private x402CalloutText: HTMLElement;

  // Privacy Audit
  private auditLabelPrimary: HTMLElement;
  private auditLabelSecondary: HTMLElement;
  private auditNoctNullifier: HTMLElement;
  private auditLayrsNullifier: HTMLElement;
  private auditStatus: HTMLElement;

  constructor() {
    // Column 1
    this.clientClaimLabel = document.getElementById("client-claim-label")!;
    this.clientClaimBox = document.getElementById("client-claim-box")!;
    this.envPolicy = document.getElementById("env-policy")!;
    this.envDomain = document.getElementById("env-domain")!;
    this.envClientPubkey = document.getElementById("env-client-pubkey")!;
    this.envIv = document.getElementById("env-iv")!;
    this.envNonce = document.getElementById("env-nonce")!;
    this.envAad = document.getElementById("env-aad")!;
    this.envCiphertextBox = document.getElementById("env-ciphertext-box")!;

    // Column 2
    this.wasmMemoryStatus = document.getElementById("wasm-memory-status")!;
    this.execPolicyText = document.getElementById("exec-policy-text")!;
    this.decisionLabel = document.getElementById("decision-label")!;
    this.wasmTier = document.getElementById("wasm-tier")!;
    this.wasmNullifier = document.getElementById("wasm-nullifier")!;
    this.customdataLabel = document.getElementById("customdata-label")!;
    this.wasmCustomData = document.getElementById("wasm-customdata")!;
    this.wasmExpiry = document.getElementById("wasm-expiry")!;
    this.wasmDigest = document.getElementById("wasm-digest")!;
    this.wasmSignature = document.getElementById("wasm-signature")!;

    // Column 3
    this.contractNetwork = document.getElementById("contract-network")!;
    this.contractSettler = document.getElementById("contract-settler")!;
    this.rowTrigger = document.getElementById("row-trigger")!;
    this.contractTrigger = document.getElementById("contract-trigger")!;
    this.contractRegistry = document.getElementById("contract-registry")!;
    this.contractTxHash = document.getElementById("contract-txhash")!;
    this.contractGas = document.getElementById("contract-gas")!;
    this.contractReadGas = document.getElementById("contract-read-gas")!;

    // Gate 1
    this.partnerCardNoct = document.getElementById("partner-card-noct")!;
    this.standardLimit = document.getElementById("standard-limit")!;
    this.zcredRateLabel = document.getElementById("zcred-rate-label")!;
    this.zcredLimit = document.getElementById("zcred-limit")!;
    this.zcredGain = document.getElementById("zcred-gain")!;
    this.borrowSummary = document.getElementById("borrow-summary")!;

    // Gate 2
    this.partnerCardLayrs = document.getElementById("partner-card-layrs")!;
    this.layrsSpotBadge = document.getElementById("layrs-spot-badge")!;
    this.layrsSpotReceipt = document.getElementById("layrs-spot-receipt")!;
    this.layrsSpotHash = document.getElementById("layrs-spot-hash")!;
    this.layrsSpotGas = document.getElementById("layrs-spot-gas")!;
    this.layrsRwaBadge = document.getElementById("layrs-rwa-badge")!;
    this.layrsRwaReceipt = document.getElementById("layrs-rwa-receipt")!;
    this.layrsRwaHash = document.getElementById("layrs-rwa-hash")!;
    this.layrsRwaGas = document.getElementById("layrs-rwa-gas")!;
    this.layrsCallout = document.getElementById("layrs-callout")!;
    this.layrsCalloutIcon = document.getElementById("layrs-callout-icon")!;
    this.layrsCalloutText = document.getElementById("layrs-callout-text")!;

    // Gate 3
    this.partnerCardX402 = document.getElementById("partner-card-x402")!;
    this.x402AuthBadge = document.getElementById("x402-auth-badge")!;
    this.x402DailyAllowance = document.getElementById("x402-daily-allowance")!;
    this.x402MaxDrawdown = document.getElementById("x402-max-drawdown")!;
    this.pillCodeHash = document.getElementById("pill-code-hash")!;
    this.pillDevAuth = document.getElementById("pill-dev-auth")!;
    this.pillAllowance = document.getElementById("pill-allowance")!;
    this.x402PayBadge = document.getElementById("x402-pay-badge")!;
    this.x402PayReceipt = document.getElementById("x402-pay-receipt")!;
    this.x402ReqId = document.getElementById("x402-req-id")!;
    this.x402PayGas = document.getElementById("x402-pay-gas")!;
    this.x402CeilingDesc = document.getElementById("x402-ceiling-desc")!;
    this.x402CeilingBadge = document.getElementById("x402-ceiling-badge")!;
    this.x402CeilingSub = document.getElementById("x402-ceiling-sub")!;
    this.x402RevertReason = document.getElementById("x402-revert-reason")!;
    this.x402Callout = document.getElementById("x402-callout")!;
    this.x402CalloutIcon = document.getElementById("x402-callout-icon")!;
    this.x402CalloutText = document.getElementById("x402-callout-text")!;

    // Privacy Audit
    this.auditLabelPrimary = document.getElementById("audit-label-primary")!;
    this.auditLabelSecondary = document.getElementById("audit-label-secondary")!;
    this.auditNoctNullifier = document.getElementById("audit-noct-nullifier")!;
    this.auditLayrsNullifier = document.getElementById("audit-layrs-nullifier")!;
    this.auditStatus = document.getElementById("audit-status")!;
  }

  public renderClaim(p: Persona, onStep5LabelChange: (label: string) => void) {
    if (p.type === "riskx") {
      onStep5LabelChange("Undercollateralized Settlement");
      this.partnerCardNoct.style.display = "block";
      this.partnerCardLayrs.style.display = "none";
      this.partnerCardX402.style.display = "none";
      this.decisionLabel.textContent = "Assigned Tier:";
      this.customdataLabel.textContent = "LTV Custom Data:";
      this.envPolicy.textContent = "0x01 (Confidential Credit)";
      this.envDomain.textContent = "lending.protocol.eth";

      this.clientClaimLabel.textContent = `Redacted Financial Claim (Client RAM Only - ${p.name})`;
      this.clientClaimBox.innerHTML = `<span class="syn-c">// Redacted Financial Claim (${p.name} - ${p.category})</span>
{
  <span class="syn-k">"liquid_net_worth_bucket"</span>: <span class="syn-s">"$${Math.floor(p.claim.liquid_net_worth_usd / 10000) * 10}k - ${Math.floor(p.claim.liquid_net_worth_usd / 10000) * 10 + 10}k"</span>,
  <span class="syn-k">"consecutive_cashflow_months"</span>: <span class="syn-n">${p.claim.consecutive_monthly_inflows}</span>,
  <span class="syn-k">"liabilities_usd"</span>: <span class="syn-n">${p.claim.total_liabilities_usd}</span>,
  <span class="syn-k">"repayment_record"</span>: <span class="syn-s">"${p.claim.successful_repayments}/${p.claim.total_historical_loans}"</span>,
  <span class="syn-k">"defaults"</span>: <span class="syn-n">${p.claim.liquidation_count}</span>,
  <span class="syn-k">"user_secret"</span>: <span class="syn-s">"0x${p.secretByte.toString(16).repeat(32)}"</span> <span class="syn-c">// Zeroized in RAM</span>
}`;
    } else if (p.type === "compliance") {
      onStep5LabelChange("Institutional Settlement");
      this.partnerCardNoct.style.display = "none";
      this.partnerCardLayrs.style.display = "block";
      this.partnerCardX402.style.display = "none";
      this.decisionLabel.textContent = "Compliance Status:";
      this.customdataLabel.textContent = "Accreditation Bitmask:";
      this.envPolicy.textContent = "0x02 (Institutional Compliance)";
      this.envDomain.textContent = "darkpool.trade.eth";

      this.clientClaimLabel.textContent = `Redacted Identity & OFAC Attestation (Client RAM Only - ${p.name})`;
      this.clientClaimBox.innerHTML = `<span class="syn-c">// Confidential Compliance Ingestion (${p.name} - ${p.category})</span>
{
  <span class="syn-k">"jurisdiction_code"</span>: <span class="syn-s">"${p.claim.jurisdiction_code}"</span>,
  <span class="syn-k">"net_worth_tier"</span>: <span class="syn-s">"$${p.claim.liquid_net_worth_usd >= 1000000 ? (p.claim.liquid_net_worth_usd / 1000000).toFixed(1) + "M+" : (p.claim.liquid_net_worth_usd / 1000).toFixed(0) + "k"}"</span>,
  <span class="syn-k">"annual_inflow_tier"</span>: <span class="syn-s">"$${(p.claim.annual_income_usd / 1000).toFixed(0)}k"</span>,
  <span class="syn-k">"pep_flag"</span>: <span class="syn-b">${p.claim.is_politically_exposed}</span>,
  <span class="syn-k">"ofac_identity_hash"</span>: <span class="syn-s">"${p.claim.identity_hash.slice(0, 18)}..."</span>,
  <span class="syn-k">"user_secret"</span>: <span class="syn-s">"0x${p.secretByte.toString(16).repeat(32)}"</span> <span class="syn-c">// Zeroized in RAM</span>
}`;
    } else {
      // Policy 3: Agent Passport
      onStep5LabelChange("x402 Micropayment Settlement");
      this.partnerCardNoct.style.display = "none";
      this.partnerCardLayrs.style.display = "none";
      this.partnerCardX402.style.display = "block";
      this.decisionLabel.textContent = "Agent Status:";
      this.customdataLabel.textContent = "Allowance & Flags Bitmask:";
      this.envPolicy.textContent = "0x03 (Agent Passport)";
      this.envDomain.textContent = "agent-gateway.internal";

      this.clientClaimLabel.textContent = `Redacted Agent Identity & Spending Spec (Client RAM Only - ${p.name})`;
      this.clientClaimBox.innerHTML = `<span class="syn-c">// Autonomous Agent Identity Spec (${p.name} - ${p.category})</span>
{
  <span class="syn-k">"developer_address"</span>: <span class="syn-s">"${p.claim.developer_address}"</span>,
  <span class="syn-k">"agent_code_hash"</span>: <span class="syn-s">"${p.claim.agent_code_hash.slice(0, 18)}... (PCR0 Spec)"</span>,
  <span class="syn-k">"max_daily_allowance_usd"</span>: <span class="syn-n">${p.claim.max_daily_allowance_usd}</span>,
  <span class="syn-k">"max_drawdown_limit"</span>: <span class="syn-s">"${(p.claim.max_drawdown_bps / 100).toFixed(1)}%"</span>,
  <span class="syn-k">"permitted_contracts"</span>: <span class="syn-s">${JSON.stringify(p.claim.permitted_contracts)}</span>,
  <span class="syn-k">"user_secret"</span>: <span class="syn-s">"0x${p.secretByte.toString(16).repeat(32)}"</span> <span class="syn-c">// Zeroized in RAM</span>
}`;
    }
  }

  public updateEnvelope(
    clientPubHex: string,
    ivHex: string,
    nonceHex: string,
    aadHex: string,
    ciphertextHex: string
  ) {
    this.envClientPubkey.textContent = `${clientPubHex.slice(0, 24)}... (${Math.floor(clientPubHex.length / 2)} bytes)`;
    this.envIv.textContent = ivHex;
    this.envNonce.textContent = `${nonceHex.slice(0, 18)}...`;
    this.envAad.textContent = aadHex;
    this.envCiphertextBox.textContent = `${ciphertextHex.slice(0, 120)}... (${Math.floor(ciphertextHex.length / 2)} bytes encrypted payload)`;
  }

  public updateEnclaveOutput(
    policyName: string,
    tierText: string,
    tierClass: string,
    nullifierHex: string,
    customDataHex: string,
    expiryFormatted: string,
    digestHex: string,
    signatureHex: string
  ) {
    this.execPolicyText.textContent = policyName;
    this.wasmTier.textContent = tierText;
    this.wasmTier.className = `tag-tier ${tierClass}`;
    this.wasmNullifier.textContent = `${nullifierHex.slice(0, 22)}...`;
    this.wasmCustomData.textContent = customDataHex;
    this.wasmExpiry.textContent = expiryFormatted;
    this.wasmDigest.textContent = `${digestHex.slice(0, 22)}...`;
    this.wasmSignature.textContent = `${signatureHex.slice(0, 26)}... (65 bytes)`;
  }

  public updateSettlementReceipt(network: NetworkConfig, txHash: string) {
    this.contractNetwork.textContent = network.name;
    this.contractSettler.textContent = network.settler;
    this.contractRegistry.textContent = `${network.registry.slice(0, 10)}... ${network.registry.slice(-6)}`;
    this.contractTxHash.textContent = `${txHash.slice(0, 18)}...`;
    this.contractGas.textContent = network.gasLabel;
    this.contractReadGas.textContent = "18,938 gas (< 26k Target)";

    if (network.hasTrigger) {
      this.rowTrigger.style.display = "flex";
      this.contractTrigger.textContent = `${network.trigger.slice(0, 10)}... ${network.trigger.slice(-6)}`;
    } else {
      this.rowTrigger.style.display = "none";
    }
  }

  public updatePartnerGates(p: Persona) {
    if (p.type === "riskx") {
      if (p.tier === 1) {
        this.standardLimit.textContent = "7.1 ETH Max (140% Margin)";
        this.zcredRateLabel.textContent = "Prime Rate (105% Margin):";
        this.zcredLimit.textContent = "9.5 ETH Max";
        this.zcredGain.textContent = "+2.4 ETH (+33.8% Liquidity Boost)";
        this.borrowSummary.className = "borrow-success-box callout-granted";
        this.borrowSummary.innerHTML = `
          <span class="callout-icon">✓</span>
          <div>
            <strong>9.0 ETH Loan Drawn Live On-Chain</strong>
            <p>Impossible under standard DeFi 140% margin without liquidating!</p>
          </div>
        `;
      } else {
        this.standardLimit.textContent = "7.1 ETH Max (140% Margin)";
        this.zcredRateLabel.textContent = "Subprime Rate (135% Margin):";
        this.zcredLimit.textContent = "7.4 ETH Max";
        this.zcredGain.textContent = "+0.3 ETH (+4.2% Liquidity Boost)";
        this.borrowSummary.className = "borrow-success-box callout-warning";
        this.borrowSummary.innerHTML = `
          <span class="callout-icon">⚠️</span>
          <div>
            <strong>5.0 ETH Loan Drawn (Tier BBB Underwritten)</strong>
            <p>Approved under tightened 135% margin reflecting elevated debt ratio.</p>
          </div>
        `;
      }
    } else if (p.type === "compliance") {
      if (p.isAccredited) {
        this.layrsSpotBadge.textContent = "✅ GRANTED";
        this.layrsSpotBadge.className = "gate-badge gate-granted";
        this.layrsSpotReceipt.style.display = "flex";
        this.layrsSpotHash.textContent = "0x20b569b906a309e3...";
        this.layrsSpotGas.textContent = "57,904 gas";

        this.layrsRwaBadge.textContent = "✅ GRANTED";
        this.layrsRwaBadge.className = "gate-badge gate-granted";
        this.layrsRwaReceipt.style.display = "flex";
        this.layrsRwaHash.textContent = "0xcf4f3653a6197e00...";
        this.layrsRwaGas.textContent = "57,939 gas";

        this.layrsCallout.className = "gate-callout callout-granted";
        this.layrsCalloutIcon.textContent = "✓";
        this.layrsCalloutText.innerHTML = `
          <strong>Institutional Accreditation Verified</strong>
          <p>${p.name} ($2.5M Net Worth) is cleared for both Spot and Institutional Dark Pool trading!</p>
        `;
      } else if (!p.isSanctioned) {
        this.layrsSpotBadge.textContent = "✅ GRANTED";
        this.layrsSpotBadge.className = "gate-badge gate-granted";
        this.layrsSpotReceipt.style.display = "flex";
        this.layrsSpotHash.textContent = "0x89ab12cd34ef5678...";
        this.layrsSpotGas.textContent = "57,904 gas";

        this.layrsRwaBadge.textContent = "🛑 BLOCKED";
        this.layrsRwaBadge.className = "gate-badge gate-blocked";
        this.layrsRwaReceipt.style.display = "none";

        this.layrsCallout.className = "gate-callout callout-warning";
        this.layrsCalloutIcon.textContent = "⚠️";
        this.layrsCalloutText.innerHTML = `
          <strong>Retail Trading Cleared / Institutional RWA Gated</strong>
          <p>${p.name} passed OFAC screening for spot books, but requires institutional accreditation for RWA Treasuries.</p>
        `;
      } else {
        this.layrsSpotBadge.textContent = "❌ REVERTED";
        this.layrsSpotBadge.className = "gate-badge gate-blocked";
        this.layrsSpotReceipt.style.display = "none";

        this.layrsRwaBadge.textContent = "❌ REVERTED";
        this.layrsRwaBadge.className = "gate-badge gate-blocked";
        this.layrsRwaReceipt.style.display = "none";

        this.layrsCallout.className = "gate-callout callout-blocked";
        this.layrsCalloutIcon.textContent = "🚫";
        this.layrsCalloutText.innerHTML = `
          <strong>Trade Rejected On-Chain: OFAC SDN Match</strong>
          <p>Enclave flagged sanctioned jurisdiction specimen. Transaction reverted with zero state change.</p>
        `;
      }
    } else {
      // Policy 3: Agent Passport
      if (p.isAttested) {
        this.x402AuthBadge.textContent = "✅ AUTHORIZED";
        this.x402AuthBadge.className = "gate-badge gate-granted";
        this.x402DailyAllowance.textContent = `$${p.dailyAllowanceUsd.toLocaleString()} USD / day`;
        this.x402MaxDrawdown.textContent = `${p.maxDrawdownPct.toFixed(1)}% (Ceiling: 15% Max)`;

        this.pillCodeHash.textContent = "✓ PCR0 Hash Verified";
        this.pillCodeHash.className = "flag-pill pill-active";
        this.pillDevAuth.textContent = "✓ Dev Authenticated";
        this.pillDevAuth.className = "flag-pill pill-active";
        this.pillAllowance.textContent = "✓ Allowance Approved";
        this.pillAllowance.className = "flag-pill pill-active";

        this.x402PayBadge.textContent = "✅ EXECUTED";
        this.x402PayBadge.className = "gate-badge gate-granted";
        this.x402PayReceipt.style.display = "flex";
        this.x402PayReceipt.innerHTML = `<span>Request ID: <strong class="mono" id="x402-req-id">${p.testPaymentRequestId.slice(0, 10)}...${p.testPaymentRequestId.slice(-4)}</strong></span><span class="gas-tag" id="x402-pay-gas">50,439 gas</span>`;

        this.x402CeilingDesc.textContent = "Attempting $600 USD charge (> $500 approved daily cap)...";
        this.x402CeilingBadge.textContent = "🛡️ REVERTED";
        this.x402CeilingBadge.className = "gate-badge gate-blocked";
        this.x402CeilingSub.style.display = "flex";
        this.x402RevertReason.textContent = "AllowanceExceeded(600, 500)";

        this.x402Callout.className = "gate-callout callout-granted";
        this.x402CalloutIcon.textContent = "✓";
        this.x402CalloutText.innerHTML = `
          <strong>Autonomous AI Agent Micropayment Cleared</strong>
          <p>${p.name} (Hardware PCR0 Verified) authorized for $${p.testPaymentUsd} pay-per-query. Daily spend ceiling strictly capped at $${p.dailyAllowanceUsd} without private API key exposure!</p>
        `;
      } else if (p.isRestricted) {
        this.x402AuthBadge.textContent = "⚠️ RESTRICTED";
        this.x402AuthBadge.className = "gate-badge gate-blocked";
        this.x402DailyAllowance.textContent = `$${p.dailyAllowanceUsd.toLocaleString()} USD (Unapproved)`;
        this.x402MaxDrawdown.textContent = `${p.maxDrawdownPct.toFixed(1)}% (Exceeds 15% Cap)`;

        this.pillCodeHash.textContent = "✓ PCR0 Hash Verified";
        this.pillCodeHash.className = "flag-pill pill-active";
        this.pillDevAuth.textContent = "✓ Dev Authenticated";
        this.pillDevAuth.className = "flag-pill pill-active";
        this.pillAllowance.textContent = "✗ Allowance Exceeded (25% Drawdown)";
        this.pillAllowance.className = "flag-pill pill-inactive";

        this.x402PayBadge.textContent = "❌ REVERTED";
        this.x402PayBadge.className = "gate-badge gate-blocked";
        this.x402PayReceipt.style.display = "flex";
        this.x402PayReceipt.innerHTML = `<span>Execution Guard: <strong class="mono" style="color: #dc2626;">Payment Aborted (Risk Ceiling Breached)</strong></span><span class="gas-tag highlight-gas">0 Wei Lost</span>`;

        this.x402CeilingDesc.textContent = "Pre-flight blocked: High-frequency drawdown exceeded parameter bounds.";
        this.x402CeilingBadge.textContent = "🛑 BLOCKED";
        this.x402CeilingBadge.className = "gate-badge gate-blocked";
        this.x402CeilingSub.style.display = "flex";
        this.x402RevertReason.textContent = "AgentNotAttested(2)";

        this.x402Callout.className = "gate-callout callout-blocked";
        this.x402CalloutIcon.textContent = "⚠️";
        this.x402CalloutText.innerHTML = `
          <strong>Restricted Agent Spending Capped</strong>
          <p>${p.name} exceeded risk drawdown ceiling (25.0% > 15.0%). Blocked from executing autonomous payments without human re-authorization.</p>
        `;
      } else {
        // Rogue
        this.x402AuthBadge.textContent = "❌ BLOCKED";
        this.x402AuthBadge.className = "gate-badge gate-blocked";
        this.x402DailyAllowance.textContent = "$0 USD (Untrusted Binary)";
        this.x402MaxDrawdown.textContent = `${p.maxDrawdownPct.toFixed(1)}% (Extreme Risk)`;

        this.pillCodeHash.textContent = "✗ PCR0 Hash Mismatch";
        this.pillCodeHash.className = "flag-pill pill-inactive";
        this.pillDevAuth.textContent = "✗ Developer Unauthenticated";
        this.pillDevAuth.className = "flag-pill pill-inactive";
        this.pillAllowance.textContent = "✗ Allowance Rejected";
        this.pillAllowance.className = "flag-pill pill-inactive";

        this.x402PayBadge.textContent = "❌ REVERTED";
        this.x402PayBadge.className = "gate-badge gate-blocked";
        this.x402PayReceipt.style.display = "flex";
        this.x402PayReceipt.innerHTML = `<span>Execution Guard: <strong class="mono" style="color: #dc2626;">Payment Aborted (PCR0 Hash Mismatch)</strong></span><span class="gas-tag highlight-gas">0 Wei Lost</span>`;

        this.x402CeilingDesc.textContent = "Untrusted binary: PCR0 code-hash failed hardware enclave attestation.";
        this.x402CeilingBadge.textContent = "🚫 BLOCKED";
        this.x402CeilingBadge.className = "gate-badge gate-blocked";
        this.x402CeilingSub.style.display = "flex";
        this.x402RevertReason.textContent = "AgentNotAttested(99)";

        this.x402Callout.className = "gate-callout callout-blocked";
        this.x402CalloutIcon.textContent = "🚫";
        this.x402CalloutText.innerHTML = `
          <strong>Rogue / Tampered Agent Reverted (Error 99)</strong>
          <p>${p.name} has an unregistered PCR0 binary hash and invalid developer address. Immediate zero-gas on-chain rejection!</p>
        `;
      }
    }
  }

  public updateAudit(
    primaryLabel: string,
    primaryNullifier: string,
    secondaryLabel: string,
    secondaryNullifier: string,
    statusText: string
  ) {
    this.auditLabelPrimary.textContent = primaryLabel;
    this.auditNoctNullifier.textContent = primaryNullifier;
    this.auditLabelSecondary.textContent = secondaryLabel;
    this.auditLayrsNullifier.textContent = secondaryNullifier;
    this.auditStatus.textContent = statusText;
  }
}
