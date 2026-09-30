/**
 * Shared builder for realistic EDA test data: a Household Account, a parent
 * Contact, a student Contact, and the hed__Relationship__c that links them
 * (EDA auto-creates the reciprocal). Every family-data test builds households
 * through here so scenarios stay realistic and consistent (see CLAUDE.md
 * "Realistic data").
 */
@isTest
public class TestDataFactory {
  public class Household {
    public Account account;
    public Contact parent;
    public Contact student;
  }

  private static Id householdRecordTypeId() {
    return Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
      .get('HH_Account')
      .getRecordTypeId();
  }

  private static Id schoolRecordTypeId() {
    return Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
      .get('Educational_Institution')
      .getRecordTypeId();
  }

  /**
   * Portal users require their Account's owner to have a Role (Salesforce
   * enforces this so the portal role hierarchy has something to nest
   * under). Test-context admin users often don't have one by default, so
   * assign one once, idempotently, before creating the household's Account.
   */
  private static void ensureRunningUserHasRole() {
    // Wrapped in System.runAs (even as the same user) so this Setup-object
    // DML (User/UserRole) doesn't collide with the non-setup DML
    // (Account/Contact) that follows it in the same test transaction --
    // Salesforce blocks mixing the two in one transaction otherwise.
    System.runAs(new User(Id = UserInfo.getUserId())) {
      User runningUser = [
        SELECT Id, UserRoleId
        FROM User
        WHERE Id = :UserInfo.getUserId()
      ];
      if (runningUser.UserRoleId == null) {
        UserRole role = new UserRole(Name = 'Test Data Factory Role');
        insert role;
        runningUser.UserRoleId = role.Id;
        update runningUser;
      }
    }
  }

  /**
   * One household: a parent and a student, linked by a Current relationship
   * using a Child-category, access-granting hed__Type__c value (see
   * Relationship_Type_Setting__mdt). Defaults to the generic "Child" value;
   * use the overload below for scenario-specific types (Daughter,
   * Stepdaughter, Foster Son, Dependent, ...) or non-access-granting/former
   * ones under test.
   */
  public static Household createHousehold(String lastName) {
    return createHousehold(lastName, 'Child');
  }

  public static Household createHousehold(
    String lastName,
    String relationshipType
  ) {
    ensureRunningUserHasRole();
    Account household = new Account(
      Name = lastName + ' Household',
      RecordTypeId = householdRecordTypeId()
    );
    insert household;

    Contact parent = new Contact(
      FirstName = 'Parent',
      LastName = lastName,
      AccountId = household.Id,
      Email = 'parent.' + lastName.toLowerCase() + '@example.com'
    );
    Contact student = createStudent(household.Id, lastName);
    insert parent;

    linkRelationship(parent.Id, student.Id, relationshipType, 'Current');

    Household result = new Household();
    result.account = household;
    result.parent = parent;
    result.student = student;
    return result;
  }

  /** An additional student Contact under an existing household Account, not yet linked to anyone. */
  public static Contact createStudent(Id householdAccountId, String lastName) {
    Contact student = new Contact(
      FirstName = 'Student',
      LastName = lastName,
      AccountId = householdAccountId,
      Birthdate = Date.newInstance(2015, 1, 1)
    );
    insert student;
    return student;
  }

  /**
   * Links an existing parent Contact to an existing student Contact with an
   * explicit hed__Type__c/hed__Status__c, for tests that need types outside
   * the default (e.g. Granddaughter, Cousin, Stepchild, Foster Son, an
   * unclassified value, or a Former relationship). hed__Type__c here always
   * describes the related contact (the student), per EDA's convention --
   * see CLAUDE.md Known Gotchas.
   */
  public static hed__Relationship__c linkRelationship(
    Id parentId,
    Id studentId,
    String relationshipType,
    String status
  ) {
    hed__Relationship__c relationship = new hed__Relationship__c(
      hed__Contact__c = parentId,
      hed__RelatedContact__c = studentId,
      hed__Type__c = relationshipType,
      hed__Status__c = status
    );
    insert relationship;
    return relationship;
  }

  /** A school Account (Educational Institution record type) applications can point to. */
  public static Account createSchool(String name) {
    Account school = new Account(
      Name = name,
      RecordTypeId = schoolRecordTypeId()
    );
    insert school;
    return school;
  }

  public static hed__Application__c createApplication(
    Id studentId,
    Id schoolId,
    String status
  ) {
    hed__Application__c application = new hed__Application__c(
      hed__Applicant__c = studentId,
      hed__Applying_To__c = schoolId,
      hed__Application_Status__c = status,
      hed__Application_Date__c = Date.today()
    );
    insert application;
    return application;
  }

  /**
   * A Customer Community Plus Login portal User linked to a parent Contact via
   * ContactId (only portal/community license types allow setting
   * ContactId at all -- confirmed empirically; it's rejected outright for
   * internal users). Used by GuardianAccessSharingServiceTest and the
   * trigger handler tests to prove real portal-user visibility end to end
   * via System.runAs(), now that GuardianAccessSharingService and Private
   * Contact OWD exist.
   *
   * Uses the same profile and permission set real parents get in the org
   * (Family Portal Parent / Family_Portal_Parent), so a test's runAs user has
   * exactly a real parent's object, field, and custom metadata access -- a
   * missing permission fails here instead of in the portal.
   */
  public static User createPortalUser(Contact parent) {
    return createPortalUser(parent, true);
  }

  public static User createPortalUser(Contact parent, Boolean isActive) {
    User portalUser = new User(
      FirstName = parent.FirstName,
      LastName = parent.LastName,
      Alias = (parent.LastName + 'prt').left(8),
      Email = parent.Email,
      Username = parent.Id + '@portal.test.example.com',
      CommunityNickname = 'p' + parent.Id,
      ContactId = parent.Id,
      TimeZoneSidKey = 'America/Los_Angeles',
      LocaleSidKey = 'en_US',
      EmailEncodingKey = 'UTF-8',
      LanguageLocaleKey = 'en_US',
      IsActive = isActive
    );

    // Same mixed-DML isolation as ensureRunningUserHasRole -- User and
    // PermissionSetAssignment are Setup objects; the caller's household
    // (Account/Contact/hed__Relationship__c) DML already ran in this
    // transaction.
    System.runAs(new User(Id = UserInfo.getUserId())) {
      portalUser.ProfileId = [
        SELECT Id
        FROM Profile
        WHERE Name = 'Family Portal Parent'
        LIMIT 1
      ]
      .Id;
      insert portalUser;

      Id permissionSetId = [
        SELECT Id
        FROM PermissionSet
        WHERE Name = 'Family_Portal_Parent'
        LIMIT 1
      ]
      .Id;
      insert new PermissionSetAssignment(
        AssigneeId = portalUser.Id,
        PermissionSetId = permissionSetId
      );
    }

    return portalUser;
  }
}
