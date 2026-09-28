/**
 * Invocable Apex for the Get_Application_Status flow (the Family Assistant
 * agent action). Replaces the flow's previous "same household Account"
 * student lookup -- which CLAUDE.md explicitly calls out as the wrong
 * boundary (Account is grouping only) -- with the same
 * RelationshipSelector-classified relationship check every other consumer
 * uses, so a parent asking the agent about "my child's status" only ever
 * gets their own linked children's applications.
 */
public with sharing class ApplicationStatusForParent {
  public class Request {
    @InvocableVariable(required=true label='Parent Contact Id')
    public Id parentContactId;
  }

  public class Result {
    @InvocableVariable(label='Linked Students')
    public List<Contact> students;
    @InvocableVariable(label='Applications')
    public List<hed__Application__c> applications;
  }

  @InvocableMethod(
    label='Get Application Status For Parent'
    description='Returns only the students and applications the given parent Contact has active, classified-relationship access to.'
  )
  public static List<Result> getApplicationStatusForParent(
    List<Request> requests
  ) {
    Set<Id> parentIds = new Set<Id>();
    for (Request request : requests) {
      if (request.parentContactId != null) {
        parentIds.add(request.parentContactId);
      }
    }

    Map<Id, Set<Id>> childIdsByParent = RelationshipSelector.childIdsForParents(
      parentIds
    );

    Set<Id> allChildIds = new Set<Id>();
    for (Set<Id> childIds : childIdsByParent.values()) {
      allChildIds.addAll(childIds);
    }

    Map<Id, Contact> studentById = allChildIds.isEmpty()
      ? new Map<Id, Contact>()
      : new Map<Id, Contact>(
          [
            SELECT Id, FirstName, LastName
            FROM Contact
            WHERE Id IN :allChildIds
          ]
        );

    Map<Id, List<hed__Application__c>> applicationsByStudentId = new Map<Id, List<hed__Application__c>>();
    if (!allChildIds.isEmpty()) {
      for (hed__Application__c application : [
        SELECT
          Id,
          hed__Applicant__c,
          hed__Applying_To__c,
          hed__Application_Status__c
        FROM hed__Application__c
        WHERE hed__Applicant__c IN :allChildIds
      ]) {
        if (
          !applicationsByStudentId.containsKey(application.hed__Applicant__c)
        ) {
          applicationsByStudentId.put(
            application.hed__Applicant__c,
            new List<hed__Application__c>()
          );
        }
        applicationsByStudentId.get(application.hed__Applicant__c)
          .add(application);
      }
    }

    List<Result> results = new List<Result>();
    for (Request request : requests) {
      Result result = new Result();
      result.students = new List<Contact>();
      result.applications = new List<hed__Application__c>();

      Set<Id> childIds = childIdsByParent.get(request.parentContactId);
      if (childIds != null) {
        for (Id childId : childIds) {
          if (studentById.containsKey(childId)) {
            result.students.add(studentById.get(childId));
          }
          if (applicationsByStudentId.containsKey(childId)) {
            result.applications.addAll(applicationsByStudentId.get(childId));
          }
        }
      }
      results.add(result);
    }
    return results;
  }
}
