import { createElement } from "lwc";
import FamilyDashboard from "c/familyDashboard";
import { getRecord } from "lightning/uiRecordApi";

jest.mock("@salesforce/user/isGuest", () => ({ default: true }), {
  virtual: true
});
jest.mock("c/portalDataService", () => ({
  getChildren: jest.fn().mockResolvedValue([]),
  getChild: jest.fn()
}));

const flushPromises = () => Promise.resolve().then(() => Promise.resolve());

describe("c-family-dashboard for a guest (not signed in)", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("neverGreetsAGuestByTheSiteGuestUserName", async () => {
    const element = createElement("c-family-dashboard", {
      is: FamilyDashboard
    });
    document.body.appendChild(element);
    getRecord.emit({
      fields: { Name: { value: "Parent Portal Site Guest User" } }
    });
    await flushPromises();

    expect(
      element.shadowRoot.querySelector(".dashboard__welcome").textContent
    ).toBe("Welcome");
  });
});
