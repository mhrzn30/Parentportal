/**
 * Proves the actual access policy end to end against the real deployed
 * Relationship_Type_Setting__mdt records (not mocked) -- these tests are
 * the contract for which hed__Type__c values grant access, per the
 * scenario catalog in CLAUDE.md / the relationship-types build spec.
 */
@isTest
private class RelationshipSelectorTest {
  @isTest
  static void parentWithCurrentDaughterRelationshipSeesThatChild() {
    TestDataFactory.Household household = TestDataFactory.createHousehold(
      'Ito',
      'Daughter'
    );

    Map<Id, Set<Id>> childIds = RelationshipSelector.childIdsForParents(
      new Set<Id>{ household.parent.Id }
    );

    Assert.isTrue(
      childIds.get(household.parent.Id).contains(household.student.Id),
      'A Current Daughter relationship must grant access to that child'
    );
  }

  @isTest
  static void stepdaughterAndFosterSonAreBothVisible() {
    TestDataFactory.Household stepHousehold = TestDataFactory.createHousehold(
      'Nakamura',
      'Stepdaughter'
    );
    Contact fosterSon = TestDataFactory.createStudent(
      stepHousehold.account.Id,
      'Nakamura'
    );
    TestDataFactory.linkRelationship(
      stepHousehold.parent.Id,
      fosterSon.Id,
      'Foster Son',
      'Current'
    );

    Set<Id> children = RelationshipSelector.childIdsForParents(
        new Set<Id>{ stepHousehold.parent.Id }
      )
      .get(stepHousehold.parent.Id);

    Assert.isTrue(
      children.contains(stepHousehold.student.Id),
      'Stepdaughter must grant access'
    );
    Assert.isTrue(fosterSon != null && children.contains(fosterSon.Id), 'Foster Son must grant access');
  }

  @isTest
  static void guardianSeesTheirDependent() {
    TestDataFactory.Household household = TestDataFactory.createHousehold(
      'Suarez',
      'Dependent'
    );

    Boolean guardianSeesDependent = RelationshipSelector.childIdsForParents(
        new Set<Id>{ household.parent.Id }
      )
      .get(household.parent.Id)
      .contains(household.student.Id);

    Assert.isTrue(
      guardianSeesDependent,
      'A Dependent relationship must grant the guardian access'
    );
  }

  @isTest
  static void grandparentNieceAndCousinTypesGrantNothing() {
    TestDataFactory.Household household = TestDataFactory.createHousehold(
      'Adeyemi'
    );
    Contact granddaughter = TestDataFactory.createStudent(
      household.account.Id,
      'Adeyemi'
    );
    Contact niece = TestDataFactory.createStudent(
      household.account.Id,
      'Adeyemi'
    );
    Contact cousin = TestDataFactory.createStudent(
      household.account.Id,
      'Adeyemi'
    );
    TestDataFactory.linkRelationship(
      household.parent.Id,
      granddaughter.Id,
      'Granddaughter',
      'Current'
    );
    TestDataFactory.linkRelationship(
      household.parent.Id,
      niece.Id,
      'Niece',
      'Current'
    );
    TestDataFactory.linkRelationship(
      household.parent.Id,
      cousin.Id,
      'Cousin',
      'Current'
    );

    Set<Id> children = RelationshipSelector.childIdsForParents(
        new Set<Id>{ household.parent.Id }
      )
      .get(household.parent.Id);

    Assert.isFalse(children.contains(granddaughter.Id), 'Granddaughter must not grant access');
    Assert.isFalse(children.contains(niece.Id), 'Niece must not grant access');
    Assert.isFalse(children.contains(cousin.Id), 'Cousin must not grant access');
  }

  @isTest
  static void parentOnlySeesChildTheyHaveTheirOwnRelationshipTo() {
    // Two parents in one household (e.g. spouses); each has their own
    // relationship to their own child only -- the other parent's child
    // must not leak across just because they share a household Account.
    TestDataFactory.Household householdWithFirstParent = TestDataFactory.createHousehold(
      'Kowalski',
      'Daughter'
    );
    Contact secondParent = new Contact(
      FirstName = 'SecondParent',
      LastName = 'Kowalski',
      AccountId = householdWithFirstParent.account.Id
    );
    insert secondParent;
    Contact secondParentsChild = TestDataFactory.createStudent(
      householdWithFirstParent.account.Id,
      'Kowalski'
    );
    TestDataFactory.linkRelationship(
      secondParent.Id,
      secondParentsChild.Id,
      'Son',
      'Current'
    );

    Set<Id> firstParentsChildren = RelationshipSelector.childIdsForParents(
        new Set<Id>{ householdWithFirstParent.parent.Id }
      )
      .get(householdWithFirstParent.parent.Id);

    Assert.isFalse(
      firstParentsChildren.contains(secondParentsChild.Id),
      'A parent must not see their spouse\'s child without their own relationship to that child'
    );
  }

  @isTest
  static void formerRelationshipGrantsNothing() {
    TestDataFactory.Household household = TestDataFactory.createHousehold(
      'Petrov',
      'Daughter'
    );
    hed__Relationship__c relationship = [
      SELECT Id
      FROM hed__Relationship__c
      WHERE
        hed__Contact__c = :household.parent.Id
        AND hed__RelatedContact__c = :household.student.Id
    ];
    relationship.hed__Status__c = 'Former';
    update relationship;

    Set<Id> children = RelationshipSelector.childIdsForParents(
        new Set<Id>{ household.parent.Id }
      )
      .get(household.parent.Id);

    Assert.isTrue(
      children == null || !children.contains(household.student.Id),
      'A Former relationship must grant no access'
    );
  }

  @isTest
  static void unclassifiedPicklistValueGrantsNothing() {
    TestDataFactory.Household household = TestDataFactory.createHousehold(
      'Haddad'
    );
    Contact friend = TestDataFactory.createStudent(
      household.account.Id,
      'Haddad'
    );
    TestDataFactory.linkRelationship(
      household.parent.Id,
      friend.Id,
      'Friend',
      'Current'
    );

    Set<Id> children = RelationshipSelector.childIdsForParents(
        new Set<Id>{ household.parent.Id }
      )
      .get(household.parent.Id);

    Assert.isFalse(
      children.contains(friend.Id),
      'A value with no Relationship_Type_Setting__mdt record must grant no access'
    );
  }

  @isTest
  static void turningOffGrantsAccessRemovesThatTypeFromResults() {
    RelationshipTypeSettings.setMockSettings(
      new List<Relationship_Type_Setting__mdt>{
        new Relationship_Type_Setting__mdt(
          Type_Value__c = 'Stepchild',
          Category__c = 'Child',
          Grants_Access__c = false
        )
      }
    );
    TestDataFactory.Household household = TestDataFactory.createHousehold(
      'Volkov',
      'Stepchild'
    );

    Map<Id, Set<Id>> childIds = RelationshipSelector.childIdsForParents(
      new Set<Id>{ household.parent.Id }
    );

    Assert.isFalse(
      childIds.containsKey(household.parent.Id),
      'Grants_Access__c = false for Stepchild must remove that access'
    );
  }

  @isTest
  static void parentInHouseholdACannotSeeChildInHouseholdB() {
    TestDataFactory.Household householdA = TestDataFactory.createHousehold(
      'Chen'
    );
    TestDataFactory.Household householdB = TestDataFactory.createHousehold(
      'Diallo'
    );

    Set<Id> householdAsChildren = RelationshipSelector.childIdsForParents(
        new Set<Id>{ householdA.parent.Id }
      )
      .get(householdA.parent.Id);

    Assert.isFalse(
      householdAsChildren.contains(householdB.student.Id),
      'Household A\'s parent must never see Household B\'s child'
    );
  }

  @isTest
  static void parentWithNoQualifyingRelationshipsGetsEmptyMapEntry() {
    Contact lonelyParent = new Contact(FirstName = 'No', LastName = 'Kids');
    insert lonelyParent;

    Map<Id, Set<Id>> childIds = RelationshipSelector.childIdsForParents(
      new Set<Id>{ lonelyParent.Id }
    );

    Assert.isFalse(
      childIds.containsKey(lonelyParent.Id),
      'A parent with no qualifying relationships must resolve to no entry, not an error'
    );
  }

  @isTest
  static void parentIdsForChildrenIsTheInverseOfChildIdsForParents() {
    TestDataFactory.Household household = TestDataFactory.createHousehold(
      'Osei',
      'Son'
    );

    Set<Id> parentIds = RelationshipSelector.parentIdsForChildren(
      new Set<Id>{ household.student.Id }
    );

    Assert.isTrue(
      parentIds.contains(household.parent.Id),
      'parentIdsForChildren must find the parent of an access-granting relationship'
    );
  }

  @isTest
  static void bulkTwoHundredRelationshipsResolveWithinLimits() {
    Contact bulkParent = new Contact(FirstName = 'Bulk', LastName = 'Parent');
    insert bulkParent;
    Account household = new Account(Name = 'Bulk Household');
    // No record type on this ad-hoc Account; only the parent/child Contacts
    // and relationships below are exercised by the selector under test.
    insert household;

    List<Contact> students = new List<Contact>();
    for (Integer i = 0; i < 200; i++) {
      students.add(
        new Contact(
          FirstName = 'Student' + i,
          LastName = 'Bulk',
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
    Map<Id, Set<Id>> childIds = RelationshipSelector.childIdsForParents(
      new Set<Id>{ bulkParent.Id }
    );
    Test.stopTest();

    Assert.areEqual(200, childIds.get(bulkParent.Id).size());
  }
}
