import getMappingById from '@salesforce/apex/AudienceSyncTableController.getMappingById';
import getFields from '@salesforce/apex/ObjectMetadataController.getFields';
import getShelfFields from '@salesforce/apex/ObjectMetadataController.getShelfFields';
import verifyAuthentication from '@salesforce/apex/ShelfWatchAuthService.verifyAuthentication';
import { LightningElement, track, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
export default class selectWizard extends LightningElement {
    selectedObj1;
    selectedObj2;
    mapping;
    @track isNewEntity = false;
    shelfResult;
    totalFields;
    @track sfFields = [];
    sfObject;
    shelfObject;
    @track requiredShelfFields = [];
    editRecordId;
    @track isLoading = false;

    selectedObj2Label;
    savedMappingRows;

    @track isAuthorized = false;
    @track authChecked = false;

    @wire(verifyAuthentication)
    wiredAuth({ data, error }) {
        if (data) {
            this.isAuthorized = data.isAuthorize === true;
            this.authChecked = true;
        } else if (error) {
            this.isAuthorized = false;
            this.authChecked = true;
        }
    }

    @wire(CurrentPageReference)
    handlePageRef(pageRef) {
        const mappingId = pageRef?.state?.c__mappingId;
        this.resetState();
        if (!mappingId) {
            return;
        }
        this.editRecordId = mappingId;
        this.isLoading = true;
        getMappingById({ recordId: mappingId })
            .then(data => {
                this.selectedObj1 = data.shelfObject;
                this.selectedObj2 = data.sfObject;
                this.selectedObj2Label = data.sfObject;
                this.isNewEntity = data.shelfObject === 'custom';
                const parsedMapping = data.mappingJSON ? JSON.parse(data.mappingJSON) : {};
                this.mapping = parsedMapping;
                const reverseMap = {};
                Object.entries(parsedMapping).forEach(([shelfField, sfApi]) => {
                    if (shelfField === sfApi) {
                        reverseMap[sfApi] = '__custom__';
                    } else {
                        reverseMap[sfApi] = shelfField;
                    }
                });
                return Promise.all([
                    getFields({ objectName: data.sfObject }),
                    getShelfFields({ entity: data.shelfObject })
                ]).then(([sfFields, shelfRes]) => {
                    this.shelfResult = shelfRes.result;
                    const selectedApis = new Set(Object.values(parsedMapping));
                    this.savedMappingRows = sfFields.map(field => ({
                        include: selectedApis.has(field.api),
                        required: false,
                        sourceApi: field.api,
                        sourceLabel: field.label,
                        target: reverseMap[field.api] || null
                    }))
                        .sort((a, b) => a.sourceLabel.localeCompare(b.sourceLabel));
                });
            })
            .then(() => {
                this.isLoading = false;
                this.currentStep = 'step2';
            })
            .catch(err => {
                this.showError(err?.body?.message || 'Failed to load mapping');
                this.isLoading = false;
            });
    }

    @track currentStep = 'step1';
    get isStep1() {
        return this.currentStep === 'step1';
    }

    get isStep2() {
        return this.currentStep === 'step2';
    }

    get isStep3() {
        return this.currentStep === 'step3';
    }

    handleStep3(event) {
        this.mapping = event.detail.mapping;
        this.totalFields = event.detail.totalFields;
        this.sfFields = event.detail.selectedApis;
        this.sfObject = event.detail.salesforceObject;
        this.shelfObject = event.detail.shelfwatchObject;
        this.requiredShelfFields = event.detail.requiredShelfFields;
        this.currentStep = 'step3';
        this.savedMappingRows = event.detail.mappingRows;
    }

    handleBack() {
        this.currentStep = 'step1';
    }
    handleBack2() {
        this.currentStep = 'step2';
    }

    handleNext(event) {
        this.selectedObj1 = event.detail.obj1;
        this.selectedObj2 = event.detail.obj2;
        this.isNewEntity = event.detail.isNew;
        this.selectedObj2Label = event.detail.obj2Label;
        this.currentStep = 'step2';
        this.shelfResult = event.detail.shelfResult;
    }

    handleImport() {
        this.dispatchEvent(
            new ShowToastEvent({
                message: 'Your Mapping has been saved.',
                title: 'Success',
                variant: 'success'
            })
        );
        this.resetState();
    }
    resetState() {
        this.currentStep = 'step1';
        this.selectedObj1 = null;
        this.selectedObj2 = null;
        this.selectedObj2Label = null;
        this.mapping = null;
        this.savedMappingRows = null;
        this.shelfResult = null;
        this.isNewEntity = false;
        this.editRecordId = null;
        this.sfFields = [];
        this.requiredShelfFields = [];
        this.totalFields = null;
        this.shelfObject = null;
        this.sfObject = null;
    }
    get step1Class() {
        if (this.currentStep === 'step1') {
            return 'step active';
        }

        if (['step2', 'step3'].includes(this.currentStep)) {
            return 'step completed';
        }

        return 'step';
    }

    get step2Class() {
        if (this.currentStep === 'step2') {
            return 'step active';
        }

        if (this.currentStep === 'step3') {
            return 'step completed';
        }

        return 'step';
    }

    get step3Class() {
        if (this.currentStep === 'step3') {
            return 'step active';
        }

        return 'step';
    }

    get isEditFlow() {
        return !!this.editRecordId;
    }

    handleCancel() {
        this.resetState();
    }
}