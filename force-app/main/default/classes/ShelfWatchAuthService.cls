/** *  @description ShelfWatchAuthService Working for authenticate the shelfwatch api */
public with sharing class ShelfWatchAuthService {
     /** * @description AuthResponse  */
    public class AuthResponse {
        /** * @description String accessToken defined  */
        public String accessToken;
        /** * @description String refreshToken defined  */
        public String refreshToken;
       /** * @description String error defined  */
        public Integer error;
       /** * @description String message defined  */
        public Object message;
      /** * @description Boolean isAuthorize defined  */
        public Boolean isAuthorize;
    }
    /** * @description setupAuthCredentials *@param authCredentials  *@return Boolean */
    @AuraEnabled
    public static Boolean setupAuthCredentials(Map<String,String> authCredentials){
        try{
            // Consider removing debug logs in production to comply with PMD best practices
            Boolean response = createAuthCredentials(authCredentials);
            return response;
        }catch(Exception e){
            throw new AuraHandledException(e.getMessage());
        }
    }
    /**
     * @description Creates or saves a credentials record using values from provided map after validating FLS.
     * @return trMap<String, Object>ue when persistence completes without Database errors
     * @throws AuraHandledException when persistence fails with a DML error
     */
    @AuraEnabled
    public static Map<String, Object> checkAuthentication(){
        try{
            AuthResponse auth        = getAccessToken();
            Map<String, Object> body = new Map<String, Object>();
            if(!auth.isAuthorize){
                body.put('isAuthorize', false);
                body.put('error', auth.error);
                body.put('message', auth.message);
            }else{
                body.put('isAuthorize', true);
            }
            return body;
        }catch(Exception e){
            throw new AuraHandledException(e.getMessage());
        }
    }
    /**
     * @description Creates or saves a credentials record using values from provided map after validating FLS.
     * @return trMap<String, Object>ue when persistence completes without Database errors
     * @throws AuraHandledException when persistence fails with a DML error
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> verifyAuthentication(){
        try{
            ParallelDots__ShelfWatch_Credentials__c shelfCred = ParallelDots__ShelfWatch_Credentials__c.getInstance('AuthCredentials');
            Map<String, Object> response = new Map<String, Object>();
            response.put('isAuthorize' , false);     // Not Depend on custom settings
            response.put('isConfigured' , true);     // Depends on custom settings
            if (shelfCred == null) {
                response.put('isConfigured' , false);
            }else{
                AuthResponse auth = getAccessToken();
                response.put('isAuthorize' , auth.isAuthorize);
            }
            return response;
        }catch(Exception e){
            throw new AuraHandledException(e.getMessage());
        }
    }
    /**
     * @description Creates or saves a credentials record using values from provided map after validating FLS
     * @throws AuraHandledException when persistence fails with a DML error
     */
    @AuraEnabled
    public static void deleteSettings(){
        try{
            ParallelDots__ShelfWatch_Credentials__c shelfCred = ParallelDots__ShelfWatch_Credentials__c.getInstance('AuthCredentials');
            if(shelfCred != null){
                delete as user shelfCred;
            }
        }catch(Exception e){
            throw new AuraHandledException(e.getMessage());
        }
    }
    /**
     * @description Creates or saves a credentials record using values from provided map after validating FLS.
     * @param authCredentials Map containing clientId, clientSecret, orgId, projectId
     * @return true when persistence completes without Database errors
     * @throws AuraHandledException when persistence fails with a DML error
     */
    private static Boolean createAuthCredentials(Map<String,String> authCredentials) {
            Database.SaveResult res;
            Boolean isInserted      = false;
            ParallelDots__ShelfWatch_Credentials__c credentials = new ParallelDots__ShelfWatch_Credentials__c();
            credentials.Name                           = 'AuthCredentials';
            credentials.ParallelDots__Client_Id__c     = authCredentials.get('clientId');
            credentials.ParallelDots__Client_Secret__c = authCredentials.get('clientSecret');
            credentials.ParallelDots__Org_Id__c        = authCredentials.get('orgId');
            credentials.ParallelDots__Project_Id__c    = authCredentials.get('projectId');
                if (Schema.sObjectType.ParallelDots__ShelfWatch_Credentials__c.fields.Name.isCreateable() &&
                Schema.sObjectType.ParallelDots__ShelfWatch_Credentials__c.fields.ParallelDots__Client_Id__c.isCreateable() &&
                Schema.sObjectType.ParallelDots__ShelfWatch_Credentials__c.fields.ParallelDots__Client_Secret__c.isCreateable() &&
                Schema.sObjectType.ParallelDots__ShelfWatch_Credentials__c.fields.ParallelDots__Org_Id__c.isCreateable() &&
                Schema.sObjectType.ParallelDots__ShelfWatch_Credentials__c.fields.ParallelDots__Project_Id__c.isCreateable()) {
                res = Database.insert(credentials , false);
            }
            isInserted = ((res != null && res.isSuccess()) ? true : false);
            return isInserted;
    }

    /**
     * @description Performs a callout to ShelfWatch JWT auth endpoint using the ShelfWatch_API Named Credential
     *              and returns a structured AuthResponse. Does not throw for non-200 responses; instead, it
     *              returns error details in the response wrapper.
     * @return AuthResponse containing access token data or error details
     */
    public static AuthResponse getAccessToken() {
        ParallelDots__ShelfWatch_Credentials__c shelfCred = ParallelDots__ShelfWatch_Credentials__c.getInstance('AuthCredentials');
        Http http                                         = new Http();
        HttpRequest req                                   = new HttpRequest();
        AuthResponse responseObj                          = new AuthResponse();
        responseObj.isAuthorize                           = false;
        if (shelfCred == null) {
            return responseObj;
        }
        req.setEndpoint('callout:ShelfWatch_API/v1/auth/jwt');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('X-Org-Id', shelfCred.ParallelDots__Org_Id__c);
        req.setHeader('X-Project-Id', shelfCred.ParallelDots__Project_Id__c);
        Map<String, Object> body = new Map<String, Object>{
            'client_id'     => shelfCred.ParallelDots__Client_Id__c,
            'client_secret' => shelfCred.ParallelDots__Client_Secret__c
        };
        req.setBody(JSON.serialize(body));
        HttpResponse res;
        res = http.send(req);
        Map<String, Object> result = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
        if (res.getStatusCode() == 200) {
            responseObj.accessToken    = (String)result.get('access_token');
            responseObj.refreshToken   = (String)result.get('refresh_token');
            responseObj.isAuthorize    = true;
        } else {
            responseObj.error   = res.getStatusCode();
            responseObj.message = (String)result.get('message');
        }
        return responseObj;
    }
}