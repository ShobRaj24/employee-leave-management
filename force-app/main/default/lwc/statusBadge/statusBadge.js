import { LightningElement, api } from 'lwc';

export default class StatusBadge extends LightningElement {

    @api status;

    get badgeClass() {

        switch (this.status) {

            case 'Approved':
                return 'badge approved';

            case 'Rejected':
                return 'badge rejected';

            case 'Pending':
                return 'badge pending';

            case 'Cancelled':
                return 'badge cancelled';

            default:
                return 'badge';
        }
    }
}