/**
 * Computes and writes the Apex-managed sharing rows that give a parent
 * portal user real record access to their linked children's Contact and
 * hed__Application__c records, plus the parent's own hed__Relationship__c
 * rows -- the portal finds children by reading those relationships as the
 * parent (see CLAUDE.md "Identity + sharing design").
 *
 * resyncForParents() is idempotent: it always recomputes the *desired*
 * share set from RelationshipSelector.childIdsForParents() (the same
 * classification RelationshipSelector/PortalDataController use) and diffs
 * against what's actually shared today, so calling it twice in a row
 * inserts nothing the second time, and calling it after a relationship
 * ends or is reclassified removes the now-unwanted share.
 *
 * The outer class stays `with sharing`. Two private `without sharing` inner
 * classes do the privileged work, and both deal only in Ids:
 *  - DesiredAccessReader works out *what should* be shared, in system mode,
 *    so the result doesn't depend on who triggered the resync (an admin, a
 *    limited staff user, or a parent adding their own child).
 *  - ShareRowWriter inserts/deletes the ContactShare, hed__Application__Share
 *    and hed__Relationship__Share rows, reading only the existing Share rows
 *    it diffs against.
 * Neither returns Contact/Application business data to anyone.
 */
public with sharing class GuardianAccessSharingService {
  @TestVisible
  private static final String ROW_CAUSE = 'Manual';

  /**
   * Parents per event. The subscriber's batch size is 1, so one subscriber
   * transaction handles at most 200 parents -- the bulk size the tests prove
   * stays within governor limits.
   */
  private static final Integer IDS_PER_EVENT = 200;

  /**
   * What triggers and portal actions call. Publishes Guardian_Access_Resync__e
   * instead of resyncing inline, because only a user who can share records
   * (the Family Portal Sharing user the subscriber runs as) may create
   * Manual shares -- a parent or limited staff user can't. Published after
   * commit, so the subscriber sees the records the caller just saved.
   */
  public static void requestResync(Set<Id> parentContactIds) {
    if (parentContactIds == null || parentContactIds.isEmpty()) {
      return;
    }
    List<Guardian_Access_Resync__e> events = new List<Guardian_Access_Resync__e>();
    List<String> batch = new List<String>();
    for (Id parentId : parentContactIds) {
      batch.add(parentId);
      if (batch.size() == IDS_PER_EVENT) {
        events.add(
          new Guardian_Access_Resync__e(
            Parent_Contact_Ids__c = String.join(batch, ',')
          )
        );
        batch = new List<String>();
      }
    }
    if (!batch.isEmpty()) {
      events.add(
        new Guardian_Access_Resync__e(
          Parent_Contact_Ids__c = String.join(batch, ',')
        )
      );
    }
    // publish() reports failures (e.g. the caller lacks Create on the event)
    // in its results instead of throwing. Surface them, so a parent is never
    // left silently without access.
    for (Database.SaveResult result : EventBus.publish(events)) {
      if (!result.isSuccess()) {
        throw new ResyncRequestException(
          'Could not request a portal access resync: ' +
          result.getErrors()[0].getMessage()
        );
      }
    }
  }

  public class ResyncRequestException extends Exception {
  }

  /**
   * Recomputes and applies the desired shares for each given parent Contact
   * id's *active* portal user, based on their current access-granting
   * relationships. A parent with no portal user yet is skipped (there is no
   * one to share with); a parent whose portal user is inactive, or who has
   * no qualifying relationships, gets all of their existing shares removed.
   * Runs from the Guardian_Access_Resync__e subscriber; callers elsewhere
   * use requestResync(). Share rows are always keyed by the
   * portal User's Id -- ContactShare/hed__Application__Share.UserOrGroupId
   * must be a User (or Group) Id, never the parent's own Contact Id.
   */
  public static void resyncForParents(Set<Id> parentContactIds) {
    if (parentContactIds == null || parentContactIds.isEmpty()) {
      return;
    }

    DesiredAccessReader reader = new DesiredAccessReader();
    Map<Id, Set<Id>> childIdsByParent = reader.childIdsByParent(
      parentContactIds
    );
    Map<Id, Set<Id>> relationshipIdsByParent = reader.relationshipIdsByParent(
      parentContactIds
    );

    Set<Id> allChildIds = new Set<Id>();
    for (Set<Id> childIds : childIdsByParent.values()) {
      allChildIds.addAll(childIds);
    }

    Map<Id, Id> applicantByApplicationId = reader.applicantByApplicationId(
      allChildIds
    );

    Map<Id, Id> activeUserIdByParentContactId = reader.portalUserIdsByContactId(
      parentContactIds,
      true
    );
    Map<Id, Id> anyUserIdByParentContactId = reader.portalUserIdsByContactId(
      parentContactIds,
      false
    );

    ShareRowWriter writer = new ShareRowWriter();
    for (Id parentId : parentContactIds) {
      Id userId = activeUserIdByParentContactId.get(parentId);
      if (userId == null) {
        // Inactive portal user: no access at all, so clear whatever they had.
        Id inactiveUserId = anyUserIdByParentContactId.get(parentId);
        if (inactiveUserId != null) {
          writer.resyncOneParent(
            inactiveUserId,
            new Set<Id>(),
            new Set<Id>(),
            new Set<Id>()
          );
        }
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

      Set<Id> desiredRelationshipIds = relationshipIdsByParent.containsKey(
          parentId
        )
        ? relationshipIdsByParent.get(parentId)
        : new Set<Id>();

      writer.resyncOneParent(
        userId,
        desiredChildIds,
        desiredApplicationIds,
        desiredRelationshipIds
      );
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
    Map<Id, Id> userIdByParentContactId = new DesiredAccessReader()
      .portalUserIdsByContactId(parentContactIds, false);
    ShareRowWriter writer = new ShareRowWriter();
    for (Id userId : userIdByParentContactId.values()) {
      writer.resyncOneParent(
        userId,
        new Set<Id>(),
        new Set<Id>(),
        new Set<Id>()
      );
    }
  }

  /**
   * Works out *who should* have access, the same way no matter who triggered
   * the resync -- an admin, a staff user who can't see every record, or a
   * parent adding their own child who can't see anything yet. Deliberately
   * `without sharing` + SYSTEM_MODE (a documented exception to the CLAUDE.md
   * guardrail): it returns only Ids to the outer class, never family data to
   * a person. Everything that shows data to a user stays `with sharing` +
   * USER_MODE.
   */
  private without sharing class DesiredAccessReader {
    Map<Id, Set<Id>> childIdsByParent(Set<Id> parentContactIds) {
      return RelationshipSelector.childIdsForParents(
        parentContactIds,
        AccessLevel.SYSTEM_MODE
      );
    }

    Map<Id, Set<Id>> relationshipIdsByParent(Set<Id> parentContactIds) {
      return RelationshipSelector.relationshipIdsForParents(
        parentContactIds,
        AccessLevel.SYSTEM_MODE
      );
    }

    /** Application id -> applicant (child) id, for the given children. */
    Map<Id, Id> applicantByApplicationId(Set<Id> childIds) {
      Map<Id, Id> result = new Map<Id, Id>();
      if (childIds.isEmpty()) {
        return result;
      }
      for (hed__Application__c application : [
        SELECT Id, hed__Applicant__c
        FROM hed__Application__c
        WHERE hed__Applicant__c IN :childIds
        WITH SYSTEM_MODE
      ]) {
        result.put(application.Id, application.hed__Applicant__c);
      }
      return result;
    }

    /** Parent Contact id -> their portal User id, optionally restricted to active users. */
    Map<Id, Id> portalUserIdsByContactId(
      Set<Id> parentContactIds,
      Boolean activeOnly
    ) {
      Map<Id, Id> result = new Map<Id, Id>();
      List<User> portalUsers = activeOnly
        ? [
            SELECT Id, ContactId
            FROM User
            WHERE ContactId IN :parentContactIds AND IsActive = true
            WITH SYSTEM_MODE
          ]
        : [
            SELECT Id, ContactId
            FROM User
            WHERE ContactId IN :parentContactIds
            WITH SYSTEM_MODE
          ];
      for (User portalUser : portalUsers) {
        result.put(portalUser.ContactId, portalUser.Id);
      }
      return result;
    }
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
      Set<Id> desiredApplicationIds,
      Set<Id> desiredRelationshipIds
    ) {
      replaceContactShares(portalUserId, desiredChildIds);
      replaceApplicationShares(portalUserId, desiredApplicationIds);
      replaceRelationshipShares(portalUserId, desiredRelationshipIds);
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

    /**
     * Same diff as replaceApplicationShares, for the parent's own
     * hed__Relationship__c rows. RowCause is the plain 'Manual' string for
     * the same reason: EDA's managed object can't take a custom Apex
     * Sharing Reason.
     */
    void replaceRelationshipShares(
      Id portalUserId,
      Set<Id> desiredRelationshipIds
    ) {
      Map<Id, hed__Relationship__Share> existingByRelationshipId = new Map<Id, hed__Relationship__Share>();
      for (hed__Relationship__Share share : [
        SELECT Id, ParentId
        FROM hed__Relationship__Share
        WHERE UserOrGroupId = :portalUserId AND RowCause = :ROW_CAUSE
      ]) {
        existingByRelationshipId.put(share.ParentId, share);
      }

      List<hed__Relationship__Share> toInsert = new List<hed__Relationship__Share>();
      for (Id relationshipId : desiredRelationshipIds) {
        if (!existingByRelationshipId.containsKey(relationshipId)) {
          toInsert.add(
            new hed__Relationship__Share(
              ParentId = relationshipId,
              UserOrGroupId = portalUserId,
              AccessLevel = 'Read',
              RowCause = ROW_CAUSE
            )
          );
        }
      }

      List<hed__Relationship__Share> toDelete = new List<hed__Relationship__Share>();
      for (Id existingRelationshipId : existingByRelationshipId.keySet()) {
        if (!desiredRelationshipIds.contains(existingRelationshipId)) {
          toDelete.add(existingByRelationshipId.get(existingRelationshipId));
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
