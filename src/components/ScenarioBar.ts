// SPDX-License-Identifier: MIT
import { PolicyType } from "../types";

export interface ScenarioBarCallbacks {
  onProfileSelect: (personaId: string) => void;
}

export class ScenarioBarComponent {
  private profilesRiskxGroup: HTMLElement;
  private profilesComplianceGroup: HTMLElement;
  private profilesAgentGroup: HTMLElement;

  private btnAlice: HTMLButtonElement;
  private btnBob: HTMLButtonElement;
  private btnCarol: HTMLButtonElement;
  private btnErin: HTMLButtonElement;
  private btnDave: HTMLButtonElement;
  private btnAgentAlpha: HTMLButtonElement;
  private btnAgentBeta: HTMLButtonElement;
  private btnAgentGamma: HTMLButtonElement;

  constructor(callbacks: ScenarioBarCallbacks) {
    this.profilesRiskxGroup = document.getElementById("profiles-riskx")!;
    this.profilesComplianceGroup = document.getElementById("profiles-compliance")!;
    this.profilesAgentGroup = document.getElementById("profiles-agent")!;

    this.btnAlice = document.getElementById("btn-alice") as HTMLButtonElement;
    this.btnBob = document.getElementById("btn-bob") as HTMLButtonElement;
    this.btnCarol = document.getElementById("btn-carol") as HTMLButtonElement;
    this.btnErin = document.getElementById("btn-erin") as HTMLButtonElement;
    this.btnDave = document.getElementById("btn-dave") as HTMLButtonElement;
    this.btnAgentAlpha = document.getElementById("btn-agent-alpha") as HTMLButtonElement;
    this.btnAgentBeta = document.getElementById("btn-agent-beta") as HTMLButtonElement;
    this.btnAgentGamma = document.getElementById("btn-agent-gamma") as HTMLButtonElement;

    this.bindEvents(callbacks);
  }

  private bindEvents(callbacks: ScenarioBarCallbacks) {
    // RiskX Profiles
    this.btnAlice.addEventListener("click", () => {
      this.setActiveBtn(this.btnAlice, this.profilesRiskxGroup);
      callbacks.onProfileSelect("alice");
    });
    this.btnBob.addEventListener("click", () => {
      this.setActiveBtn(this.btnBob, this.profilesRiskxGroup);
      callbacks.onProfileSelect("bob");
    });

    // Compliance Profiles
    this.btnCarol.addEventListener("click", () => {
      this.setActiveBtn(this.btnCarol, this.profilesComplianceGroup);
      callbacks.onProfileSelect("carol");
    });
    this.btnErin.addEventListener("click", () => {
      this.setActiveBtn(this.btnErin, this.profilesComplianceGroup);
      callbacks.onProfileSelect("erin");
    });
    this.btnDave.addEventListener("click", () => {
      this.setActiveBtn(this.btnDave, this.profilesComplianceGroup);
      callbacks.onProfileSelect("dave");
    });

    // Agent Profiles
    this.btnAgentAlpha.addEventListener("click", () => {
      this.setActiveBtn(this.btnAgentAlpha, this.profilesAgentGroup);
      callbacks.onProfileSelect("alpha");
    });
    this.btnAgentBeta.addEventListener("click", () => {
      this.setActiveBtn(this.btnAgentBeta, this.profilesAgentGroup);
      callbacks.onProfileSelect("beta");
    });
    this.btnAgentGamma.addEventListener("click", () => {
      this.setActiveBtn(this.btnAgentGamma, this.profilesAgentGroup);
      callbacks.onProfileSelect("gamma");
    });
  }

  private setActiveBtn(btn: HTMLButtonElement, group: HTMLElement) {
    group.querySelectorAll(".profile-btn").forEach((b) => b.classList.remove("active"));
    btn.classList.add("active");
  }

  public showPolicyProfiles(policy: PolicyType) {
    this.profilesRiskxGroup.style.display = policy === "riskx" ? "flex" : "none";
    this.profilesComplianceGroup.style.display = policy === "compliance" ? "flex" : "none";
    this.profilesAgentGroup.style.display = policy === "agent" ? "flex" : "none";

    // Auto-select first profile in the newly shown group
    if (policy === "riskx") this.setActiveBtn(this.btnAlice, this.profilesRiskxGroup);
    if (policy === "compliance") this.setActiveBtn(this.btnCarol, this.profilesComplianceGroup);
    if (policy === "agent") this.setActiveBtn(this.btnAgentAlpha, this.profilesAgentGroup);
  }
}
