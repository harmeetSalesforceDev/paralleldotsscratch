@isTest
private class ShelfWatchApiServiceTest {

    private class MultiCalloutMock implements HttpCalloutMock {
        private Integer authStatus;
        private Integer apiStatus;
        private String  apiBody;

        public MultiCalloutMock(Integer authStatus, Integer apiStatus, String apiBody) {
            this.authStatus = authStatus;
            this.apiStatus  = apiStatus;
            this.apiBody    = apiBody;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');

            if (req.getEndpoint().contains('/v1/auth/jwt')) {
                res.setStatusCode(authStatus);
                if (authStatus == 200) {
                    res.setBody('{"access_token":"mock_token","refresh_token":"mock_refresh"}');
                } else {
                    res.setBody('{"message":"Unauthorized"}');
                }
            } else {
                res.setStatusCode(apiStatus);
                res.setBody(apiBody);
            }
            return res;
        }
    }

    private static void insertCredentials() {
        insert new ParallelDots__ShelfWatch_Credentials__c(
            Name                               = 'AuthCredentials',
            ParallelDots__Client_Id__c         = 'cid',
            ParallelDots__Client_Secret__c     = 'csecret',
            ParallelDots__Org_Id__c            = 'oid',
            ParallelDots__Project_Id__c        = 'pid'
        );
    }

    private static Map<String, Object> buildIngestBody(Id accountId) {
        return new Map<String, Object>{
            'entity'        => 'user',
            'sObjectEntity' => 'Account',
            'fieldMapping'  => new Map<String, String>{ 'user_name' => 'Name' },
            'entityFields'  => new List<String>{ 'user_name' },
            'records'       => new List<Object>()
        };
    }

    @isTest
    static void testHandleSelectedEntity_AuthorizedReturnsResult() {
        insertCredentials();
        Test.setMock(HttpCalloutMock.class, new MultiCalloutMock(
            200, 200, '{"fields":["name","email"]}'
        ));

        Test.startTest();
            Map<String, Object> result = ShelfWatchApiService.handleSelectedEntity('user');
        Test.stopTest();

        System.assertEquals(true, (Boolean) result.get('isAuthorize'), 'Should be authorized');
        System.assertNotEquals(null, result.get('result'), 'result key should be populated');
    }

    @isTest
    static void testHandleSelectedEntity_UnauthorizedReturnsError() {
        insertCredentials();
        Test.setMock(HttpCalloutMock.class, new MultiCalloutMock(
            401, 0, ''
        ));

        Test.startTest();
            Map<String, Object> result = ShelfWatchApiService.handleSelectedEntity('user');
        Test.stopTest();

        System.assertEquals(false, (Boolean) result.get('isAuthorize'), 'Should not be authorized');
        System.assertNotEquals(null, result.get('errorMessage'), 'errorMessage should be set');
    }

    @isTest
    static void testExportPayloadCreation_SuccessReturns202() {
        insertCredentials();
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Test.setMock(HttpCalloutMock.class, new MultiCalloutMock(
            200, 202, '{"status":"queued"}'
        ));

        Test.startTest();
            Map<String, Object> result = ShelfWatchApiService.exportPayloadCreation(
                buildIngestBody(acc.Id)
            );
        Test.stopTest();

        System.assertEquals(true, (Boolean) result.get('isAuthorize'), 'Should be authorized on 202');
        System.assertNotEquals(null, result.get('result'), 'result key should be set');
    }

}