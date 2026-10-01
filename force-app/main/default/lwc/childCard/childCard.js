import { LightningElement, api } from "lwc";

export default class ChildCard extends LightningElement {
  @api child;

  get displayName() {
    if (!this.child) {
      return "";
    }
    return `${this.child.firstName} ${this.child.lastName}`;
  }

  get initials() {
    if (!this.child) {
      return "";
    }
    return [this.child.firstName, this.child.lastName]
      .map((part) => (part ? part.trim().charAt(0) : ""))
      .join("")
      .toUpperCase();
  }

  get metaText() {
    if (!this.child) {
      return "";
    }
    const grade = this.child.gradeLevel ? `Grade ${this.child.gradeLevel}` : "";
    const school = this.child.schoolName || "";
    return [grade, school].filter(Boolean).join(" · ");
  }

  get applications() {
    return (this.child && this.child.applications) || [];
  }

  get hasApplications() {
    return this.applications.length > 0;
  }

  handleActivate() {
    this.dispatchEvent(
      new CustomEvent("childselect", { detail: { childId: this.child.id } })
    );
  }
}
