// SPDX-License-Identifier: MIT

export class PipelineTrackerComponent {
  private step5Label: HTMLElement;

  constructor() {
    this.step5Label = document.getElementById("step-5-label")!;
  }

  public setStep(num: number) {
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

  public setStep5Label(label: string) {
    this.step5Label.textContent = label;
  }

  public reset() {
    document.querySelectorAll(".step-item").forEach((s) => s.classList.remove("active", "completed"));
    document.querySelectorAll(".exec-step").forEach((s) => s.classList.remove("active"));
  }
}
