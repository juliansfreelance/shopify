/**
 * @description Servicios de sincronización de Shopify con objetos nativos de Salesforce
 * @author Sistema de Integración Shopify
 * @date 2025-01-27
 */
public with sharing class ShopifySyncService {
    
    /**
     * @description Sincroniza clientes de Shopify a Account + Contact
     * @param customerNodes Lista de nodos de clientes desde GraphQL
     */
    public static void syncCustomers(List<Map<String, Object>> customerNodes) {
        try {
            System.debug('🔄 SINCRONIZANDO CLIENTES A ACCOUNT + CONTACT');
            System.debug('📊 Total de clientes a procesar: ' + customerNodes.size());
            
            List<Account> accountsToUpsert = new List<Account>();
            List<Contact> contactsToUpsert = new List<Contact>();
            
            for (Map<String, Object> node : customerNodes) {
                try {
                    // Crear Account
                    Account acc = ShopifyToCoreMapper.mapCustomerToAccount(node);
                    accountsToUpsert.add(acc);
                } catch (Exception e) {
                    System.debug('❌ Error mapeando cliente: ' + e.getMessage());
                    System.debug('❌ Nodo problemático: ' + node);
                }
            }
            
            if (!accountsToUpsert.isEmpty()) {
                System.debug('💾 Upsertando ' + accountsToUpsert.size() + ' Accounts');
                upsert accountsToUpsert Account.ShopifyCustomerId__c;
                System.debug('✅ Accounts sincronizados exitosamente');
                
                // Crear Contacts después de que los Accounts estén creados
                Map<String, Id> accountIdsByShopifyId = new Map<String, Id>();
                for (Account acc : accountsToUpsert) {
                    accountIdsByShopifyId.put(acc.ShopifyCustomerId__c, acc.Id);
                }
                
                for (Map<String, Object> node : customerNodes) {
                    try {
                        String shopifyId = extractShopifyCustomerId(node);
                        if (accountIdsByShopifyId.containsKey(shopifyId)) {
                            Contact con = ShopifyToCoreMapper.mapCustomerToContact(node, accountIdsByShopifyId.get(shopifyId));
                            contactsToUpsert.add(con);
                        }
                    } catch (Exception e) {
                        System.debug('❌ Error mapeando contact: ' + e.getMessage());
                    }
                }
                
                if (!contactsToUpsert.isEmpty()) {
                    System.debug('💾 Upsertando ' + contactsToUpsert.size() + ' Contacts');
                    upsert contactsToUpsert Contact.ShopifyCustomerId__c;
                    System.debug('✅ Contacts sincronizados exitosamente');
                }
            } else {
                System.debug('⚠️ No hay cuentas para sincronizar');
            }
            
        } catch (Exception e) {
            System.debug('❌ ERROR sincronizando clientes: ' + e.getMessage());
            System.debug('❌ Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error sincronizando clientes: ' + e.getMessage());
        }
    }
    
    /**
     * @description Sincroniza productos de Shopify a Product2 y PricebookEntry
     * @param productNodes Lista de nodos de productos desde GraphQL
     */
    public static void syncProducts(List<Map<String, Object>> productNodes, String shopCurrency) {
        try {
            System.debug('🔄 SINCRONIZANDO PRODUCTOS A PRODUCT2');
            System.debug('📊 Total de productos a procesar: ' + productNodes.size());
            
            List<Product2> productsToUpsert = new List<Product2>();
            
            for (Map<String, Object> node : productNodes) {
                try {
                    Product2 product = ShopifyToCoreMapper.mapProductToProduct2(node);
                    productsToUpsert.add(product);
                } catch (Exception e) {
                    System.debug('❌ Error mapeando producto: ' + e.getMessage());
                    System.debug('❌ Nodo problemático: ' + node);
                }
            }
            
            if (!productsToUpsert.isEmpty()) {
                System.debug('💾 Upsertando ' + productsToUpsert.size() + ' Product2');
                upsert productsToUpsert Product2.ShopifyProductId__c;
                System.debug('✅ Product2 sincronizados exitosamente');
                
                    // Crear PricebookEntries
                    createPricebookEntries(productsToUpsert, productNodes, shopCurrency);
            } else {
                System.debug('⚠️ No hay productos para sincronizar');
            }
            
        } catch (Exception e) {
            System.debug('❌ ERROR sincronizando productos: ' + e.getMessage());
            System.debug('❌ Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error sincronizando productos: ' + e.getMessage());
        }
    }
    
    /**
     * @description Sincroniza órdenes de Shopify a Order
     * @param orderNodes Lista de nodos de órdenes desde GraphQL
     */
    public static void syncOrders(List<Map<String, Object>> orderNodes) {
        try {
            System.debug('🔄 SINCRONIZANDO ÓRDENES A ORDER');
            System.debug('📊 Total de órdenes a procesar: ' + orderNodes.size());
            
            // Pre-resolver cuentas por email
            Map<String, Account> accountByEmail = getAccountsByEmail();
            System.debug('📧 Cuentas encontradas por email: ' + accountByEmail.size());
            
            List<Order> ordersToUpsert = new List<Order>();
            
            for (Map<String, Object> node : orderNodes) {
                try {
                    Order order = ShopifyToCoreMapper.mapOrderToOrder(node, accountByEmail);
                    ordersToUpsert.add(order);
                } catch (Exception e) {
                    System.debug('❌ Error mapeando orden: ' + e.getMessage());
                    System.debug('❌ Nodo problemático: ' + node);
                }
            }
            
            if (!ordersToUpsert.isEmpty()) {
                System.debug('💾 Upsertando ' + ordersToUpsert.size() + ' Orders');
                upsert ordersToUpsert Order.ShopifyOrderId__c;
                System.debug('✅ Orders sincronizados exitosamente');
                
                // Crear OrderItems para cada orden
                System.debug('🔄 CREANDO ORDERITEMS');
                createOrderItems(orderNodes, ordersToUpsert);
                
                // Activar órdenes que deberían estar activadas
                System.debug('🔄 ACTIVANDO ÓRDENES PAGADAS');
                activatePaidOrders(ordersToUpsert, orderNodes);
            } else {
                System.debug('⚠️ No hay órdenes para sincronizar');
            }
            
        } catch (Exception e) {
            System.debug('❌ ERROR sincronizando órdenes: ' + e.getMessage());
            System.debug('❌ Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error sincronizando órdenes: ' + e.getMessage());
        }
    }
    
    /**
     * @description Crea PricebookEntries para los productos sincronizados
     * @param products Lista de Product2 sincronizados
     * @param productNodes Nodos originales para extraer precios
     */
    private static void createPricebookEntries(List<Product2> products, List<Map<String, Object>> productNodes, String shopCurrency) {
        try {
            System.debug('🔄 CREANDO PRICEBOOK ENTRIES');
            
            // Crear mapa de productos por Shopify ID
            Map<String, Product2> productsByShopifyId = new Map<String, Product2>();
            for (Product2 p : products) {
                productsByShopifyId.put(p.ShopifyProductId__c, p);
            }
            
            // Crear mapa de precios por Shopify ID
            Map<String, Decimal> pricesByShopifyId = new Map<String, Decimal>();
            for (Map<String, Object> node : productNodes) {
                try {
                    String shopifyId = extractShopifyId(node);
                    System.debug('🔍 Procesando producto Shopify ID: ' + shopifyId);
                    System.debug('🔍 Nodo completo: ' + JSON.serialize(node));
                    
                    Decimal price = ShopifyToCoreMapper.extractFirstVariantPrice(node);
                    System.debug('💰 Precio extraído: ' + price);
                    
                    if (shopifyId != null && price != null && price > 0) {
                        pricesByShopifyId.put(shopifyId, price);
                        System.debug('✅ Precio agregado para ' + shopifyId + ': ' + price);
                    } else {
                        System.debug('⚠️ Precio no válido para ' + shopifyId + ': ' + price);
                    }
                } catch (Exception e) {
                    System.debug('⚠️ Error extrayendo precio: ' + e.getMessage());
                    System.debug('⚠️ Stack trace: ' + e.getStackTraceString());
                }
            }
            
            System.debug('📊 Total de precios extraídos: ' + pricesByShopifyId.size());
            
            // Crear PricebookEntries
            List<PricebookEntry> pbesToInsert = new List<PricebookEntry>();
            Id standardPricebookId = getStandardPricebookId();
            
            for (Product2 product : products) {
                if (pricesByShopifyId.containsKey(product.ShopifyProductId__c)) {
                    Decimal price = pricesByShopifyId.get(product.ShopifyProductId__c);
                    System.debug('💾 Creando PricebookEntry para ' + product.Name + ' con precio: ' + price);
                    
                    PricebookEntry pbe = ShopifyToCoreMapper.createPricebookEntry(
                        product.Id, 
                        price, 
                        standardPricebookId
                    );
                    pbesToInsert.add(pbe);
                } else {
                    System.debug('⚠️ No se encontró precio para producto: ' + product.Name + ' (ID: ' + product.ShopifyProductId__c + ')');
                }
            }
            
            if (!pbesToInsert.isEmpty()) {
                System.debug('💾 Insertando ' + pbesToInsert.size() + ' PricebookEntries');
                insert pbesToInsert;
                System.debug('✅ PricebookEntries creados exitosamente');
            }
            
        } catch (Exception e) {
            System.debug('❌ ERROR creando PricebookEntries: ' + e.getMessage());
            // No lanzar excepción para no interrumpir la sincronización de productos
        }
    }
    
    /**
     * @description Obtiene cuentas por email para relacionar órdenes
     * @return Map de cuentas por email
     */
    private static Map<String, Account> getAccountsByEmail() {
        try {
            System.debug('🔄 Obteniendo cuentas por email...');
            
            List<Contact> contacts = [
                SELECT Id, Email, AccountId, Account.Name
                FROM Contact 
                WHERE Email != null
                LIMIT 1000
            ];
            
            System.debug('📧 Contactos encontrados: ' + contacts.size());
            
            Map<String, Account> accountByEmail = new Map<String, Account>();
            for (Contact con : contacts) {
                if (con.Email != null && con.AccountId != null) {
                    Account acc = new Account();
                    acc.Id = con.AccountId;
                    acc.Name = con.Account.Name;
                    accountByEmail.put(con.Email, acc);
                }
            }
            
            System.debug('📧 Cuentas mapeadas por email: ' + accountByEmail.size());
            return accountByEmail;
        } catch (Exception e) {
            System.debug('❌ ERROR obteniendo cuentas por email: ' + e.getMessage());
            System.debug('❌ Stack trace: ' + e.getStackTraceString());
            return new Map<String, Account>();
        }
    }
    
    /**
     * @description Extrae el ID de Shopify de un nodo de producto
     * @param node Nodo de GraphQL
     * @return ID de Shopify sin prefijo
     */
    private static String extractShopifyId(Map<String, Object> node) {
        String shopifyId = String.valueOf(node.get('id'));
        if (shopifyId.startsWith('gid://shopify/Product/')) {
            return shopifyId.replace('gid://shopify/Product/', '');
        }
        return shopifyId;
    }
    
    /**
     * @description Extrae el ID de Shopify de un nodo de cliente
     * @param node Nodo de GraphQL
     * @return ID de Shopify sin prefijo
     */
    private static String extractShopifyCustomerId(Map<String, Object> node) {
        String shopifyId = String.valueOf(node.get('id'));
        if (shopifyId.startsWith('gid://shopify/Customer/')) {
            return shopifyId.replace('gid://shopify/Customer/', '');
        }
        return shopifyId;
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
            System.debug('❌ ERROR obteniendo Standard Pricebook: ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * @description Limpia TODOS los datos de Shopify de objetos nativos
     */
    public static void cleanTestData() {
        try {
            System.debug('🧹 INICIANDO LIMPIEZA DE DATOS DE SHOPIFY');
            
            // Eliminar TODAS las órdenes de Shopify
            List<Order> shopifyOrders = [
                SELECT Id FROM Order 
                WHERE ShopifyOrderId__c != null
            ];
            if (!shopifyOrders.isEmpty()) {
                System.debug('🗑️ Eliminando ' + shopifyOrders.size() + ' órdenes de Shopify');
                delete shopifyOrders;
            }
            
            // Eliminar TODOS los productos de Shopify
            List<Product2> shopifyProducts = [
                SELECT Id FROM Product2 
                WHERE ShopifyProductId__c != null
            ];
            if (!shopifyProducts.isEmpty()) {
                System.debug('🗑️ Eliminando ' + shopifyProducts.size() + ' productos de Shopify');
                
                // Primero eliminar PricebookEntries asociados
                List<Id> productIds = new List<Id>();
                for(Product2 p : shopifyProducts) {
                    productIds.add(p.Id);
                }
                
                if(!productIds.isEmpty()) {
                    List<PricebookEntry> pbesToDelete = [
                        SELECT Id FROM PricebookEntry 
                        WHERE Product2Id IN :productIds 
                        AND Pricebook2.IsStandard = true
                    ];
                    if(!pbesToDelete.isEmpty()) {
                        System.debug('🗑️ Eliminando ' + pbesToDelete.size() + ' PricebookEntries asociados');
                        delete pbesToDelete;
                    }
                }
                
                delete shopifyProducts;
            }
            
            // Eliminar TODAS las cuentas de Shopify
            List<Account> shopifyAccounts = [
                SELECT Id FROM Account 
                WHERE ShopifyCustomerId__c != null
            ];
            if (!shopifyAccounts.isEmpty()) {
                System.debug('🗑️ Eliminando ' + shopifyAccounts.size() + ' cuentas de Shopify');
                delete shopifyAccounts;
            }
            
            // Eliminar TODOS los contactos de Shopify
            List<Contact> shopifyContacts = [
                SELECT Id FROM Contact 
                WHERE ShopifyCustomerId__c != null
            ];
            if (!shopifyContacts.isEmpty()) {
                System.debug('🗑️ Eliminando ' + shopifyContacts.size() + ' contactos de Shopify');
                delete shopifyContacts;
            }
            
            System.debug('✅ LIMPIEZA DE DATOS DE SHOPIFY COMPLETADA');
            
        } catch (Exception e) {
            System.debug('❌ ERROR en limpieza: ' + e.getMessage());
            throw new AuraHandledException('Error al limpiar datos de Shopify: ' + e.getMessage());
        }
    }
    
    /**
     * @description Crea OrderItems para las órdenes sincronizadas
     * @param orderNodes Nodos de órdenes desde GraphQL
     * @param orders Lista de órdenes creadas en Salesforce
     */
    private static void createOrderItems(List<Map<String, Object>> orderNodes, List<Order> orders) {
        try {
            System.debug('🔄 CREANDO ORDERITEMS PARA ÓRDENES');
            
            // Crear mapa de órdenes por Shopify ID
            Map<String, Order> ordersByShopifyId = new Map<String, Order>();
            for (Order order : orders) {
                ordersByShopifyId.put(order.ShopifyOrderId__c, order);
            }
            
            // Obtener productos existentes por Shopify ID
            Map<String, Product2> productsByShopifyId = getProductsByShopifyId();
            System.debug('📦 Productos encontrados: ' + productsByShopifyId.size());
            
            // Obtener IDs de productos para buscar PricebookEntries
            List<Id> productIds = new List<Id>();
            for (Product2 product : productsByShopifyId.values()) {
                productIds.add(product.Id);
            }
            
            // Obtener PricebookEntries
            Map<Id, PricebookEntry> pricebookEntries = getPricebookEntries(productIds);
            
            List<OrderItem> orderItemsToInsert = new List<OrderItem>();
            
            for (Map<String, Object> orderNode : orderNodes) {
                try {
                    String orderShopifyId = extractOrderShopifyId(orderNode);
                    Order order = ordersByShopifyId.get(orderShopifyId);
                    
                    if (order == null) {
                        System.debug('⚠️ No se encontró orden para Shopify ID: ' + orderShopifyId);
                        continue;
                    }
                    
                    // Extraer lineItems de la orden (API REST tiene line_items directamente)
                    List<Object> lineItems = (List<Object>)orderNode.get('line_items');
                    if (lineItems == null || lineItems.isEmpty()) {
                        System.debug('⚠️ No hay line_items para orden: ' + orderShopifyId);
                        continue;
                    }
                    
                    System.debug('📦 Procesando ' + lineItems.size() + ' productos para orden: ' + orderShopifyId);
                    
                    for (Object lineItemObj : lineItems) {
                        try {
                            Map<String, Object> lineItem = (Map<String, Object>)lineItemObj;
                            
                            OrderItem orderItem = ShopifyToCoreMapper.mapLineItemToOrderItem(lineItem, order.Id, productsByShopifyId, pricebookEntries);
                            if (orderItem != null) {
                                orderItemsToInsert.add(orderItem);
                                System.debug('✅ OrderItem creado para producto: ' + orderItem.Product2Id);
                            }
                            
                        } catch (Exception e) {
                            System.debug('❌ Error procesando lineItem: ' + e.getMessage());
                        }
                    }
                    
                } catch (Exception e) {
                    System.debug('❌ Error procesando orden: ' + e.getMessage());
                }
            }
            
            if (!orderItemsToInsert.isEmpty()) {
                System.debug('💾 Insertando ' + orderItemsToInsert.size() + ' OrderItems');
                insert orderItemsToInsert;
                System.debug('✅ OrderItems creados exitosamente');
            } else {
                System.debug('⚠️ No hay OrderItems para crear');
            }
            
        } catch (Exception e) {
            System.debug('❌ ERROR creando OrderItems: ' + e.getMessage());
            System.debug('❌ Stack trace: ' + e.getStackTraceString());
            // No lanzar excepción para no interrumpir la sincronización
        }
    }
    
    /**
     * @description Obtiene productos por Shopify ID
     * @return Map de productos por Shopify ID
     */
    private static Map<String, Product2> getProductsByShopifyId() {
        try {
            List<Product2> products = [
                SELECT Id, Name, ShopifyProductId__c
                FROM Product2
                WHERE ShopifyProductId__c != null
                LIMIT 1000
            ];
            
            Map<String, Product2> productsByShopifyId = new Map<String, Product2>();
            for (Product2 product : products) {
                productsByShopifyId.put(product.ShopifyProductId__c, product);
            }
            
            return productsByShopifyId;
        } catch (Exception e) {
            System.debug('❌ ERROR obteniendo productos: ' + e.getMessage());
            return new Map<String, Product2>();
        }
    }
    
    /**
     * @description Obtiene PricebookEntry para productos
     * @param productIds Lista de IDs de productos
     * @return Map de Product2Id a PricebookEntry
     */
    private static Map<Id, PricebookEntry> getPricebookEntries(List<Id> productIds) {
        Map<Id, PricebookEntry> pricebookEntries = new Map<Id, PricebookEntry>();
        
        try {
            // Obtener el Standard Price Book
            Pricebook2 standardPricebook = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1];
            
            if (standardPricebook != null) {
                List<PricebookEntry> entries = [
                    SELECT Id, Product2Id, UnitPrice 
                    FROM PricebookEntry 
                    WHERE Product2Id IN :productIds 
                    AND Pricebook2Id = :standardPricebook.Id
                    LIMIT 1000
                ];
                
                for (PricebookEntry entry : entries) {
                    pricebookEntries.put(entry.Product2Id, entry);
                }
                
                System.debug('💰 PricebookEntries encontrados: ' + pricebookEntries.size());
            }
            
        } catch (Exception e) {
            System.debug('❌ Error obteniendo PricebookEntries: ' + e.getMessage());
        }
        
        return pricebookEntries;
    }
    
    /**
     * @description Extrae el ID de Shopify de un nodo de orden
     * @param node Nodo de GraphQL
     * @return ID de Shopify sin prefijo
     */
    private static String extractOrderShopifyId(Map<String, Object> node) {
        String shopifyId = String.valueOf(node.get('id'));
        if (shopifyId.startsWith('gid://shopify/Order/')) {
            return shopifyId.replace('gid://shopify/Order/', '');
        }
        return shopifyId;
    }
    
    /**
     * @description Activa las órdenes que están pagadas en Shopify
     * @param orders Lista de órdenes creadas
     * @param orderNodes Nodos de órdenes desde GraphQL
     */
    private static void activatePaidOrders(List<Order> orders, List<Map<String, Object>> orderNodes) {
        try {
            System.debug('🔄 ACTIVANDO ÓRDENES PAGADAS');
            
            // Crear mapa de órdenes por Shopify ID
            Map<String, Order> ordersByShopifyId = new Map<String, Order>();
            for (Order order : orders) {
                ordersByShopifyId.put(order.ShopifyOrderId__c, order);
            }
            
            List<Order> ordersToActivate = new List<Order>();
            
            for (Map<String, Object> orderNode : orderNodes) {
                try {
                    String orderShopifyId = extractOrderShopifyId(orderNode);
                    Order order = ordersByShopifyId.get(orderShopifyId);
                    
                    if (order == null) continue;
                    
                    String financialStatus = (String)orderNode.get('financial_status');
                    if ('paid'.equalsIgnoreCase(financialStatus) || 
                        'partially_paid'.equalsIgnoreCase(financialStatus) || 
                        'refunded'.equalsIgnoreCase(financialStatus)) {
                        
                        order.Status = 'Activated';
                        ordersToActivate.add(order);
                        System.debug('✅ Orden marcada para activar: ' + order.ShopifyOrderNumber__c + ' (estado: ' + financialStatus + ')');
                    }
                    
                } catch (Exception e) {
                    System.debug('❌ Error procesando orden para activación: ' + e.getMessage());
                }
            }
            
            if (!ordersToActivate.isEmpty()) {
                System.debug('💾 Activando ' + ordersToActivate.size() + ' órdenes');
                update ordersToActivate;
                System.debug('✅ Órdenes activadas exitosamente');
            } else {
                System.debug('⚠️ No hay órdenes para activar');
            }
            
        } catch (Exception e) {
            System.debug('❌ ERROR activando órdenes: ' + e.getMessage());
            System.debug('❌ Stack trace: ' + e.getStackTraceString());
            // No lanzar excepción para no interrumpir la sincronización
        }
    }
}
