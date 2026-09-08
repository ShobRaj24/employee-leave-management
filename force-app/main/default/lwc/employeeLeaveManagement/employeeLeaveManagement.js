import { LightningElement } from 'lwc';

export default class EmployeeLeaveManagement extends LightningElement {
    handleLeaveCreated() {
        const listCmp = this.template.querySelector('c-leave-request-list');
        if (listCmp) {
            listCmp.refreshList();
        }

        const managerCmp = this.template.querySelector('c-manager-leave-approval');
        if (managerCmp) {
            managerCmp.refreshApprovals();
        }
    }

    handleLeaveCancelled() {
        const formCmp = this.template.querySelector('c-leave-request-form');
        if (formCmp) {
            formCmp.refreshBalance();
        }

        const managerCmp = this.template.querySelector('c-manager-leave-approval');
        if (managerCmp) {
            managerCmp.refreshApprovals();
        }
    }

    handleApprovalProcessed() {
        const formCmp = this.template.querySelector('c-leave-request-form');
        if (formCmp) {
            formCmp.refreshBalance();
        }

        const listCmp = this.template.querySelector('c-leave-request-list');
        if (listCmp) {
            listCmp.refreshList();
        }
    }
}