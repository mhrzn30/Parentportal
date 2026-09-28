import { createElement } from "lwc";
import AddChildDialog from "c/addChildDialog";

const flushPromises = () => Promise.resolve().then(() => Promise.resolve());

describe("c-add-child-dialog", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("explainsVerificationIsRequiredAndDoesNotLinkAChild", async () => {
    const element = createElement("c-add-child-dialog", {
      is: AddChildDialog
    });
    document.body.appendChild(element);
    await flushPromises();

    expect(element.shadowRoot.textContent).toContain("verification");
    expect(element.shadowRoot.querySelector("[role='dialog']")).not.toBeNull();
  });

  it("emitsCloseWhenTheCloseButtonIsActivated", async () => {
    const element = createElement("c-add-child-dialog", {
      is: AddChildDialog
    });
    document.body.appendChild(element);
    await flushPromises();

    const handler = jest.fn();
    element.addEventListener("close", handler);
    element.shadowRoot.querySelector("button").click();

    expect(handler).toHaveBeenCalledTimes(1);
  });

  it("emitsCloseOnEscape", async () => {
    const element = createElement("c-add-child-dialog", {
      is: AddChildDialog
    });
    document.body.appendChild(element);
    await flushPromises();

    const handler = jest.fn();
    element.addEventListener("close", handler);
    element.shadowRoot
      .querySelector(".dialog-backdrop")
      .dispatchEvent(
        new KeyboardEvent("keydown", { key: "Escape", bubbles: true })
      );

    expect(handler).toHaveBeenCalledTimes(1);
  });
});
