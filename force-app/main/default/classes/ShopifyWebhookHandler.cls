public with sharing class ShopifyWebhookHandler {
    
    // Método para procesar webhooks de órdenes
    public static void handleOrderWebhook(String webhookData) {
        try {
            // Parsear el JSON del webhook
            Map<String, Object> orderData = (Map<String, Object>) JSON.deserializeUntyped(webhookData);
            
            // Extraer información de la orden
            String shopifyOrderId = String.valueOf(orderData.get('id'));
            String orderNumber = String.valueOf(orderData.get('order_number'));
            String totalPrice = String.valueOf(orderData.get('total_price'));
            String orderStatus = String.valueOf(orderData.get('financial_status'));
            String customerEmail = '';
            
            // Extraer información del cliente si existe
            if (orderData.containsKey('customer')) {
                Map<String, Object> customer = (Map<String, Object>) orderData.get('customer');
                customerEmail = String.valueOf(customer.get('email'));
            }
            
            // Crear o actualizar la orden en Salesforce
            upsertOrder(shopifyOrderId, orderNumber, totalPrice, orderStatus, customerEmail);
            
        } catch (Exception e) {
            System.debug('Error procesando webhook de orden: ' + e.getMessage());
            // Aquí podrías implementar logging o notificaciones
        }
    }
    
    // Método para procesar webhooks de productos
    public static void handleProductWebhook(String webhookData) {
        try {
            // Parsear el JSON del webhook
            Map<String, Object> productData = (Map<String, Object>) JSON.deserializeUntyped(webhookData);
            
            // Extraer información del producto
            String shopifyProductId = String.valueOf(productData.get('id'));
            String productTitle = String.valueOf(productData.get('title'));
            String price = String.valueOf(productData.get('variants'));
            String productType = String.valueOf(productData.get('product_type'));
            String status = String.valueOf(productData.get('status'));
            
            // Crear o actualizar el producto en Salesforce
            upsertProduct(shopifyProductId, productTitle, price, productType, status);
            
        } catch (Exception e) {
            System.debug('Error procesando webhook de producto: ' + e.getMessage());
        }
    }
    
    // Método para procesar webhooks de clientes
    public static void handleCustomerWebhook(String webhookData) {
        try {
            // Parsear el JSON del webhook
            Map<String, Object> customerData = (Map<String, Object>) JSON.deserializeUntyped(webhookData);
            
            // Extraer información del cliente
            String shopifyCustomerId = String.valueOf(customerData.get('id'));
            String firstName = String.valueOf(customerData.get('first_name'));
            String lastName = String.valueOf(customerData.get('last_name'));
            String email = String.valueOf(customerData.get('email'));
            String phone = String.valueOf(customerData.get('phone'));
            
            // Crear o actualizar el cliente en Salesforce
            upsertCustomer(shopifyCustomerId, firstName, lastName, email, phone);
            
        } catch (Exception e) {
            System.debug('Error procesando webhook de cliente: ' + e.getMessage());
        }
    }
    
    // Método privado para upsert de órdenes
    private static void upsertOrder(String shopifyOrderId, String orderNumber, String totalPrice, String orderStatus, String customerEmail) {
        try {
            ShopifyOrder__c order = new ShopifyOrder__c(
                ShopifyOrderId__c = shopifyOrderId,
                OrderNumber__c = orderNumber,
                TotalPrice__c = totalPrice != null ? Decimal.valueOf(totalPrice) : 0,
                OrderStatus__c = mapOrderStatus(orderStatus),
                CustomerEmail__c = customerEmail,
                CreatedAt__c = System.now()
            );
            
            upsert order ShopifyOrderId__c;
            System.debug('Orden procesada exitosamente: ' + shopifyOrderId);
            
        } catch (Exception e) {
            System.debug('Error upsertando orden: ' + e.getMessage());
        }
    }
    
    // Método privado para upsert de productos
    private static void upsertProduct(String shopifyProductId, String productTitle, String price, String productType, String status) {
        try {
            ShopifyProduct__c product = new ShopifyProduct__c(
                ShopifyProductId__c = shopifyProductId,
                ProductTitle__c = productTitle,
                Price__c = price != null ? Decimal.valueOf(price) : 0,
                ProductType__c = productType,
                Status__c = mapProductStatus(status)
            );
            
            upsert product ShopifyProductId__c;
            System.debug('Producto procesado exitosamente: ' + shopifyProductId);
            
        } catch (Exception e) {
            System.debug('Error upsertando producto: ' + e.getMessage());
        }
    }
    
    // Método privado para upsert de clientes
    private static void upsertCustomer(String shopifyCustomerId, String firstName, String lastName, String email, String phone) {
        try {
            ShopifyCustomer__c customer = new ShopifyCustomer__c(
                ShopifyCustomerId__c = shopifyCustomerId,
                FirstName__c = firstName,
                LastName__c = lastName,
                Email__c = email,
                Phone__c = phone
            );
            
            upsert customer ShopifyCustomerId__c;
            System.debug('Cliente procesado exitosamente: ' + shopifyCustomerId);
            
        } catch (Exception e) {
            System.debug('Error upsertando cliente: ' + e.getMessage());
        }
    }
    
    // Método para mapear estados de orden
    private static String mapOrderStatus(String shopifyStatus) {
        if (shopifyStatus == 'paid') return 'closed';
        if (shopifyStatus == 'pending') return 'pending';
        if (shopifyStatus == 'refunded') return 'cancelled';
        return 'open';
    }
    
    // Método para mapear estados de producto
    private static String mapProductStatus(String shopifyStatus) {
        if (shopifyStatus == 'active') return 'active';
        if (shopifyStatus == 'archived') return 'archived';
        return 'draft';
    }
}
