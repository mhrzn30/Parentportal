/**
 * Subscriber for Guardian_Access_Resync__e. Runs as the Family Portal
 * Sharing user (see PlatformEventSubscriberConfig
 * GuardianAccessResyncConfig), which is allowed to create Manual shares.
 * Batch size is 1 and each event carries at most 200 parent Ids, so one run
 * resyncs at most 200 parents in one bulk call.
 */
public with sharing class GuardianAccessResyncHandler {
  public static void handle(List<Guardian_Access_Resync__e> events) {
    Set<Id> parentContactIds = new Set<Id>();
    for (Guardian_Access_Resync__e event : events) {
      if (String.isBlank(event.Parent_Contact_Ids__c)) {
        continue;
      }
      for (String rawId : event.Parent_Contact_Ids__c.split(',')) {
        parentContactIds.add(Id.valueOf(rawId.trim()));
      }
    }
    GuardianAccessSharingService.resyncForParents(parentContactIds);
  }
}
