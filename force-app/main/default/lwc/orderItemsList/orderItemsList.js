import { LightningElement, api, track, wire } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import getOrderItems from '@salesforce/apex/ShopifyDataController.getOrderItems';

// Campos de la orden
const ORDER_FIELDS = [
    'Order.Id',
    'Order.OrderNumber'
];

export default class OrderItemsList extends LightningElement {
    @api recordId;
    @track orderItems = [];
    @track isLoading = true;
    @track hasOrderItems = false;

    // Obtener datos de la orden
    @wire(getRecord, { recordId: '$recordId', fields: ORDER_FIELDS })
    wiredOrder({ error, data }) {
        if (data) {
            this.loadOrderItems();
        } else if (error) {
            console.error('Error loading order:', error);
            this.isLoading = false;
        }
    }

    // Cargar OrderItems
    loadOrderItems() {
        this.isLoading = true;
        
        getOrderItems({ orderId: this.recordId })
            .then(result => {
                this.orderItems = result.map(item => ({
                    ...item,
                    ProductName: item.Product2?.Name || 'Producto no encontrado',
                    ProductCode: item.Product2?.ProductCode || 'N/A',
                    TotalPrice: (item.UnitPrice * item.Quantity).toFixed(2)
                }));
                
                this.hasOrderItems = this.orderItems.length > 0;
                this.isLoading = false;
            })
            .catch(error => {
                console.error('Error loading order items:', error);
                this.isLoading = false;
            });
    }
}

