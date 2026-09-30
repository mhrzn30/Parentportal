/**
 * Keeps guardian sharing in sync when a hed__Application__c is created for
 * (or reassigned to) a student -- so a new application for an
 * already-linked child is visible to the parent immediately, without
 * waiting for the next relationship change to trigger a resync.
 */
public with sharing class ApplicationAccessTriggerHandler {
  public static void handleAfterInsert(List<hed__Application__c> newRows) {
    resyncParentsOf(collectApplicantIds(newRows));
  }

  public static void handleAfterUpdate(
    List<hed__Application__c> newRows,
    Map<Id, hed__Application__c> oldById
  ) {
    Set<Id> applicantIds = new Set<Id>();
    for (hed__Application__c row : newRows) {
      hed__Application__c previous = oldById.get(row.Id);
      if (row.hed__Applicant__c == previous.hed__Applicant__c) {
        continue;
      }
      if (row.hed__Applicant__c != null) {
        applicantIds.add(row.hed__Applicant__c);
      }
      if (previous.hed__Applicant__c != null) {
        applicantIds.add(previous.hed__Applicant__c);
      }
    }
    resyncParentsOf(applicantIds);
  }

  private static Set<Id> collectApplicantIds(
    List<hed__Application__c> rows
  ) {
    Set<Id> applicantIds = new Set<Id>();
    for (hed__Application__c row : rows) {
      if (row.hed__Applicant__c != null) {
        applicantIds.add(row.hed__Applicant__c);
      }
    }
    return applicantIds;
  }

  private static void resyncParentsOf(Set<Id> applicantIds) {
    if (applicantIds.isEmpty()) {
      return;
    }
    // SYSTEM_MODE: whoever saved the application (staff, integration) may
    // lack field access to relationships; this only yields Ids to publish.
    Set<Id> parentIds = RelationshipSelector.parentIdsForChildren(
      applicantIds,
      AccessLevel.SYSTEM_MODE
    );
    if (!parentIds.isEmpty()) {
      GuardianAccessSharingService.requestResync(parentIds);
    }
  }
}
