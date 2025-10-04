import { LightningElement, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import limpiarBaseDeDatos from '@salesforce/apex/ShopifyDataController.limpiarBaseDeDatos';
import syncProductsOnly from '@salesforce/apex/ShopifyDataController.syncProductsOnly';
import syncCustomersOnly from '@salesforce/apex/ShopifyDataController.syncCustomersOnly';
import syncOrdersOnly from '@salesforce/apex/ShopifyDataController.syncOrdersOnly';
import syncHistoricalDataFromShopify from '@salesforce/apex/ShopifyDataController.syncHistoricalDataFromShopify';

export default class ShopifyDashboard extends LightningElement {
    // Propiedad configurable desde el metadata
    @api header = 'Dashboard de Shopify';
    
    // Credenciales hardcodeadas para Shopify
    shopDomain = 'https://michelltemp.myshopify.com';
    apiKey = 'd7867f5f3a45d8fe055eb4c25c4f80e6';
    webhookSecret = '2839a7a4078978479b46522ad4e3fdd7144138fa26cf20d619f3f723bd1e7128';
    
    // Endpoint del webhook
    get webhookEndpoint() {
        const baseUrl = window.location.origin;
        return `${baseUrl}/services/apexrest/shopify/webhook`;
    }
    
    // Método que se ejecuta cuando el componente se carga
    connectedCallback() {
        // Establecer conexión automáticamente al cargar
        this.establishConnection();
    }
    
    // Establecer conexión automáticamente
    establishConnection() {
        console.log('Estableciendo conexión automática con Shopify...');
        console.log('Dominio:', this.shopDomain);
        console.log('API Key:', this.apiKey);
        console.log('Webhook Secret:', this.webhookSecret);
        console.log('Endpoint:', this.webhookEndpoint);
    }
    

    async limpiarBaseDeDatos() {
        try {
            console.log('🧹 Iniciando limpieza de base de datos...');
            this.showToast('Información', 'Iniciando limpieza de base de datos...', 'info');
            
            const result = await limpiarBaseDeDatos();
            
            console.log('✅ Base de datos limpiada:', result);
            this.showToast('Éxito', result, 'success');
            
            // Refrescar la página para mostrar el estado limpio
            setTimeout(() => {
                window.location.reload();
            }, 2000);
            
        } catch (error) {
            console.error('❌ Error limpiando base de datos:', error);
            this.showToast('Error', 'Error al limpiar base de datos: ' + error.message, 'error');
        }
    }
    
    // Sincronizar solo productos
    async syncProductsOnly() {
        try {
            console.log('🔄 Iniciando sincronización de productos...');
            this.showToast('Información', 'Iniciando sincronización de productos...', 'info');
            
            const result = await syncProductsOnly();
            
            console.log('✅ Productos sincronizados:', result);
            this.showToast('Éxito', 'Productos sincronizados correctamente', 'success');
            
            // Refrescar la página para mostrar los nuevos datos
            setTimeout(() => {
                window.location.reload();
            }, 2000);
            
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
            
            this.showToast('Error', 'Error al sincronizar productos: ' + errorMessage, 'error');
        }
    }
    
    // Sincronizar solo clientes
    async syncCustomersOnly() {
        try {
            console.log('🔄 Iniciando sincronización de clientes...');
            this.showToast('Información', 'Iniciando sincronización de clientes...', 'info');
            
            const result = await syncCustomersOnly();
            
            console.log('✅ Clientes sincronizados:', result);
            this.showToast('Éxito', 'Clientes sincronizados correctamente', 'success');
            
            // Refrescar la página para mostrar los nuevos datos
            setTimeout(() => {
                window.location.reload();
            }, 2000);
            
        } catch (error) {
            console.error('❌ Error sincronizando clientes:', error);
            this.showToast('Error', 'Error al sincronizar clientes: ' + error.message, 'error');
        }
    }
    
    // Sincronizar solo órdenes
    async syncOrdersOnly() {
        try {
            console.log('🔄 Iniciando sincronización de órdenes...');
            this.showToast('Información', 'Iniciando sincronización de órdenes...', 'info');
            
            const result = await syncOrdersOnly();
            
            console.log('✅ Órdenes sincronizadas:', result);
            this.showToast('Éxito', 'Órdenes sincronizadas correctamente', 'success');
            
            // Refrescar la página para mostrar los nuevos datos
            setTimeout(() => {
                window.location.reload();
            }, 2000);
            
        } catch (error) {
            console.error('❌ Error sincronizando órdenes:', error);
            this.showToast('Error', 'Error al sincronizar órdenes: ' + error.message, 'error');
        }
    }
    
    // Sincronizar todos los datos históricos
    async syncHistoricalData() {
        try {
            console.log('🔄 Iniciando sincronización completa...');
            this.showToast('Información', 'Iniciando sincronización completa...', 'info');
            
            await syncHistoricalDataFromShopify();
            
            console.log('✅ Sincronización completa exitosa');
            this.showToast('Éxito', 'Sincronización completa exitosa', 'success');
            
        } catch (error) {
            console.error('❌ Error en sincronización completa:', error);
            this.showToast('Error', 'Error en sincronización completa: ' + error.message, 'error');
        }
    }
    
    // Mostrar notificaciones
    showToast(title, message, variant) {
        const toastEvent = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(toastEvent);
    }
}