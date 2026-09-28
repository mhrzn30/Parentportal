import { getChildren, getChild } from "c/portalDataService";
import apexGetChildren from "@salesforce/apex/PortalDataController.getChildren";
import apexGetChild from "@salesforce/apex/PortalDataController.getChild";

jest.mock(
  "@salesforce/apex/PortalDataController.getChildren",
  () => ({ default: jest.fn() }),
  { virtual: true }
);
jest.mock(
  "@salesforce/apex/PortalDataController.getChild",
  () => ({ default: jest.fn() }),
  { virtual: true }
);

describe("c-portal-data-service", () => {
  afterEach(() => {
    jest.clearAllMocks();
  });

  it("resolvesTheSignedInParentsLinkedChildrenFromApex", async () => {
    const children = [{ id: "003000000000001", firstName: "Aarav" }];
    apexGetChildren.mockResolvedValue(children);

    const result = await getChildren();

    expect(apexGetChildren).toHaveBeenCalledWith();
    expect(result).toBe(children);
  });

  it("resolvesOneChildsFullDetailByIdFromApex", async () => {
    const child = {
      id: "003000000000001",
      firstName: "Aarav",
      applications: []
    };
    apexGetChild.mockResolvedValue(child);

    const result = await getChild("003000000000001");

    expect(apexGetChild).toHaveBeenCalledWith({ childId: "003000000000001" });
    expect(result).toBe(child);
  });

  it("resolvesNullForAChildFromAnotherHousehold", async () => {
    apexGetChild.mockResolvedValue(null);

    const result = await getChild("003000000000002");

    expect(result).toBeNull();
  });
});
