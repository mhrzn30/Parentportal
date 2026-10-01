import { LightningElement, api, wire } from "lwc";
import { getRecord, getFieldValue } from "lightning/uiRecordApi";
import USER_ID from "@salesforce/user/Id";
import IS_GUEST from "@salesforce/user/isGuest";
import USER_NAME from "@salesforce/schema/User.Name";

const VIEW = {
  GRID: "grid",
  DETAIL: "detail"
};

export default class FamilyDashboard extends LightningElement {
  @api headingText = "Your children";
  @api hideAddChild = false;
  @api hideChat = false;

  get showAddChild() {
    return !this.hideAddChild;
  }

  get showChat() {
    return !this.hideChat;
  }

  @wire(getRecord, { recordId: USER_ID, fields: [USER_NAME] })
  signedInUser;

  get welcomeText() {
    const name =
      !IS_GUEST && this.signedInUser?.data
        ? getFieldValue(this.signedInUser.data, USER_NAME)
        : null;
    return name ? `Welcome, ${name}` : "Welcome";
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
