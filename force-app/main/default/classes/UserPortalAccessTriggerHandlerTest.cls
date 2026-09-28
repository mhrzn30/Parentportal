/**
 * Proves the portal User's own lifecycle drives access: created after the
 * relationship already exists, an inactive user gets nothing, and
 * reactivating restores access -- all via the User trigger alone.
 */
@isTest
private class UserPortalAccessTriggerHandlerTest {
  @isTest
  static void portalUserCreatedAfterRelationshipStillGetsAccess() {
    TestDataFactory.Household household = TestDataFactory.createHousehold(
      'Larsson',
      'Daughter'
    );

    Test.startTest();
    User portalUser = TestDataFactory.createPortalUser(household.parent);
    Test.stopTest();

    System.runAs(portalUser) {
      Assert.areEqual(
        1,
        [SELECT COUNT() FROM Contact WHERE Id = :household.student.Id],
        'A portal user created after the relationship already exists must still get access'
      );
    }
  }

  @isTest
  static void inactivePortalUserGetsNoAccess() {
    TestDataFactory.Household household = TestDataFactory.createHousehold(
      'Bianchi',
      'Son'
    );

    User inactivePortalUser = TestDataFactory.createPortalUser(
      household.parent,
      false
    );

    Assert.areEqual(
      0,
      [
        SELECT COUNT()
        FROM ContactShare
        WHERE
          ContactId = :household.student.Id
          AND UserOrGroupId = :inactivePortalUser.Id
          AND RowCause = 'Manual'
      ],
      'An inactive portal user must receive no access'
    );
  }

  @isTest
  static void reactivatingAPortalUserRestoresAccess() {
    TestDataFactory.Household household = TestDataFactory.createHousehold(
      'Moreau',
      'Daughter'
    );
    User portalUser = TestDataFactory.createPortalUser(
      household.parent,
      false
    );

    Test.startTest();
    // Re-query and flip IsActive as its own update, isolated from the
    // Setup-object mixed-DML rules the same way TestDataFactory does.
    System.runAs(new User(Id = UserInfo.getUserId())) {
      portalUser.IsActive = true;
      update portalUser;
    }
    Test.stopTest();

    System.runAs(portalUser) {
      Assert.areEqual(
        1,
        [SELECT COUNT() FROM Contact WHERE Id = :household.student.Id],
        'Reactivating the portal user must restore access'
      );
    }
  }
}
