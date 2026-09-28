/**
 * Apex bridge between the Family Assistant LWC and the Agentforce Agent API.
 * All callouts go through the Family_Assistant_Agent_API Named Credential so
 * no client id, secret, or token ever reaches the browser.
 */
public with sharing class FamilyAssistantAgentController {
  private static final String NAMED_CREDENTIAL = 'callout:Family_Assistant_Agent_API';
  // TODO: move to a Custom Metadata Type before this goes past the dev org (see docs/family-assistant-agent-progress.md)
  private static final String AGENT_ID = '0Xxfj000003t47hCAA';
  private static final Integer TIMEOUT_MS = 20000;
  private static final String GENERIC_ERROR = 'The Family Assistant is unavailable right now.';

  public class AgentReply {
    @AuraEnabled
    public String sessionId;
    @AuraEnabled
    public List<String> replies;
  }

  @AuraEnabled
  public static AgentReply startSession() {
    Map<String, Object> requestBody = new Map<String, Object>{
      'externalSessionKey' => String.valueOf(Uuid.randomUUID()),
      'instanceConfig' => new Map<String, Object>{
        'endpoint' => Url.getOrgDomainUrl().toExternalForm()
      },
      'streamingCapabilities' => new Map<String, Object>{
        'chunkTypes' => new List<String>{ 'Text' }
      },
      'bypassUser' => true
    };

    Map<String, Object> responseBody = sendCallout(
      'POST',
      '/einstein/ai-agent/v1/agents/' + AGENT_ID + '/sessions',
      requestBody
    );

    AgentReply result = new AgentReply();
    result.sessionId = (String) responseBody.get('sessionId');
    result.replies = extractSafeReplies(responseBody);
    return result;
  }

  @AuraEnabled
  public static AgentReply sendMessage(
    String sessionId,
    Integer sequenceId,
    String message
  ) {
    Map<String, Object> requestBody = new Map<String, Object>{
      'message' => new Map<String, Object>{
        'sequenceId' => sequenceId,
        'type' => 'Text',
        'text' => message
      }
    };

    Map<String, Object> responseBody = sendCallout(
      'POST',
      '/einstein/ai-agent/v1/sessions/' + sessionId + '/messages',
      requestBody
    );

    AgentReply result = new AgentReply();
    result.sessionId = sessionId;
    result.replies = extractSafeReplies(responseBody);
    return result;
  }

  @AuraEnabled
  public static void endSession(String sessionId) {
    HttpRequest req = new HttpRequest();
    req.setEndpoint(
      NAMED_CREDENTIAL + '/einstein/ai-agent/v1/sessions/' + sessionId
    );
    req.setMethod('DELETE');
    req.setHeader('x-session-end-reason', 'UserRequest');
    req.setTimeout(TIMEOUT_MS);

    try {
      new Http().send(req);
    } catch (Exception e) {
      // Best-effort cleanup only; the user has already closed the panel.
    }
  }

  private static Map<String, Object> sendCallout(
    String method,
    String path,
    Map<String, Object> body
  ) {
    HttpRequest req = new HttpRequest();
    req.setEndpoint(NAMED_CREDENTIAL + path);
    req.setMethod(method);
    req.setHeader('Content-Type', 'application/json');
    req.setBody(JSON.serialize(body));
    req.setTimeout(TIMEOUT_MS);

    HttpResponse response;
    try {
      response = new Http().send(req);
    } catch (Exception e) {
      throw new AuraHandledException(GENERIC_ERROR);
    }

    if (response.getStatusCode() >= 300) {
      throw new AuraHandledException(GENERIC_ERROR);
    }

    return (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
  }

  private static List<String> extractSafeReplies(
    Map<String, Object> responseBody
  ) {
    List<String> replies = new List<String>();
    List<Object> messages = (List<Object>) responseBody.get('messages');
    if (messages == null) {
      return replies;
    }

    for (Object rawMessage : messages) {
      Map<String, Object> messageMap = (Map<String, Object>) rawMessage;
      Object isContentSafe = messageMap.get('isContentSafe');
      String text = (String) messageMap.get('message');
      if (String.isNotBlank(text) && isContentSafe != false) {
        replies.add(text);
      }
    }
    return replies;
  }
}
