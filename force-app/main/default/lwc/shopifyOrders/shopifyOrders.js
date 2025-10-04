import { LightningElement, track, wire, api } from 'lwc';
import getShopifyOrders from '@salesforce/apex/ShopifyDataController.getShopifyOrders';
import syncOrdersOnly from '@salesforce/apex/ShopifyDataController.syncOrdersOnly';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';

export default class ShopifyOrders extends NavigationMixin(LightningElement) {
    @api header = 'Órdenes de Shopify';
    @track orders = [];
    @track filteredOrders = [];
    @track isLoading = false;
    @track selectedStatus = '';
    @track searchEmail = '';
    @track error;
    wiredOrdersResult;

    // Opciones para el filtro de estado
    statusOptions = [
        { label: 'Todos los estados', value: '' },
        { label: 'Draft', value: 'Draft' },
        { label: 'Activated', value: 'Activated' },
        { label: 'Shipped', value: 'Shipped' },
        { label: 'Delivered', value: 'Delivered' },
        { label: 'Cancelled', value: 'Cancelled' }
    ];

    // Wire para obtener las órdenes
    @wire(getShopifyOrders)
    wiredOrders(result) {
        this.wiredOrdersResult = result;
        const { data, error } = result;
        if (data) {
            this.orders = data.map(order => ({
                ...order,
                formattedTotalPrice: this.formatCurrency(order.TotalAmount),
                formattedCreatedAt: this.formatDate(order.EffectiveDate),
                statusClass: this.getStatusClass(order.Status),
                statusLabel: order.Status
            }));
            this.filteredOrders = [...this.orders];
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.orders = [];
            this.filteredOrders = [];
        }
    }

    // Método para sincronizar datos con Shopify
    async syncWithShopify() {
        this.isLoading = true;
        try {
            await syncOrdersOnly();
            this.displayToast('Éxito', 'Órdenes sincronizadas correctamente', 'success');
            // Forzar recarga de datos
            await this.refreshData();
        } catch (error) {
            this.displayToast('Error', 'Error al sincronizar órdenes: ' + error.body.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // Método para filtrar por estado
    handleStatusChange(event) {
        this.selectedStatus = event.detail.value;
        this.applyFilters();
    }

    // Método para buscar por email
    handleEmailSearch(event) {
        this.searchEmail = event.detail.value;
        this.applyFilters();
    }

    // Método para aplicar filtros
    applyFilters() {
        this.filteredOrders = this.orders.filter(order => {
            const statusMatch = !this.selectedStatus || order.Status === this.selectedStatus;
            const emailMatch = !this.searchEmail || 
                (order.Account && order.Account.Name && 
                 order.Account.Name.toLowerCase().includes(this.searchEmail.toLowerCase()));
            
            return statusMatch && emailMatch;
        });
    }

    // Método para ver detalles de la orden
    viewOrderDetails(event) {
        const orderId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: orderId,
                objectApiName: 'Order',
                actionName: 'view'
            }
        });
    }

    // Método para refrescar datos
    async refreshData() {
        // Forzar recarga de datos wire usando refreshApex
        this.isLoading = true;
        try {
            await refreshApex(this.wiredOrdersResult);
        } catch (error) {
            console.error('Error refreshing data:', error);
        } finally {
            this.isLoading = false;
        }
    }

        // Método para formatear moneda
        formatCurrency(value) {
            if (!value) return '$0.00';
            return new Intl.NumberFormat('es-CO', {
                style: 'currency',
                currency: 'COP'
            }).format(value);
        }

    // Método para formatear fecha
    formatDate(dateValue) {
        if (!dateValue) return '';
        const date = new Date(dateValue);
        return date.toLocaleDateString('es-ES', {
            year: 'numeric',
            month: 'short',
            day: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        });
    }

    // Método para obtener clase CSS del estado
    getStatusClass(status) {
        switch (status) {
            case 'Draft':
                return 'slds-theme_info';
            case 'Activated':
                return 'slds-theme_success';
            case 'Shipped':
                return 'slds-theme_warning';
            case 'Delivered':
                return 'slds-theme_success';
            case 'Cancelled':
                return 'slds-theme_error';
            default:
                return 'slds-theme_default';
        }
    }

    // Método para mostrar notificaciones
    displayToast(toastHeader, message, variant) {
        const toastEvent = new ShowToastEvent({
            title: toastHeader,
            message: message,
            variant: variant
        });
        this.dispatchEvent(toastEvent);
    }
}
