/**
 * @description Mapper para convertir datos de Shopify a objetos nativos de Salesforce
 * @author Sistema de Integración Shopify
 * @date 2025-01-27
 */
public with sharing class ShopifyToCoreMapper {
    
    /**
     * @description Mapea un cliente de Shopify a Account (Business Account)
     * @param node Datos del cliente desde GraphQL
     * @return Account configurado
     */
    public static Account mapCustomerToAccount(Map<String, Object> node) {
        System.debug('🔄 Mapeando cliente a Account: ' + node);
        
        Account acc = new Account();
        
        // Extraer ID de Shopify (formato: gid://shopify/Customer/123456)
        String shopifyId = String.valueOf(node.get('id'));
        if (shopifyId.startsWith('gid://shopify/Customer/')) {
            acc.ShopifyCustomerId__c = shopifyId.replace('gid://shopify/Customer/', '');
        } else {
            acc.ShopifyCustomerId__c = shopifyId;
        }
        
        // Configurar nombre de la cuenta con manejo de valores null
        String firstName = (String)node.get('firstName');
        String lastName = (String)node.get('lastName');
        
        if (firstName == null) firstName = '';
        if (lastName == null) lastName = '';
        
        String fullName = (firstName + ' ' + lastName).trim();
        if (String.isBlank(fullName)) {
            fullName = 'Cliente Shopify ' + acc.ShopifyCustomerId__c;
        }
        acc.Name = fullName;
        
        // Configurar tipo de cuenta
        acc.Type = 'Customer';
        
        System.debug('✅ Account mapeado: ' + acc.Name + ' (' + acc.ShopifyCustomerId__c + ')');
        System.debug('   - firstName: ' + firstName);
        System.debug('   - lastName: ' + lastName);
        return acc;
    }
    
    /**
     * @description Mapea un cliente de Shopify a Contact
     * @param node Datos del cliente desde GraphQL
     * @param accountId ID del Account relacionado
     * @return Contact configurado
     */
    public static Contact mapCustomerToContact(Map<String, Object> node, Id accountId) {
        System.debug('🔄 Mapeando cliente a Contact: ' + node);
        
        Contact con = new Contact();
        
        // Extraer ID de Shopify
        String shopifyId = String.valueOf(node.get('id'));
        if (shopifyId.startsWith('gid://shopify/Customer/')) {
            con.ShopifyCustomerId__c = shopifyId.replace('gid://shopify/Customer/', '');
        } else {
            con.ShopifyCustomerId__c = shopifyId;
        }
        
        // Relacionar con Account
        con.AccountId = accountId;
        
        // Mapear datos personales con manejo de valores null
        String firstName = (String)node.get('firstName');
        String lastName = (String)node.get('lastName');
        String email = (String)node.get('email');
        String phone = (String)node.get('phone');
        
        con.FirstName = firstName != null ? firstName : '';
        con.LastName = lastName != null ? lastName : '';
        con.Email = email != null ? email : '';
        con.Phone = phone != null ? phone : '';
        
        // Si no hay nombre, usar un nombre por defecto
        if (String.isBlank(con.FirstName) && String.isBlank(con.LastName)) {
            con.FirstName = 'Cliente';
            con.LastName = 'Shopify';
        }
        
        System.debug('✅ Contact mapeado: ' + con.FirstName + ' ' + con.LastName + ' (' + con.ShopifyCustomerId__c + ')');
        System.debug('   - Email: ' + con.Email);
        System.debug('   - Phone: ' + con.Phone);
        return con;
    }
    
    /**
     * @description Mapea un producto de Shopify a Product2
     * @param node Datos del producto desde GraphQL
     * @return Product2 configurado
     */
    public static Product2 mapProductToProduct2(Map<String, Object> node) {
        System.debug('🔄 Mapeando producto a Product2: ' + node);
        
        Product2 product = new Product2();
        
        // Extraer ID de Shopify
        String shopifyId = String.valueOf(node.get('id'));
        if (shopifyId.startsWith('gid://shopify/Product/')) {
            product.ShopifyProductId__c = shopifyId.replace('gid://shopify/Product/', '');
        } else {
            product.ShopifyProductId__c = shopifyId;
        }
        
        // Mapear datos del producto
        product.Name = (String)node.get('title');
        product.ProductCode = (String)node.get('handle');
        product.Description = (String)node.get('description');
        
        // Mapear categoría (Family) - usar productType o primera tag
        String productType = (String)node.get('productType');
        List<Object> tags = (List<Object>)node.get('tags');
        
        if (String.isNotBlank(productType)) {
            product.Family = productType;
        } else if (tags != null && !tags.isEmpty()) {
            // Usar la primera tag como categoría si no hay productType
            product.Family = (String)tags[0];
        } else {
            product.Family = 'General'; // Categoría por defecto
        }
        
        // Configurar estado activo
        String status = (String)node.get('status');
        product.IsActive = 'ACTIVE'.equalsIgnoreCase(status);
        
        System.debug('✅ Product2 mapeado: ' + product.Name + ' (' + product.ShopifyProductId__c + ')');
        return product;
    }
    
    /**
     * @description Mapea una orden de Shopify a Order
     * @param node Datos de la orden desde GraphQL
     * @param accountByEmail Map de cuentas por email para relacionar
     * @return Order configurado
     */
    public static Order mapOrderToOrder(Map<String, Object> node, Map<String, Account> accountByEmail) {
        System.debug('🔄 Mapeando orden a Order: ' + node);
        
        Order order = new Order();
        
        // Extraer ID de Shopify (API REST usa ID numérico)
        Object idObj = node.get('id');
        if (idObj != null) {
            order.ShopifyOrderId__c = String.valueOf(idObj);
        }
        
        // Mapear datos de la orden
        order.ShopifyOrderNumber__c = String.valueOf(node.get('name'));
        
        // Mapear fecha de procesamiento (fecha real de la orden)
        String processedAt = (String)node.get('processed_at');
        if (processedAt != null) {
            try {
                // Manejar formato ISO 8601 con zona horaria
                if (processedAt.contains('T')) {
                    // Formato: 2025-08-27T16:53:15-05:00
                    // Remover la zona horaria usando regex
                    String cleanDate = processedAt.replaceAll('T(\\d{2}:\\d{2}:\\d{2})[-+]\\d{2}:\\d{2}$', 'T$1');
                    order.EffectiveDate = Datetime.valueOfGmt(cleanDate).date();
                    System.debug('📅 Fecha procesada: ' + processedAt + ' -> ' + order.EffectiveDate);
                } else {
                    order.EffectiveDate = Date.today();
                }
            } catch (Exception e) {
                System.debug('⚠️ Error parseando fecha: ' + processedAt + ' - ' + e.getMessage());
                // Fallback: usar solo la parte de fecha
                try {
                    String dateOnly = processedAt.substring(0, 10);
                    order.EffectiveDate = Date.valueOf(dateOnly);
                    System.debug('📅 Fecha fallback: ' + dateOnly + ' -> ' + order.EffectiveDate);
                } catch (Exception e2) {
                    System.debug('⚠️ Error en fallback de fecha: ' + e2.getMessage());
                    order.EffectiveDate = Date.today();
                }
            }
        } else {
            order.EffectiveDate = Date.today();
        }
        
        // Mapear estado financiero
        String financialStatus = (String)node.get('financial_status');
        order.put('ShopifyFinancialStatus__c', financialStatus); // Almacenar estado de Shopify
        
        // Siempre crear como Draft inicialmente (Salesforce no permite crear directamente como Activated)
        order.Status = 'Draft';
        
        // Asignar Standard Price Book
        try {
            Pricebook2 standardPricebook = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1];
            if (standardPricebook != null) {
                order.Pricebook2Id = standardPricebook.Id;
                System.debug('💰 Pricebook2 asignado: ' + standardPricebook.Id);
            }
        } catch (Exception e) {
            System.debug('⚠️ Error obteniendo Standard Pricebook: ' + e.getMessage());
        }
        
        System.debug('📋 Estado inicial: Draft (estado Shopify: ' + financialStatus + ')');
        
        // Mapear precio total
        try {
            Object totalPrice = node.get('current_total_price');
            if (totalPrice != null) {
                Decimal totalAmount = 0;
                if (totalPrice instanceof String) {
                    totalAmount = Decimal.valueOf((String)totalPrice);
                } else if (totalPrice instanceof Decimal) {
                    totalAmount = (Decimal)totalPrice;
                }
                
                // Mapear a campo personalizado
                order.put('ShopifyTotalAmount__c', totalAmount);
                System.debug('💰 Total mapeado: ' + totalAmount);
            } else {
                System.debug('⚠️ No se encontró current_total_price, usando total_price');
                Object fallbackPrice = node.get('total_price');
                if (fallbackPrice != null) {
                    Decimal totalAmount = 0;
                    if (fallbackPrice instanceof String) {
                        totalAmount = Decimal.valueOf((String)fallbackPrice);
                    } else if (fallbackPrice instanceof Decimal) {
                        totalAmount = (Decimal)fallbackPrice;
                    }
                    order.put('ShopifyTotalAmount__c', totalAmount);
                }
            }
        } catch (Exception e) {
            System.debug('⚠️ Error mapeando precio total: ' + e.getMessage());
            order.put('ShopifyTotalAmount__c', 0);
        }
        
        // Relacionar con Account por email
        String email = (String)node.get('email');
        if (email != null && accountByEmail.containsKey(email)) {
            order.AccountId = accountByEmail.get(email).Id;
            System.debug('✅ Orden relacionada con Account: ' + email);
        } else {
            System.debug('⚠️ No se encontró Account para email: ' + email);
        }
        
        System.debug('✅ Order mapeado: ' + order.ShopifyOrderNumber__c + ' (' + order.ShopifyOrderId__c + ')');
        return order;
    }
    
    /**
     * @description Crea PricebookEntry para un Product2
     * @param productId ID del Product2
     * @param unitPrice Precio unitario
     * @param pricebookId ID del Pricebook (opcional, usa Standard si es null)
     * @return PricebookEntry configurado
     */
    public static PricebookEntry createPricebookEntry(Id productId, Decimal unitPrice, Id pricebookId) {
        if (pricebookId == null) {
            pricebookId = getStandardPricebookId();
        }
        
        PricebookEntry pbe = new PricebookEntry();
        pbe.Pricebook2Id = pricebookId;
        pbe.Product2Id = productId;
        pbe.UnitPrice = unitPrice != null ? unitPrice : 0;
        pbe.IsActive = true;
        pbe.UseStandardPrice = false;
        
        System.debug('✅ PricebookEntry creado: Product2=' + productId + ', Price=' + unitPrice);
        return pbe;
    }
    
    /**
     * @description Obtiene el RecordTypeId de Business Account
     * @return Id del RecordType de Business Account
     */
    private static Id getBusinessAccountRecordTypeId() {
        try {
            RecordType businessAccountRT = [
                SELECT Id 
                FROM RecordType 
                WHERE SObjectType = 'Account' 
                AND Name = 'Business Account'
                LIMIT 1
            ];
            return businessAccountRT.Id;
        } catch (Exception e) {
            System.debug('❌ Error obteniendo Business Account RecordType: ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * @description Obtiene el ID del Standard Pricebook
     * @return Id del Standard Pricebook
     */
    private static Id getStandardPricebookId() {
        try {
            Pricebook2 standardPB = [
                SELECT Id 
                FROM Pricebook2 
                WHERE IsStandard = true 
                LIMIT 1
            ];
            return standardPB.Id;
        } catch (Exception e) {
            System.debug('❌ Error obteniendo Standard Pricebook: ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * @description Mapea el estado financiero de Shopify al estado de Order
     * @param shopifyStatus Estado financiero de Shopify
     * @return Estado de Order de Salesforce
     */
    private static String mapShopifyStatusToOrderStatus(String shopifyStatus) {
        if (shopifyStatus == null) return 'Draft';
        
        switch on shopifyStatus.toUpperCase() {
            when 'PENDING' {
                return 'Draft';
            }
            when 'AUTHORIZED', 'PARTIALLY_PAID' {
                return 'Activated';
            }
            when 'PAID' {
                return 'Activated';
            }
            when 'PARTIALLY_REFUNDED', 'REFUNDED' {
                return 'Activated';
            }
            when 'VOIDED' {
                return 'Cancelled';
            }
            when else {
                return 'Draft';
            }
        }
    }
    
    /**
     * @description Extrae el precio de la primera variante de un producto
     * @param node Datos del producto desde GraphQL
     * @return Precio de la primera variante o 0 si no existe
     */
    public static Decimal extractFirstVariantPrice(Map<String, Object> node) {
        try {
            Map<String, Object> variants = (Map<String, Object>)node.get('variants');
            if (variants == null) return 0;
            
            List<Object> edges = (List<Object>)variants.get('edges');
            if (edges == null || edges.isEmpty()) return 0;
            
            Map<String, Object> firstEdge = (Map<String, Object>)edges[0];
            Map<String, Object> firstVariant = (Map<String, Object>)firstEdge.get('node');
            
            if (firstVariant == null) return 0;
            
            Object price = firstVariant.get('price');
            if (price == null) return 0;
            
            // El precio puede venir como String o Decimal
            if (price instanceof String) {
                return Decimal.valueOf((String)price);
            } else if (price instanceof Decimal) {
                return (Decimal)price;
            } else {
                return 0;
            }
            
        } catch (Exception e) {
            System.debug('⚠️ Error extrayendo precio de variante: ' + e.getMessage());
            return 0;
        }
    }
    
    /**
     * @description Mapea un lineItem de Shopify a OrderItem de Salesforce
     * @param lineItem Datos del lineItem desde GraphQL
     * @param orderId ID de la orden de Salesforce
     * @param productsByShopifyId Map de productos por Shopify ID
     * @param pricebookEntries Map de PricebookEntries por Product2Id
     * @return OrderItem configurado o null si no se encuentra el producto
     */
    public static OrderItem mapLineItemToOrderItem(Map<String, Object> lineItem, Id orderId, Map<String, Product2> productsByShopifyId, Map<Id, PricebookEntry> pricebookEntries) {
        try {
            System.debug('🔄 Mapeando lineItem a OrderItem: ' + lineItem);
            
            // Extraer ID del producto (API REST tiene product_id directamente)
            Object productIdObj = lineItem.get('product_id');
            if (productIdObj == null) {
                System.debug('⚠️ No hay product_id en lineItem');
                return null;
            }
            
            String productShopifyId = String.valueOf(productIdObj);
            
            // Buscar producto en Salesforce
            Product2 salesforceProduct = productsByShopifyId.get(productShopifyId);
            if (salesforceProduct == null) {
                System.debug('⚠️ Producto no encontrado en Salesforce: ' + productShopifyId);
                return null;
            }
            
            // Crear OrderItem
            OrderItem orderItem = new OrderItem();
            orderItem.OrderId = orderId;
            orderItem.Product2Id = salesforceProduct.Id;
            
            // Obtener PricebookEntryId
            PricebookEntry pricebookEntry = pricebookEntries.get(salesforceProduct.Id);
            if (pricebookEntry != null) {
                orderItem.PricebookEntryId = pricebookEntry.Id;
                System.debug('💰 PricebookEntry encontrado: ' + pricebookEntry.Id);
            } else {
                System.debug('⚠️ No se encontró PricebookEntry para producto: ' + salesforceProduct.Name);
                return null; // No se puede crear OrderItem sin PricebookEntry
            }
            
            // Mapear cantidad
            Object quantity = lineItem.get('quantity');
            if (quantity != null) {
                if (quantity instanceof String) {
                    orderItem.Quantity = Decimal.valueOf((String)quantity);
                } else if (quantity instanceof Decimal) {
                    orderItem.Quantity = (Decimal)quantity;
                } else if (quantity instanceof Integer) {
                    orderItem.Quantity = Decimal.valueOf((Integer)quantity);
                }
            } else {
                orderItem.Quantity = 1; // Cantidad por defecto
            }
            
            // Mapear precio unitario (API REST tiene price directamente)
            try {
                Object price = lineItem.get('price');
                if (price != null) {
                    if (price instanceof String) {
                        orderItem.UnitPrice = Decimal.valueOf((String)price);
                    } else if (price instanceof Decimal) {
                        orderItem.UnitPrice = (Decimal)price;
                    }
                } else {
                    orderItem.UnitPrice = 0;
                }
            } catch (Exception e) {
                System.debug('⚠️ Error mapeando precio unitario: ' + e.getMessage());
                orderItem.UnitPrice = 0;
            }
            
            // Configurar campos requeridos
            orderItem.ServiceDate = Date.today();
            
            System.debug('✅ OrderItem mapeado: Producto=' + salesforceProduct.Name + ', Cantidad=' + orderItem.Quantity + ', Precio=' + orderItem.UnitPrice);
            return orderItem;
            
        } catch (Exception e) {
            System.debug('❌ ERROR mapeando lineItem: ' + e.getMessage());
            System.debug('❌ Stack trace: ' + e.getStackTraceString());
            return null;
        }
    }
}
