trigger UserPortalAccessTrigger on User (after insert, after update) {
  if (Trigger.isInsert) {
    UserPortalAccessTriggerHandler.handleAfterInsert(Trigger.new);
  } else if (Trigger.isUpdate) {
    UserPortalAccessTriggerHandler.handleAfterUpdate(
      Trigger.new,
      Trigger.oldMap
    );
  }
}
