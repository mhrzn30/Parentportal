import { LightningElement, api } from "lwc";

const KNOWN_MODIFIERS = new Set([
  "waitlisted",
  "in_review",
  "submitted",
  "offered",
  "enrolled",
  "declined",
  "withdrawn"
]);

export default class StatusBadge extends LightningElement {
  @api status; // { code, label }

  get hasStatus() {
    return Boolean(this.status && this.status.label);
  }

  get badgeClass() {
    const code = this.status && this.status.code;
    const modifier =
      typeof code === "string" && KNOWN_MODIFIERS.has(code.toLowerCase())
        ? code.toLowerCase()
        : "unknown";
    return `status-badge status-badge--${modifier}`;
  }

  get label() {
    return this.status ? this.status.label : "";
  }
}
