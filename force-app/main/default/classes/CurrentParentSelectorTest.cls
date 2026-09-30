@isTest
private class CurrentParentSelectorTest {
  @isTest
  static void portalParentResolvesToOwnContact() {
    TestDataFactory.Household householdA = TestDataFactory.createHousehold(
      'Adeyemi'
    );
    TestDataFactory.Household householdB = TestDataFactory.createHousehold(
      'Lindgren'
    );
    User portalUserA = TestDataFactory.createPortalUser(householdA.parent);
    TestDataFactory.createPortalUser(householdB.parent);

    Id resolved;
    Test.startTest();
    System.runAs(portalUserA) {
      resolved = CurrentParentSelector.contactId();
    }
    Test.stopTest();

    System.assertEquals(
      householdA.parent.Id,
      resolved,
      'A portal parent must resolve to their own Contact, never another household\'s'
    );
  }

  @isTest
  static void userWithoutContactResolvesToNull() {
    Test.startTest();
    Id resolved = CurrentParentSelector.contactId();
    Test.stopTest();

    System.assertEquals(
      null,
      resolved,
      'An internal user has no parent identity'
    );
  }
}
