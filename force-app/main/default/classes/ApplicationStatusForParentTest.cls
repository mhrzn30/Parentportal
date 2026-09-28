/**
 * Proves the invocable action behind Get_Application_Status returns only
 * the requesting parent's own linked children and applications -- the
 * "what's my child's status" agent scenario, including multiple children/
 * applications, cross-household denial, and the "no children" case, all
 * without touching the Flow.
 */
@isTest
private class ApplicationStatusForParentTest {
  @isTest
  static void returnsRequestingParentsChildAndApplication() {
    TestDataFactory.Household household = TestDataFactory.createHousehold(
      'Ahn',
      'Daughter'
    );
    Account school = TestDataFactory.createSchool('Ridgeline Elementary');
    TestDataFactory.createApplication(
      household.student.Id,
      school.Id,
      'Waitlisted'
    );

    ApplicationStatusForParent.Request request = new ApplicationStatusForParent.Request();
    request.parentContactId = household.parent.Id;

    List<ApplicationStatusForParent.Result> results = ApplicationStatusForParent.getApplicationStatusForParent(
      new List<ApplicationStatusForParent.Request>{ request }
    );

    Assert.areEqual(1, results.size());
    Assert.areEqual(1, results[0].students.size());
    Assert.areEqual(household.student.Id, results[0].students[0].Id);
    Assert.areEqual(1, results[0].applications.size());
    Assert.areEqual(
      household.student.Id,
      results[0].applications[0].hed__Applicant__c
    );
  }

  @isTest
  static void returnsMultipleChildrenAndApplications() {
    TestDataFactory.Household household = TestDataFactory.createHousehold(
      'Bello',
      'Daughter'
    );
    Contact secondChild = TestDataFactory.createStudent(
      household.account.Id,
      'Bello'
    );
    TestDataFactory.linkRelationship(
      household.parent.Id,
      secondChild.Id,
      'Son',
      'Current'
    );
    Account schoolA = TestDataFactory.createSchool('Harborview School');
    Account schoolB = TestDataFactory.createSchool('Crestwood Academy');
    TestDataFactory.createApplication(household.student.Id, schoolA.Id, 'In Review');
    TestDataFactory.createApplication(secondChild.Id, schoolB.Id, 'Waitlisted');

    ApplicationStatusForParent.Request request = new ApplicationStatusForParent.Request();
    request.parentContactId = household.parent.Id;

    List<ApplicationStatusForParent.Result> results = ApplicationStatusForParent.getApplicationStatusForParent(
      new List<ApplicationStatusForParent.Request>{ request }
    );

    Assert.areEqual(2, results[0].students.size());
    Assert.areEqual(2, results[0].applications.size());
  }

  @isTest
  static void doesNotReturnAnotherHouseholdsChildOrApplication() {
    TestDataFactory.Household householdA = TestDataFactory.createHousehold(
      'Kwan',
      'Daughter'
    );
    TestDataFactory.Household householdB = TestDataFactory.createHousehold(
      'Delacroix',
      'Son'
    );
    Account school = TestDataFactory.createSchool('Summit Prep');
    TestDataFactory.createApplication(
      householdB.student.Id,
      school.Id,
      'In Review'
    );

    ApplicationStatusForParent.Request request = new ApplicationStatusForParent.Request();
    request.parentContactId = householdA.parent.Id;

    List<ApplicationStatusForParent.Result> results = ApplicationStatusForParent.getApplicationStatusForParent(
      new List<ApplicationStatusForParent.Request>{ request }
    );

    for (Contact student : results[0].students) {
      Assert.areNotEqual(householdB.student.Id, student.Id);
    }
    for (hed__Application__c application : results[0].applications) {
      Assert.areNotEqual(householdB.student.Id, application.hed__Applicant__c);
    }
  }

  @isTest
  static void parentWithNoLinkedChildrenGetsEmptyListsNotAnError() {
    Contact lonelyParent = new Contact(FirstName = 'No', LastName = 'Kids');
    insert lonelyParent;

    ApplicationStatusForParent.Request request = new ApplicationStatusForParent.Request();
    request.parentContactId = lonelyParent.Id;

    List<ApplicationStatusForParent.Result> results = ApplicationStatusForParent.getApplicationStatusForParent(
      new List<ApplicationStatusForParent.Request>{ request }
    );

    Assert.areEqual(1, results.size());
    Assert.isTrue(results[0].students.isEmpty());
    Assert.isTrue(results[0].applications.isEmpty());
  }
}
