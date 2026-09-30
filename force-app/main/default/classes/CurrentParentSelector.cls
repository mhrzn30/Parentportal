/**
 * The single place that resolves the signed-in parent's identity:
 * UserInfo.getUserId() -> User.ContactId. Set by Salesforce at login, so it
 * can never come from the browser or the agent conversation. Returns null for
 * internal and guest users (no Contact), which callers treat as "no family
 * data". Used by PortalDataController and FamilyAssistantAgentController.
 */
public with sharing class CurrentParentSelector {
  public static Id contactId() {
    List<User> runningUser = [
      SELECT ContactId
      FROM User
      WHERE Id = :UserInfo.getUserId()
    ];
    return runningUser.isEmpty() ? null : runningUser[0].ContactId;
  }
}
