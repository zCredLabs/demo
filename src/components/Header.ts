// SPDX-License-Identifier: MIT
import { PolicyType } from "../types";

export interface HeaderCallbacks {
  onPolicyChange: (policy: PolicyType) => void;
  onNetworkChange: (network: "local" | "sepolia") => void;
  onRunPipeline: () => void;
}

export class HeaderComponent {
  private btnPolicyRiskx: HTMLButtonElement;
  private btnPolicyCompliance: HTMLButtonElement;
  private btnPolicyAgent: HTMLButtonElement;
  private btnNetLocal: HTMLButtonElement;
  private btnNetSepolia: HTMLButtonElement;
  private btnRun: HTMLButtonElement;

  constructor(callbacks: HeaderCallbacks) {
    this.btnPolicyRiskx = document.getElementById("btn-policy-riskx") as HTMLButtonElement;
    this.btnPolicyCompliance = document.getElementById("btn-policy-compliance") as HTMLButtonElement;
    this.btnPolicyAgent = document.getElementById("btn-policy-agent") as HTMLButtonElement;
    this.btnNetLocal = document.getElementById("btn-net-local") as HTMLButtonElement;
    this.btnNetSepolia = document.getElementById("btn-net-sepolia") as HTMLButtonElement;
    this.btnRun = document.getElementById("btn-run") as HTMLButtonElement;

    this.bindEvents(callbacks);
  }

  private bindEvents(callbacks: HeaderCallbacks) {
    this.btnPolicyRiskx.addEventListener("click", () => {
      this.setActivePolicyBtn("riskx");
      callbacks.onPolicyChange("riskx");
    });

    this.btnPolicyCompliance.addEventListener("click", () => {
      this.setActivePolicyBtn("compliance");
      callbacks.onPolicyChange("compliance");
    });

    this.btnPolicyAgent.addEventListener("click", () => {
      this.setActivePolicyBtn("agent");
      callbacks.onPolicyChange("agent");
    });

    this.btnNetLocal.addEventListener("click", () => {
      this.setActiveNetworkBtn("local");
      callbacks.onNetworkChange("local");
    });

    this.btnNetSepolia.addEventListener("click", () => {
      this.setActiveNetworkBtn("sepolia");
      callbacks.onNetworkChange("sepolia");
    });

    this.btnRun.addEventListener("click", () => {
      callbacks.onRunPipeline();
    });
  }

  public setActivePolicyBtn(policy: PolicyType) {
    [this.btnPolicyRiskx, this.btnPolicyCompliance, this.btnPolicyAgent].forEach((b) =>
      b.classList.remove("active")
    );
    if (policy === "riskx") this.btnPolicyRiskx.classList.add("active");
    if (policy === "compliance") this.btnPolicyCompliance.classList.add("active");
    if (policy === "agent") this.btnPolicyAgent.classList.add("active");
  }

  public setActiveNetworkBtn(net: "local" | "sepolia") {
    [this.btnNetLocal, this.btnNetSepolia].forEach((b) => b.classList.remove("active"));
    if (net === "local") this.btnNetLocal.classList.add("active");
    if (net === "sepolia") this.btnNetSepolia.classList.add("active");
  }

  public setRunningState(isRunning: boolean) {
    this.btnRun.disabled = isRunning;
    if (isRunning) {
      this.btnRun.innerHTML = `<span class="btn-icon">⏳</span><span>Evaluating in Nitro Enclave...</span>`;
    } else {
      this.btnRun.innerHTML = `<span class="btn-icon">⚡</span><span>Execute In-Enclave Pipeline</span>`;
    }
  }
}
