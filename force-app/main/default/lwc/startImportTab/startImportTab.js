import { LightningElement, api } from 'lwc';
import createShelfMapping from '@salesforce/apex/ObjectMetadataController.createShelfMapping';
import updateShelfMapping from '@salesforce/apex/ObjectMetadataController.updateShelfMapping';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
export default class StartImportTab extends LightningElement {
    @api isNewEntity = false;
    @api editRecordId;

    @api objectName;

    @api mapping = {};

    @api totalFields;

    @api sfFields = [];
    @api requiredShelfFields = [];
    @api optionalShelfFields = [];
    @api shelfObject;
    @api sfObject;


    get selectedCount() {
        return Object.keys(this.mapping || {}).length;
    }


    get mappedCount() {
        return Object.values(this.mapping || {}).filter(val => val).length;
    }

    get unmappedCount() {
        return (this.totalFields || 0) - this.mappedCount;
    }

    handleBack() {
        this.dispatchEvent(new CustomEvent('previous'));
    }

    handleImport() {
        const savePromise = this.editRecordId
            ? updateShelfMapping({
                mappingJSON: this.mapping,
                recordId: this.editRecordId,
                requiredFields: this.requiredShelfFields,
                sfFields: this.sfFields,
                unmappedCount: this.unmappedCount,
                optionalShelfFields: this.optionalShelfFields
            })
            : createShelfMapping({
                mappingJSON: this.mapping,
                requiredFields: this.requiredShelfFields,
                sfFields: this.sfFields,
                sfObject: this.sfObject,
                shelfObject: this.shelfObject,
                unmappedCount: this.unmappedCount,
                optionalShelfFields: this.optionalShelfFields
            });

        savePromise
            .then(() => {
                this.dispatchEvent(new CustomEvent('startimport' ));
            })
            .catch(err => {
                this.showError(err?.body?.message || 'Save failed');
            });
    }

    showError(msg) {
    this.dispatchEvent(
        new ShowToastEvent({
            title: 'Error',
            message: msg,
            variant: 'error'
        })
    );
}

}