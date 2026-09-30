/**
 * Proves the hed__Relationship__c trigger itself keeps sharing in sync --
 * no test here calls GuardianAccessSharingService directly, only inserts/
 * updates/deletes hed__Relationship__c rows the way real usage would.
 */
@isTest
private class RelationshipAccessTriggerHandlerTest {
  @isTest
  static void insertingARelationshipAutomaticallyGrantsAccess() {
    TestDataFactory.Household household = TestDataFactory.createHousehold(
      'Ferreira',
      'Daughter'
    );
    User portalUser = TestDataFactory.createPortalUser(household.parent);

    // No explicit resyncForParents call -- TestDataFactory.createHousehold's
    // insert of the hed__Relationship__c row is what must trigger it. The
    // trigger publishes Guardian_Access_Resync__e; deliver() runs the
    // subscriber the way the event bus would after commit.
    Test.getEventBus().deliver();
    System.runAs(portalUser) {
      Assert.areEqual(
        1,
        [SELECT COUNT() FROM Contact WHERE Id = :household.student.Id],
        'Inserting the relationship must trigger a resync automatically'
      );
    }
  }

  @isTest
  static void deletingARelationshipAutomaticallyRemovesAccess() {
    TestDataFactory.Household household = TestDataFactory.createHousehold(
      'Kaminski',
      'Son'
    );
    User portalUser = TestDataFactory.createPortalUser(household.parent);

    hed__Relationship__c relationship = [
      SELECT Id
      FROM hed__Relationship__c
      WHERE
        hed__Contact__c = :household.parent.Id
        AND hed__RelatedContact__c = :household.student.Id
    ];

    Test.startTest();
    delete relationship;
    Test.stopTest();

    System.runAs(portalUser) {
      Assert.areEqual(
        0,
        [SELECT COUNT() FROM Contact WHERE Id = :household.student.Id],
        'Deleting the relationship must automatically remove access'
      );
    }
  }
}
