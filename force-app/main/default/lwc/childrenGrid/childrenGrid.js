import { LightningElement } from "lwc";
import { getChildren } from "c/portalDataService";

const STATE = {
  LOADING: "loading",
  POPULATED: "populated",
  EMPTY: "empty",
  ERROR: "error"
};

export default class ChildrenGrid extends LightningElement {
  state = STATE.LOADING;
  children = [];

  connectedCallback() {
    this.loadChildren();
  }

  async loadChildren() {
    this.state = STATE.LOADING;
    try {
      const children = await getChildren();
      this.children = children || [];
      this.state = this.children.length ? STATE.POPULATED : STATE.EMPTY;
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

  get isEmpty() {
    return this.state === STATE.EMPTY;
  }

  get isError() {
    return this.state === STATE.ERROR;
  }

  handleRetry() {
    this.loadChildren();
  }

  handleChildSelect(event) {
    this.dispatchEvent(
      new CustomEvent("childselect", { detail: event.detail })
    );
  }
}
