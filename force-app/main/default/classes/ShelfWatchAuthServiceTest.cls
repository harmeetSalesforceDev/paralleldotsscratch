@isTest
private class ShelfWatchAuthServiceTest {
    private class AuthSuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setHeader('Content-Type', 'application/json');
            res.setBody(JSON.serialize(new Map<String, Object>{
                'access_token'  => 'mock_access_token_123',
                'refresh_token' => 'mock_refresh_token_456'
            }));
            return res;
        }
    }

    private class AuthUnauthorizedMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(401);
            res.setHeader('Content-Type', 'application/json');
            res.setBody(JSON.serialize(new Map<String, Object>{
                'message' => 'Invalid credentials'
            }));
            return res;
        }
    }

    private class AuthServerErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setHeader('Content-Type', 'application/json');
            res.setBody(JSON.serialize(new Map<String, Object>{
                'message' => 'Internal server error'
            }));
            return res;
        }
    }

    private static ParallelDots__ShelfWatch_Credentials__c insertCredentials() {
        ParallelDots__ShelfWatch_Credentials__c cred = new ParallelDots__ShelfWatch_Credentials__c(
            Name                               = 'AuthCredentials',
            ParallelDots__Client_Id__c         = 'test_client_id',
            ParallelDots__Client_Secret__c     = 'test_client_secret',
            ParallelDots__Org_Id__c            = 'test_org_id',
            ParallelDots__Project_Id__c        = 'test_project_id'
        );
        insert cred;
        return cred;
    }

    private static Map<String, String> buildAuthMap() {
        return new Map<String, String>{
            'clientId'     => 'test_client_id',
            'clientSecret' => 'test_client_secret',
            'orgId'        => 'test_org_id',
            'projectId'    => 'test_project_id'
        };
    }
    
    @isTest
    static void testSetupAuthCredentials_ReturnsTrueOnSuccess() {
        Map<String, String> authMap = buildAuthMap();

        Test.startTest();
            Boolean result = ShelfWatchAuthService.setupAuthCredentials(authMap);
        Test.stopTest();

        System.assertEquals(true, result, 'setupAuthCredentials should return true on successful insert');

        List<ParallelDots__ShelfWatch_Credentials__c> inserted = [
            SELECT Name,
                   ParallelDots__Client_Id__c,
                   ParallelDots__Client_Secret__c,
                   ParallelDots__Org_Id__c,
                   ParallelDots__Project_Id__c
            FROM   ParallelDots__ShelfWatch_Credentials__c
            WHERE  Name = 'AuthCredentials'
        ];
        System.assertEquals(1,                  inserted.size(),                          'One credential record should be created');
        System.assertEquals('test_client_id',   inserted[0].ParallelDots__Client_Id__c,   'Client Id should match');
        System.assertEquals('test_client_secret', inserted[0].ParallelDots__Client_Secret__c, 'Client Secret should match');
        System.assertEquals('test_org_id',      inserted[0].ParallelDots__Org_Id__c,      'Org Id should match');
        System.assertEquals('test_project_id',  inserted[0].ParallelDots__Project_Id__c,  'Project Id should match');
    }

    @isTest
    static void testCheckAuthentication_AuthorizedWhen200() {
        insertCredentials();
        Test.setMock(HttpCalloutMock.class, new AuthSuccessMock());

        Test.startTest();
            Map<String, Object> result = ShelfWatchAuthService.checkAuthentication();
        Test.stopTest();

        System.assertNotEquals(null, result, 'Result map should not be null');
        System.assertEquals(true, (Boolean) result.get('isAuthorize'), 'isAuthorize should be true for 200 response');
        System.assertEquals(false, result.containsKey('error'),   'No error key expected on success');
        System.assertEquals(false, result.containsKey('message'), 'No message key expected on success');
    }

    @isTest
    static void testCheckAuthentication_NotAuthorizedWhen401() {
        insertCredentials();
        Test.setMock(HttpCalloutMock.class, new AuthUnauthorizedMock());

        Test.startTest();
            Map<String, Object> result = ShelfWatchAuthService.checkAuthentication();
        Test.stopTest();

        System.assertEquals(false, (Boolean) result.get('isAuthorize'), 'isAuthorize should be false for 401');
        System.assertEquals(401,   (Integer) result.get('error'),       'error should be 401');
        System.assertEquals('Invalid credentials', (String) result.get('message'), 'message should match mock');
    }

    @isTest
    static void testCheckAuthentication_NotAuthorizedWhenNoCredentials() {
        Test.startTest();
            Map<String, Object> result = ShelfWatchAuthService.checkAuthentication();
        Test.stopTest();

        System.assertEquals(false, (Boolean) result.get('isAuthorize'),
            'isAuthorize should be false when no credentials exist');
    }

    @isTest
    static void testVerifyAuthentication_ConfiguredAndAuthorized() {
        insertCredentials();
        Test.setMock(HttpCalloutMock.class, new AuthSuccessMock());

        Test.startTest();
            Map<String, Object> result = ShelfWatchAuthService.verifyAuthentication();
        Test.stopTest();

        System.assertEquals(true, (Boolean) result.get('isConfigured'), 'isConfigured should be true when credentials exist');
        System.assertEquals(true, (Boolean) result.get('isAuthorize'),  'isAuthorize should be true for 200 response');
    }

    @isTest
    static void testVerifyAuthentication_NotConfiguredWhenNoCredentials() {
        List<ParallelDots__ShelfWatch_Credentials__c> existing = [
            SELECT Id FROM ParallelDots__ShelfWatch_Credentials__c WHERE Name = 'AuthCredentials'
        ];
        if (!existing.isEmpty()) { delete existing; }

        Test.startTest();
            Map<String, Object> result = ShelfWatchAuthService.verifyAuthentication();
        Test.stopTest();

        System.assertEquals(false, (Boolean) result.get('isConfigured'), 'isConfigured should be false when no credentials exist');
        System.assertEquals(false, (Boolean) result.get('isAuthorize'),  'isAuthorize should be false when not configured');
    }

    @isTest
    static void testDeleteSettings_DeletesExistingCredentials() {
        insertCredentials();

        Test.startTest();
            ShelfWatchAuthService.deleteSettings();
        Test.stopTest();

        List<ParallelDots__ShelfWatch_Credentials__c> remaining = [
            SELECT Id FROM ParallelDots__ShelfWatch_Credentials__c WHERE Name = 'AuthCredentials'
        ];
        System.assertEquals(0, remaining.size(), 'Credential record should be deleted');
    }

}