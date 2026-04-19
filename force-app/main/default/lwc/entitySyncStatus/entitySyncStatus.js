import deleteMapping from '@salesforce/apex/AudienceSyncTableController.deleteMapping';
import getMappingRecords from '@salesforce/apex/AudienceSyncTableController.getMappingRecords';
import syncNow from '@salesforce/apex/AudienceSyncTableController.syncNow';
import verifyAuthentication from '@salesforce/apex/ShelfWatchAuthService.verifyAuthentication';
import updateAutoSync from '@salesforce/apex/AudienceSyncTableController.updateAutoSync';
import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import retryFailedSync from '@salesforce/apex/AudienceSyncTableController.retryFailedSync';
import getJobStatus from '@salesforce/apex/AudienceSyncTableController.getJobStatus';
export default class EntitySyncStatus extends NavigationMixin(LightningElement) {
    columns = [
        { key: 'entityName', label: 'Shelfwatch Entity' },
        { key: 'sfObjectName', label: 'Salesforce Object' },
        { key: 'unmappedFields', label: 'Unmapped Fields' },
        { key: 'lastSync', label: 'Last Sync' },
        { key: 'syncStatus', label: 'Sync Status' },
        { key: 'syncNow', label: 'Sync Now' },
        { key: 'retry', label: 'Retry' },
        { key: 'autoSync', label: 'Auto Sync' },
        { key: 'edit', label: 'Edit' },
        { key: 'delete', label: 'Delete' }
    ];
    deleteRecordId;
    @track entities = [];
    @track isLoading = true;
    error;
    @track showDeleteModal = false;

    @track isAuthorized = false;
    @track isLoading = true;
    @track authChecked = false;
    pollingIntervals = {};

    @wire(verifyAuthentication)
    wiredAuth({ data, error }) {
        if (data) {
            this.isAuthorized = data.isAuthorize === true;
            this.authChecked = true;
            this.isLoading = false;
        } else if (error) {
            this.isAuthorized = false;
            this.authChecked = true;
            this.isLoading = false;
        }
        //this.authChecked = true;
        //this.isLoading = false;
    }

    connectedCallback() {
        this.loadRecords();
    }

    loadRecords() {
        this.isLoading = true;
        getMappingRecords()
            .then(data => {
                this.entities = data.map(row => this.enrichRow(row));
                this.error = null;
            })
            .catch(err => {
                this.error = err?.body?.message || 'Unknown error';
                this.entities = [];
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleRefresh() {
        this.loadRecords();
    }

    get isEmpty() {
        return !this.isLoading && this.entities.length === 0;
    }

    handleSyncNow(event) {
        const recordId = event.currentTarget.dataset.id;
        console.log('recordId: ' + recordId);

        const entity = this.entities.find(row => row.id === recordId);
        const existingJobId = entity?.batchJobId;

        if (existingJobId) {
            getJobStatus({ jobId: existingJobId })
                .then(status => {
                    if (['Queued', 'Processing', 'Preparing'].includes(status)) {
                        this.dispatchEvent(new ShowToastEvent({
                            title: 'Sync In Progress',
                            message: 'A sync is already running. Please wait for it to complete.',
                            variant: 'error'
                        }));
                    } else {
                        this.startSync(recordId);
                    }
                })
                .catch(() => this.startSync(recordId));
        } else {
            this.startSync(recordId);
        }
    }

    startSync(recordId) {
        this.entities = this.entities.map(row =>
            row.id === recordId ? { ...row, isSyncing: true } : row
        );

        syncNow({ recordId })
            .then(jobId => {
                console.log('Batch Job Id: ' + jobId);
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Success',
                    message: 'Sync started successfully',
                    variant: 'success'
                }));
            })
            .catch(err => {
                this.error = err?.body?.message || 'Sync failed';
                this.entities = this.entities.map(row =>
                    row.id === recordId ? { ...row, isSyncing: false } : row
                );
            });
    }


    disconnectedCallback() {
        Object.values(this.pollingIntervals).forEach(interval => clearInterval(interval));
        this.pollingIntervals = {};
    }

    handleEdit(event) {
        const editRowId = event.currentTarget.dataset.id;
        console.log('rowId: ' + editRowId);
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: {
                apiName: 'ParallelDots__Export_Wizard'
            },
            state: {
                c__mappingId: editRowId
            }
        });
    }

    handleDeleteClick(event) {
        this.deleteRecordId = event.target.dataset.id;
        console.log('this.deleteRecordId' + this.deleteRecordId);
        this.showDeleteModal = true;
    }

    handleDeleteCancel() {
        this.showDeleteModal = false;
        this.deleteRecordId = null;
    }

    handleDeleteConfirm() {
        this.showDeleteModal = false;
        this.deleteRecord();
    }

    deleteRecord() {
        deleteMapping({ recordId: this.deleteRecordId })
            .then(() => {
                this.entities = this.entities.filter(row => row.id !== this.deleteRecordId);
                this.deleteRecordId = null;
            })
            .catch(err => {
                this.error = err?.body?.message || 'Delete failed';
            });
    }

    enrichRow(row) {
        return {
            ...row,
            hasUnmappedFields: row.unmappedFields > 0,
            lastSyncTime: row.lastSyncTime
                ? new Date(row.lastSyncTime).toLocaleString()
                : '—',
            isAutoActive: row.isAutoActive || false,
            isSyncing: false
        };
    }

    handleAutoSync(event) {
        const recordId = event.currentTarget.dataset.id;
        const isActive = event.detail.checked;
        updateAutoSync({ recordId, isActive })
            .then(() => {
                this.entities = this.entities.map(row =>
                    row.id === recordId ? { ...row, isAutoActive: isActive } : row
                );
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Auto Sync',
                    message: isActive ? 'Auto Sync is Active Now! Data will sync at 11pm daily' : 'Auto Sync Disabled!',
                    variant: isActive ? 'success' : 'warning'
                }));
            })
            .catch(err => {
                this.error = err?.body?.message || 'Auto sync update failed';
            });
    }


    handleRetry(event) {
        const recordId = event.currentTarget.dataset.id;

        this.entities = this.entities.map(row =>
            row.id === recordId ? { ...row, isSyncing: true } : row
        );

        retryFailedSync({ recordId })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Retry Started',
                    message: 'Retrying failed records...',
                    variant: 'info'
                }));
                setTimeout(() => this.loadRecords(), 1500);
            })
            .catch(err => {
                this.dispatchEvent(new ShowToastEvent({
                    title: 'Retry Failed',
                    message: err?.body?.message || 'Retry could not be started',
                    variant: 'error'
                }));
                this.entities = this.entities.map(row =>
                    row.id === recordId ? { ...row, isSyncing: false } : row
                );
            });
    }

    get showRetryColumn() {
        return this.entities.some(row => row.canRetry);
    }

    get visibleColumns() {
        return this.columns.filter(col => {
            if (col.key === 'retry') {
                return this.showRetryColumn;
            }
            return true;
        });
    }
}