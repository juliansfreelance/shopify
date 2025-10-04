@RestResource(urlMapping='/shopify/webhook/*')
global with sharing class ShopifyWebhookReceiver {
    
    @HttpPost
    global static void receiveWebhook() {
        try {
            // Obtener el cuerpo de la petición
            String webhookData = RestContext.request.requestBody.toString();
            
            // Obtener el tipo de webhook del header
            String webhookTopic = RestContext.request.headers.get('X-Shopify-Topic');
            String shopDomain = RestContext.request.headers.get('X-Shopify-Shop-Domain');
            
            System.debug('Webhook recibido de: ' + shopDomain);
            System.debug('Tipo de webhook: ' + webhookTopic);
            System.debug('Datos del webhook: ' + webhookData);
            
            // Procesar el webhook según el tipo
            if (webhookTopic != null) {
                if (webhookTopic.contains('orders')) {
                    ShopifyWebhookHandler.handleOrderWebhook(webhookData);
                } else if (webhookTopic.contains('products')) {
                    ShopifyWebhookHandler.handleProductWebhook(webhookData);
                } else if (webhookTopic.contains('customers')) {
                    ShopifyWebhookHandler.handleCustomerWebhook(webhookData);
                }
            }
            
            // Responder con éxito
            RestContext.response.statusCode = 200;
            RestContext.response.responseBody = Blob.valueOf('Webhook procesado exitosamente');
            
        } catch (Exception e) {
            System.debug('Error procesando webhook: ' + e.getMessage());
            
            // Responder con error
            RestContext.response.statusCode = 500;
            RestContext.response.responseBody = Blob.valueOf('Error procesando webhook: ' + e.getMessage());
        }
    }
    
    @HttpGet
    global static void verifyWebhook() {
        // Método para verificar la configuración del webhook
        RestContext.response.statusCode = 200;
        RestContext.response.responseBody = Blob.valueOf('Webhook endpoint activo');
    }
}
