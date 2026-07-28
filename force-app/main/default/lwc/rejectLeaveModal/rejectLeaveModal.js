import { api } from 'lwc';
import LightningModal from 'lightning/modal';

export default class RejectLeaveModal extends LightningModal {

    @api comments = '';

    handleCommentsChange(event) {
        this.comments = event.target.value;
    }

    handleCancel() {
        this.close();
    }

    handleReject() {

       this.close(this.comments);
    }
}