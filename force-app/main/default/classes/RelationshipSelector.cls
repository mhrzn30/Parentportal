/**
 * The single query surface for "which children can this parent see" and its
 * inverse. Every other class (PortalDataController, GuardianAccessSharingService,
 * the Get_Application_Status action) goes through here instead of writing
 * its own hed__Relationship__c query, so there is exactly one place that
 * encodes the access rule: Status = 'Current' and hed__Type__c in
 * RelationshipTypeSettings.accessGrantingChildTypes().
 *
 * hed__Type__c on a hed__Relationship__c row always describes the *related*
 * contact from the *contact*'s point of view. On the parent's own row
 * (hed__Contact__c = parent, hed__RelatedContact__c = child) that's a
 * child-side value like "Daughter"; EDA auto-creates the reciprocal row on
 * the child's record with a guardian-side value like "Father". Both
 * childIdsForParents and parentIdsForChildren query the parent's own row
 * (the one with the child-side type), just from opposite ends -- see
 * CLAUDE.md Known Gotchas.
 *
 * WITH USER_MODE everywhere: this class runs `inherited sharing`, so a
 * caller declared `with sharing` (PortalDataController) gets the running
 * user's own record-level sharing enforced on top of USER_MODE's FLS/CRUD
 * enforcement.
 */
public inherited sharing class RelationshipSelector {
  /** parentContactId -> the set of child Contact ids that parent currently has access to. */
  public static Map<Id, Set<Id>> childIdsForParents(Set<Id> parentContactIds) {
    return childIdsForParents(parentContactIds, AccessLevel.USER_MODE);
  }

  /**
   * Same, with an explicit access mode. Only GuardianAccessSharingService
   * passes SYSTEM_MODE, so its share computation doesn't depend on who
   * triggered it; everything that returns data to a person uses the
   * USER_MODE overload above.
   */
  public static Map<Id, Set<Id>> childIdsForParents(
    Set<Id> parentContactIds,
    AccessLevel mode
  ) {
    Map<Id, Set<Id>> result = new Map<Id, Set<Id>>();
    for (
      hed__Relationship__c relationship : accessGrantingRelationshipsForParents(
        parentContactIds,
        mode
      )
    ) {
      if (!result.containsKey(relationship.hed__Contact__c)) {
        result.put(relationship.hed__Contact__c, new Set<Id>());
      }
      result.get(relationship.hed__Contact__c)
        .add(relationship.hed__RelatedContact__c);
    }
    return result;
  }

  /**
   * parentContactId -> the Ids of that parent's own access-granting
   * relationship rows. GuardianAccessSharingService shares these rows to the
   * parent, because the portal reads children *through* them as the parent.
   */
  public static Map<Id, Set<Id>> relationshipIdsForParents(
    Set<Id> parentContactIds,
    AccessLevel mode
  ) {
    Map<Id, Set<Id>> result = new Map<Id, Set<Id>>();
    for (
      hed__Relationship__c relationship : accessGrantingRelationshipsForParents(
        parentContactIds,
        mode
      )
    ) {
      if (!result.containsKey(relationship.hed__Contact__c)) {
        result.put(relationship.hed__Contact__c, new Set<Id>());
      }
      result.get(relationship.hed__Contact__c).add(relationship.Id);
    }
    return result;
  }

  /** The one query that encodes the parent-side access rule. */
  private static List<hed__Relationship__c> accessGrantingRelationshipsForParents(
    Set<Id> parentContactIds,
    AccessLevel mode
  ) {
    if (parentContactIds == null || parentContactIds.isEmpty()) {
      return new List<hed__Relationship__c>();
    }

    Set<String> accessGrantingTypes = RelationshipTypeSettings.accessGrantingChildTypes();
    if (accessGrantingTypes.isEmpty()) {
      return new List<hed__Relationship__c>();
    }

    return Database.queryWithBinds(
      'SELECT Id, hed__Contact__c, hed__RelatedContact__c' +
        ' FROM hed__Relationship__c' +
        ' WHERE hed__Contact__c IN :parentContactIds' +
        ' AND hed__Type__c IN :accessGrantingTypes' +
        ' AND hed__Status__c = \'Current\'',
      new Map<String, Object>{
        'parentContactIds' => parentContactIds,
        'accessGrantingTypes' => accessGrantingTypes
      },
      mode
    );
  }

  /** The set of parent Contact ids who currently have access to any of the given children. */
  public static Set<Id> parentIdsForChildren(Set<Id> childContactIds) {
    return parentIdsForChildren(childContactIds, AccessLevel.USER_MODE);
  }

  /** Same, with an explicit access mode -- see childIdsForParents(Set<Id>, AccessLevel). */
  public static Set<Id> parentIdsForChildren(
    Set<Id> childContactIds,
    AccessLevel mode
  ) {
    Set<Id> result = new Set<Id>();
    if (childContactIds == null || childContactIds.isEmpty()) {
      return result;
    }

    Set<String> accessGrantingTypes = RelationshipTypeSettings.accessGrantingChildTypes();
    if (accessGrantingTypes.isEmpty()) {
      return result;
    }

    List<hed__Relationship__c> relationships = Database.queryWithBinds(
      'SELECT hed__Contact__c' +
        ' FROM hed__Relationship__c' +
        ' WHERE hed__RelatedContact__c IN :childContactIds' +
        ' AND hed__Type__c IN :accessGrantingTypes' +
        ' AND hed__Status__c = \'Current\'',
      new Map<String, Object>{
        'childContactIds' => childContactIds,
        'accessGrantingTypes' => accessGrantingTypes
      },
      mode
    );
    for (hed__Relationship__c relationship : relationships) {
      result.add(relationship.hed__Contact__c);
    }
    return result;
  }
}
