trigger ApplicationAccessTrigger on hed__Application__c (
  after insert,
  after update
) {
  if (Trigger.isInsert) {
    ApplicationAccessTriggerHandler.handleAfterInsert(Trigger.new);
  } else if (Trigger.isUpdate) {
    ApplicationAccessTriggerHandler.handleAfterUpdate(
      Trigger.new,
      Trigger.oldMap
    );
  }
}
