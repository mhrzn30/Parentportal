import { LightningElement, api } from "lwc";

const VIEW = {
  GRID: "grid",
  DETAIL: "detail"
};

export default class FamilyDashboard extends LightningElement {
  @api headingText = "Your children";
  @api hideAddChild = false;

  get showAddChild() {
    return !this.hideAddChild;
  }

  currentView = VIEW.GRID;
  selectedChildId;
  isAddChildOpen = false;

  get isGridView() {
    return this.currentView === VIEW.GRID;
  }

  get isDetailView() {
    return this.currentView === VIEW.DETAIL;
  }

  handleChildSelect(event) {
    this.selectedChildId = event.detail.childId;
    this.currentView = VIEW.DETAIL;
  }

  handleBack() {
    this.currentView = VIEW.GRID;
  }

  handleAddChildOpen() {
    this.isAddChildOpen = true;
  }

  handleAddChildClose() {
    this.isAddChildOpen = false;
  }
}
