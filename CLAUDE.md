# CLAUDE.md — Family Assistant + Parent Portal

Read this first in every session, then `docs/family-assistant-agent-progress.md` for
live status. Update the progress file as work lands; edit this file only when
architecture, conventions, or guardrails change. Do not re-derive anything below.

## Teaching mode (intern learning this codebase)

The person working in this repo is an intern, learning Salesforce/LWC/Apex as they go.
These rules are **strict** and apply to **every** change to any file (code, tests,
metadata, config, docs). Understanding comes before speed.

**1. Explain in detail BEFORE changing, then ask permission.**
Before editing any file, describe the planned change in plain language:

- **Which file(s)** and which function/section will change.
- **What** will change (show the old vs new code, or the new code if it's a new file).
- **Why** it's needed — the problem it solves or the requirement/scenario it serves.
- **How it connects** to code that already exists, and what could break.

Then **stop and ask for permission**. Do not edit until the user says yes. If the user
asks a question or says no, answer/adjust and ask again. Approval covers only the change
that was described — not the next one.

**2. One small change at a time.**
One function, one small edit, or one small file per step. Never a multi-file feature in
one shot. If a task needs several changes, list the steps first, then do them one by one,
each with its own explain → permission → change → recap cycle.

**3. Recap AFTER every function or small change.**
Right after each change, explain:

- **What changed** — the exact file and function/lines (use clickable links), in plain words.
- **Why** it was done this way (the reasoning, not just the syntax), and any alternative
  that was rejected and why.
- **Salesforce/LWC/Apex gotchas** involved (e.g. why a boolean `@api` must default to
  `false`, why `with sharing`, why a jest mock needs `{ virtual: true }`).
- **What's next** — the next small step and how it builds on this one.

**4. Pause between changes.** Let each piece land and make sense before moving on. Invite
questions. Never chain several edits silently, even if they seem obvious or mechanical.

**5. Assume nothing is obvious.** Use simple language, define Salesforce terms the first
time they appear, and avoid unexplained jargon.

## What this is

Salesforce Experience Cloud parent portal for Any Schools (agent greeting currently says
"Northbridge Schools"; confirm the final brand name) on EDA, plus an Agentforce agent "Family Assistant".

- Parents log in, add children (verified), upload documents, view/edit their own and
  their children's info, track applications.
- Agent answers FAQs (applying, lottery/waitlist, documents, account/dashboard) from
  Knowledge, and looks up the signed-in parent's own children's real application status.
- Hard rule: a parent never sees another household's data (portal UI OR agent).
- Next deliverable: standalone LWC chat widget calling the Agent API via an Apex proxy.

## How we test

Tests describe what the feature must do for parents and the school, not what the code
happens to do. They come from the scenarios below, written before or alongside the code,
never reverse-engineered from an implementation.

- **Start from behavior.** Before coding a feature, pick its scenarios from the catalog
  below (add missing ones to the catalog first). Each test name reads as a requirement:
  `parentCannotSeeOtherHouseholdApplications`, not `testResync2`.
- **Tests are the contract.** If a test fails, fix the code. Change a test only when the
  requirement itself changed, and record why in the progress file's Decisions Log.
- **Assert outcomes, not internals.** Check what a real user could see or do (records
  visible via `System.runAs(portalUser)`, response shown in the widget, error shown),
  not private method calls or query counts, unless the requirement is about limits.
- **Every family-data feature has three kinds of test:** the happy path, the
  cross-household denial, and a failure path (missing data, API error, revoked relationship).
- **Design for testability.** Callouts behind an injectable interface + `HttpCalloutMock`;
  queries in a selector class; no logic in triggers; LWC Apex calls mocked in Jest.
- **Realistic data.** Shared `TestDataFactory` builds full EDA households (Account,
  parent + student Contacts, Relationship, Affiliation, Application, portal User).
  Minimum two households in any sharing or agent test.
- **Bulk matters.** Sharing and trigger tests run with 200 records.
- **Coverage is a side effect.** Aim for 90%+, but never add a test just to cover lines.

Commands: `sf apex run test --class-names <Test> --result-format human --synchronous`,
`npm run test:unit`, deploy with `sf project deploy start --source-dir force-app`.
A task is done when its scenarios pass and the progress file is updated.

## Scenario catalog (the source of truth for tests)

**Access and sharing**

- Parent sees their linked children and those children's applications.
- Parent cannot see, query, or edit another household's parents, children, or applications.
- A second guardian of the same child also gets access; an unrelated adult in the same
  Household Account does not.
- Ending or deleting a relationship removes access; restoring it restores access.
- A new application for an already-linked child is visible to the parent immediately.
- A parent whose portal user is created after the relationship still gets access.
- Inactive portal users receive no access.
- Resync is idempotent: running twice creates no duplicate shares.
- Works in bulk (200 relationships/applications) within governor limits.

**Linking children**

- A child can only be linked through verification (invite code / admin / match on existing data).
- Wrong or reused verification cannot link a child from another household.

**Profile and documents**

- Parent can view and edit their own and their linked children's details.
- Parent cannot edit fields reserved for staff (application status, lottery number).
- Uploaded documents attach to the right child/application and are visible only to that household.

**Agent and widget**

- Session starts only when the parent opens the chat, and uses the signed-in parent's
  identity set on the server, never a value from the conversation.
- "What's my child's status?" returns only that parent's children's applications,
  including a parent with multiple children and multiple applications.
- A parent asking about another family's child gets no data.
- A parent with no linked children gets a clear "nothing found" answer, not an error.
- Anonymous (FAQ-only) sessions never reach family-data actions.
- Unsafe messages (`isContentSafe = false`) are not shown.
- API failure, timeout, or expired session shows the fallback + Family Support contact.
- Typed input like `<script>` is shown as plain text.
- Keyboard: Enter sends; bubble, close, and input have accessible labels.
- Session is ended when the widget is removed.
- A session without a signed-in parent gets a clear sign-in message, never placeholders or invented data.
- A parent can't switch to another family's identity mid-conversation.

## Org

- CloudMandap `00Dfj00000f759S`, Developer Edition, EDA installed (`hed__`).
- My Domain: `orgfarm-ba5ad2787e-dev-ed.develop.my.salesforce.com`
- Standard SFDX layout, `force-app/main/default`.
- Secrets (consumer key/secret) live only in the External Credential Principal and local
  secure notes. Never in code, docs, logs, or chat.

## Agent

- `Family_Assistant`, AgentType EinsteinServiceAgent, Id `0Xxfj000003t47hCAA` (must be Activated).
- `agent_router` → subagents: general_info, application_help, lottery_waitlist, documents,
  account_dashboard, escalation, off_topic, ambiguous_question.
- Knowledge grounding: Agentforce Data Library, rag_feature_config_id `ARFPC_1JDfj00000CDDwbGAH`.
- Action `Get_Application_Status` (Flow → `ApplicationStatusForParent` Apex): real EDA lookup.
- Source of truth: `force-app/main/default/aiAuthoringBundles/Family_Assistant/`. If anyone edits
  in Builder, retrieve and diff before deploying.
- Runs as `EinsteinServiceAgent User` (`005fj00000OO3a2`) with its own permission set.
- AgentScript `actions:` blocks are per-subagent (no global block). Prefer Canvas mode
  over hand-editing AgentScript for Data Libraries and actions.

## Knowledge

Lightning Knowledge (single `Knowledge__kav`, Record Type "Family Assistant FAQ"), 20 published
articles, Data Categories: Applying, Lottery, Documents, Account, Help. The widget never holds
its own FAQ content, dates, or lottery logic.

## Data model (EDA, Contact-centric)

- `Account`: Record Types Household / Educational Institution. Grouping only, not the access boundary.
- `Contact`: parents (have portal Users) and students (no login).
- `hed__Relationship__c`: `hed__Contact__c` (parent) → `hed__RelatedContact__c` (student),
  `hed__Status__c` Current. EDA auto-creates the reciprocal. **This is the trust boundary.**
  `hed__Type__c` describes the related contact and is gender-specific (Daughter/Son/Child on
  the parent's own row; EDA auto-creates the gender-specific reciprocal — Father/Mother/Parent —
  on the child's row). Which values grant access is decided only by
  `Relationship_Type_Setting__mdt` (via `RelationshipTypeSettings`/`RelationshipSelector`), never
  a hardcoded list; any value with no record there, including new picklist values added later,
  grants no access.
- `hed__Affiliation__c`: student ↔ school Account.
- `hed__Application__c`: EDA-native (not custom). Status values seen: "Waitlisted", "In Review".
  Query picklist values before assuming others. Confirm the applicant lookup field name in org.
- Documents: Salesforce Files linked to Student Contact / Application.

## Agent API auth (DONE, verified from Apex: 200 + sessionId)

- Named Credential `Family_Assistant_Agent_API` → `https://api.salesforce.com`, Generate Auth Header on.
  Apex uses `callout:Family_Assistant_Agent_API/...`
- External Credential (same name): OAuth 2.0, Client Credentials with Client Secret, token URL =
  My Domain `/services/oauth2/token`, credentials in body, **Scope blank**.
- Principal holds client id/secret; Permission Set `Family_Assistant_Agent_API` grants access.
- Endpoints:
  - `POST /einstein/ai-agent/v1/agents/{agentId}/sessions`
  - `POST /einstein/ai-agent/v1/sessions/{sessionId}/messages` (sync; body
    `{"message":{"sequenceId":n,"type":"Text","text":"..."}}`, sequenceId increments)
  - `.../messages/stream` (SSE, deferred; not possible with plain Apex Http)
  - `DELETE /einstein/ai-agent/v1/sessions/{sessionId}`
- Session body: `externalSessionKey` (uuid), `instanceConfig.endpoint` = My Domain,
  `tz`, `variables` (incl. `$Context.EndUserLanguage`), `featureSupport`, `bypassUser`.

## Identity + sharing design (decided)

- Parent identity resolved server-side in Apex running as the portal user:
  `CurrentParentSelector.contactId()` (`UserInfo.getUserId()` → `User.ContactId`), sent by
  `startSession()` as the External agent variable `PortalParentContactId` (default `""`).
  The LLM never supplies or chooses a record Id.
- Agent side: actions run as `EinsteinServiceAgent User`, and the API session runs as the
  integration user, so **portal sharing does not protect agent queries**. Every agent
  action must filter by `PortalParentContactId` → `RelationshipSelector` → those students'
  applications only. The agent user serves every household, so it holds read-only View All
  via `Family_Assistant_Agent_Data_Access` (assigned to that user only); isolation is the
  action filter, not sharing.
- Portal side: relationship-driven Apex managed sharing. OWD Private on Contact (not
  "Controlled by Parent") and `hed__Application__c`. `GuardianAccessSharingService`
  (with sharing) `resyncForParents(Set<Id>)` recomputes desired shares and diffs
  (idempotent), called from triggers on `hed__Relationship__c`, `hed__Application__c`,
  and `User` (portal user activated after relationship exists).
- Parent↔child linking must be verified (invite code / admin / match on existing data),
  never self-declared.

## Agent actions (rules for every new action)

- Identity only from `PortalParentContactId`; gate the action with
  `available when @variables.PortalParentContactId != ""`.
- Never bind identity or record Ids with `with x = ...`; any Id the model proposes must be in the
  parent's `RelationshipSelector` set, or the action refuses.
- Writes set only an explicit allow-list of fields; staff-reserved fields (status, lottery number)
  are never writable by the agent.
- The agent drafts; consequential steps (e.g. submitting an application) are confirmed by the
  parent in the portal, running as the portal user. Low-risk records (e.g. a Case) may be created
  directly, linked from the server identity.
- No deletes; cancel/withdraw is a status change.

## Planned components (reference designs; regenerate in repo, tests first)

- `FamilyAssistantAgentController` (Apex, with sharing): `startSession()`,
  `sendMessage(sessionId, sequenceId, message)`, `endSession(sessionId)`. Parses
  `messages[]`, drops `isContentSafe == false`, sync mode. Adds parent context variable.
- `familyAssistantChat` (LWC): bubble 60px + panel 380×560, brand `#f7941e`, `.notranslate`,
  session starts on first open (not on load), ends in `disconnectedCallback`. Targets App/
  Record/Home and `lightningCommunity__Page`/`__Default`.
- `GuardianAccessSharingService` + 3 triggers (see sharing design).

## Guardrails (always)

- No secrets/tokens in Apex, LWC, docs, or logs.
- Apex touching family data is `with sharing`. No `without sharing` shortcuts.
- Flow run mode chosen deliberately (autolaunched flows default to system context).
- No PII in committed `console.log`/`System.debug`; no transcripts in browser storage;
  no third-party analytics on chat. Treat student data as FERPA-sensitive (plus org GDPR/HIPAA policy).
- LWC renders agent text via template binding only (no `lwc:dom="manual"`/innerHTML).
- Errors show fallback + Family Support contact; never blank panel or endless spinner.
- No production data deletes outside the sharing-row diff logic.
- Follow existing repo ESLint/Prettier and naming conventions.
- Least privilege for `EinsteinServiceAgent User` and the integration user. Deliberate exception:
  read-only View All on family objects for the agent user (see Identity design). Never add View All
  to a permission set that portal parents hold.

## Known gotchas

- Blockers in this org have almost always been permissions/visibility (Record Type
  Settings, FLS, the agent user's permission set), not logic. Check those first.
- "URL No Longer Exists" HTML = wrong host; Agent API uses `api.salesforce.com`.
- 404 "Bot ... has no active version" = agent not Activated. (This was the Start Session 404; resolved.)
- `scope parameter not supported` = clear External Credential Scope.
- Client Credentials uses a free-text token URL, not an Auth Provider
  (`Family_Assistant_Agent_Auth` Auth Provider is unused; safe to delete).
- Agent Connections page only lists channels (Enhanced Chat v2, Messaging); no API connection needed.
- `invalid ID field: current` in `Get_Application_Status` = action input was model-filled.
  Bind `parentContactId` to the server-set context variable.
- Apex managed sharing to portal users needs Customer Community Plus (or Partner) licenses;
  plain Customer Community gets Sharing Sets only. Confirm license first.
- Confirmed: Apex Sharing Reasons can't be added to `hed__Application__c` (managed package);
  used `RowCause = 'Manual'` on `hed__Application__Share` instead (plain string works — no
  `Schema.X.RowCause` enum exists for custom objects, unlike standard ones). `ContactShare`
  does use the enum form: `RowCause = Schema.ContactShare.RowCause.Manual`.
- `hed__Type__c` describes the related contact; values can be gender-specific
  (Daughter/Father); access is decided only by `Relationship_Type_Setting__mdt`; unclassified
  values grant nothing.
- `ContactShare.UserOrGroupId` / `hed__Application__Share.UserOrGroupId` must be a **User**
  (or Group) Id, never the parent's own Contact Id — sharing to the Contact Id fails with
  `FIELD_INTEGRITY_EXCEPTION: id value of incorrect type`. `GuardianAccessSharingService`
  resolves each parent Contact's *active* portal User first and shares to that User's Id.
- A Custom Metadata Type's object-meta.xml can't have `<deploymentStatus>` (deploy fails:
  "Cannot specify: deploymentStatus for Custom Metadata Type"). A CMDT record's `.md-meta.xml`
  needs `<label>` as a **child element** of `<CustomMetadata>`, not an XML attribute on it —
  the attribute form deploys without error but leaves `MasterLabel` unpopulated, which then
  fails as "Required fields are missing: [MasterLabel]".
- Deploying an OWD change (`sharingModel`/`externalSharingModel`) in the *same* deploy as Apex
  that references that object's `Share` table (e.g. `ContactShare`) can fail with "Field is not
  writeable" — the object metadata may not apply before Apex compilation validates in the same
  transaction. Deploy the OWD change alone first, then the dependent Apex, in two passes.
- Deploying the whole `force-app` tree with `--test-level RunSpecifiedTests` and a narrow
  `--tests` list can fail on code-coverage warnings for *unrelated* pre-existing classes whose
  own tests weren't included (they show 0% coverage in that run). Use `RunLocalTests` (or scope
  the deploy to just the changed files) for a deploy that includes the whole source tree.
- Contact OWD is now `Private` (internal + external), changed from `ControlledByParent`, to let
  `GuardianAccessSharingService` create direct `ContactShare` rows — `hed__Application__c`'s
  *external* sharing model was already `Private` (distinct from its internal `ReadWrite`), so it
  didn't need changing; `hed__Application__Share` rows already work under it.
- `sObject type 'X' is not supported` from Apex/Flow usually means the running user has no access to
  that object or Custom Metadata Type (check the permission set before the spelling).
- Agent API `InternalVariableMutationAttemptException` = the variable isn't API-writable; needs
  AgentScript `visibility: "External"` (Builder "Enable API write access"). Toggling it in Builder
  dropped our `= ""` default — check after any retrieve.
- AgentScript `with x = ...` = the model fills `x` from the conversation (the cause of the old
  `invalid ID field: current` error).
- `sf agent publish` rejects an action output missing from the action's saved schema; `sf agent
  validate` doesn't check this, and the schema doesn't refresh when the flow gains outputs.
- A subagent's `description` also drives routing; removing a topic from it re-routes those questions.

Test data and the open-items checklist now live in `docs/family-assistant-agent-progress.md`
(they're live status, not architecture/conventions/guardrails).
