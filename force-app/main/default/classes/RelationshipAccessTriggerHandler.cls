/**
 * Keeps guardian sharing in sync whenever a hed__Relationship__c row is
 * created, changed, deleted, or restored -- so ending a relationship
 * removes access and restoring it (or reclassifying its hed__Type__c)
 * restores access, without a separate manual step. All logic lives here,
 * not in the trigger, per CLAUDE.md.
 */
public with sharing class RelationshipAccessTriggerHandler {
  public static void handleAfterInsert(List<hed__Relationship__c> newRows) {
    resync(collectParentIds(newRows, null));
  }

  public static void handleAfterUpdate(
    List<hed__Relationship__c> newRows,
    List<hed__Relationship__c> oldRows
  ) {
    resync(collectParentIds(newRows, oldRows));
  }

  public static void handleAfterDelete(List<hed__Relationship__c> oldRows) {
    resync(collectParentIds(null, oldRows));
  }

  public static void handleAfterUndelete(List<hed__Relationship__c> newRows) {
    resync(collectParentIds(newRows, null));
  }

  private static Set<Id> collectParentIds(
    List<hed__Relationship__c> newRows,
    List<hed__Relationship__c> oldRows
  ) {
    Set<Id> parentIds = new Set<Id>();
    for (hed__Relationship__c row : newRows == null
      ? new List<hed__Relationship__c>()
      : newRows) {
      if (row.hed__Contact__c != null) {
        parentIds.add(row.hed__Contact__c);
      }
    }
    for (hed__Relationship__c row : oldRows == null
      ? new List<hed__Relationship__c>()
      : oldRows) {
      if (row.hed__Contact__c != null) {
        parentIds.add(row.hed__Contact__c);
      }
    }
    return parentIds;
  }

  private static void resync(Set<Id> parentIds) {
    if (!parentIds.isEmpty()) {
      GuardianAccessSharingService.resyncForParents(parentIds);
    }
  }
}
