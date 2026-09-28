/**
 * Test-first per CLAUDE.md: these describe what PortalDataController must do
 * before the class exists. Covers the happy path and the cross-household
 * denial (see docs/family-assistant-agent-progress.md for why bulk/inactive
 * -user scenarios were deferred out of this pass).
 *
 * Calls the @TestVisible getChildrenForParent()/getChildForParent() seams
 * directly with an explicit parent Contact id, rather than going through
 * UserInfo.getUserId() -> User.ContactId. That resolution is portal-user
 * -only by platform design (ContactId can't be set on an internal User at
 * all -- confirmed empirically), so a real Experience Cloud portal user
 * plus real sharing infrastructure (neither of which exists yet) would be
 * required to exercise it end to end. These tests instead prove the actual
 * security-critical part -- the relationship-filtered access logic -- which
 * is identical either way.
 */
@isTest
private class PortalDataControllerTest {
  @isTest
  static void parentSeesOwnLinkedChildAndTheirApplications() {
    TestDataFactory.Household household = TestDataFactory.createHousehold(
      'Maharjan'
    );
    Account school = TestDataFactory.createSchool('Lakeview Academy');
    TestDataFactory.createApplication(
      household.student.Id,
      school.Id,
      'In Review'
    );

    List<PortalDataController.ChildWrapper> children = PortalDataController.getChildrenForParent(
      household.parent.Id
    );
    PortalDataController.ChildWrapper child = PortalDataController.getChildForParent(
      household.parent.Id,
      household.student.Id
    );

    Assert.areEqual(
      1,
      children.size(),
      'Expected exactly the one linked child'
    );
    Assert.areEqual(household.student.Id, children[0].id);
    Assert.areEqual('Student', children[0].firstName);

    Assert.isNotNull(
      child,
      'A parent must be able to load their own child by id'
    );
    Assert.areEqual(1, child.applications.size());
    Assert.areEqual(school.Id, child.applications[0].schoolId);
    Assert.areEqual('Lakeview Academy', child.applications[0].schoolName);
    Assert.areEqual('In Review', child.applications[0].status.label);
  }

  @isTest
  static void parentCannotSeeAnotherHouseholdsChildOrApplications() {
    TestDataFactory.Household householdA = TestDataFactory.createHousehold(
      'Maharjan'
    );
    TestDataFactory.Household householdB = TestDataFactory.createHousehold(
      'Okafor'
    );
    Account school = TestDataFactory.createSchool('Northgate Middle');
    TestDataFactory.createApplication(
      householdB.student.Id,
      school.Id,
      'Waitlist'
    );

    List<PortalDataController.ChildWrapper> children = PortalDataController.getChildrenForParent(
      householdA.parent.Id
    );
    PortalDataController.ChildWrapper otherHouseholdsChild = PortalDataController.getChildForParent(
      householdA.parent.Id,
      householdB.student.Id
    );

    for (PortalDataController.ChildWrapper c : children) {
      Assert.areNotEqual(
        householdB.student.Id,
        c.id,
        'Household A must never see Household B\'s child'
      );
    }
    Assert.isNull(
      otherHouseholdsChild,
      'Requesting another household\'s child by id must resolve to nothing, not an error'
    );
  }
}
