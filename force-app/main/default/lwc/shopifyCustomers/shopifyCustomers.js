import { LightningElement, track, wire, api } from 'lwc';
import getContacts from '@salesforce/apex/ShopifyDataController.getShopifyCustomers';
import syncCustomersOnly from '@salesforce/apex/ShopifyDataController.syncCustomersOnly';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';

export default class ShopifyCustomers extends NavigationMixin(LightningElement) {
    @api header = 'Clientes de Shopify';
    @track customers = [];
    @track filteredCustomers = [];
    @track isLoading = false;
    @track searchTerm = '';
    @track error;
    wiredCustomersResult;

    // Wire para obtener los contactos de Shopify
    @wire(getContacts)
    wiredCustomers(result) {
        this.wiredCustomersResult = result;
        const { data, error } = result;
        if (data) {
            this.customers = data.map(customer => ({
                ...customer,
                fullName: this.getFullName(customer.FirstName, customer.LastName)
            }));
            this.filteredCustomers = [...this.customers];
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.customers = [];
            this.filteredCustomers = [];
        }
    }

    // Método para sincronizar clientes con Shopify
    async syncCustomers() {
        this.isLoading = true;
        try {
            await syncCustomersOnly();
            this.displayToast('Éxito', 'Clientes sincronizados correctamente', 'success');
            // Forzar recarga de datos
            this.refreshData();
        } catch (error) {
            this.displayToast('Error', 'Error al sincronizar clientes: ' + error.body.message, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // Método para buscar clientes
    handleSearch(event) {
        this.searchTerm = event.detail.value;
        this.applyFilters();
    }

    // Método para aplicar filtros
    applyFilters() {
        this.filteredCustomers = this.customers.filter(customer => {
            if (!this.searchTerm) return true;
            
            const searchLower = this.searchTerm.toLowerCase();
            const firstName = customer.FirstName ? customer.FirstName.toLowerCase() : '';
            const lastName = customer.LastName ? customer.LastName.toLowerCase() : '';
            const email = customer.Email ? customer.Email.toLowerCase() : '';
            const fullName = customer.fullName ? customer.fullName.toLowerCase() : '';
            
            return firstName.includes(searchLower) || 
                   lastName.includes(searchLower) || 
                   email.includes(searchLower) || 
                   fullName.includes(searchLower);
        });
    }

    // Método para ver detalles del cliente
    viewCustomerDetails(event) {
        const customerId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: customerId,
                objectApiName: 'Contact',
                actionName: 'view'
            }
        });
    }

    // Método para editar cliente
    editCustomer(event) {
        const customerId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: customerId,
                objectApiName: 'Contact',
                actionName: 'edit'
            }
        });
    }

    // Método para refrescar datos
    async refreshData() {
        // Forzar recarga de datos wire usando refreshApex
        this.isLoading = true;
        try {
            await refreshApex(this.wiredCustomersResult);
        } catch (error) {
            console.error('Error refreshing data:', error);
        } finally {
            this.isLoading = false;
        }
    }

    // Método para obtener nombre completo
    getFullName(firstName, lastName) {
        if (firstName && lastName) {
            return `${firstName} ${lastName}`;
        } else if (firstName) {
            return firstName;
        } else if (lastName) {
            return lastName;
        }
        return 'Sin nombre';
    }

    // Método para mostrar notificaciones
    displayToast(toastHeader, message, variant) {
        const toastEvent = new ShowToastEvent({
            header: toastHeader,
            message: message,
            variant: variant
        });
        this.dispatchEvent(toastEvent);
    }
}
