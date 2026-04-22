import getFields from '@salesforce/apex/ObjectMetadataController.getFields';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { LightningElement, api, track } from 'lwc';

export default class EditMappingTab extends LightningElement {
    @api isNew;

    @api sourceObject;
    @api targetObject;

    @track sourceFields = [];
    @track targetFields = [];
    @track mappingRows = [];
    @track mapping = [];
    @api shelfResult;

    @api savedMappingRows;

    @api savedMapping;
    @track fieldsLoaded = false;

    @api hideBack = false;

    // @track sfTypeMap = {};
    // @track shelfTypeMap = {};
    @track requiredShelfFields = [];

    get cardTitle() {
        const src = this.sourceObject ? this.sourceObject.charAt(0).toUpperCase() + this.sourceObject.slice(1) : '';
        return this.isNew
            ? `New Entity Mapping: ${src}`
            : `Field Mapping: ${src} → ${this.targetObject?.charAt(0).toUpperCase() + this.targetObject?.slice(1) || ''}`;
    }

    get targetObjectLabel() {
        return this.targetObject
            ? this.targetObject.charAt(0).toUpperCase() + this.targetObject.slice(1)
            : '';
    }

    get allSelected() {
        return this.mappingRows?.length &&
            this.mappingRows.every(row => row.include);
    }

    handleSelectAll(event) {
        const checked = event.target.checked;

        this.mappingRows = this.mappingRows.map(row => ({
            ...row,
            include: checked
        }));
    }

    connectedCallback() {
        this.initializeFields();
        this.initializeSavedMappings();
        this.initializeShelfSchema();
    }

    initializeFields() {
        if (!this.fieldsLoaded) {
            this.loadFields();
        }
    }

    initializeSavedMappings() {
        if (this.savedMapping) {
            this.mapping = JSON.parse(JSON.stringify(this.savedMapping));
        }

        if (this.savedMappingRows?.length) {
            this.mappingRows = JSON.parse(JSON.stringify(this.savedMappingRows));
            this.fieldsLoaded = true;
        }
    }

    initializeShelfSchema() {
        if (!this.shelfResult) {
            return;
        }
         console.log('shelfResult (edit flow):', JSON.stringify(this.shelfResult, null, 2));
        const props =
            this.shelfResult?.schema?.properties?.records?.items?.properties || {};
        const required =
            this.shelfResult?.schema?.properties?.records?.items?.required || [];

        const localRequiredShelfFields = [...required];
        const localTargetFields = localRequiredShelfFields.map(fieldName => ({
            label: fieldName,
            type: props[fieldName]?.type || 'string',
            value: fieldName
        }));
        const localShelfTypeMap = {};

        localTargetFields.forEach(field => {
            localShelfTypeMap[field.value] = field.type;
        });

        this.requiredShelfFields = localRequiredShelfFields;
        this.targetFields = localTargetFields;
        this.shelfTypeMap = localShelfTypeMap;
    }

    loadFields() {

        getFields({ objectName: this.sourceObject })
            // .then(res => {
            //     this.sourceFields = res;

            //     // const localSfTypeMap = {};
            //     // res.forEach(field => {
            //     //     localSfTypeMap[field.api] = field.type;
            //     // });
            //     // this.sfTypeMap = localSfTypeMap;
            //     if (!this.savedMappingRows || !this.savedMappingRows.length) {
            //         this.buildRows();
            //     }
            // });

            .then(res => {
                this.sourceFields = res.slice().sort((a, b) => a.label.localeCompare(b.label));
                if (!this.savedMappingRows || !this.savedMappingRows.length) {
                    this.buildRows();
                }
            });

        this.fieldsLoaded = true;
    }

    buildRows() {

        const required = this.shelfResult?.required || [];

        this.mappingRows = this.sourceFields.map(field => ({
            include: false,
            required: required.includes(field.api),
            sourceApi: field.api,
            sourceLabel: field.label,
            target: null
        }));
    }

    get targetOptions() {
        return [
            ...(this.targetFields || []),
            { label: 'Custom', value: '__custom__' },
            { label: '--None--', value: '' }
        ];
    }

    handleMapping(event) {
        const src = event.target.dataset.source;
        const val = event.detail.value;
        if (!val) {
            this.mappingRows = this.mappingRows.map(row =>
                row.sourceApi === src ? { ...row, target: null } : row
            );
            return;
        }
        const alreadyUsed = this.mappingRows.find(
            row => row.target === val && row.sourceApi !== src
        );
        if (alreadyUsed && val !== '__custom__') {
            this.mappingRows = this.mappingRows.map(row => {
                if (row.sourceApi === src) {
                    return {
                        ...row,
                        target: null
                    };
                }
                return row;
            });
            this.dispatchEvent(
                new ShowToastEvent({
                    message: 'This target field is already mapped.',
                    title: 'Duplicate Mapping',
                    variant: 'error'
                })
            );
            event.target.value = null;
            return;
        }
        this.mappingRows = this.mappingRows.map(row => {
            if (row.sourceApi === src) {
                return {
                    ...row,
                    target: val
                };
            }
            return row;
        });
    }

    handleBack() {
        this.dispatchEvent(new CustomEvent('back'));
    }

    handleNext() {
        const mappingObj = {};
        const selectedApis = [];
        const totalFields = this.sourceFields?.length || 0;
        const requiredShelfFields = (this.targetFields || []).map(field => field.value);

        (this.mappingRows || []).forEach(row => {

            if (this.isNew && row.include) {
                mappingObj[row.sourceApi] = row.sourceApi;
                selectedApis.push(row.sourceApi);
            }
            if (!this.isNew && row.target) {

                let targetField;

                if (row.target === '__custom__') {
                    targetField = row.sourceApi;

                    //this.shelfTypeMap[targetField] = this.sfTypeMap[row.sourceApi] || 'STRING';
                } else {
                    targetField = row.target;
                }

                mappingObj[targetField] = row.sourceApi;
                selectedApis.push(row.sourceApi);
            }
        });

        if (!this.isNew) {
            const mappedTargets = Object.keys(mappingObj);

            const missingRequired = requiredShelfFields.filter(
                field => !mappedTargets.includes(field)
            );

            if (missingRequired.length > 0) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        message: `Map all required Shelfwatch fields: ${missingRequired.join(', ')}`,
                        title: 'Missing Required Fields',
                        variant: 'error'
                    })
                );
                return;
            }
        }

        console.log('FINAL MAP → ', JSON.stringify(mappingObj));
        console.log('Salesforce fields → ' + JSON.stringify(selectedApis));
        console.log('Shelfwatch fields: ' + JSON.stringify(requiredShelfFields));

        // if (!this.isNew) {
        //     for (let target in mappingObj) {

        //         const sfField = mappingObj[target];

        //         const sfType = this.sfTypeMap[sfField];
        //         const shelfType = this.shelfTypeMap[target] || this.sfTypeMap[target];

        //         if (!this.isCompatible(sfType, shelfType)) {
        //             this.dispatchEvent(
        //                 new ShowToastEvent({
        //                     message: `${sfField} (${sfType}) cannot map to ${target} (${shelfType})`,
        //                     title: 'Invalid Mapping',
        //                     variant: 'error'
        //                 })
        //             );
        //             return;
        //         }
        //     }
        // }

        this.dispatchEvent(
            new CustomEvent('next', {
                detail: {
                    mapping: mappingObj,
                    totalFields: totalFields,
                    selectedApis: selectedApis,
                    mappingRows: this.mappingRows,

                    salesforceObject: this.sourceObject,
                    shelfwatchObject: this.targetObject,
                    requiredShelfFields: requiredShelfFields
                }

            })
        );

    }

    handleInclude(event) {
        const src = event.target.dataset.source;
        const val = event.target.checked;

        this.mappingRows = this.mappingRows.map(row =>
            row.sourceApi === src
                ? { ...row, include: val }
                : row
        );
    }

    // isCompatible(sfType, shelfType) {

    //     if (!sfType || !shelfType) {
    //         return true;
    //     }

    //     const sf = sfType.toUpperCase();
    //     const shelf = shelfType.toLowerCase();

    //     if (shelf === 'string' && (sf === 'ID' || sf === 'REFERENCE')) {
    //         return false;
    //     }

    //     const map = {
    //         boolean: ['BOOLEAN'],
    //         date: ['DATE', 'DATETIME'],
    //         id: ['ID', 'REFERENCE'],
    //         number: ['DOUBLE', 'INTEGER', 'CURRENCY', 'PERCENT'],
    //         string: ['STRING', 'TEXTAREA', 'EMAIL', 'PHONE', 'URL', 'PICKLIST']
    //     };

    //     if (!map[shelf]) {
    //         return true;
    //     }

    //     return map[shelf].includes(sf);
    // }

    handleCancel() {
        this.dispatchEvent(new CustomEvent('cancel'));
    }

    get allMappedAsCustom() {
        return this.mappingRows?.length &&
            this.mappingRows.every(row => row.target === '__custom__');
    }

    handleMapAllCustom(event) {
        const checked = event.target.checked;
        this.mappingRows = this.mappingRows.map(row => ({
            ...row,
            target: checked ? '__custom__' : null
        }));
    }

}