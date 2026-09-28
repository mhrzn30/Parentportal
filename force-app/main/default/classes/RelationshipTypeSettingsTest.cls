/**
 * Proves RelationshipTypeSettings reads Category/Grants_Access__c correctly
 * and ignores Guardian-category rows, using setMockSettings() so this test
 * doesn't depend on the org's actual deployed CMDT records.
 */
@isTest
private class RelationshipTypeSettingsTest {
  @isTest
  static void returnsOnlyChildCategoryTypesWithAccessGranted() {
    RelationshipTypeSettings.setMockSettings(
      new List<Relationship_Type_Setting__mdt>{
        mdt('Daughter', 'Child', true),
        mdt('Stepchild', 'Child', true),
        mdt('Cousin', 'Child', false),
        mdt('Father', 'Guardian', true)
      }
    );

    Set<String> accessGrantingTypes = RelationshipTypeSettings.accessGrantingChildTypes();

    Assert.areEqual(
      new Set<String>{ 'Daughter', 'Stepchild' },
      accessGrantingTypes,
      'Only Child-category rows with Grants_Access__c checked should grant access'
    );
  }

  @isTest
  static void emptyMetadataGrantsNothing() {
    RelationshipTypeSettings.setMockSettings(
      new List<Relationship_Type_Setting__mdt>()
    );

    Assert.isTrue(
      RelationshipTypeSettings.accessGrantingChildTypes().isEmpty(),
      'No metadata rows means no type grants access'
    );
  }

  private static Relationship_Type_Setting__mdt mdt(
    String typeValue,
    String category,
    Boolean grantsAccess
  ) {
    return new Relationship_Type_Setting__mdt(
      Type_Value__c = typeValue,
      Category__c = category,
      Grants_Access__c = grantsAccess
    );
  }
}
