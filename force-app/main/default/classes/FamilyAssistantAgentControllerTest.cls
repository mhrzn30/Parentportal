@isTest
private class FamilyAssistantAgentControllerTest {
  private class SessionOpenMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      System.assertEquals('POST', req.getMethod());
      System.assert(req.getEndpoint().contains('/sessions'));

      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setBody(
        '{"sessionId":"session-123","messages":[' +
          '{"message":"Hi! How can I help your family today?","isContentSafe":true}' +
          ']}'
      );
      return res;
    }
  }

  private class SendMessageMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      System.assertEquals('POST', req.getMethod());
      System.assert(
        req.getEndpoint().contains('/sessions/session-123/messages')
      );

      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setBody(
        '{"messages":[' +
          '{"message":"Create a parent portal account to start.","isContentSafe":true},' +
          '{"message":"unsafe content that should be filtered","isContentSafe":false}' +
          ']}'
      );
      return res;
    }
  }

  private class ErrorMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      HttpResponse res = new HttpResponse();
      res.setStatusCode(500);
      res.setBody('{"error":"internal"}');
      return res;
    }
  }

  private class EndSessionMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      System.assertEquals('DELETE', req.getMethod());
      System.assertEquals('UserRequest', req.getHeader('x-session-end-reason'));

      HttpResponse res = new HttpResponse();
      res.setStatusCode(204);
      return res;
    }
  }

  private class ThrowingMock implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
      throw new CalloutException('simulated network failure');
    }
  }

  private class CapturingMock implements HttpCalloutMock {
    public String capturedBody;
    public HttpResponse respond(HttpRequest req) {
      capturedBody = req.getBody();
      HttpResponse res = new HttpResponse();
      res.setStatusCode(200);
      res.setBody(
        '{"sessionId":"session-123","messages":[' +
          '{"type":"Inform","message":"Hi, I\'m Family Assistant.","isContentSafe":true}' +
          ']}'
      );
      return res;
    }
  }

  private static Map<String, Object> sessionVariable(
    String requestBody,
    String name
  ) {
    Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(
      requestBody
    );
    List<Object> variables = (List<Object>) body.get('variables');
    if (variables == null) {
      return null;
    }
    for (Object rawVariable : variables) {
      Map<String, Object> variable = (Map<String, Object>) rawVariable;
      if (variable.get('name') == name) {
        return variable;
      }
    }
    return null;
  }

  @isTest
  static void startSessionReturnsSessionIdAndSafeReplies() {
    Test.setMock(HttpCalloutMock.class, new SessionOpenMock());

    Test.startTest();
    FamilyAssistantAgentController.AgentReply result = FamilyAssistantAgentController.startSession();
    Test.stopTest();

    System.assertEquals('session-123', result.sessionId);
    System.assertEquals(1, result.replies.size());
    System.assertEquals(
      'Hi! How can I help your family today?',
      result.replies[0]
    );
  }

  @isTest
  static void sendMessageFiltersOutUnsafeReplies() {
    Test.setMock(HttpCalloutMock.class, new SendMessageMock());

    Test.startTest();
    FamilyAssistantAgentController.AgentReply result = FamilyAssistantAgentController.sendMessage(
      'session-123',
      1,
      'How do I apply?'
    );
    Test.stopTest();

    System.assertEquals('session-123', result.sessionId);
    System.assertEquals(1, result.replies.size());
    System.assertEquals(
      'Create a parent portal account to start.',
      result.replies[0]
    );
  }

  @isTest
  static void sendMessageThrowsAuraHandledExceptionOnCalloutFailure() {
    Test.setMock(HttpCalloutMock.class, new ErrorMock());

    Test.startTest();
    try {
      FamilyAssistantAgentController.sendMessage(
        'session-123',
        1,
        'How do I apply?'
      );
      System.assert(false, 'Expected an AuraHandledException to be thrown');
    } catch (AuraHandledException e) {
      System.assert(true);
    }
    Test.stopTest();
  }

  @isTest
  static void endSessionSendsExpectedDeleteRequest() {
    Test.setMock(HttpCalloutMock.class, new EndSessionMock());

    Test.startTest();
    FamilyAssistantAgentController.endSession('session-123');
    Test.stopTest();
  }

  @isTest
  static void endSessionSwallowsCalloutFailures() {
    Test.setMock(HttpCalloutMock.class, new ThrowingMock());

    Test.startTest();
    FamilyAssistantAgentController.endSession('session-123');
    Test.stopTest();
  }

  @isTest
  static void portalParentSessionSendsOwnContactId() {
    TestDataFactory.Household householdA = TestDataFactory.createHousehold(
      'Adeyemi'
    );
    TestDataFactory.Household householdB = TestDataFactory.createHousehold(
      'Lindgren'
    );
    User portalUserA = TestDataFactory.createPortalUser(householdA.parent);
    TestDataFactory.createPortalUser(householdB.parent);
    CapturingMock mock = new CapturingMock();
    Test.setMock(HttpCalloutMock.class, mock);

    Test.startTest();
    System.runAs(portalUserA) {
      FamilyAssistantAgentController.startSession();
    }
    Test.stopTest();

    Map<String, Object> identity = sessionVariable(
      mock.capturedBody,
      'PortalParentContactId'
    );
    System.assertNotEquals(
      null,
      identity,
      'The session must carry the signed-in parent\'s identity'
    );
    System.assertEquals('Text', identity.get('type'));
    System.assertEquals(
      String.valueOf(householdA.parent.Id),
      identity.get('value'),
      'The session must carry the signed-in parent\'s own Contact Id'
    );
    System.assert(
      !mock.capturedBody.contains(householdB.parent.Id),
      'Another household\'s parent must never appear in the session'
    );
  }

  @isTest
  static void userWithoutContactSendsNoParentIdentity() {
    CapturingMock mock = new CapturingMock();
    Test.setMock(HttpCalloutMock.class, mock);

    Test.startTest();
    FamilyAssistantAgentController.startSession();
    Test.stopTest();

    System.assertEquals(
      null,
      sessionVariable(mock.capturedBody, 'PortalParentContactId'),
      'A user with no Contact must get an FAQ-only session with no parent identity'
    );
    System.assertEquals(
      null,
      sessionVariable(mock.capturedBody, 'PortalParentFirstName'),
      'A user with no Contact must not be greeted by name'
    );
  }

  @isTest
  static void portalParentSessionSendsOwnFirstName() {
    TestDataFactory.Household householdA = TestDataFactory.createHousehold(
      'Adeyemi'
    );
    TestDataFactory.Household householdB = TestDataFactory.createHousehold(
      'Lindgren'
    );
    User portalUserA = TestDataFactory.createPortalUser(householdA.parent);
    TestDataFactory.createPortalUser(householdB.parent);
    CapturingMock mock = new CapturingMock();
    Test.setMock(HttpCalloutMock.class, mock);

    Test.startTest();
    System.runAs(portalUserA) {
      FamilyAssistantAgentController.startSession();
    }
    Test.stopTest();

    Map<String, Object> firstName = sessionVariable(
      mock.capturedBody,
      'PortalParentFirstName'
    );
    System.assertNotEquals(
      null,
      firstName,
      'The session must carry the signed-in parent\'s first name'
    );
    System.assertEquals('Text', firstName.get('type'));
    System.assertEquals(portalUserA.FirstName, firstName.get('value'));
    System.assert(
      !mock.capturedBody.contains('Lindgren'),
      'Another household\'s name must never appear in the session'
    );
  }

  @isTest
  static void sendMessageNeverSendsVariables() {
    CapturingMock mock = new CapturingMock();
    Test.setMock(HttpCalloutMock.class, mock);

    Test.startTest();
    FamilyAssistantAgentController.sendMessage(
      'session-123',
      1,
      'What is my child\'s status?'
    );
    Test.stopTest();

    Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(
      mock.capturedBody
    );
    System.assert(
      !body.containsKey('variables'),
      'sendMessage must never send variables, so identity cannot change mid-session'
    );
  }
}
