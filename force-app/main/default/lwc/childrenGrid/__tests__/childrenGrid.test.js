import { createElement } from "lwc";
import ChildrenGrid from "c/childrenGrid";
import { getChildren } from "c/portalDataService";

jest.mock("c/portalDataService", () => ({
  getChildren: jest.fn()
}));

const flushPromises = () => Promise.resolve().then(() => Promise.resolve());

describe("c-children-grid", () => {
  afterEach(() => {
    jest.clearAllMocks();
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("showsOneCardPerLinkedChildOnceTheRequestResolves", async () => {
    getChildren.mockResolvedValue([
      {
        id: "chd-a1",
        firstName: "Aarav",
        lastName: "Maharjan",
        applications: []
      },
      {
        id: "chd-a2",
        firstName: "Diya",
        lastName: "Maharjan",
        applications: []
      }
    ]);

    const element = createElement("c-children-grid", {
      is: ChildrenGrid
    });
    document.body.appendChild(element);
    await flushPromises();

    expect(element.shadowRoot.querySelectorAll("c-child-card")).toHaveLength(2);
  });

  it("showsEmptyStateWhenParentHasNoChildren", async () => {
    getChildren.mockResolvedValue([]);

    const element = createElement("c-children-grid", {
      is: ChildrenGrid
    });
    document.body.appendChild(element);
    await flushPromises();

    const empty = element.shadowRoot.querySelector(".state-message--empty");
    expect(empty).not.toBeNull();
    expect(empty.getAttribute("role")).toBe("status");
    expect(
      element.shadowRoot.querySelector(".state-message--error")
    ).toBeNull();
  });

  it("showsFallbackAndRetryWhenTheChildrenRequestFails", async () => {
    getChildren.mockRejectedValue(new Error("network down"));

    const element = createElement("c-children-grid", {
      is: ChildrenGrid
    });
    document.body.appendChild(element);
    await flushPromises();

    const error = element.shadowRoot.querySelector(".state-message--error");
    expect(error).not.toBeNull();
    expect(error.getAttribute("role")).toBe("alert");

    getChildren.mockResolvedValue([
      {
        id: "chd-a1",
        firstName: "Aarav",
        lastName: "Maharjan",
        applications: []
      }
    ]);
    element.shadowRoot.querySelector(".state-message--error button").click();
    await flushPromises();

    expect(
      element.shadowRoot.querySelector(".state-message--error")
    ).toBeNull();
    expect(element.shadowRoot.querySelectorAll("c-child-card")).toHaveLength(1);
  });

  it("emitsChildSelectWhenACardIsActivated", async () => {
    getChildren.mockResolvedValue([
      {
        id: "chd-a1",
        firstName: "Aarav",
        lastName: "Maharjan",
        applications: []
      }
    ]);

    const element = createElement("c-children-grid", {
      is: ChildrenGrid
    });
    document.body.appendChild(element);
    await flushPromises();

    const handler = jest.fn();
    element.addEventListener("childselect", handler);
    element.shadowRoot
      .querySelector("c-child-card")
      .shadowRoot.querySelector("button")
      .click();

    expect(handler).toHaveBeenCalledTimes(1);
    expect(handler.mock.calls[0][0].detail).toEqual({ childId: "chd-a1" });
  });
});
