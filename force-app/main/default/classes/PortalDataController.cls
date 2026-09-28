/**
 * Apex bridge between the Family Dashboard LWC and real EDA data, replacing
 * c/portalDataService's mock fixtures. Returns the same shape the LWC
 * already consumes (see c/portalDataService).
 *
 * `with sharing` per CLAUDE.md guardrail. Access boundary today is
 * RelationshipSelector.childIdsForParents(), scoped from the signed-in
 * parent (resolved server-side from UserInfo.getUserId() -> User.ContactId,
 * never a client-supplied id) through hed__Relationship__c rows whose
 * hed__Type__c is classified as access-granting in
 * Relationship_Type_Setting__mdt -- the same trust boundary the Family
 * Assistant agent action and GuardianAccessSharingService use, so a picklist
 * value never has to be reclassified in more than one place.
 *
 * A real Experience Cloud/Customer Community Plus portal user now sees
 * their own linked children and applications: GuardianAccessSharingService
 * grants them real ContactShare/hed__Application__Share rows (RowCause
 * Manual), kept in sync by triggers on hed__Relationship__c,
 * hed__Application__c, and User. Still not yet placed on an Experience
 * Cloud site (no digital experience exists in this repo yet).
 */
public with sharing class PortalDataController {
  public class StatusWrapper {
    @AuraEnabled
    public String code;
    @AuraEnabled
    public String label;
  }

  public class ApplicationWrapper {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public Id childId;
    @AuraEnabled
    public Id schoolId;
    @AuraEnabled
    public String schoolName;
    @AuraEnabled
    public StatusWrapper status;
    @AuraEnabled
    public Integer lotteryNumber;
    @AuraEnabled
    public Date submittedDate;
  }

  public class ChildWrapper {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public String firstName;
    @AuraEnabled
    public String lastName;
    @AuraEnabled
    public String gradeLevel;
    @AuraEnabled
    public String schoolName;
    @AuraEnabled
    public Date dateOfBirth;
    @AuraEnabled
    public String relationshipType;
    @AuraEnabled
    public List<ApplicationWrapper> applications;
  }

  /** The signed-in parent's linked children (without needing a child id). */
  @AuraEnabled(cacheable=true)
  public static List<ChildWrapper> getChildren() {
    return getChildrenForParent(currentParentContactId());
  }

  /**
   * Split out from getChildren() so the relationship-filtered access logic
   * -- the security-critical part -- can be unit tested directly with any
   * user, independent of UserInfo.getUserId()/ContactId. That resolution is
   * portal-user-only by platform design (ContactId can't be set on an
   * internal User at all -- confirmed empirically), so it isn't something a
   * test can drive without a real Experience Cloud portal user, which needs
   * sharing infrastructure this org doesn't have yet (see class doc).
   */
  @TestVisible
  private static List<ChildWrapper> getChildrenForParent(Id parentContactId) {
    if (parentContactId == null) {
      return new List<ChildWrapper>();
    }

    Set<Id> childIds = RelationshipSelector.childIdsForParents(
        new Set<Id>{ parentContactId }
      )
      .get(parentContactId);
    if (childIds == null || childIds.isEmpty()) {
      return new List<ChildWrapper>();
    }

    Map<Id, String> relationshipTypeByStudentId = relationshipTypeByStudentId(
      parentContactId,
      childIds
    );
    Map<Id, List<hed__Application__c>> applicationsByStudentId = applicationsByStudentId(
      childIds
    );

    List<ChildWrapper> children = new List<ChildWrapper>();
    for (Contact student : [
      SELECT Id, FirstName, LastName, Birthdate
      FROM Contact
      WHERE Id IN :childIds
    ]) {
      children.add(
        toChildWrapper(
          student,
          relationshipTypeByStudentId.get(student.Id),
          applicationsByStudentId.get(student.Id)
        )
      );
    }
    return children;
  }

  /**
   * One child's full detail, including applications -- but only if that
   * child has an active relationship to the signed-in parent. A child from
   * another household resolves to null, never an error, so the client
   * can't distinguish "not yours" from "doesn't exist".
   */
  @AuraEnabled(cacheable=true)
  public static ChildWrapper getChild(Id childId) {
    return getChildForParent(currentParentContactId(), childId);
  }

  /** Test seam -- see getChildrenForParent(). */
  @TestVisible
  private static ChildWrapper getChildForParent(
    Id parentContactId,
    Id childId
  ) {
    if (parentContactId == null || childId == null) {
      return null;
    }

    Set<Id> childIds = RelationshipSelector.childIdsForParents(
        new Set<Id>{ parentContactId }
      )
      .get(parentContactId);
    if (childIds == null || !childIds.contains(childId)) {
      return null;
    }

    List<Contact> students = [
      SELECT Id, FirstName, LastName, Birthdate
      FROM Contact
      WHERE Id = :childId
    ];
    if (students.isEmpty()) {
      return null;
    }

    return toChildWrapper(
      students[0],
      relationshipTypeByStudentId(parentContactId, new Set<Id>{ childId })
        .get(childId),
      applicationsByStudentId(new Set<Id>{ childId }).get(childId)
    );
  }

  private static Id currentParentContactId() {
    List<User> runningUser = [
      SELECT ContactId
      FROM User
      WHERE Id = :UserInfo.getUserId()
    ];
    return runningUser.isEmpty() ? null : runningUser[0].ContactId;
  }

  /**
   * The hed__Type__c label (e.g. "Daughter", "Foster Son") for each already
   * -authorized child, for display only. Both hed__Contact__c and
   * hed__RelatedContact__c are pinned to values RelationshipSelector already
   * vetted, so this never widens access -- it just fetches the label for
   * children the caller already knows are in scope.
   */
  private static Map<Id, String> relationshipTypeByStudentId(
    Id parentId,
    Set<Id> childIds
  ) {
    Map<Id, String> result = new Map<Id, String>();
    for (hed__Relationship__c relationship : [
      SELECT hed__RelatedContact__c, hed__Type__c
      FROM hed__Relationship__c
      WHERE
        hed__Contact__c = :parentId
        AND hed__RelatedContact__c IN :childIds
        AND hed__Status__c = 'Current'
    ]) {
      result.put(relationship.hed__RelatedContact__c, relationship.hed__Type__c);
    }
    return result;
  }

  private static Map<Id, List<hed__Application__c>> applicationsByStudentId(
    Set<Id> studentIds
  ) {
    Map<Id, List<hed__Application__c>> result = new Map<Id, List<hed__Application__c>>();
    List<hed__Application__c> applications = [
      SELECT
        Id,
        hed__Applicant__c,
        hed__Applying_To__c,
        hed__Applying_To__r.Name,
        hed__Application_Status__c,
        hed__Application_Date__c
      FROM hed__Application__c
      WHERE hed__Applicant__c IN :studentIds
    ];
    for (hed__Application__c application : applications) {
      if (!result.containsKey(application.hed__Applicant__c)) {
        result.put(
          application.hed__Applicant__c,
          new List<hed__Application__c>()
        );
      }
      result.get(application.hed__Applicant__c).add(application);
    }
    return result;
  }

  private static ChildWrapper toChildWrapper(
    Contact student,
    String relationshipType,
    List<hed__Application__c> applications
  ) {
    ChildWrapper wrapper = new ChildWrapper();
    wrapper.id = student.Id;
    wrapper.firstName = student.FirstName;
    wrapper.lastName = student.LastName;
    // Grade level and "current school" aren't modeled as confirmed fields
    // in this org yet -- left null rather than guessed (see progress doc).
    wrapper.gradeLevel = null;
    wrapper.schoolName = null;
    wrapper.dateOfBirth = student.Birthdate;
    wrapper.relationshipType = relationshipType;
    wrapper.applications = toApplicationWrappers(student.Id, applications);
    return wrapper;
  }

  private static List<ApplicationWrapper> toApplicationWrappers(
    Id childId,
    List<hed__Application__c> applications
  ) {
    List<ApplicationWrapper> wrappers = new List<ApplicationWrapper>();
    if (applications == null) {
      return wrappers;
    }
    for (hed__Application__c application : applications) {
      ApplicationWrapper wrapper = new ApplicationWrapper();
      wrapper.id = application.Id;
      wrapper.childId = childId;
      wrapper.schoolId = application.hed__Applying_To__c;
      wrapper.schoolName = application.hed__Applying_To__r?.Name;
      wrapper.status = toStatusWrapper(application.hed__Application_Status__c);
      // No lottery-number field exists on hed__Application__c yet.
      wrapper.lotteryNumber = null;
      wrapper.submittedDate = application.hed__Application_Date__c == null
        ? null
        : application.hed__Application_Date__c.date();
      wrappers.add(wrapper);
    }
    return wrappers;
  }

  private static StatusWrapper toStatusWrapper(String rawStatus) {
    StatusWrapper wrapper = new StatusWrapper();
    wrapper.label = rawStatus;
    wrapper.code = String.isBlank(rawStatus)
      ? null
      : rawStatus.toLowerCase().replace(' ', '_');
    return wrapper;
  }
}
