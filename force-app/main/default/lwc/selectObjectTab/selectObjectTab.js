import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import checkMappingExists from '@salesforce/apex/ObjectMetadataController.checkMappingExists';
import getAllObjects from '@salesforce/apex/ObjectMetadataController.getAllObjects';
import getShelfFields from '@salesforce/apex/ObjectMetadataController.getShelfFields';
export default class SelectObjectTab extends LightningElement {

    @api selectedObj1;
    @api selectedObj2;
    @track fields;

    @api selectedObj2Label;

    @track objectOptions = [];
    @track shelfobjectOptions = [
        { label: 'User', value: 'users' },
        { label: 'Stores', value: 'stores' },
        { label: 'Route Plan', value: 'route_plan' },
        { label: 'Assortment List', value: 'assortment_list' },
        { label: 'Sku Master', value: 'sku_master' }
    ];

    @track searchTerm = '';
    @track showList = false;
    @track newEntity = false;
    @track newObjectName = false;
    newObjectLabel;
    shelfApiResult;

    connectedCallback() {
        this.handleOutsideClick = this.handleOutsideClick.bind(this);
        document.addEventListener('click', this.handleOutsideClick);

        if (this.selectedObj2 && !this.searchTerm) {
            this.searchTerm = this.selectedObj2Label || this.selectedObj2;
        }
    }

    disconnectedCallback() {
        document.removeEventListener('click', this.handleOutsideClick);
    }

    handleOutsideClick(event) {
        const path = event.composedPath();

        if (path.includes(this.template.host)) {
            return;
        }

        this.showList = false;
    }


    get filteredOptions() {
        if (!this.searchTerm) {
            return this.objectOptions;
        }

        const term = this.searchTerm.toLowerCase();

        return this.objectOptions
            .filter(opt => opt.label.toLowerCase().includes(term))
            .sort((a, b) => {
                const aLabel = a.label.toLowerCase();
                const bLabel = b.label.toLowerCase();

                if (aLabel === term) return -1;
                if (bLabel === term) return 1;

                if (aLabel.startsWith(term) && !bLabel.startsWith(term)) return -1;
                if (!aLabel.startsWith(term) && bLabel.startsWith(term)) return 1;

                return aLabel.localeCompare(bLabel);
            });
    }

    handleSearch(event) {
        this.searchTerm = event.target.value;
        this.showList = true;
        this.selectedObj2 = null;
    }

    showDropdown() {
        this.showList = true;
    }

    preventClose(event) {
        event.stopPropagation();
    }


    selectOption(event) {
        const val = event.currentTarget.dataset.value;

        this.selectedObj2 = val;

        this.searchTerm = this.objectOptions.find(obj => obj.value === val).label;
        this.showList = false;
    }

    @wire(getAllObjects)
    wiredObjects({ data, error }) {
        if (data) {
            this.objectOptions = data
                .map(obj => ({ label: obj.label, value: obj.value }))
                .sort((a, b) => a.label.localeCompare(b.label));
        } else if (error) {
            this.showError(error.body?.message || 'Failed to load objects');
        }
    }

    handleObj1(event) {
        this.selectedObj1 = event.detail.value;
    }

    handleObj2(event) {
        this.selectedObj2 = event.detail.value;
    }

    async handleNext() {
        if (!this.selectedObj2) {
            this.showError('Please select Salesforce object');
            return;
        }

        const entityName = this.selectedObj1;

        if (this.newEntity) {
            try {
                // const exists = await checkMappingExists({ shelfObject: entityName });
                // if (exists) {
                //     this.showError(`A mapping for "${entityName}" already exists.`);
                //     return;
                // }
            } catch (err) {
                this.showError(err.body?.message || 'Validation failed');
                return;
            }
            this.fireNext(entityName, null);
            return;
        }

        try {
            // const exists = await checkMappingExists({ shelfObject: entityName });
            // if (exists) {
            //     this.showError(`A mapping for "${entityName}" already exists.`);
            //     return;
            // }

            const res = await getShelfFields({ entity: entityName });
            if (!res.isAuthorize) {
                this.showError(res.errorMessage || 'Authorization failed');
                return;
            }
            this.shelfApiResult = res.result;
            this.fireNext(entityName, res.result);

        } catch (err) {
            this.showError(err.body?.message || err.message);
        }
    }

    showError(msg) {
        this.dispatchEvent(
            new ShowToastEvent({
                message: msg,
                title: 'Error',
                variant: 'error'
            })
        );
    }

    fireNext(targetObj, apiResult) {
        this.dispatchEvent(
            new CustomEvent('nextstep', {
                detail: {
                    isNew: this.newEntity,
                    obj1: targetObj,
                    obj2: this.selectedObj2,
                    obj2Label: this.searchTerm,
                    shelfResult: apiResult
                }

            })
        );
    }

    handleToggle(event) {
        this.newEntity = event.target.checked;
        if (this.newEntity) {
            this.selectedObj1 = null;
            this.selectedObj2 = null;
            this.searchTerm = '';
            this.showList = false;
        }
    }

    handleObjNameCheckbox(event) {
        this.newObjectName = event.target.checked;
    }

    handleObjNameInput(event) {
        this.newObjectLabel = event.target.value;
    }

}