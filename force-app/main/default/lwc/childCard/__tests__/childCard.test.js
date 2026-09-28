import { createElement } from "lwc";
import ChildCard from "c/childCard";

const flushPromises = () => Promise.resolve().then(() => Promise.resolve());

const CHILD = {
  id: "chd-a1",
  firstName: "Aarav",
  lastName: "Maharjan",
  gradeLevel: "5",
  schoolName: "Riverbend Elementary",
  applications: [
    { id: "app-1", status: { code: "WAITLISTED", label: "Waitlisted" } }
  ]
};

describe("c-child-card", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });

  it("showsTheChildsNameGradeAndSchool", async () => {
    const element = createElement("c-child-card", { is: ChildCard });
    element.child = CHILD;
    document.body.appendChild(element);
    await flushPromises();

    expect(element.shadowRoot.textContent).toContain("Aarav Maharjan");
    expect(element.shadowRoot.textContent).toContain("Grade 5");
    expect(element.shadowRoot.textContent).toContain("Riverbend Elementary");
  });

  it("exposesTheCardActionAsARealButtonNotAClickableDiv", async () => {
    const element = createElement("c-child-card", { is: ChildCard });
    element.child = CHILD;
    document.body.appendChild(element);
    await flushPromises();

    const button = element.shadowRoot.querySelector("button[type='button']");
    expect(button).not.toBeNull();
    expect(button.textContent).toBe("Aarav Maharjan");
  });

  it("emitsChildSelectWithTheChildIdWhenActivated", async () => {
    const element = createElement("c-child-card", { is: ChildCard });
    element.child = CHILD;
    document.body.appendChild(element);
    await flushPromises();

    const handler = jest.fn();
    element.addEventListener("childselect", handler);
    element.shadowRoot.querySelector("button").click();

    expect(handler).toHaveBeenCalledTimes(1);
    expect(handler.mock.calls[0][0].detail).toEqual({ childId: "chd-a1" });
  });

  it("doesNotShowDateOfBirthOnTheCard", async () => {
    const element = createElement("c-child-card", { is: ChildCard });
    element.child = { ...CHILD, dateOfBirth: "2015-04-12" };
    document.body.appendChild(element);
    await flushPromises();

    expect(element.shadowRoot.textContent).not.toContain("2015-04-12");
  });
});
