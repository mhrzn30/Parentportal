import { createElement } from "lwc";
import ChildDetail from "c/childDetail";
import { getChild } from "c/portalDataService";

jest.mock("c/portalDataService", () => ({
  getChild: jest.fn()
}));

const flushPromises = () => Promise.resolve().then(() => Promise.resolve());

const CHILD = {
  id: "chd-a1",
  firstName: "Aarav",
  lastName: "Maharjan",
  gradeLevel: "5",
  schoolName: "Riverbend Elementary",
  dateOfBirth: "2015-04-12",
  relationshipType: "Parent",
  applications: [
    {
      id: "app-1",
      schoolName: "Northgate Middle",
      status: { code: "WAITLISTED", label: "Waitlisted" },
      lotteryNumber: 214,
      submittedDate: "2025-11-03"
    }
  ]
};

describe("c-child-detail", () => {
  afterEach(() => {
    jest.clearAllMocks();
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("loadsAndShowsTheSelectedChildsProfileAndApplications", async () => {
    getChild.mockResolvedValue(CHILD);

    const element = createElement("c-child-detail", { is: ChildDetail });
    element.childId = "chd-a1";
    document.body.appendChild(element);
    await flushPromises();

    expect(getChild).toHaveBeenCalledWith("chd-a1");
    expect(element.shadowRoot.textContent).toContain("Aarav Maharjan");
    expect(element.shadowRoot.querySelectorAll("tbody tr")).toHaveLength(1);
  });

  it("showsStaffOwnedFieldsAsReadOnlyTextNotInputs", async () => {
    getChild.mockResolvedValue(CHILD);

    const element = createElement("c-child-detail", { is: ChildDetail });
    element.childId = "chd-a1";
    document.body.appendChild(element);
    await flushPromises();

    expect(element.shadowRoot.querySelector("input")).toBeNull();
    expect(element.shadowRoot.textContent).toContain("214");
  });

  it("showsNothingFoundForApplicationsWhenTheChildHasNone", async () => {
    getChild.mockResolvedValue({ ...CHILD, applications: [] });

    const element = createElement("c-child-detail", { is: ChildDetail });
    element.childId = "chd-a1";
    document.body.appendChild(element);
    await flushPromises();

    expect(element.shadowRoot.querySelector("table")).toBeNull();
    expect(element.shadowRoot.textContent).toContain("No applications yet");
  });

  it("emitsBackWhenTheBackControlIsActivated", async () => {
    getChild.mockResolvedValue(CHILD);

    const element = createElement("c-child-detail", { is: ChildDetail });
    element.childId = "chd-a1";
    document.body.appendChild(element);
    await flushPromises();

    const handler = jest.fn();
    element.addEventListener("back", handler);
    element.shadowRoot.querySelector(".detail__back").click();

    expect(handler).toHaveBeenCalledTimes(1);
  });

  it("showsFallbackWhenTheDetailRequestFails", async () => {
    getChild.mockRejectedValue(new Error("network down"));

    const element = createElement("c-child-detail", { is: ChildDetail });
    element.childId = "chd-a1";
    document.body.appendChild(element);
    await flushPromises();

    const error = element.shadowRoot.querySelector(".state-message--error");
    expect(error).not.toBeNull();
    expect(error.getAttribute("role")).toBe("alert");
  });
});
