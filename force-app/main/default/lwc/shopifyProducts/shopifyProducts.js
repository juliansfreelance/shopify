import { LightningElement, track, wire, api } from 'lwc';
import getShopifyProducts from '@salesforce/apex/ShopifyDataController.getShopifyProducts';
import syncProductsOnly from '@salesforce/apex/ShopifyDataController.syncProductsOnly';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';

export default class ShopifyProducts extends NavigationMixin(LightningElement) {
    @api header = 'Productos de Shopify';
    @track products = [];
    @track filteredProducts = [];
    @track isLoading = false;
    @track selectedStatus = '';
    @track searchTerm = '';
    @track error;
    wiredProductsResult;

    // Opciones para el filtro de estado
    statusOptions = [
        { label: 'Todos los estados', value: '' },
        { label: 'Activo', value: 'active' },
        { label: 'Inactivo', value: 'inactive' }
    ];

    // Wire para obtener los productos
    @wire(getShopifyProducts)
    wiredProducts(result) {
        this.wiredProductsResult = result;
        const { data, error } = result;
        if (data) {
            this.products = data.map(product => ({
                ...product,
                formattedPrice: this.formatCurrency(product.PricebookEntries && product.PricebookEntries.length > 0 ? product.PricebookEntries[0].UnitPrice : 0),
                statusClass: this.getStatusClass(product.IsActive ? 'active' : 'inactive'),
                statusLabel: product.IsActive ? 'Activo' : 'Inactivo'
            }));
            this.filteredProducts = [...this.products];
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.products = [];
            this.filteredProducts = [];
        }
    }

        // Método para sincronizar productos con Shopify
        async syncProducts() {
            this.isLoading = true;
            try {
                console.log('🔄 Iniciando sincronización de productos...');
                await syncProductsOnly();
                console.log('✅ Productos sincronizados exitosamente');
                this.displayToast('Éxito', 'Productos sincronizados correctamente', 'success');
                // Forzar recarga de datos
                await this.refreshData();
            } catch (error) {
                console.error('❌ Error sincronizando productos:', error);
                console.error('❌ Error details:', JSON.stringify(error, null, 2));
                
                let errorMessage = 'Error desconocido';
                if (error.body && error.body.message) {
                    errorMessage = error.body.message;
                } else if (error.message) {
                    errorMessage = error.message;
                } else if (error.body) {
                    errorMessage = JSON.stringify(error.body);
                }
                
                this.displayToast('Error', 'Error al sincronizar productos: ' + errorMessage, 'error');
            } finally {
                this.isLoading = false;
            }
        }

    // Método para filtrar por estado
    handleStatusChange(event) {
        this.selectedStatus = event.detail.value;
        this.applyFilters();
    }

    // Método para buscar productos
    handleSearch(event) {
        this.searchTerm = event.detail.value;
        this.applyFilters();
    }

    // Método para aplicar filtros
    applyFilters() {
        this.filteredProducts = this.products.filter(product => {
            const statusMatch = !this.selectedStatus || 
                (this.selectedStatus === 'active' && product.IsActive) ||
                (this.selectedStatus === 'inactive' && !product.IsActive);
            const searchMatch = !this.searchTerm || 
                (product.Name && 
                 product.Name.toLowerCase().includes(this.searchTerm.toLowerCase()));
            
            return statusMatch && searchMatch;
        });
    }

    // Método para ver detalles del producto
    viewProductDetails(event) {
        const productId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: productId,
                objectApiName: 'Product2',
                actionName: 'view'
            }
        });
    }

    // Método para refrescar datos
    async refreshData() {
        // Forzar recarga de datos wire usando refreshApex
        this.isLoading = true;
        try {
            await refreshApex(this.wiredProductsResult);
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

    // Método para obtener clase CSS del estado
    getStatusClass(status) {
        switch (status) {
            case 'active':
                return 'slds-theme_success';
            case 'inactive':
                return 'slds-theme_warning';
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
