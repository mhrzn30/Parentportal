trigger RelationshipAccessTrigger on hed__Relationship__c (
  after insert,
  after update,
  after delete,
  after undelete
) {
  if (Trigger.isInsert || Trigger.isUndelete) {
    RelationshipAccessTriggerHandler.handleAfterInsert(Trigger.new);
  } else if (Trigger.isUpdate) {
    RelationshipAccessTriggerHandler.handleAfterUpdate(
      Trigger.new,
      Trigger.old
    );
  } else if (Trigger.isDelete) {
    RelationshipAccessTriggerHandler.handleAfterDelete(Trigger.old);
  }
}
