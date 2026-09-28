import { createElement } from "lwc";
import FamilyAssistantChat from "c/familyAssistantChat";
import startSession from "@salesforce/apex/FamilyAssistantAgentController.startSession";
import sendMessageApex from "@salesforce/apex/FamilyAssistantAgentController.sendMessage";
import endSession from "@salesforce/apex/FamilyAssistantAgentController.endSession";

jest.mock(
  "@salesforce/apex/FamilyAssistantAgentController.startSession",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/FamilyAssistantAgentController.sendMessage",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/FamilyAssistantAgentController.endSession",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

const flushPromises = () => Promise.resolve().then(() => Promise.resolve());

// lightning-formatted-text is a base component stubbed by sfdx-lwc-jest with an
// empty template, so its rendered textContent is always blank in unit tests.
// Read the `value` property of each stub instance instead of shadowRoot.textContent.
function getMessageTexts(element) {
  return Array.from(
    element.shadowRoot.querySelectorAll("lightning-formatted-text")
  ).map((node) => node.value);
}

describe("c-family-assistant-chat", () => {
  beforeEach(() => {
    startSession.mockResolvedValue({
      sessionId: "session-123",
      replies: [
        "Hi! I can help with applying, school choice, documents, and your Family Dashboard."
      ]
    });
    endSession.mockResolvedValue();
  });

  afterEach(() => {
    jest.clearAllMocks();
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("renders the launcher and opens the welcome panel using the agent's own greeting", async () => {
    const element = createElement("c-family-assistant-chat", {
      is: FamilyAssistantChat
    });
    document.body.appendChild(element);

    element.shadowRoot.querySelector(".ppc-chat__launcher").click();
    await flushPromises();

    expect(element.shadowRoot.querySelector(".ppc-chat__panel")).not.toBeNull();
    expect(startSession).toHaveBeenCalledTimes(1);
    expect(element.shadowRoot.textContent).toContain("Family Assistant");
    expect(getMessageTexts(element)).toContain(
      "Hi! I can help with applying, school choice, documents, and your Family Dashboard."
    );
    expect(element.shadowRoot.querySelectorAll(".ppc-chat__chip")).toHaveLength(
      5
    );
  });

  it("submits a starter question through the agent controller with an incrementing sequence id", async () => {
    sendMessageApex.mockResolvedValue({
      sessionId: "session-123",
      replies: ["Create a Northbridge Schools parent portal account to start."]
    });

    const element = createElement("c-family-assistant-chat", {
      is: FamilyAssistantChat
    });
    document.body.appendChild(element);
    element.shadowRoot.querySelector(".ppc-chat__launcher").click();
    await flushPromises();

    element.shadowRoot.querySelector(".ppc-chat__chip").click();
    await flushPromises();

    expect(sendMessageApex).toHaveBeenCalledWith({
      sessionId: "session-123",
      sequenceId: 1,
      message: "How do I apply?"
    });
    const texts = getMessageTexts(element);
    expect(texts).toContain("How do I apply?");
    expect(texts).toContain(
      "Create a Northbridge Schools parent portal account to start."
    );
  });

  it("passes agent replies as data to lightning-formatted-text, never as raw HTML", async () => {
    sendMessageApex.mockResolvedValue({
      sessionId: "session-123",
      replies: ["<script>alert(1)</script>"]
    });

    const element = createElement("c-family-assistant-chat", {
      is: FamilyAssistantChat
    });
    document.body.appendChild(element);
    element.shadowRoot.querySelector(".ppc-chat__launcher").click();
    await flushPromises();

    const input = element.shadowRoot.querySelector("input");
    input.value = "echo this back";
    // eslint-disable-next-line @lwc/lwc/prefer-custom-event -- simulating a native DOM event, not dispatching from the component
    input.dispatchEvent(new Event("input"));
    element.shadowRoot
      .querySelector("form")
      // eslint-disable-next-line @lwc/lwc/prefer-custom-event -- simulating a native DOM event, not dispatching from the component
      .dispatchEvent(new Event("submit"));
    await flushPromises();

    expect(getMessageTexts(element)).toContain("<script>alert(1)</script>");
    expect(element.shadowRoot.querySelector("script")).toBeNull();
  });

  it("shows the fallback message and Family Support contacts when the callout fails", async () => {
    startSession.mockRejectedValueOnce(new Error("callout failed"));

    const element = createElement("c-family-assistant-chat", {
      is: FamilyAssistantChat
    });
    document.body.appendChild(element);
    element.shadowRoot.querySelector(".ppc-chat__launcher").click();
    await flushPromises();

    const texts = getMessageTexts(element).join(" ");
    expect(texts).toContain("having trouble connecting");
    expect(texts).toContain("families@example.com");
  });

  it("closes with Escape without creating a second panel", async () => {
    const element = createElement("c-family-assistant-chat", {
      is: FamilyAssistantChat
    });
    document.body.appendChild(element);
    element.shadowRoot.querySelector(".ppc-chat__launcher").click();
    await flushPromises();

    element.shadowRoot
      .querySelector("input")
      .dispatchEvent(new KeyboardEvent("keydown", { key: "Escape" }));
    await flushPromises();

    expect(element.shadowRoot.querySelector(".ppc-chat__panel")).toBeNull();

    element.shadowRoot.querySelector(".ppc-chat__launcher").click();
    await flushPromises();
    expect(
      element.shadowRoot.querySelectorAll(".ppc-chat__panel")
    ).toHaveLength(1);
  });

  it("ends the agent session when the component is removed", async () => {
    const element = createElement("c-family-assistant-chat", {
      is: FamilyAssistantChat
    });
    document.body.appendChild(element);
    element.shadowRoot.querySelector(".ppc-chat__launcher").click();
    await flushPromises();

    document.body.removeChild(element);

    expect(endSession).toHaveBeenCalledWith({ sessionId: "session-123" });
  });
});
