/**
 * Wraps Relationship_Type_Setting__mdt: the single place that decides which
 * hed__Relationship__c.hed__Type__c values grant access. Every consumer
 * (RelationshipSelector, and anything built on top of it) calls
 * accessGrantingChildTypes() instead of hardcoding a type list, so a new
 * picklist value never grants access until someone deliberately classifies
 * it here.
 *
 * Only Category__c = 'Child' rows are ever read for access decisions -- the
 * Guardian-side reciprocal rows (Father/Mother/... ) exist in the metadata
 * for documentation/audit only, per CLAUDE.md's "use the child-side type
 * list everywhere" rule.
 */
public inherited sharing class RelationshipTypeSettings {
  private static List<Relationship_Type_Setting__mdt> cachedSettings;

  /**
   * Test seam: lets a unit test supply in-memory metadata rows instead of
   * depending on what's actually deployed to the org, so a test isn't
   * broken by someone editing the CMDT records later. Not used outside
   * tests.
   */
  @TestVisible
  private static void setMockSettings(
    List<Relationship_Type_Setting__mdt> mockSettings
  ) {
    cachedSettings = mockSettings;
  }

  /** Every Category = 'Child' value with Grants_Access__c checked. */
  public static Set<String> accessGrantingChildTypes() {
    Set<String> result = new Set<String>();
    for (Relationship_Type_Setting__mdt setting : allSettings()) {
      if (setting.Category__c == 'Child' && setting.Grants_Access__c) {
        result.add(setting.Type_Value__c);
      }
    }
    return result;
  }

  /** Reads Relationship_Type_Setting__mdt once per transaction, then caches it. */
  private static List<Relationship_Type_Setting__mdt> allSettings() {
    if (cachedSettings == null) {
      cachedSettings = [
        SELECT Type_Value__c, Category__c, Grants_Access__c
        FROM Relationship_Type_Setting__mdt
      ];
    }
    return cachedSettings;
  }
}
