/**
 * Computes and writes the Apex-managed sharing rows that give a parent
 * portal user real record access to their linked children's Contact and
 * hed__Application__c records (see CLAUDE.md "Identity + sharing design").
 *
 * resyncForParents() is idempotent: it always recomputes the *desired*
 * share set from RelationshipSelector.childIdsForParents() (the same
 * classification RelationshipSelector/PortalDataController use) and diffs
 * against what's actually shared today, so calling it twice in a row
 * inserts nothing the second time, and calling it after a relationship
 * ends or is reclassified removes the now-unwanted share.
 *
 * The outer class stays `with sharing` per CLAUDE.md guardrail -- it only
 * ever reads hed__Relationship__c (via RelationshipSelector) and
 * hed__Application__c to figure out *what should* be shared. The literal
 * ContactShare/hed__Application__Share DML is isolated in the private
 * `without sharing` ShareRowWriter inner class, which takes only Ids the
 * outer class already computed -- it never queries or returns Contact/
 * Application business data itself, only the existing Share rows needed to
 * diff against.
 */
public with sharing class GuardianAccessSharingService {
  @TestVisible
  private static final String ROW_CAUSE = 'Manual';

  /**
   * Recomputes and applies the desired shares for each given parent Contact
   * id's *active* portal user, based on their current access-granting
   * relationships. A parent with no active portal user yet is skipped (there
   * is no one to share with); a parent with no qualifying relationships gets
   * all of their existing shares removed. Share rows are always keyed by the
   * portal User's Id -- ContactShare/hed__Application__Share.UserOrGroupId
   * must be a User (or Group) Id, never the parent's own Contact Id.
   */
  public static void resyncForParents(Set<Id> parentContactIds) {
    if (parentContactIds == null || parentContactIds.isEmpty()) {
      return;
    }

    Map<Id, Set<Id>> childIdsByParent = RelationshipSelector.childIdsForParents(
      parentContactIds
    );

    Set<Id> allChildIds = new Set<Id>();
    for (Set<Id> childIds : childIdsByParent.values()) {
      allChildIds.addAll(childIds);
    }

    Map<Id, Id> applicantByApplicationId = new Map<Id, Id>();
    if (!allChildIds.isEmpty()) {
      for (hed__Application__c application : [
        SELECT Id, hed__Applicant__c
        FROM hed__Application__c
        WHERE hed__Applicant__c IN :allChildIds
      ]) {
        applicantByApplicationId.put(
          application.Id,
          application.hed__Applicant__c
        );
      }
    }

    Map<Id, Id> activeUserIdByParentContactId = portalUserIdsByContactId(
      parentContactIds,
      true
    );

    ShareRowWriter writer = new ShareRowWriter();
    for (Id parentId : parentContactIds) {
      Id userId = activeUserIdByParentContactId.get(parentId);
      if (userId == null) {
        continue;
      }

      Set<Id> desiredChildIds = childIdsByParent.containsKey(parentId)
        ? childIdsByParent.get(parentId)
        : new Set<Id>();

      Set<Id> desiredApplicationIds = new Set<Id>();
      for (Id applicationId : applicantByApplicationId.keySet()) {
        if (desiredChildIds.contains(applicantByApplicationId.get(applicationId))) {
          desiredApplicationIds.add(applicationId);
        }
      }

      writer.resyncOneParent(userId, desiredChildIds, desiredApplicationIds);
    }
  }

  /**
   * Removes every Manual share previously granted to the given parents'
   * portal users -- including an inactive one, since by the time this runs
   * (e.g. after a User is deactivated) that user's shares still exist and
   * need cleaning up.
   */
  public static void revokeForParents(Set<Id> parentContactIds) {
    if (parentContactIds == null || parentContactIds.isEmpty()) {
      return;
    }
    Map<Id, Id> userIdByParentContactId = portalUserIdsByContactId(
      parentContactIds,
      false
    );
    ShareRowWriter writer = new ShareRowWriter();
    for (Id userId : userIdByParentContactId.values()) {
      writer.resyncOneParent(userId, new Set<Id>(), new Set<Id>());
    }
  }

  /** Parent Contact id -> their portal User id, optionally restricted to active users. */
  private static Map<Id, Id> portalUserIdsByContactId(
    Set<Id> parentContactIds,
    Boolean activeOnly
  ) {
    Map<Id, Id> result = new Map<Id, Id>();
    List<User> portalUsers = activeOnly
      ? [
          SELECT Id, ContactId
          FROM User
          WHERE ContactId IN :parentContactIds AND IsActive = true
        ]
      : [SELECT Id, ContactId FROM User WHERE ContactId IN :parentContactIds];
    for (User portalUser : portalUsers) {
      result.put(portalUser.ContactId, portalUser.Id);
    }
    return result;
  }

  /**
   * The only code in this service allowed to insert/delete ContactShare and
   * hed__Application__Share rows. Deliberately `without sharing` -- these
   * are Setup-adjacent sharing rows, not family data -- and deliberately
   * narrow: every method takes Ids the caller already resolved, and the
   * only SOQL here reads existing Share rows (UserOrGroupId/RowCause/the
   * shared record's Id), never Contact or hed__Application__c field data.
   */
  private without sharing class ShareRowWriter {
    void resyncOneParent(
      Id portalUserId,
      Set<Id> desiredChildIds,
      Set<Id> desiredApplicationIds
    ) {
      replaceContactShares(portalUserId, desiredChildIds);
      replaceApplicationShares(portalUserId, desiredApplicationIds);
    }

    void replaceContactShares(Id portalUserId, Set<Id> desiredChildIds) {
      Map<Id, ContactShare> existingByChildId = new Map<Id, ContactShare>();
      for (ContactShare share : [
        SELECT Id, ContactId
        FROM ContactShare
        WHERE UserOrGroupId = :portalUserId AND RowCause = :ROW_CAUSE
      ]) {
        existingByChildId.put(share.ContactId, share);
      }

      List<ContactShare> toInsert = new List<ContactShare>();
      for (Id childId : desiredChildIds) {
        if (!existingByChildId.containsKey(childId)) {
          toInsert.add(
            new ContactShare(
              ContactId = childId,
              UserOrGroupId = portalUserId,
              ContactAccessLevel = 'Read',
              RowCause = Schema.ContactShare.RowCause.Manual
            )
          );
        }
      }

      List<ContactShare> toDelete = new List<ContactShare>();
      for (Id existingChildId : existingByChildId.keySet()) {
        if (!desiredChildIds.contains(existingChildId)) {
          toDelete.add(existingByChildId.get(existingChildId));
        }
      }

      if (!toInsert.isEmpty()) {
        insert toInsert;
      }
      if (!toDelete.isEmpty()) {
        delete toDelete;
      }
    }

    void replaceApplicationShares(
      Id portalUserId,
      Set<Id> desiredApplicationIds
    ) {
      Map<Id, hed__Application__Share> existingByApplicationId = new Map<Id, hed__Application__Share>();
      for (hed__Application__Share share : [
        SELECT Id, ParentId
        FROM hed__Application__Share
        WHERE UserOrGroupId = :portalUserId AND RowCause = :ROW_CAUSE
      ]) {
        existingByApplicationId.put(share.ParentId, share);
      }

      List<hed__Application__Share> toInsert = new List<hed__Application__Share>();
      for (Id applicationId : desiredApplicationIds) {
        if (!existingByApplicationId.containsKey(applicationId)) {
          toInsert.add(
            new hed__Application__Share(
              ParentId = applicationId,
              UserOrGroupId = portalUserId,
              AccessLevel = 'Read',
              RowCause = ROW_CAUSE
            )
          );
        }
      }

      List<hed__Application__Share> toDelete = new List<hed__Application__Share>();
      for (Id existingApplicationId : existingByApplicationId.keySet()) {
        if (!desiredApplicationIds.contains(existingApplicationId)) {
          toDelete.add(existingByApplicationId.get(existingApplicationId));
        }
      }

      if (!toInsert.isEmpty()) {
        insert toInsert;
      }
      if (!toDelete.isEmpty()) {
        delete toDelete;
      }
    }
  }
}
