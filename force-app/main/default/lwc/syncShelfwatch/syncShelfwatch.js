import { LightningElement , track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import handleSelectedEntity from '@salesforce/apex/ShelfWatchApiService.handleSelectedEntity';
import exportPayloadCreation from '@salesforce/apex/ShelfWatchApiService.exportPayloadCreation';
export default class SyncShelfwatch extends LightningElement {
   /* @track fieldMapping = {
        'user_id'   : 'Id',
        'user_name' : 'Name',
        'email'     : 'Email'
    }
    
    async handleSyncUsers(){
        try{
            const requiredFields = await this.handleGetSchema()
            console.log('response==> ' + requiredFields)
            const ingestResponse = await this.handleIngestData(requiredFields)
            console.log('ingestResponse==> ' + JSON.stringify(ingestResponse))
            if(ingestResponse?.isAuthorize){
                this.showToast('Sync Successfully!', ingestResponse?.result?.transaction_id, 'success', 'sticky');
            }else{
                this.showToast('Error', ingestResponse?.errorMessage , 'error', 'sticky')
            }
            
        }catch(error){
            console.error(JSON.stringify(error))
        }

    }

    handleGetSchema(){
        return handleSelectedEntity({selectedEntity : 'users'})
        .then(response => {
            console.log(response)
            if(response){
                return response?.result?.schema?.properties?.records?.items?.required ?? [];
            }
        })
        .catch(error => {
            console.error(JSON.stringify(error))
        })
    }

    handleIngestData(requiredFields){
        let payload = {
            entity       : 'users',
            fieldMapping : this.fieldMapping,
            entityFields : requiredFields,
            records      : [],
            sObjectEntity : 'User'
            
        }
        return exportPayloadCreation({ingestBody : payload})
        .then(response => {
            return response
        })
        .catch(error => {
            console.error(JSON.stringify(error))
        })
    }

    showToast(title, message, variant, mode) {
        const evt = new ShowToastEvent({
            title,
            message,
            variant,
            mode
        });
        this.dispatchEvent(evt);
    }*/

}