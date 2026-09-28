import apexGetChildren from "@salesforce/apex/PortalDataController.getChildren";
import apexGetChild from "@salesforce/apex/PortalDataController.getChild";

/**
 * Parent portal data service.
 *
 * Every component imports ONLY this module -- never Apex directly. That is
 * the whole swap point: this used to resolve local fixture data
 * (c/portalMockData) after a simulated delay; now it calls
 * PortalDataController, returning the same shape. No other file in the UI
 * needed to change for the swap.
 */

/** The signed-in parent's linked children (without their applications). */
export function getChildren() {
  return apexGetChildren();
}

/**
 * One child's full detail, including applications -- but only if that
 * child belongs to the signed-in parent's household. A child from another
 * household resolves to null, the same "not found" shape a real record you
 * cannot see would produce.
 */
export function getChild(childId) {
  return apexGetChild({ childId });
}
