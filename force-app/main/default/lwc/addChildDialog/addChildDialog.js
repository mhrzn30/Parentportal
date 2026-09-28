import { LightningElement } from "lwc";

export default class AddChildDialog extends LightningElement {
  handleClose() {
    this.dispatchEvent(new CustomEvent("close"));
  }

  handleKeydown(event) {
    if (event.key === "Escape") {
      this.handleClose();
    }
  }
}
