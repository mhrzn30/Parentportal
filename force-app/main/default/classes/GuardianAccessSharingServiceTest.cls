/**
 * Proves GuardianAccessSharingService actually grants/removes real record
 * visibility for a portal user -- not just that share rows exist, but that
 * System.runAs(portalUser) can (or can't) see the record, per CLAUDE.md's
 * "assert outcomes a real user could see" rule.
 */
@isTest
private class GuardianAccessSharingServiceTest {
  @isTest
  static void resyncGrantsPortalUserAccessToChildAndApplication() {
    TestDataFactory.Household household = TestDataFactory.createHousehold(
      'Farrow',
      'Daughter'
    );
    Account school = TestDataFactory.createSchool('Brookline Elementary');
    hed__Application__c application = TestDataFactory.createApplication(
      household.student.Id,
      school.Id,
      'In Review'
    );
    User portalUser = TestDataFactory.createPortalUser(household.parent);

    Test.startTest();
    GuardianAccessSharingService.resyncForParents(
      new Set<Id>{ household.parent.Id }
    );
    Test.stopTest();

    System.runAs(portalUser) {
      List<Contact> visibleChildren = [
        SELECT Id
        FROM Contact
        WHERE Id = :household.student.Id
      ];
      List<hed__Application__c> visibleApplications = [
        SELECT Id
        FROM hed__Application__c
        WHERE Id = :application.Id
      ];
      Assert.areEqual(
        1,
        visibleChildren.size(),
        'Resync must grant the portal user real visibility into their child'
      );
      Assert.areEqual(
        1,
        visibleApplications.size(),
        'Resync must grant the portal user real visibility into their child\'s application'
      );
    }
  }

  @isTest
  static void resyncIsIdempotent() {
    TestDataFactory.Household household = TestDataFactory.createHousehold(
      'Lindqvist',
      'Son'
    );
    User portalUser = TestDataFactory.createPortalUser(household.parent);

    Test.startTest();
    GuardianAccessSharingService.resyncForParents(
      new Set<Id>{ household.parent.Id }
    );
    GuardianAccessSharingService.resyncForParents(
      new Set<Id>{ household.parent.Id }
    );
    Test.stopTest();

    Integer shareCount = [
      SELECT COUNT()
      FROM ContactShare
      WHERE
        ContactId = :household.student.Id
        AND UserOrGroupId = :portalUser.Id
        AND RowCause = 'Manual'
    ];
    Assert.areEqual(
      1,
      shareCount,
      'Running resync twice must not create a duplicate share row'
    );
    Assert.areEqual(
      1,
      relationshipShareCount(portalUser.Id),
      'Running resync twice must not create a duplicate relationship share row'
    );
  }

  @isTest
  static void endingThenRestoringRelationshipRemovesThenRestoresAccess() {
    TestDataFactory.Household household = TestDataFactory.createHousehold(
      'Petrenko',
      'Daughter'
    );
    User portalUser = TestDataFactory.createPortalUser(household.parent);
    GuardianAccessSharingService.resyncForParents(
      new Set<Id>{ household.parent.Id }
    );

    hed__Relationship__c relationship = [
      SELECT Id, hed__Status__c
      FROM hed__Relationship__c
      WHERE
        hed__Contact__c = :household.parent.Id
        AND hed__RelatedContact__c = :household.student.Id
    ];

    Test.startTest();
    relationship.hed__Status__c = 'Former';
    update relationship;
    GuardianAccessSharingService.resyncForParents(
      new Set<Id>{ household.parent.Id }
    );

    System.runAs(portalUser) {
      Assert.areEqual(
        0,
        [SELECT COUNT() FROM Contact WHERE Id = :household.student.Id],
        'Ending the relationship and resyncing must remove access'
      );
    }

    relationship.hed__Status__c = 'Current';
    update relationship;
    GuardianAccessSharingService.resyncForParents(
      new Set<Id>{ household.parent.Id }
    );
    Test.stopTest();

    System.runAs(portalUser) {
      Assert.areEqual(
        1,
        [SELECT COUNT() FROM Contact WHERE Id = :household.student.Id],
        'Restoring the relationship and resyncing must restore access'
      );
    }
  }

  @isTest
  static void turningOffGrantsAccessForStepchildRemovesAccessAfterResync() {
    TestDataFactory.Household household = TestDataFactory.createHousehold(
      'Marchetti',
      'Stepchild'
    );
    User portalUser = TestDataFactory.createPortalUser(household.parent);
    GuardianAccessSharingService.resyncForParents(
      new Set<Id>{ household.parent.Id }
    );
    System.runAs(portalUser) {
      Assert.areEqual(
        1,
        [SELECT COUNT() FROM Contact WHERE Id = :household.student.Id],
        'Stepchild must grant access before the setting is turned off'
      );
    }

    Test.startTest();
    RelationshipTypeSettings.setMockSettings(
      new List<Relationship_Type_Setting__mdt>{
        new Relationship_Type_Setting__mdt(
          Type_Value__c = 'Stepchild',
          Category__c = 'Child',
          Grants_Access__c = false
        )
      }
    );
    GuardianAccessSharingService.resyncForParents(
      new Set<Id>{ household.parent.Id }
    );
    Test.stopTest();

    System.runAs(portalUser) {
      Assert.areEqual(
        0,
        [SELECT COUNT() FROM Contact WHERE Id = :household.student.Id],
        'Turning off Grants_Access__c for Stepchild must remove access after resync'
      );
    }
  }

  @isTest
  static void parentInHouseholdACannotSeeChildOrApplicationInHouseholdB() {
    TestDataFactory.Household householdA = TestDataFactory.createHousehold(
      'Whitfield',
      'Daughter'
    );
    TestDataFactory.Household householdB = TestDataFactory.createHousehold(
      'Boateng',
      'Son'
    );
    Account school = TestDataFactory.createSchool('Meridian High');
    hed__Application__c applicationB = TestDataFactory.createApplication(
      householdB.student.Id,
      school.Id,
      'Waitlisted'
    );
    User portalUserA = TestDataFactory.createPortalUser(householdA.parent);

    GuardianAccessSharingService.resyncForParents(
      new Set<Id>{ householdA.parent.Id, householdB.parent.Id }
    );

    System.runAs(portalUserA) {
      Assert.areEqual(
        0,
        [SELECT COUNT() FROM Contact WHERE Id = :householdB.student.Id],
        'Household A\'s portal user must not see Household B\'s child'
      );
      Assert.areEqual(
        0,
        [SELECT COUNT() FROM hed__Application__c WHERE Id = :applicationB.Id],
        'Household A\'s portal user must not see Household B\'s application'
      );
    }
  }

  @isTest
  static void secondGuardianGetsAccessUnrelatedHouseholdMemberDoesNot() {
    TestDataFactory.Household household = TestDataFactory.createHousehold(
      'Okonkwo',
      'Daughter'
    );
    Contact secondGuardian = new Contact(
      FirstName = 'SecondGuardian',
      LastName = 'Okonkwo',
      AccountId = household.account.Id,
      Email = 'second.guardian.okonkwo@example.com'
    );
    Contact unrelatedAdult = new Contact(
      FirstName = 'Unrelated',
      LastName = 'Okonkwo',
      AccountId = household.account.Id,
      Email = 'unrelated.okonkwo@example.com'
    );
    insert new List<Contact>{ secondGuardian, unrelatedAdult };
    TestDataFactory.linkRelationship(
      secondGuardian.Id,
      household.student.Id,
      'Stepdaughter',
      'Current'
    );
    User secondGuardianPortalUser = TestDataFactory.createPortalUser(
      secondGuardian
    );
    User unrelatedAdultPortalUser = TestDataFactory.createPortalUser(
      unrelatedAdult
    );

    GuardianAccessSharingService.resyncForParents(
      new Set<Id>{
        household.parent.Id,
        secondGuardian.Id,
        unrelatedAdult.Id
      }
    );

    Assert.areEqual(
      1,
      [
        SELECT COUNT()
        FROM ContactShare
        WHERE
          ContactId = :household.student.Id
          AND UserOrGroupId = :secondGuardianPortalUser.Id
          AND RowCause = 'Manual'
      ],
      'A second guardian with their own relationship to the same child must also get access'
    );
    Assert.areEqual(
      0,
      [
        SELECT COUNT()
        FROM ContactShare
        WHERE
          ContactId = :household.student.Id
          AND UserOrGroupId = :unrelatedAdultPortalUser.Id
          AND RowCause = 'Manual'
      ],
      'An unrelated adult in the same household Account must not get access'
    );
  }

  @isTest
  static void bulkTwoHundredRelationshipsResyncWithinLimitsNoDuplicates() {
    Contact bulkParent = new Contact(
      FirstName = 'Bulk',
      LastName = 'Guardian',
      Email = 'bulk.guardian@example.com'
    );
    insert bulkParent;
    User bulkPortalUser = TestDataFactory.createPortalUser(bulkParent);
    Account household = new Account(Name = 'Bulk Guardian Household');
    insert household;

    List<Contact> students = new List<Contact>();
    for (Integer i = 0; i < 200; i++) {
      students.add(
        new Contact(
          FirstName = 'BulkChild' + i,
          LastName = 'Guardian',
          AccountId = household.Id
        )
      );
    }
    insert students;

    List<hed__Relationship__c> relationships = new List<hed__Relationship__c>();
    for (Contact student : students) {
      relationships.add(
        new hed__Relationship__c(
          hed__Contact__c = bulkParent.Id,
          hed__RelatedContact__c = student.Id,
          hed__Type__c = 'Child',
          hed__Status__c = 'Current'
        )
      );
    }
    insert relationships;

    Test.startTest();
    GuardianAccessSharingService.resyncForParents(
      new Set<Id>{ bulkParent.Id }
    );
    GuardianAccessSharingService.resyncForParents(
      new Set<Id>{ bulkParent.Id }
    );
    Test.stopTest();

    Assert.areEqual(
      200,
      [
        SELECT COUNT()
        FROM ContactShare
        WHERE UserOrGroupId = :bulkPortalUser.Id AND RowCause = 'Manual'
      ],
      'Bulk resync must produce exactly one share per child, even run twice'
    );
    Assert.areEqual(
      200,
      relationshipShareCount(bulkPortalUser.Id),
      'Bulk resync must produce exactly one relationship share per relationship, even run twice'
    );
  }

  @isTest
  static void resyncGrantsPortalUserAccessToOwnRelationship() {
    TestDataFactory.Household household = TestDataFactory.createHousehold(
      'Haddad',
      'Daughter'
    );
    User portalUser = TestDataFactory.createPortalUser(household.parent);

    Test.startTest();
    GuardianAccessSharingService.resyncForParents(
      new Set<Id>{ household.parent.Id }
    );
    Test.stopTest();

    System.runAs(portalUser) {
      Assert.areEqual(
        1,
        [
          SELECT COUNT()
          FROM hed__Relationship__c
          WHERE
            hed__Contact__c = :household.parent.Id
            AND hed__RelatedContact__c = :household.student.Id
        ],
        'Resync must let the parent see their own relationship to their child -- the portal reads children through it'
      );
    }
  }

  @isTest
  static void parentInHouseholdACannotSeeRelationshipInHouseholdB() {
    TestDataFactory.Household householdA = TestDataFactory.createHousehold(
      'Nakamura',
      'Son'
    );
    TestDataFactory.Household householdB = TestDataFactory.createHousehold(
      'Oyelaran',
      'Daughter'
    );
    User portalUserA = TestDataFactory.createPortalUser(householdA.parent);
    TestDataFactory.createPortalUser(householdB.parent);

    GuardianAccessSharingService.resyncForParents(
      new Set<Id>{ householdA.parent.Id, householdB.parent.Id }
    );

    System.runAs(portalUserA) {
      Assert.areEqual(
        0,
        [
          SELECT COUNT()
          FROM hed__Relationship__c
          WHERE hed__Contact__c = :householdB.parent.Id
        ],
        'Household A\'s portal user must not see Household B\'s relationships'
      );
    }
  }

  @isTest
  static void endingRelationshipRemovesRelationshipAccess() {
    TestDataFactory.Household household = TestDataFactory.createHousehold(
      'Castellanos',
      'Son'
    );
    User portalUser = TestDataFactory.createPortalUser(household.parent);
    GuardianAccessSharingService.resyncForParents(
      new Set<Id>{ household.parent.Id }
    );

    hed__Relationship__c relationship = [
      SELECT Id, hed__Status__c
      FROM hed__Relationship__c
      WHERE
        hed__Contact__c = :household.parent.Id
        AND hed__RelatedContact__c = :household.student.Id
    ];

    Test.startTest();
    relationship.hed__Status__c = 'Former';
    update relationship;
    GuardianAccessSharingService.resyncForParents(
      new Set<Id>{ household.parent.Id }
    );
    Test.stopTest();

    System.runAs(portalUser) {
      Assert.areEqual(
        0,
        [SELECT COUNT() FROM hed__Relationship__c WHERE Id = :relationship.Id],
        'Ending the relationship and resyncing must remove the parent\'s access to it'
      );
    }
  }

  /**
   * A parent adding a child from the portal requests the resync as the
   * parent themselves, before they have access to anything. The shares must
   * come out the same as when an admin runs it.
   */
  @isTest
  static void resyncRequestedByTheParentThemselvesStillGrantsAccess() {
    TestDataFactory.Household household = TestDataFactory.createHousehold(
      'Vanderberg',
      'Daughter'
    );
    User portalUser = TestDataFactory.createPortalUser(household.parent);
    // Flush the user trigger's own resync event first, so the only thing
    // that can grant access below is the parent's own request.
    Test.getEventBus().deliver();
    GuardianAccessSharingService.revokeForParents(
      new Set<Id>{ household.parent.Id }
    );

    Test.startTest();
    System.runAs(portalUser) {
      GuardianAccessSharingService.requestResync(
        new Set<Id>{ household.parent.Id }
      );
    }
    Test.stopTest();

    System.runAs(portalUser) {
      Assert.areEqual(
        1,
        [SELECT COUNT() FROM Contact WHERE Id = :household.student.Id],
        'Resync run as the parent must still grant access to their child'
      );
      Assert.areEqual(
        1,
        [
          SELECT COUNT()
          FROM hed__Relationship__c
          WHERE hed__Contact__c = :household.parent.Id
        ],
        'Resync run as the parent must still grant access to their own relationship'
      );
    }
  }

  private static Integer relationshipShareCount(Id portalUserId) {
    return [
      SELECT COUNT()
      FROM hed__Relationship__Share
      WHERE UserOrGroupId = :portalUserId AND RowCause = 'Manual'
    ];
  }
}
