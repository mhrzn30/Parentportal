/**
 * Keeps guardian sharing in sync with a portal user's own lifecycle: a
 * parent whose portal user is created after the relationship already
 * exists still gets access (resync on insert), and an inactive portal user
 * gets no access at all (revoke, not resync, whenever IsActive is false).
 * Only User rows with a ContactId are portal/community users -- internal
 * users can never have one (see CLAUDE.md Known Gotchas) -- so this is a
 * cheap no-op for every internal User insert/update.
 */
public with sharing class UserPortalAccessTriggerHandler {
  public static void handleAfterInsert(List<User> newRows) {
    Set<Id> toResync = new Set<Id>();
    Set<Id> toRevoke = new Set<Id>();
    for (User row : newRows) {
      partition(row.ContactId, row.IsActive, toResync, toRevoke);
    }
    apply(toResync, toRevoke);
  }

  public static void handleAfterUpdate(
    List<User> newRows,
    Map<Id, User> oldById
  ) {
    Set<Id> toResync = new Set<Id>();
    Set<Id> toRevoke = new Set<Id>();
    for (User row : newRows) {
      User previous = oldById.get(row.Id);
      if (row.IsActive == previous.IsActive) {
        continue;
      }
      partition(row.ContactId, row.IsActive, toResync, toRevoke);
    }
    apply(toResync, toRevoke);
  }

  private static void partition(
    Id contactId,
    Boolean isActive,
    Set<Id> toResync,
    Set<Id> toRevoke
  ) {
    if (contactId == null) {
      return;
    }
    if (isActive) {
      toResync.add(contactId);
    } else {
      toRevoke.add(contactId);
    }
  }

  /**
   * Both cases go through the same resync request: the subscriber grants
   * access for an active user and clears it for an inactive one.
   */
  private static void apply(Set<Id> toResync, Set<Id> toRevoke) {
    Set<Id> parentIds = new Set<Id>(toResync);
    parentIds.addAll(toRevoke);
    GuardianAccessSharingService.requestResync(parentIds);
  }
}
