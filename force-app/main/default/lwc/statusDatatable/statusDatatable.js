import LightningDatatable from 'lightning/datatable';

import statusBadgeTemplate from './statusBadgeTemplate.html';

export default class StatusDatatable extends LightningDatatable {

    static customTypes = {

        statusBadge: {

            template: statusBadgeTemplate,

            standardCellLayout: true,

            typeAttributes: ['status']
        }
    };
}