/**
 * Configuration Page (LWC)
 * Purpose:
 * - Capture client configuration values required by the application
 * - Validate inputs on the client and present a success state
 *
 * UX/Data Notes:
 * - Uses SLDS and an optional static resource stylesheet for look-and-feel overrides
 * - Form visibility controlled via `showForm`
 * - Inputs are tracked in `formData` and validated before submit
 */
import { LightningElement, track, wire } from 'lwc';
import { loadStyle } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

import checkAuthentication from '@salesforce/apex/ShelfWatchAuthService.checkAuthentication';
import deleteSettings from '@salesforce/apex/ShelfWatchAuthService.deleteSettings';
import setupAuthCredentials from '@salesforce/apex/ShelfWatchAuthService.setupAuthCredentials';
import verifyAuthentication from '@salesforce/apex/ShelfWatchAuthService.verifyAuthentication';

import configurationOverride from '@salesforce/resourceUrl/configurationOverride';

import { authenticationMessage } from 'c/utility';


export default class ConfigurationPage extends LightningElement {
    // Controls which template block is rendered (form vs. success)
    @track showForm = false;
    @track isLoading = true;
    @track isModalOpen = false
    @track feedBackMessage = {}

    // Reactive form model for the inputs. Keys align to the `name` attribute on lightning-inputs
    @track formData = {
        clientId: '',
        clientSecret: '',
        orgId: '',
        projectId: ''
    };

    connectedCallback() {
        Promise.all([
            loadStyle(this, configurationOverride)
        ]);
    }

    @wire(verifyAuthentication)
    wiredVerification({ data, error }) {
        if (data) {
            this.isLoading = false;

            const isAuthorized = data?.isAuthorize;
            const isConfigured = data?.isConfigured;

            this.showForm = !isAuthorized && !isConfigured;
            const feedback = isAuthorized || !isConfigured;

            this.feedBackMessage = authenticationMessage(feedback);

        } else if (error) {
            this.isLoading = false;
            //console.error(JSON.stringify(error));
        }
    }


    handleChange(event) {
        const { name, value } = event.target;
        this.formData[name] = value;
        event.target.setCustomValidity('');
        event.target.reportValidity();
    }

    handleSubmit() {
        let isValid = true;

        // Validate all lightning-inputs (required check)
        const inputs = this.template.querySelectorAll('lightning-input');
        inputs.forEach(input => {
            if (!input.value) {
                input.setCustomValidity('This field is required.');
                input.reportValidity();
                isValid = false;
            }
        });

        if (!isValid) {
            // Early return pattern: stop if validation failed
            return;
        }
        //console.log('Form Data:', JSON.stringify(this.formData));

        this.isLoading = true;
        this.handleAuthentication()
    }

    handleReset() {
        this.isModalOpen = true
        this.formData = {
            clientId: '',
            clientSecret: '',
            orgId: '',
            projectId: ''
        };

        const inputs = this.template.querySelectorAll('lightning-input');
        inputs.forEach(input => {
            input.value = '';
            input.setCustomValidity('');
        });
    }

    async handleAuthentication() {
        try {
            const settingsRes = await this.handleCreateCredentials();
            if (!settingsRes) {
                this.isLoading = false
                this.showToast('Error', 'Internal Server Error', 'error', 'sticky')
                return;
            }
            const checkAuthRes = await this.handleCheckAuthorize();
            this.isLoading = false
            if (!checkAuthRes?.isAuthorize) {
                await this.handleDeleteSettings();
                this.showToast('Error', `${checkAuthRes.error} ${checkAuthRes.message}`, 'error', 'sticky')
                return;
            }
            this.feedBackMessage = authenticationMessage(true)
            this.showForm = false;
            this.showToast('Success', 'Your Credentials is successfully authenticated!', 'success', 'dismissible');

        } catch (error) {
            //console.error(JSON.stringify(error))
        }
    }
    async handleCreateCredentials() {
        return setupAuthCredentials({ authCredentials: this.formData })
            .then((response) => {
                console.log(JSON.stringify(response))
                return response;
            }).catch((error) => {
                console.error(JSON.stringify(error))
                return false;
            })
    }

    async handleCheckAuthorize() {
        return checkAuthentication().then((response) => {
            //console.log(JSON.stringify(response))
            return response
        }).catch((error) => {
            //console.error(JSON.stringify(error))
        })
    }

    async handleDeleteSettings() {
        return deleteSettings().then(() => {
        }).catch((error) => {
            //console.error(JSON.stringify(error))
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
    }

    handleSettingError() {
        this.isloading = false
    }

    closeModal() {
        this.isModalOpen = false
    }

    async handleResetCredent() {
        this.isModalOpen = false
        this.handleDeleteSettings()
        this.showForm = true
    }



}