# Family Assistant Agent — Progress

## Status
Working end-to-end in the dev org: the real LWC now drives the real agent through Apex — `startSession` → `sendMessage` → `endSession` — verified both by a deployed Jest/Apex test suite and a live anonymous-Apex round trip that returned a grounded, agent-generated answer. Not yet placed on a Lightning App Page or into Experience Cloud, and the Named Credential/External Credential still exist only as org config, not as retrieved source metadata.

The parent portal dashboard (`c/familyDashboard`) is now wired to real EDA data via `PortalDataController` (was mock fixtures) — Apex + Jest tests passing, deployed. Confirmed portal license is Customer Community Plus (CLAUDE.md open item 1). Also not yet on a Lightning App Page.

**Update:** `GuardianAccessSharingService` + relationship-type classification (open item 4) are now built and deployed — a real Experience Cloud/Customer Community Plus portal user now gets genuine record-level visibility into their own linked children's Contact and `hed__Application__c` records via Apex-managed sharing, verified with `System.runAs(portalUser)` in `GuardianAccessSharingServiceTest` and the trigger handler tests. See "Relationship-Type Access & Guardian Sharing" below for the full breakdown.

**Update (2026-09-30):** The agent now uses the signed-in portal parent's identity (server-set `PortalParentContactId`, no hardcoded Id) and shows only their own children's status — agent **v4** live; it also answers "What's my name?" from the server-set `PortalParentFirstName`; see "Agent Identity & Data Access".

## Done
- [x] Connected App configured for Client Credentials Flow (run-as user set, scopes `api chatbot_api sfap_api`)
- [x] External Credential `Family_Assistant_Agent_API` configured: OAuth 2.0, Client Credentials with Client Secret Flow, token endpoint `https://orgfarm-ba5ad2787e-dev-ed.develop.my.salesforce.com/services/oauth2/token`, Pass Client Credentials in Request Body checked, Scope field left blank
- [x] Principal created under the External Credential holding the Connected App's Client ID/Secret directly (no separate Authentication Parameters rows)
- [x] Permission Set `Family_Assistant_Agent_API` created (grants External Credential Principal Access) and assigned to the test user
- [x] Named Credential `Family_Assistant_Agent_API` created — URL `https://api.salesforce.com`, linked to the External Credential, Generate Authorization Header checked; callable from Apex as `callout:Family_Assistant_Agent_API/...`
- [x] Auth Provider `Family_Assistant_Agent_Auth` created, then confirmed unnecessary for Client Credentials flow (candidate for deletion — not wired to anything)
- [x] `FamilyAssistantAgentController.cls` written: `startSession()`, `sendMessage(sessionId, sequenceId, message)`, `endSession(sessionId)`; builds the Agent API JSON bodies server-side, calls the Named Credential, parses `messages[]`, filters replies on `isContentSafe`, throws `AuraHandledException` with a generic message on callout failure (no internal error detail leaks to the client)
- [x] `FamilyAssistantAgentControllerTest.cls` written with `HttpCalloutMock` coverage for session open, send-message (incl. unsafe-content filtering), a 500 error path, and end-session (incl. a callout-throws path) — 5/5 tests passing when deployed to the dev org
- [x] `familyAssistantChat` LWC rewired from the static keyword-matcher mock to the real Apex controller — session started on first panel open (not `connectedCallback`), `sequenceId` incremented per turn, session ended in `disconnectedCallback`, fallback message + Family Support contacts shown on any Apex error
- [x] LWC Jest suite rewritten for the real controller (6/6 passing): welcome message comes from the agent's own greeting, starter questions call `sendMessage` with the right `sequenceId`, agent replies are proven to go through `lightning-formatted-text`'s `value` binding (not raw HTML) with no `<script>` ever created, fallback path on callout failure, Escape-close behavior, and `endSession` firing on component removal
- [x] `npm run lint` and `npx prettier --check` clean on all new/changed files
- [x] Deployed `FamilyAssistantAgentController(.cls/Test)` and the `familyAssistantChat` LWC bundle to the `parentPortal` dev org via `sf project deploy start --test-level RunSpecifiedTests` — succeeded, 5/5 Apex tests passed in-org
- [x] Live round trip verified via anonymous Apex against the real Agent API: `startSession` returned a real greeting, `sendMessage('How do I apply?')` returned a real Knowledge-grounded, multi-step answer, `endSession` completed without error

## In Progress
Nothing actively in flight — the LWC + Apex integration is functionally complete and verified in the dev org. Next work is deployment surface (App Page / Experience Cloud) and production hardening items below.

## Parent Portal Dashboard
Separate from the agent work above: a parent-facing dashboard UI, now wired to real EDA data.

- [x] `c/portalDataService` (`getChildren()`, `getChild(id)`) is the single swap point. Was reading local fixtures (`c/portalMockData`, now deleted — no longer used) with a simulated delay; now calls `PortalDataController` via `@salesforce/apex` imports, same function signatures, same shape. No other component changed.
- [x] UI: `c/familyDashboard` (isExposed, targets `lightningCommunity__Default`/`Page`, `lightning__AppPage`, `lightning__HomePage`) composing `c/childrenGrid` (loading/empty/error/populated states) → `c/childCard` → `c/statusBadge`, and `c/childDetail` (profile + read-only applications table) with an in-place view swap (no NavigationMixin, no site/flexipage dependency) and a placeholder `c/addChildDialog`.
- [x] `PortalDataController.cls` (`with sharing`): `getChildren()`/`getChild(childId)`, `@AuraEnabled(cacheable=true)`. Resolves the signed-in parent server-side via `UserInfo.getUserId() -> User.ContactId` (never a client-supplied id), then joins through `hed__Relationship__c` (`hed__Status__c = 'Current'`, not filtered by `hed__Type__c`) to find students, then `hed__Application__c` by `hed__Applicant__c`. Split into public `@AuraEnabled` methods plus `@TestVisible` private seams (`getChildrenForParent`/`getChildForParent`) that take the parent Contact id explicitly, so the relationship-filtering logic is unit-testable independent of `UserInfo`/`ContactId` (see Known Gotchas — `ContactId` can't be set on an internal test user at all).
- [x] `gradeLevel`, child-level `schoolName`, and `lotteryNumber` return `null` — no confirmed backing field exists in this org yet (`Level__c` on Contact is an EDA education-level enum, not K-12 grade; no lottery-number field exists on `hed__Application__c`). Left null rather than guessed, per the "don't invent facts" guardrail.
- [x] `TestDataFactory.cls` (new, shared `@isTest` factory): `createHousehold(lastName)`, `createSchool(name)`, `createApplication(...)`, `createPortalUser(parentContact)` (Customer Community Plus, not yet usable end-to-end — see Known Gotchas), `ensureRunningUserHasRole()` (portal account owners need a Role assigned).
- [x] `PortalDataControllerTest.cls`: happy path + cross-household denial (the catalog's minimum two-household scenarios for this pass; bulk/inactive-user/ended-relationship scenarios deferred). Calls the `@TestVisible` seams directly with an explicit parent Contact id rather than through a real portal user — passes both via deploy-triggered test run and standalone `sf apex run test`.
- [x] `Family_Portal_Data_Access` permission set (new, source-retrieved, least-privilege read-only): Contact/Account/`hed__Relationship__c`/`hed__Application__c` object read + the specific custom fields queried. Required-field FLS entries (e.g. `hed__Contact__c`) omitted — Salesforce rejects explicit FLS on fields that are always implicitly readable.
- [x] 33 Jest tests passing (8 suites, `portalDataService.test.js` rewritten to mock `@salesforce/apex/PortalDataController.*`); `npm run lint` and `npx prettier --check` clean on all new/changed files.
- [x] 2026-09-28: `c/familyAssistantChat` embedded in `c/familyDashboard`, outside the grid/detail `lwc:if` swap so the chat (and its Agent API session) survives switching views. New `hideChat` `@api`/App Builder toggle (default `false`) to avoid a duplicate bubble if the chat is also placed on the page separately. 3 new Jest tests (present, same instance across view swap, hideable); dashboard + chat suites 14/14 passing. Deployed 2026-09-29 (Deploy ID `0Affj00000T5P9zCAF`, succeeded).
- [x] 2026-09-29: On the site the chat returned "The Family Assistant is unavailable right now." Cause: the Apex callout runs as the portal user, and only one internal user held the `Family_Assistant_Agent_API` permission set (External Credential principal access). Fix: added `externalCredentialPrincipalAccesses` → `Family_Assistant_Agent_API-Agent_API_Creds` to `Family_Portal_Parent` (Customer Community Plus Login license accepts it; deployed). VS Code's XML schema falsely flags that element — ignore it.
- [ ] Not yet placed on a Lightning App Page/FlexiPage for browser click-through (no `flexipages`/`applications` exist yet — this is the actual next surface, not Experience Cloud).
- [x] **Real Experience Cloud portal-user access now works** — `GuardianAccessSharingService` (Apex managed sharing) built; see the section below. Open item 4 done.
- [ ] Support contact / agent id are still hardcoded in `familyAssistantChat.js` — belongs in Custom Metadata Type, not fixed in this pass.

## Relationship-Type Access & Guardian Sharing
Which `hed__Relationship__c` types grant a parent access to a child, and the real Apex-managed sharing that acts on that classification.

- [x] `Relationship_Type_Setting__mdt` (Text `Type_Value__c`, Picklist `Category__c` [Child/Guardian], Checkbox `Grants_Access__c`): 18 records covering every value in the access-policy table (Daughter/Son/Child, Stepdaughter/Stepson/Stepchild, Foster Daughter/Son/Child, Dependent as Child-category; Father/Mother/Parent, Stepfather/Stepmother/Stepparent, Foster Parent, Guardian as Guardian-category, for documentation/audit — only Child-category rows are ever read for access decisions). The build spec said "16 values"; the table it gave actually lists 18 distinct values, so all 18 were created.
- [x] `RelationshipTypeSettings` (`inherited sharing`): reads the CMDT once per transaction and caches it; `accessGrantingChildTypes()` returns the Child-category, `Grants_Access__c = true` values as a `Set<String>`; `setMockSettings()` test seam.
- [x] `RelationshipSelector` (`inherited sharing`, `WITH USER_MODE`): `childIdsForParents(Set<Id>)` → `Map<Id, Set<Id>>`, `parentIdsForChildren(Set<Id>)` → `Set<Id>`. Both query only the child-side type list, so every consumer agrees on one rule.
- [x] `PortalDataController` rewired off its old unfiltered (no `hed__Type__c` filter at all, in the actual prior code — not the hardcoded `'Parent','Guardian'` list the build spec assumed existed) relationship query onto `RelationshipSelector`.
- [x] `GuardianAccessSharingService` (`with sharing`, built new — did not exist before this pass): `resyncForParents(Set<Id>)` recomputes desired `ContactShare`/`hed__Application__Share` rows from `RelationshipSelector` and diffs against what's actually shared (idempotent); `revokeForParents(Set<Id>)` removes all shares (used for deactivated portal users). The literal Share-row DML is isolated in a private `without sharing` inner class (`ShareRowWriter`) that only takes Ids and never queries Contact/Application field data — Apex doesn't allow `static` methods on inner classes, so its methods are instance methods called on a `new ShareRowWriter()`.
- [x] Three triggers + bulk-safe handlers, all logic in the handler not the trigger: `RelationshipAccessTrigger`/`Handler` (after insert/update/delete/undelete — ending, restoring, or reclassifying a relationship resyncs), `ApplicationAccessTrigger`/`Handler` (after insert/update — a new application for an already-linked child is shared immediately), `UserPortalAccessTrigger`/`Handler` (after insert/update on `IsActive` — a portal user created after the relationship still gets access; an inactive one gets none).
- [x] `ApplicationStatusForParent` (`@InvocableMethod`, `with sharing`): replaces `Get_Application_Status`'s previous same-household-Account student lookup (it never actually filtered by relationship type — it matched on `AccountId`, which CLAUDE.md's own data model explicitly calls out as *not* the access boundary) with the same `RelationshipSelector` classification. The flow's `Get_Parent_Household`/`Get_Household_Students`/`Get_All_Applications` record-lookups were replaced with one call to this action; the rest of the summary-building flow (loops, `Get_Student`/`Get_School`, the formula) is unchanged.
- [x] Contact OWD (internal + external `sharingModel`/`externalSharingModel`) changed from `ControlledByParent` to `Private`, deployed as its own pass before the dependent Apex (see Known Gotchas) — required for `ContactShare` rows to be insertable/effective at all. `hed__Application__c`'s *external* sharing model was already `Private` (distinct from its internal `ReadWrite`), so it was left alone.
- [x] 12 new/changed Apex test classes, including `System.runAs(portalUser)` assertions per CLAUDE.md's testing philosophy: happy path, second guardian vs. unrelated household member, cross-household denial, Former status, unclassified picklist value, turning `Grants_Access__c` off, inactive/reactivated portal user, new application visible immediately, bulk 200. Verified via both a deploy-triggered `RunLocalTests` run (187/187 components, 65/65 tests) and a standalone `sf apex run test` (100% pass rate) per CLAUDE.md's "always verify standalone, not only via deploy" gotcha.
- [ ] Not done in this pass: no admin-facing UI for editing `Relationship_Type_Setting__mdt` (edit via Setup's Custom Metadata Types page); no re-check of whether `Family_Portal_Data_Access` needs new field grants for anything beyond what it already had (it didn't — verified).

## Agent Identity & Data Access (2026-09-29 – 09-30)
The agent now serves the signed-in portal parent's own children, with no hardcoded Contact Id.

- [x] `Family_Assistant_Agent_Data_Access` permission set (new, source-tracked), assigned only to
  `EinsteinServiceAgent User`: read + **View All** on Contact, `hed__Relationship__c`,
  `hed__Application__c`; read on Account; the 6 queried fields; `Relationship_Type_Setting__mdt`
  access. No create/edit/delete. Fixed, in order: `sObject type ... is not supported` (CMDT, then
  object access = missing permission), then 0 rows (Contact OWD Private + `with sharing`).
- [x] Agent retrieved into source: `aiAuthoringBundles/Family_Assistant/` (was org-only).
- [x] Removed a model-filled duplicate binding (`with parentContactId = ...`) in account_dashboard —
  let the LLM choose whose data to look up.
- [x] `DevContactId` (hardcoded) → `PortalParentContactId: mutable string = ""` with
  `visibility: "External"` (Builder: "Enable API write access"). Both bindings use it plus
  `available when @variables.PortalParentContactId != ""`, so anonymous sessions can't reach the action.
- [x] `CurrentParentSelector.contactId()` (new, `with sharing`): the single
  `UserInfo.getUserId() → User.ContactId` resolver; `PortalDataController` now uses it (private copy removed).
- [x] `FamilyAssistantAgentController.startSession()` sends
  `{ name: PortalParentContactId, type: Text, value: <ContactId> }` only when there is a parent;
  `sendMessage()` never sends `variables`.
- [x] Conditional instructions (`if` / `else` on `PortalParentContactId`) in lottery_waitlist and
  account_dashboard: no parent → sign-in message, never `[placeholder]` templates.
- [x] account_dashboard: removed a real person's name from an example and a reference to a
  non-existent `parentFullName` output.
- [x] Flow `Get_Application_Status` v9: `Assignment_6` no longer appends `childrenNames` to itself
  (2 children produced "A, A, B,").
- [x] Tests: `CurrentParentSelectorTest` (2), `FamilyAssistantAgentControllerTest` +3
  (`portalParentSessionSendsOwnContactId`, `userWithoutContactSendsNoParentIdentity`,
  `sendMessageNeverSendsVariables`) — 8/8; `PortalDataControllerTest` still 3/3.
- [x] Released: agent **v3 Active** (rollback: `sf agent activate --api-name Family_Assistant --version 2`).
  Verified on the site (own child's status, one reply) and in Postman without the variable
  (sign-in message, no placeholders). (Superseded by v4, see below.)
- [ ] `childrenNames` not reaching the model: the action's saved schema only lists
  `applicationSummary`; publish rejects declaring `childrenNames` until the schema is refreshed.
  Children with no application are therefore not listed.
- [x] "What's my name?" (2026-09-30): `startSession()` also sends `PortalParentFirstName`
  (`UserInfo.getFirstName()`, External, default `""`), only when there is a parent. Unused `FullName`
  variable removed. account_dashboard description mentions the parent's name (fixes routing to
  ambiguous_question); the name rule is in the `if`, and the no-parent `else` never gives a name.
  Test `portalParentSessionSendsOwnFirstName` + a no-name assertion — controller 9/9.
  Released: agent **v4 Active** (rollback: `--version 3`); verified on the site and in Postman.
- [ ] `GuardianAccessResyncConfig` hardcodes the sharing user's username — set it per org before
  deploying elsewhere.
- [ ] Flow still queries inside a loop (`Get_Student`/`Get_School` in `Loop_Build_Summary`).
- [ ] Remove the manual Setup grants added to an Agentforce auto-generated permission set during
  debugging (superseded by `Family_Assistant_Agent_Data_Access`).
- [ ] Assignment of `Family_Assistant_Agent_Data_Access` is org data — repeat per org:
  `sf org assign permset --name Family_Assistant_Agent_Data_Access --on-behalf-of <agent username>`.
- [ ] Local AgentScript compiler not usable on this machine (`spawnSync npm ENOENT`); using
  `sf agent validate authoring-bundle` instead.

## Not Yet Done
- [ ] Add the component to a Lightning App Page and click through it in the browser (repo currently has no `flexipages`/`applications` to drop it on — needs one created) before touching Experience Cloud
- [ ] Experience Cloud rollout: enable the permission set for guest user access (Digital Experiences setting); confirm `.js-meta.xml` targets `lightningCommunity__Default` (it does)
- [ ] Confirm the agent's Knowledge articles cover the full FAQ list from the build spec (`apply`, `lottery`, `waitlist`, etc.) — the LWC no longer owns any FAQ content itself
- [ ] Move `AGENT_ID` off a hardcoded Apex constant onto a Custom Metadata Type before production
- [ ] Rotate the Connected App's Consumer Secret (it was pasted in chat during setup) before this goes anywhere beyond the current dev org
- [ ] Retrieve the Named Credential / External Credential / Permission Set as source metadata (currently only exist as org config, not in `force-app`) so the whole feature is deployable from source

## Known Gotchas
- If Client Credentials flow setup looks incomplete without an Auth Provider record, that's expected — this flow type doesn't use one at all. Don't spend time wiring one up.
- If the External Credential's Identity Provider field shows as a free-text box instead of a dropdown, that's correct for this flow type — the dropdown only appears for Browser/Web Server flows.
- If the token endpoint callout 400s with `invalid_request: scope parameter not supported`, it means an explicit `scope` was set on the External Credential. Fix: leave the External Credential's Scope field blank — scopes come from the Connected App, not this field.
- If a Jest assertion on `shadowRoot.textContent` can't find text you know you rendered through `<lightning-formatted-text value={...}>`, it means sfdx-lwc-jest's built-in stub for that base component renders an empty `<template></template>` — it never echoes `value` into the DOM. Fix: query `lightning-formatted-text` elements directly and read the `.value` property instead of relying on rendered text (see `getMessageTexts()` in `familyAssistantChat.test.js`).
- If an LWC Jest assertion immediately after a `.click()` or `dispatchEvent()` sees stale DOM (e.g. a panel that should have closed is still there), it means the component's re-render hasn't flushed yet — LWC schedules re-renders as a microtask even for synchronous property writes inside an event handler. Fix: `await` a promise-microtask flush (e.g. `Promise.resolve().then(() => Promise.resolve())`) before asserting on the DOM.
- **Org OWD (2026-09-25, via `sf project retrieve start -m "CustomObject:X"` and checking `<sharingModel>`)**: Contact = `ControlledByParent`, `hed__Relationship__c` = `ReadWrite`, `hed__Application__c` = `ReadWrite` (internal), `Private` (external — was already set this way, distinct from internal). **Update (2026-09-28):** Contact's internal + external `sharingModel`/`externalSharingModel` are now `Private`, deployed as part of the relationship-type-access pass, to let `GuardianAccessSharingService` create real `ContactShare` rows. `hed__Relationship__c` and `hed__Application__c`'s internal OWD are unchanged (still `ReadWrite`) — see CLAUDE.md Known Gotchas for why `hed__Application__c` didn't need an internal-OWD change.
- **A real Experience Cloud/portal-license user cannot see ANY record they don't own, regardless of OWD, `with`/`without sharing`, or object/field permissions.** Confirmed empirically: a Customer Community Plus test user with full object/field read granted (`Schema...isAccessible()` true) and OWD `ReadWrite` still got zero rows from a completely unfiltered `hed__Relationship__c` query, both `with sharing` and `without sharing`. Portal/external users only see records they own or that are explicitly shared with them (Sharing Rule, Sharing Set, or real Apex-managed sharing rows) — this is enforced independently of the sharing keyword and of OWD. Until a Sharing Set or `GuardianAccessSharingService` exists, no Apex trick fixes this; don't spend time trying `without sharing` again.
- **`User.ContactId` can only be set for portal/community-license users** — inserting it on an internal user (e.g. `Standard User` profile) throws `FIELD_INTEGRITY_EXCEPTION: only portal users can be associated to a contact`. This means `PortalDataController`'s `UserInfo.getUserId() -> ContactId` identity resolution is inherently portal-only and can't be exercised with an internal test user. Fix used: split the relationship-filtering logic into `@TestVisible` methods taking the parent Contact id as an explicit parameter, and test those directly.
- Creating a portal User in a test requires its Account's owner to have a `UserRole` (`portal account owner must have a role`) — `TestDataFactory.ensureRunningUserHasRole()` assigns one idempotently.
- Any DML that mixes a Setup object (`User`, `UserRole`, `PermissionSetAssignment`, etc.) with a non-setup object (`Account`, `Contact`, ...) in the same transaction throws `MIXED_DML_OPERATION`, **in either order**. Deploy-triggered test runs (`sf project deploy start --test-level RunSpecifiedTests`) silently do NOT enforce this, but standalone test execution (`sf apex run test`) does — a test can pass via deploy and still be broken. Fix: wrap the Setup-object DML in `System.runAs(new User(Id = UserInfo.getUserId()))` (works even impersonating the same user) to isolate it from the surrounding transaction. **Always verify Apex tests with a standalone `sf apex run test` at least once, not only via `sf project deploy start`** — a failed deploy-triggered test run also rolls back every component in that deploy, including ones that had nothing to do with the failure.
- A Permission Set can't declare `<fieldPermissions>` for a field Salesforce marks required/non-`permissionable` (e.g. `hed__Relationship__c.hed__Contact__c`) — deploy fails with `You cannot deploy to a required field`. Such fields are always implicitly readable; omit them from the permission set entirely.

## Guardrails
- No secrets in the component. No client id, secret, or bearer token in `.js`, `.html`, or any LWC file — all auth stays behind the Named Credential; the component only calls `@AuraEnabled` Apex methods.
- Escape user input. Never bind parent-typed text with `lwc:dom="manual"` raw HTML or string concatenation into a template that renders unescaped HTML. `<template for:each>` binding is safe by default — keep it that way. Satisfies the build spec's XSS acceptance test (`<script>alert(1)</script>` must render as text).
- Don't invent facts client-side. The LWC only displays what the agent returns — no fallback knowledge base, hardcoded dates, or lottery/deadline logic in the component. That content lives in Salesforce Knowledge grounding the agent, per the build spec's "do not invent deadlines" rule.
- No PII in transit or logs. Don't `console.log` message bodies, don't wire chat text into any third-party analytics component, and don't persist transcripts to browser storage (localStorage/sessionStorage).
- Preserve the mount/session guard if a single-instance `mount` pattern is reused from the original spec — don't let a re-render create a second `sessionId` for the same open panel.
- Fail closed, not silent. On an Apex error, show the fallback message + Family Support contacts (per build spec) — never leave the user looking at a spinner or a blank panel.
- No blocking network calls in `connectedCallback`. Defer `startSession()` until the user opens the panel (first click), not on component load.
- Follow existing repo conventions — match the codebase's existing ESLint/Prettier config, naming conventions, and folder structure; don't introduce a second style within the same LWC namespace.
- Accessibility per spec: bubble and close button need `aria-label`, input needs an associated label, Enter key sends — don't drop these while refactoring.

## Test Data
Household 1 (Maharjan): parent Contact `003fj00001jtXAbAAM`, student `003fj00001jtXAcAAM`,
2 applications (different schools/statuses). A second household with one child exists (used for
the Postman External-variable test). No two-child household yet — needed to verify `childrenNames`.

## Open Items (in order)
1. ~~Confirm portal license type (gates sharing approach).~~ Done — Customer Community Plus.
2. ~~Replace hardcoded `DevContactId` with the real session context variable.~~ Done —
   `PortalParentContactId` (External), set by `startSession()`; see "Agent Identity & Data Access".
3. ~~Create a second household; test-first cross-household isolation (portal + agent).~~ Done —
   `RelationshipSelectorTest`/`GuardianAccessSharingServiceTest` cover this via
   `System.runAs(portalUser)` with two households.
4. ~~Build `GuardianAccessSharingService` + triggers, tests first.~~ Done — see above.
5. Build `FamilyAssistantAgentController` + `familyAssistantChat` with tests; App Page, then portal.
   (Controller/LWC done per above; still needs an App Page and Experience Cloud rollout.)
6. Verified add-child flow, parent profile view/edit, document upload.
7. Least-privilege review of `EinsteinServiceAgent User` permission set.
8. Republish the Experience site once one exists (LWR serves a published snapshot) — not yet
   applicable; no site/digital experience has been created yet in this repo.

## Decisions Log
- `sendMessage`/`startSession` throw a generic `AuraHandledException('The Family Assistant is unavailable right now.')` on any callout failure or non-2xx status, rather than surfacing the underlying HTTP status or response body to the client. Keeps internal error detail (and any agent-side error text) out of the browser and console, per the no-PII-in-logs guardrail.
- `sessionId`/`sequenceId` are tracked as plain (non-`@track`) component fields in the LWC, not persisted to browser storage, so a page refresh always starts a fresh agent session rather than resuming a stale one silently.
- Used `featureSupport: 'Sync'` (synchronous `/messages` endpoint) instead of streaming for the MVP. Streaming would require Platform Events/Continuation instead of a plain Apex `Http` call — deferred as out of scope for now.
- Chose Client Credentials Flow for the Connected App so no secrets ever live in the client; all auth stays behind the Named Credential and Apex is the only caller.
- Left the External Credential's Scope field blank rather than setting it explicitly, since Salesforce's token endpoint rejects a `scope` param on this flow type — scopes are inherited from the Connected App instead.
- Held the Connected App's Client ID/Secret directly on a single External Credential principal rather than adding an Auth Provider — Auth Provider isn't used by Client Credentials flow.
- `PortalDataController` runs `with sharing` (not an exception to the guardrail) even though it currently contributes nothing given OWD is `ReadWrite` — kept on because it's free/correct for internal users and costs nothing; the class's own relationship-filtered SOQL is the real boundary either way. Considered `without sharing` first, reverted after confirming it doesn't even fix real portal-user access (see Known Gotchas) and would just be an unjustified guardrail exception.
- `PortalDataControllerTest` calls `@TestVisible` seams (`getChildrenForParent`/`getChildForParent`) with an explicit parent Contact id instead of driving the public methods through a real portal user via `System.runAs`. Chosen after confirming portal-user record visibility requires sharing infrastructure that doesn't exist yet (a Sharing Set or `GuardianAccessSharingService`) — building that was explicitly out of scope for this pass. Revisit once that infrastructure lands, per CLAUDE.md's stated preference for testing via `System.runAs(portalUser)`. **Update: that infrastructure now exists** (`GuardianAccessSharingService`) — `RelationshipSelectorTest`/`GuardianAccessSharingServiceTest`/the trigger handler tests now do use real `System.runAs(portalUser)` assertions; `PortalDataControllerTest` itself wasn't converted since its `@TestVisible`-seam approach still directly proves the same relationship-filtering logic `PortalDataController` shares with everything else.
- `RelationshipSelector`/`GuardianAccessSharingService` filter *only* on the Child-category type list, querying from both directions (`hed__Contact__c IN` for `childIdsForParents`, `hed__RelatedContact__c IN` for `parentIdsForChildren`) rather than also checking the Guardian-category reciprocal row. One direction is sufficient because EDA always writes both rows for a Current relationship, and checking only the child-side type keeps exactly one rule everywhere (per the build spec) instead of two rules that could drift apart if a Guardian-category record were ever misconfigured.
- An unclassified `hed__Type__c` value (no `Relationship_Type_Setting__mdt` record at all, e.g. "Friend" or "Cousin") grants no access, by construction: `accessGrantingChildTypes()` only ever contains values with an actual CMDT record, so `hed__Type__c IN :accessGrantingTypes` simply never matches an unlisted value. No explicit denylist needed, and a new picklist value added later is safe-by-default (no access) until someone deliberately classifies it.
- `GuardianAccessSharingService.resyncForParents`/`revokeForParents` take parent **Contact** ids (matching every other consumer's identity) but resolve each one's active portal **User** id internally before writing shares — `ContactShare`/`hed__Application__Share.UserOrGroupId` must be a User/Group Id, not a Contact Id (`FIELD_INTEGRITY_EXCEPTION` otherwise, caught via a live deploy). A parent with no active portal user yet is silently skipped by `resyncForParents` (nothing to share to); `revokeForParents` looks up the User without the `IsActive` filter, since by the time it runs (just-deactivated) the user is already inactive and its stale shares still need removing.
- Chose to flip Contact OWD to `Private` (both internal and external sharing model) as its own separate deploy before the dependent Apex/triggers, after a combined deploy failed with "Field is not writeable" on `ContactShare` fields — object metadata apparently doesn't reliably apply before Apex compiles in the same deploy transaction. Did not flip `hed__Application__c`'s internal OWD (left `ReadWrite`); its *external* sharing model was already `Private` from before this pass, which is the one that actually gates portal/external users, so no change was needed there.
- `gradeLevel`, child-level `schoolName`, and `lotteryNumber` return `null` from `PortalDataController` rather than a guessed field mapping — no confirmed field exists for any of the three in this org (checked via `sf sobject describe`). Add real mappings once the fields are confirmed or created.
- Agent data access via a dedicated `Family_Assistant_Agent_Data_Access` permission set with read-only
  View All, not by editing Agentforce's auto-generated permission sets (can be regenerated on publish)
  or reusing portal/sharing sets (would give parents View All, or give the agent Modify All). The agent
  runs as one user for every parent, so sharing can't separate households; isolation is the action
  filtering by the server-set `PortalParentContactId`. View All creates no share rows, so it scales.
- Identity lookup moved into `CurrentParentSelector` now rather than copied into the agent controller —
  one place for the most security-sensitive rule; portal regression covered by `PortalDataControllerTest`.
- Anonymous-session behaviour enforced with AgentScript `if`/`else` instructions and `available when`,
  not with "don't guess" wording — the platform controls what the model sees; instructions are hints.
- Released agent v3 without the `childrenNames` output declaration rather than blocking the placeholder
  fix on an unrelated action-schema refresh.
