@isTest
public class SyncMonitorControllerTest {
    @TestSetup
    public static void testSetup(){
        ParallelDots__Shelfwatch_Mapping__c mappingRecord = new ParallelDots__Shelfwatch_Mapping__c();
        mappingRecord.Name = 'Account users Mapping';
        mappingRecord.ParallelDots__Salesforce_Object__c = 'Account';
        mappingRecord.ParallelDots__Shelfwatch_Object__c = 'users';
        insert mappingRecord;
    }
	@isTest
    public static void testMethod1(){
        Test.startTest();
        SyncMonitorController.getMappingOptions();
        Test.stopTest();
    }
    
    @isTest
    public static void testMethod2(){
        List<ParallelDots__Shelfwatch_Mapping__c> mapRecord = [SELECT Id,Name FROM ParallelDots__Shelfwatch_Mapping__c];
        Test.startTest();
        SyncMonitorController.getSyncLogsByMapping(mapRecord[0].Id);
        Test.stopTest();
    }
}