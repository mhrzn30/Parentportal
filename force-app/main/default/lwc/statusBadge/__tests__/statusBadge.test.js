import { createElement } from "lwc";
import StatusBadge from "c/statusBadge";

const flushPromises = () => Promise.resolve().then(() => Promise.resolve());

describe("c-status-badge", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("stylesAKnownStatusWithItsOwnBadgeClass", async () => {
    const element = createElement("c-status-badge", { is: StatusBadge });
    element.status = { code: "WAITLISTED", label: "Waitlisted" };
    document.body.appendChild(element);
    await flushPromises();

    const badge = element.shadowRoot.querySelector("span.status-badge");
    expect(badge.classList).toContain("status-badge--waitlisted");
  });

  it("fallsBackToTheNeutralStyleForAStatusItDoesNotRecognise", async () => {
    const element = createElement("c-status-badge", { is: StatusBadge });
    element.status = { code: "SOME_NEW_STATUS", label: "Something New" };
    document.body.appendChild(element);
    await flushPromises();

    const badge = element.shadowRoot.querySelector("span.status-badge");
    expect(badge.classList).toContain("status-badge--unknown");
    expect(
      element.shadowRoot.querySelector("lightning-formatted-text").value
    ).toBe("Something New");
  });

  it("rendersNothingWhenThereIsNoStatus", async () => {
    const element = createElement("c-status-badge", { is: StatusBadge });
    document.body.appendChild(element);
    await flushPromises();

    expect(element.shadowRoot.querySelector("span.status-badge")).toBeNull();
  });
});
