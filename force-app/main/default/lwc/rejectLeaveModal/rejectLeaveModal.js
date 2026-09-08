import { api } from 'lwc';
import LightningModal from 'lightning/modal';

export default class RejectLeaveModal extends LightningModal {
    @api comments = '';

    handleCommentsChange(event) {
        this.comments = event.target.value;
        const textarea = this.template.querySelector('lightning-textarea');
        if (this.comments && this.comments.trim()) {
            textarea.setCustomValidity('');
            textarea.reportValidity();
        }
    }

    handleCancel() {
        this.close();
    }

    handleReject() {
        const textarea = this.template.querySelector('lightning-textarea');
        if (!this.comments || !this.comments.trim()) {
            textarea.setCustomValidity('Please provide a reason before rejecting.');
            textarea.reportValidity();
            return;
        }

        textarea.setCustomValidity('');
        textarea.reportValidity();
        this.close(this.comments.trim());
    }
}