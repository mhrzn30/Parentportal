/**
 * Proves a new hed__Application__c for an already-linked child becomes
 * visible to that child's parent immediately -- via the trigger alone, no
 * explicit resync call.
 */
@isTest
private class ApplicationAccessTriggerHandlerTest {
  @isTest
  static void newApplicationForLinkedChildIsVisibleToParentImmediately() {
    TestDataFactory.Household household = TestDataFactory.createHousehold(
      'Dubois',
      'Daughter'
    );
    User portalUser = TestDataFactory.createPortalUser(household.parent);
    Account school = TestDataFactory.createSchool('Fairview Academy');

    Test.startTest();
    hed__Application__c application = TestDataFactory.createApplication(
      household.student.Id,
      school.Id,
      'In Review'
    );
    Test.stopTest();

    System.runAs(portalUser) {
      Assert.areEqual(
        1,
        [
          SELECT COUNT()
          FROM hed__Application__c
          WHERE Id = :application.Id
        ],
        'A new application for an already-linked child must be visible immediately'
      );
    }
  }
}
