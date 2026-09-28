import { LightningElement, api } from "lwc";
import { getChild } from "c/portalDataService";

const STATE = {
  LOADING: "loading",
  POPULATED: "populated",
  ERROR: "error"
};

export default class ChildDetail extends LightningElement {
  state = STATE.LOADING;
  child;

  @api
  get childId() {
    return this._childId;
  }

  set childId(value) {
    this._childId = value;
    this.loadChild();
  }

  async loadChild() {
    if (!this._childId) {
      return;
    }
    this.state = STATE.LOADING;
    try {
      const child = await getChild(this._childId);
      this.child = child;
      this.state = STATE.POPULATED;
    } catch {
      this.state = STATE.ERROR;
    }
  }

  get isLoading() {
    return this.state === STATE.LOADING;
  }

  get isPopulated() {
    return this.state === STATE.POPULATED;
  }

  get isError() {
    return this.state === STATE.ERROR;
  }

  get displayName() {
    return this.child ? `${this.child.firstName} ${this.child.lastName}` : "";
  }

  get applications() {
    return (this.child && this.child.applications) || [];
  }

  get hasApplications() {
    return this.applications.length > 0;
  }

  handleBack() {
    this.dispatchEvent(new CustomEvent("back"));
  }

  handleRetry() {
    this.loadChild();
  }
}
