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
}
