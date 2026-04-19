import { LightningElement, track, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getMappingOptions from '@salesforce/apex/SyncMonitorController.getMappingOptions';
import getSyncLogsByMapping from '@salesforce/apex/SyncMonitorController.getSyncLogsByMapping';

export default class SyncMonitorTab extends LightningElement {
    @track selectedMappingId = null;
    @track mappingOptions = [];
    @track logs = [];
    @track isLoading = false;
    @track showErrorModal = false;
    @track activeError = '';
    wiredLogsResult;

    connectedCallback() {
        this.loadMappingOptions();
    }

    loadMappingOptions() {
        getMappingOptions()
            .then(data => {
                this.mappingOptions = data.map(opt => ({
                    label: opt.label,
                    value: opt.value
                }));
            })
            .catch(error => {
                console.error('Error loading mapping options', error);
            });
    }

    @wire(getSyncLogsByMapping, { mappingId: '$selectedMappingId' })
    wiredLogs(result) {
        this.wiredLogsResult = result;
        if (result.data) {
            this.logs = result.data.map(log => ({
                ...log,
                hasError: !!log.ParallelDots__Error_Messages__c,
                statusClass: this.getStatusClass(log.ParallelDots__Status__c)
            }));
            this.isLoading = false;
        } else if (result.error) {
            this.isLoading = false;
        }
    }

    get isEmpty() {
        return !this.logs || this.logs.length === 0;
    }

    getStatusClass(status) {
        const base = 'status-badge ';
        if (status === 'Success')     return base + 'status-badge--success';
        if (status === 'Failed')      return base + 'status-badge--error';
        if (status === 'In Progress') return base + 'status-badge--progress';
        return base;
    }

    handleMappingChange(event) {
        this.selectedMappingId = event.detail.value;
        this.isLoading = true;
        this.logs = [];
    }

    handleRefresh() {
        this.isLoading = true;
        refreshApex(this.wiredLogsResult).then(() => {
            this.isLoading = false;
        });
    }

    handleViewError(event) {
        const id = event.target.dataset.id;
        const log = this.logs.find(l => l.Id === id);
        if (log) {
            this.activeError = log.ParallelDots__Error_Messages__c;
            this.showErrorModal = true;
        }
    }

    closeErrorModal() {
        this.showErrorModal = false;
        this.activeError = '';
    }
}