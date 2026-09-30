import { createElement } from "lwc";
import FamilyDashboard from "c/familyDashboard";
import { getChildren, getChild } from "c/portalDataService";

jest.mock("c/portalDataService", () => ({
  getChildren: jest.fn(),
  getChild: jest.fn()
}));

const flushPromises = () => Promise.resolve().then(() => Promise.resolve());

const CHILD = {
  id: "chd-a1",
  firstName: "Aarav",
  lastName: "Maharjan",
  applications: []
};

describe("c-family-dashboard", () => {
  beforeEach(() => {
    getChildren.mockResolvedValue([CHILD]);
    getChild.mockResolvedValue(CHILD);
  });

  afterEach(() => {
    jest.clearAllMocks();
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("showsTheChildrenGridWhenTheDashboardFirstLoads", async () => {
    const element = createElement("c-family-dashboard", {
      is: FamilyDashboard
    });
    document.body.appendChild(element);
    await flushPromises();

    expect(element.shadowRoot.querySelector("c-children-grid")).not.toBeNull();
    expect(element.shadowRoot.querySelector("c-child-detail")).toBeNull();
  });

  it("swapsToTheChildDetailViewWhenACardIsSelected", async () => {
    const element = createElement("c-family-dashboard", {
      is: FamilyDashboard
    });
    document.body.appendChild(element);
    await flushPromises();

    element.shadowRoot
      .querySelector("c-children-grid")
      .dispatchEvent(
        new CustomEvent("childselect", { detail: { childId: "chd-a1" } })
      );
    await flushPromises();

    expect(element.shadowRoot.querySelector("c-child-detail")).not.toBeNull();
    expect(element.shadowRoot.querySelector("c-children-grid")).toBeNull();
  });

  it("returnsToTheGridWhenBackIsActivated", async () => {
    const element = createElement("c-family-dashboard", {
      is: FamilyDashboard
    });
    document.body.appendChild(element);
    await flushPromises();

    element.shadowRoot
      .querySelector("c-children-grid")
      .dispatchEvent(
        new CustomEvent("childselect", { detail: { childId: "chd-a1" } })
      );
    await flushPromises();

    element.shadowRoot
      .querySelector("c-child-detail")
      .dispatchEvent(new CustomEvent("back"));
    await flushPromises();

    expect(element.shadowRoot.querySelector("c-children-grid")).not.toBeNull();
  });

  it("opensAndClosesTheAddChildPlaceholderWithoutLinkingAChild", async () => {
    const element = createElement("c-family-dashboard", {
      is: FamilyDashboard
    });
    document.body.appendChild(element);
    await flushPromises();

    element.shadowRoot.querySelector(".dashboard__add").click();
    await flushPromises();
    expect(
      element.shadowRoot.querySelector("c-add-child-dialog")
    ).not.toBeNull();

    element.shadowRoot
      .querySelector("c-add-child-dialog")
      .dispatchEvent(new CustomEvent("close"));
    await flushPromises();

    expect(element.shadowRoot.querySelector("c-add-child-dialog")).toBeNull();
    expect(getChildren).toHaveBeenCalledTimes(1);
    expect(getChild).not.toHaveBeenCalled();
  });

  it("hidesTheAddChildButtonWhenConfiguredToDoSo", async () => {
    const element = createElement("c-family-dashboard", {
      is: FamilyDashboard
    });
    element.hideAddChild = true;
    document.body.appendChild(element);
    await flushPromises();

    expect(element.shadowRoot.querySelector(".dashboard__add")).toBeNull();
  });

  it("offersTheFamilyAssistantOnTheDashboard", async () => {
    const element = createElement("c-family-dashboard", {
      is: FamilyDashboard
    });
    document.body.appendChild(element);
    await flushPromises();

    expect(
      element.shadowRoot.querySelector("c-family-assistant-chat")
    ).not.toBeNull();
  });

  it("keepsTheSameFamilyAssistantWhenSwitchingToChildDetail", async () => {
    const element = createElement("c-family-dashboard", {
      is: FamilyDashboard
    });
    document.body.appendChild(element);
    await flushPromises();

    const chatBefore = element.shadowRoot.querySelector(
      "c-family-assistant-chat"
    );
    element.shadowRoot
      .querySelector("c-children-grid")
      .dispatchEvent(
        new CustomEvent("childselect", { detail: { childId: "chd-a1" } })
      );
    await flushPromises();

    expect(element.shadowRoot.querySelector("c-family-assistant-chat")).toBe(
      chatBefore
    );
  });

  it("hidesTheFamilyAssistantWhenConfiguredToDoSo", async () => {
    const element = createElement("c-family-dashboard", {
      is: FamilyDashboard
    });
    element.hideChat = true;
    document.body.appendChild(element);
    await flushPromises();

    expect(element.shadowRoot.querySelector("c-family-assistant-chat")).toBeNull();
  });
});
