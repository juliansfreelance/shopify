public with sharing class ShopifyDataController {

    // Métodos de consulta para LWC (Objetos Nativos)
    @AuraEnabled(cacheable=true)
    public static List<Order> getShopifyOrders() {
        try {
            return [
                SELECT Id, OrderNumber, Status, EffectiveDate, TotalAmount,
                       AccountId, Account.Name, ShopifyOrderId__c, ShopifyOrderNumber__c,
                       ShopifyTotalAmount__c, ShopifyFinancialStatus__c
                FROM Order
                WHERE ShopifyOrderId__c != null
                ORDER BY EffectiveDate DESC
                LIMIT 1000
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error al obtener órdenes: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Product2> getShopifyProducts() {
        try {
            List<Product2> products = [
                SELECT Id, Name, ProductCode, Family, IsActive, ShopifyProductId__c, Description,
                       (SELECT Id, UnitPrice FROM PricebookEntries WHERE Pricebook2.IsStandard = true LIMIT 1)
                FROM Product2
                WHERE ShopifyProductId__c != null
                ORDER BY Name ASC
                LIMIT 1000
            ];

            // Agregar precio a cada producto (usando variable temporal)
            for (Product2 product : products) {
                if (!product.PricebookEntries.isEmpty()) {
                    // El precio se obtiene desde PricebookEntry, no se asigna a Product2
                    System.debug('💰 Precio para ' + product.Name + ': ' + product.PricebookEntries[0].UnitPrice);
                }
            }

            return products;
        } catch (Exception e) {
            throw new AuraHandledException('Error al obtener productos: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Contact> getShopifyCustomers() {
        try {
            return [
                SELECT Id, FirstName, LastName, Email, Phone,
                       AccountId, Account.Name, ShopifyCustomerId__c
                FROM Contact
                WHERE ShopifyCustomerId__c != null
                ORDER BY FirstName ASC
                LIMIT 1000
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error al obtener clientes: ' + e.getMessage());
        }
    }

    // Métodos de sincronización principales
    @AuraEnabled
    public static void syncHistoricalDataFromShopify() {
        try {
            System.debug('🚀 INICIANDO SINCRONIZACIÓN HISTÓRICA DE SHOPIFY');
            
            // Configuración hardcodeada
            String shopDomain = 'michelltemp.myshopify.com';
            String apiVersion = '2025-07';
            
            System.debug('📋 Configuración:');
            System.debug('   - Shop Domain: ' + shopDomain);
            System.debug('   - API Version: ' + apiVersion);
            
            // Sincronizar productos
            System.debug('🔄 Sincronizando productos...');
            syncProductsOnly();
            
            // Sincronizar clientes
            System.debug('🔄 Sincronizando clientes...');
            syncCustomersOnly();
            
            // Sincronizar órdenes
            System.debug('🔄 Sincronizando órdenes...');
            syncOrdersOnly();
            
            System.debug('✅ SINCRONIZACIÓN HISTÓRICA COMPLETADA');
        } catch (Exception e) {
            System.debug('❌ ERROR en sincronización histórica: ' + e.getMessage());
            System.debug('❌ Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error en sincronización histórica: ' + e.getMessage());
        }
    }

    /**
     * @description Sincroniza solo productos de Shopify
     */
    @AuraEnabled
    public static void syncProductsOnly() {
        try {
            System.debug('🔄 SINCRONIZANDO SOLO PRODUCTOS - MÉTODO SIMPLIFICADO');
            
            // Obtener moneda de la tienda
            String shopCurrency = getShopCurrency();
            System.debug('💰 Moneda detectada: ' + shopCurrency);
            
            // Obtener productos usando query simple que funciona
            System.debug('📡 Obteniendo productos con query simple...');
            List<Map<String, Object>> productNodes = getProductsSimple();
            System.debug('📊 Productos obtenidos: ' + productNodes.size());
            
            // Obtener precios ANTES del upsert (para evitar el error de callout)
            System.debug('💰 Obteniendo precios reales de Shopify...');
            Map<String, Decimal> pricesByShopifyId = getRealPricesFromShopify();
            System.debug('💰 Precios obtenidos: ' + pricesByShopifyId.size());
            
            // Sincronizar productos básicos CON precios reales
            System.debug('🔄 Sincronizando productos básicos...');
            syncProductsBasicWithPrices(productNodes, shopCurrency, pricesByShopifyId);
            
            System.debug('✅ PRODUCTOS SINCRONIZADOS EXITOSAMENTE');
        } catch (Exception e) {
            System.debug('❌ ERROR sincronizando productos: ' + e.getMessage());
            System.debug('❌ Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error sincronizando productos: ' + e.getMessage());
        }
    }
    
    /**
     * @description Obtiene productos con query simple que funciona
     */
    private static List<Map<String, Object>> getProductsSimple() {
        try {
            System.debug('🔄 OBTENIENDO PRODUCTOS SIMPLES');
            
            String shopDomain = 'michelltemp.myshopify.com';
            String apiVersion = '2025-07';
            String endpoint = 'https://' + shopDomain + '/admin/api/' + apiVersion + '/graphql.json';
            
            // Query simple que sabemos que funciona
            String query = '{"query": "{ products(first: 10) { edges { node { id title handle productType status description tags } } } }"}';
            System.debug('📝 Query: ' + query);
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('X-Shopify-Access-Token', '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');
            req.setBody(query);
            req.setTimeout(120000);
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            System.debug('📊 Status: ' + res.getStatusCode());
            System.debug('📊 Body: ' + res.getBody());
            
            if (res.getStatusCode() == 200) {
                Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
                Map<String, Object> data = (Map<String, Object>)responseMap.get('data');
                Map<String, Object> products = (Map<String, Object>)data.get('products');
                List<Object> edges = (List<Object>)products.get('edges');
                
                List<Map<String, Object>> productNodes = new List<Map<String, Object>>();
                for (Object edgeObj : edges) {
                    Map<String, Object> edge = (Map<String, Object>)edgeObj;
                    Map<String, Object> node = (Map<String, Object>)edge.get('node');
                    if (node != null) {
                        productNodes.add(node);
                    }
                }
                
                System.debug('✅ Productos obtenidos: ' + productNodes.size());
                return productNodes;
            } else {
                throw new CalloutException('Error HTTP: ' + res.getStatusCode() + ' - ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug('❌ ERROR obteniendo productos simples: ' + e.getMessage());
            throw new AuraHandledException('Error obteniendo productos: ' + e.getMessage());
        }
    }
    
    /**
     * @description Sincroniza productos básicos CON Price Book Entries
     */
    private static void syncProductsBasic(List<Map<String, Object>> productNodes, String shopCurrency) {
        try {
            System.debug('🔄 SINCRONIZANDO PRODUCTOS BÁSICOS CON PRECIOS');
            
            List<Product2> productsToUpsert = new List<Product2>();
            
            for (Map<String, Object> node : productNodes) {
                try {
                    Product2 product = new Product2();
                    
                    // Extraer ID de Shopify
                    String shopifyId = String.valueOf(node.get('id'));
                    if (shopifyId.startsWith('gid://shopify/Product/')) {
                        product.ShopifyProductId__c = shopifyId.replace('gid://shopify/Product/', '');
                    } else {
                        product.ShopifyProductId__c = shopifyId;
                    }
                    
                    // Mapear datos básicos
                    product.Name = (String)node.get('title');
                    product.ProductCode = (String)node.get('handle');
                    product.Description = (String)node.get('description');
                    
                    // Mapear categoría
                    String productType = (String)node.get('productType');
                    List<Object> tags = (List<Object>)node.get('tags');
                    
                    if (String.isNotBlank(productType)) {
                        product.Family = productType;
                    } else if (tags != null && !tags.isEmpty()) {
                        product.Family = (String)tags[0];
                    } else {
                        product.Family = 'General';
                    }
                    
                    // Estado activo
                    String status = (String)node.get('status');
                    product.IsActive = 'ACTIVE'.equalsIgnoreCase(status);
                    
                    productsToUpsert.add(product);
                    System.debug('📦 Producto mapeado: ' + product.Name + ' (' + product.ShopifyProductId__c + ')');
                    
                } catch (Exception e) {
                    System.debug('❌ Error mapeando producto: ' + e.getMessage());
                }
            }
            
            if (!productsToUpsert.isEmpty()) {
                System.debug('💾 Upsertando ' + productsToUpsert.size() + ' productos');
                upsert productsToUpsert Product2.ShopifyProductId__c;
                System.debug('✅ Productos sincronizados exitosamente');
                
                // CREAR PRICE BOOK ENTRIES
                System.debug('💰 CREANDO PRICE BOOK ENTRIES');
                createPriceBookEntries(productsToUpsert, shopCurrency);
            }
            
        } catch (Exception e) {
            System.debug('❌ ERROR sincronizando productos básicos: ' + e.getMessage());
            throw new AuraHandledException('Error sincronizando productos: ' + e.getMessage());
        }
    }
    
    /**
     * @description Sincroniza productos básicos CON precios reales (nuevo método)
     */
    private static void syncProductsBasicWithPrices(List<Map<String, Object>> productNodes, String shopCurrency, Map<String, Decimal> pricesByShopifyId) {
        try {
            System.debug('🔄 SINCRONIZANDO PRODUCTOS BÁSICOS CON PRECIOS REALES');
            
            List<Product2> productsToUpsert = new List<Product2>();
            
            for (Map<String, Object> node : productNodes) {
                try {
                    Product2 product = new Product2();
                    
                    // Extraer ID de Shopify
                    String shopifyId = String.valueOf(node.get('id'));
                    if (shopifyId.startsWith('gid://shopify/Product/')) {
                        product.ShopifyProductId__c = shopifyId.replace('gid://shopify/Product/', '');
                    } else {
                        product.ShopifyProductId__c = shopifyId;
                    }
                    
                    // Mapear datos básicos
                    product.Name = (String)node.get('title');
                    product.ProductCode = (String)node.get('handle');
                    product.Description = (String)node.get('description');
                    
                    // Mapear categoría
                    String productType = (String)node.get('productType');
                    List<Object> tags = (List<Object>)node.get('tags');
                    
                    if (String.isNotBlank(productType)) {
                        product.Family = productType;
                    } else if (tags != null && !tags.isEmpty()) {
                        product.Family = (String)tags[0];
                    } else {
                        product.Family = 'General';
                    }
                    
                    // Estado activo
                    String status = (String)node.get('status');
                    product.IsActive = 'ACTIVE'.equalsIgnoreCase(status);
                    
                    productsToUpsert.add(product);
                    System.debug('📦 Producto mapeado: ' + product.Name + ' (' + product.ShopifyProductId__c + ')');
                    
                } catch (Exception e) {
                    System.debug('❌ Error mapeando producto: ' + e.getMessage());
                }
            }
            
            if (!productsToUpsert.isEmpty()) {
                System.debug('💾 Upsertando ' + productsToUpsert.size() + ' productos');
                upsert productsToUpsert Product2.ShopifyProductId__c;
                System.debug('✅ Productos sincronizados exitosamente');
                
                // CREAR PRICE BOOK ENTRIES CON PRECIOS REALES
                System.debug('💰 CREANDO PRICE BOOK ENTRIES CON PRECIOS REALES');
                createPriceBookEntriesWithPrices(productsToUpsert, pricesByShopifyId);
            }
            
        } catch (Exception e) {
            System.debug('❌ ERROR sincronizando productos básicos: ' + e.getMessage());
            throw new AuraHandledException('Error sincronizando productos: ' + e.getMessage());
        }
    }
    
    /**
     * @description Crea Price Book Entries para los productos con precios reales de Shopify
     */
    private static void createPriceBookEntries(List<Product2> products, String shopCurrency) {
        try {
            System.debug('🔄 CREANDO PRICE BOOK ENTRIES CON PRECIOS REALES');
            
            // Obtener Standard Pricebook ID
            Id standardPricebookId = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1].Id;
            System.debug('📚 Standard Pricebook ID: ' + standardPricebookId);
            
            // Obtener precios reales de Shopify
            Map<String, Decimal> pricesByShopifyId = getRealPricesFromShopify();
            System.debug('💰 Precios obtenidos de Shopify: ' + pricesByShopifyId.size());
            
            // Crear Price Book Entries
            List<PricebookEntry> pbesToInsert = new List<PricebookEntry>();
            
            for (Product2 product : products) {
                // Obtener precio real de Shopify o usar precio por defecto
                Decimal realPrice = pricesByShopifyId.get(product.ShopifyProductId__c);
                if (realPrice == null || realPrice <= 0) {
                    realPrice = 50.00; // Precio por defecto si no se encuentra
                    System.debug('⚠️ Precio no encontrado para ' + product.Name + ', usando precio por defecto: ' + realPrice);
                } else {
                    System.debug('✅ Precio real encontrado para ' + product.Name + ': ' + realPrice);
                }
                
                PricebookEntry pbe = new PricebookEntry();
                pbe.Pricebook2Id = standardPricebookId;
                pbe.Product2Id = product.Id;
                pbe.UnitPrice = realPrice;
                pbe.IsActive = true;
                pbe.UseStandardPrice = false;
                pbesToInsert.add(pbe);
                System.debug('💰 Price Book Entry creado para: ' + product.Name + ' - Precio: ' + realPrice);
            }
            
            if (!pbesToInsert.isEmpty()) {
                System.debug('💾 Insertando ' + pbesToInsert.size() + ' Price Book Entries');
                insert pbesToInsert;
                System.debug('✅ Price Book Entries creados exitosamente');
            }
            
        } catch (Exception e) {
            System.debug('❌ ERROR creando Price Book Entries: ' + e.getMessage());
            System.debug('❌ Stack trace: ' + e.getStackTraceString());
            // No lanzar excepción para no interrumpir la sincronización de productos
        }
    }
    
    /**
     * @description Crea Price Book Entries con precios ya obtenidos (nuevo método)
     */
    private static void createPriceBookEntriesWithPrices(List<Product2> products, Map<String, Decimal> pricesByShopifyId) {
        try {
            System.debug('🔄 CREANDO PRICE BOOK ENTRIES CON PRECIOS YA OBTENIDOS');
            
            // Obtener Standard Pricebook ID
            Id standardPricebookId = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1].Id;
            System.debug('📚 Standard Pricebook ID: ' + standardPricebookId);
            
            // Crear Price Book Entries
            List<PricebookEntry> pbesToInsert = new List<PricebookEntry>();
            
            for (Product2 product : products) {
                // Obtener precio real de Shopify o usar precio por defecto
                Decimal realPrice = pricesByShopifyId.get(product.ShopifyProductId__c);
                if (realPrice == null || realPrice <= 0) {
                    realPrice = 50.00; // Precio por defecto si no se encuentra
                    System.debug('⚠️ Precio no encontrado para ' + product.Name + ', usando precio por defecto: ' + realPrice);
                } else {
                    System.debug('✅ Precio real encontrado para ' + product.Name + ': ' + realPrice);
                }
                
                PricebookEntry pbe = new PricebookEntry();
                pbe.Pricebook2Id = standardPricebookId;
                pbe.Product2Id = product.Id;
                pbe.UnitPrice = realPrice;
                pbe.IsActive = true;
                pbe.UseStandardPrice = false;
                pbesToInsert.add(pbe);
                System.debug('💰 Price Book Entry creado para: ' + product.Name + ' - Precio: ' + realPrice);
            }
            
            if (!pbesToInsert.isEmpty()) {
                System.debug('💾 Insertando ' + pbesToInsert.size() + ' Price Book Entries');
                insert pbesToInsert;
                System.debug('✅ Price Book Entries creados exitosamente');
            }
            
        } catch (Exception e) {
            System.debug('❌ ERROR creando Price Book Entries: ' + e.getMessage());
            System.debug('❌ Stack trace: ' + e.getStackTraceString());
            // No lanzar excepción para no interrumpir la sincronización de productos
        }
    }
    
    /**
     * @description Obtiene precios reales de Shopify
     */
    private static Map<String, Decimal> getRealPricesFromShopify() {
        try {
            System.debug('🔄 OBTENIENDO PRECIOS REALES DE SHOPIFY');
            
            String shopDomain = 'michelltemp.myshopify.com';
            String apiVersion = '2025-07';
            String endpoint = 'https://' + shopDomain + '/admin/api/' + apiVersion + '/graphql.json';
            
            // Query para obtener precios de variants
            String query = '{"query": "{ products(first: 10) { edges { node { id variants(first: 1) { edges { node { price } } } } } } }"}';
            System.debug('📝 Query para precios: ' + query);
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('X-Shopify-Access-Token', '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');
            req.setBody(query);
            req.setTimeout(120000);
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            System.debug('📊 Status: ' + res.getStatusCode());
            System.debug('📊 Body: ' + res.getBody());
            
            Map<String, Decimal> pricesByShopifyId = new Map<String, Decimal>();
            
            if (res.getStatusCode() == 200) {
                Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
                System.debug('📊 ResponseMap completo: ' + JSON.serialize(responseMap));
                
                Map<String, Object> data = (Map<String, Object>)responseMap.get('data');
                if (data == null) {
                    System.debug('❌ Data es null en la respuesta');
                    return pricesByShopifyId;
                }
                
                Map<String, Object> products = (Map<String, Object>)data.get('products');
                if (products == null) {
                    System.debug('❌ Products es null en la respuesta');
                    return pricesByShopifyId;
                }
                
                List<Object> edges = (List<Object>)products.get('edges');
                if (edges == null) {
                    System.debug('❌ Edges es null en la respuesta');
                    return pricesByShopifyId;
                }
                
                System.debug('📊 Total de productos encontrados: ' + edges.size());
                
                for (Object edgeObj : edges) {
                    Map<String, Object> edge = (Map<String, Object>)edgeObj;
                    Map<String, Object> node = (Map<String, Object>)edge.get('node');
                    
                    String shopifyId = String.valueOf(node.get('id'));
                    System.debug('🔍 Procesando producto: ' + shopifyId);
                    
                    if (shopifyId.startsWith('gid://shopify/Product/')) {
                        shopifyId = shopifyId.replace('gid://shopify/Product/', '');
                    }
                    
                    // Extraer precio de la primera variant
                    Map<String, Object> variants = (Map<String, Object>)node.get('variants');
                    System.debug('🔍 Variants encontradas: ' + (variants != null ? 'Sí' : 'No'));
                    
                    if (variants != null) {
                        List<Object> variantEdges = (List<Object>)variants.get('edges');
                        System.debug('🔍 Variant edges: ' + (variantEdges != null ? String.valueOf(variantEdges.size()) : 'null'));
                        
                        if (variantEdges != null && !variantEdges.isEmpty()) {
                            Map<String, Object> variantEdge = (Map<String, Object>)variantEdges[0];
                            Map<String, Object> variant = (Map<String, Object>)variantEdge.get('node');
                            Object price = variant.get('price');
                            
                            System.debug('🔍 Precio encontrado: ' + price);
                            
                            if (price != null) {
                                Decimal priceValue = 0;
                                if (price instanceof String) {
                                    priceValue = Decimal.valueOf((String)price);
                                } else if (price instanceof Decimal) {
                                    priceValue = (Decimal)price;
                                }
                                
                                if (priceValue > 0) {
                                    pricesByShopifyId.put(shopifyId, priceValue);
                                    System.debug('💰 Precio extraído para ' + shopifyId + ': ' + priceValue);
                                } else {
                                    System.debug('⚠️ Precio inválido para ' + shopifyId + ': ' + priceValue);
                                }
                            } else {
                                System.debug('⚠️ Precio es null para ' + shopifyId);
                            }
                        } else {
                            System.debug('⚠️ No hay variant edges para ' + shopifyId);
                        }
                    } else {
                        System.debug('⚠️ No hay variants para ' + shopifyId);
                    }
                }
            } else {
                System.debug('❌ Error HTTP: ' + res.getStatusCode() + ' - ' + res.getBody());
            }
            
            System.debug('✅ Total de precios extraídos: ' + pricesByShopifyId.size());
            return pricesByShopifyId;
            
        } catch (Exception e) {
            System.debug('❌ ERROR obteniendo precios de Shopify: ' + e.getMessage());
            return new Map<String, Decimal>();
        }
    }

    @AuraEnabled
    public static void syncCustomersOnly() {
        System.debug('🔄 SINCRONIZANDO SOLO CLIENTES');
        ShopifySyncService.syncCustomers(getCustomersFromGraphQL());
        System.debug('✅ CLIENTES SINCRONIZADOS EXITOSAMENTE');
    }

    @AuraEnabled
    public static void syncOrdersOnly() {
        System.debug('🔄 SINCRONIZANDO SOLO ÓRDENES');
        ShopifySyncService.syncOrders(getOrdersFromGraphQL());
        System.debug('✅ ÓRDENES SINCRONIZADAS EXITOSAMENTE');
    }

    @AuraEnabled
    public static String limpiarBaseDeDatos() {
        try {
            System.debug('🧹 INICIANDO LIMPIEZA DE BASE DE DATOS');
            
            // Contar registros antes de eliminar
            Integer ordersCount = [SELECT COUNT() FROM Order WHERE ShopifyOrderId__c != null];
            Integer productsCount = [SELECT COUNT() FROM Product2 WHERE ShopifyProductId__c != null];
            Integer accountsCount = [SELECT COUNT() FROM Account WHERE ShopifyCustomerId__c != null];
            Integer contactsCount = [SELECT COUNT() FROM Contact WHERE ShopifyCustomerId__c != null];
            
            System.debug('📊 Registros a eliminar:');
            System.debug('   - Órdenes: ' + ordersCount);
            System.debug('   - Productos: ' + productsCount);
            System.debug('   - Cuentas: ' + accountsCount);
            System.debug('   - Contactos: ' + contactsCount);
            
            // Eliminar órdenes (desactivar primero si están activadas)
            if (ordersCount > 0) {
                List<Order> ordersToDelete = [SELECT Id, Status FROM Order WHERE ShopifyOrderId__c != null];
                
                // Desactivar órdenes que estén activadas
                List<Order> ordersToDeactivate = new List<Order>();
                for (Order order : ordersToDelete) {
                    if (order.Status == 'Activated') {
                        order.Status = 'Draft';
                        ordersToDeactivate.add(order);
                    }
                }
                
                if (!ordersToDeactivate.isEmpty()) {
                    update ordersToDeactivate;
                    System.debug('🔄 Desactivadas ' + ordersToDeactivate.size() + ' órdenes');
                }
                
                // Ahora eliminar las órdenes
                delete ordersToDelete;
                System.debug('🗑️ Eliminadas ' + ordersToDelete.size() + ' órdenes');
            }
            
            if (productsCount > 0) {
                List<Product2> productsToDelete = [SELECT Id FROM Product2 WHERE ShopifyProductId__c != null];
                delete productsToDelete;
                System.debug('🗑️ Eliminados ' + productsToDelete.size() + ' productos');
            }
            
            if (accountsCount > 0) {
                List<Account> accountsToDelete = [SELECT Id FROM Account WHERE ShopifyCustomerId__c != null];
                delete accountsToDelete;
                System.debug('🗑️ Eliminadas ' + accountsToDelete.size() + ' cuentas');
            }
            
            if (contactsCount > 0) {
                List<Contact> contactsToDelete = [SELECT Id FROM Contact WHERE ShopifyCustomerId__c != null];
                delete contactsToDelete;
                System.debug('🗑️ Eliminados ' + contactsToDelete.size() + ' contactos');
            }
            
            System.debug('✅ LIMPIEZA DE BASE DE DATOS COMPLETADA');
            
            return 'Limpieza completada. Eliminados: ' + ordersCount + ' órdenes, ' + 
                   productsCount + ' productos, ' + accountsCount + ' cuentas, ' + 
                   contactsCount + ' contactos.';
                   
        } catch (Exception e) {
            System.debug('❌ ERROR en limpieza: ' + e.getMessage());
            System.debug('❌ Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error al limpiar base de datos: ' + e.getMessage());
        }
    }
    
    /**
     * @description Obtiene los OrderItems de una orden específica
     * @param orderId ID de la orden
     * @return Lista de OrderItems con información del producto
     */
    @AuraEnabled(cacheable=true)
    public static List<OrderItem> getOrderItems(Id orderId) {
        try {
            List<OrderItem> orderItems = [
                SELECT Id, OrderId, Product2Id, Product2.Name, Product2.ProductCode, 
                       Quantity, UnitPrice, PricebookEntryId, ServiceDate
                FROM OrderItem 
                WHERE OrderId = :orderId
                ORDER BY CreatedDate ASC
            ];
            
            System.debug('📦 OrderItems encontrados: ' + orderItems.size());
            return orderItems;
            
        } catch (Exception e) {
            System.debug('❌ Error obteniendo OrderItems: ' + e.getMessage());
            throw new AuraHandledException('Error obteniendo productos de la orden: ' + e.getMessage());
        }
    }

    // ========================================
    // MÉTODOS DE CONEXIÓN GRAPHQL
    // ========================================
    
    /**
     * @description Obtiene la moneda de la tienda Shopify
     */
    private static String getShopCurrency() {
        try {
            System.debug('🔄 OBTENIENDO MONEDA DE LA TIENDA SHOPIFY');

            String shopDomain = 'michelltemp.myshopify.com';
            String apiVersion = '2025-07';
            String endpoint = 'https://' + shopDomain + '/admin/api/' + apiVersion + '/graphql.json';
            System.debug('🌐 Endpoint: ' + endpoint);

            String query = '{"query": "{ shop { currencyCode } }"}';
            System.debug('📝 Query GraphQL: ' + query);

            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('X-Shopify-Access-Token', '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');
            req.setBody(query);
            req.setTimeout(120000);

            Http http = new Http();
            HttpResponse res = http.send(req);

            System.debug('📊 Response Status: ' + res.getStatusCode());
            System.debug('📊 Response Body: ' + res.getBody());

            if (res.getStatusCode() == 200) {
                Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
                Map<String, Object> data = (Map<String, Object>)responseMap.get('data');
                Map<String, Object> shop = (Map<String, Object>)data.get('shop');
                String currencyCode = (String)shop.get('currencyCode');
                
                System.debug('✅ Moneda de la tienda: ' + currencyCode);
                return currencyCode != null ? currencyCode : 'USD';
            } else {
                System.debug('⚠️ Error obteniendo moneda, usando USD por defecto');
                return 'USD';
            }
        } catch (Exception e) {
            System.debug('❌ ERROR obteniendo moneda: ' + e.getMessage());
            return 'USD';
        }
    }

    /**
     * @description Obtiene productos desde GraphQL de Shopify
     */
    private static List<Map<String, Object>> getProductsFromGraphQL() {
        try {
            System.debug('🔄 OBTENIENDO PRODUCTOS DESDE GRAPHQL');
            
            String shopDomain = 'michelltemp.myshopify.com';
            String apiVersion = '2025-07';
            String endpoint = 'https://' + shopDomain + '/admin/api/' + apiVersion + '/graphql.json';
            System.debug('🌐 Endpoint: ' + endpoint);
            
            // Query con variants (ahora que sabemos que funciona)
            String query = '{"query": "{ products(first: 10) { edges { node { id title handle productType status description tags variants(first: 1) { edges { node { price } } } } } }"}';
            System.debug('📝 Query GraphQL: ' + query);
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('X-Shopify-Access-Token', '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');
            req.setBody(query);
            req.setTimeout(120000);
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            System.debug('📊 Response Status: ' + res.getStatusCode());
            System.debug('📊 Response Body: ' + res.getBody());
            
            if (res.getStatusCode() == 200) {
                // Verificar si hay errores en la respuesta GraphQL
                Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
                
                // Verificar errores GraphQL
                if (responseMap.containsKey('errors')) {
                    List<Object> errors = (List<Object>)responseMap.get('errors');
                    System.debug('❌ Errores GraphQL: ' + errors);
                    throw new CalloutException('Errores GraphQL: ' + JSON.serialize(errors));
                }
                
                Map<String, Object> data = (Map<String, Object>)responseMap.get('data');
                if (data == null) {
                    throw new CalloutException('No hay datos en la respuesta GraphQL');
                }
                
                Map<String, Object> products = (Map<String, Object>)data.get('products');
                if (products == null) {
                    throw new CalloutException('No hay productos en la respuesta');
                }
                
                List<Object> edges = (List<Object>)products.get('edges');
                if (edges == null) {
                    throw new CalloutException('No hay edges en la respuesta');
                }
                
                List<Map<String, Object>> productNodes = new List<Map<String, Object>>();
                for (Object edgeObj : edges) {
                    Map<String, Object> edge = (Map<String, Object>)edgeObj;
                    Map<String, Object> node = (Map<String, Object>)edge.get('node');
                    if (node != null) {
                        productNodes.add(node);
                    }
                }
                
                System.debug('✅ Productos obtenidos: ' + productNodes.size());
                return productNodes;
            } else {
                throw new CalloutException('Error en GraphQL: ' + res.getStatusCode() + ' - ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug('❌ ERROR obteniendo productos: ' + e.getMessage());
            System.debug('❌ Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error obteniendo productos: ' + e.getMessage());
        }
    }

    private static List<Map<String, Object>> getCustomersFromGraphQL() {
        try {
            System.debug('🔄 OBTENIENDO CLIENTES DESDE GRAPHQL');

            String shopDomain = 'michelltemp.myshopify.com';
            String apiVersion = '2025-07';
            String endpoint = 'https://' + shopDomain + '/admin/api/' + apiVersion + '/graphql.json';
            System.debug('🌐 Endpoint: ' + endpoint);

            String query = '{"query": "{ customers(first: 50) { edges { node { id firstName lastName email phone } } } }"}';
            System.debug('📝 Query GraphQL: ' + query);

            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('X-Shopify-Access-Token', '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');
            req.setBody(query);
            req.setTimeout(120000);

            Http http = new Http();
            HttpResponse res = http.send(req);

            System.debug('📊 Response Status: ' + res.getStatusCode());
            System.debug('📊 Response Body: ' + res.getBody());

            if (res.getStatusCode() == 200) {
                Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
                Map<String, Object> data = (Map<String, Object>)responseMap.get('data');
                Map<String, Object> customers = (Map<String, Object>)data.get('customers');
                List<Object> edges = (List<Object>)customers.get('edges');

                List<Map<String, Object>> customerNodes = new List<Map<String, Object>>();
                for (Object edgeObj : edges) {
                    Map<String, Object> edge = (Map<String, Object>)edgeObj;
                    Map<String, Object> node = (Map<String, Object>)edge.get('node');
                    customerNodes.add(node);
                }

                System.debug('✅ Clientes obtenidos: ' + customerNodes.size());
                return customerNodes;
            } else {
                throw new CalloutException('Error en GraphQL: ' + res.getStatusCode() + ' - ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug('❌ ERROR obteniendo clientes: ' + e.getMessage());
            throw new AuraHandledException('Error obteniendo clientes: ' + e.getMessage());
        }
    }

    private static List<Map<String, Object>> getOrdersFromGraphQL() {
        try {
            System.debug('🔄 OBTENIENDO ÓRDENES DESDE API REST');

            String shopDomain = 'michelltemp.myshopify.com';
            String apiVersion = '2023-10';
            String endpoint = 'https://' + shopDomain + '/admin/api/' + apiVersion + '/orders.json?limit=10';
            System.debug('🌐 Endpoint: ' + endpoint);

            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('GET');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('X-Shopify-Access-Token', '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');
            req.setTimeout(120000);

            Http http = new Http();
            HttpResponse res = http.send(req);

            System.debug('📊 Response Status: ' + res.getStatusCode());
            System.debug('📊 Response Body: ' + res.getBody());

            if (res.getStatusCode() == 200) {
                Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
                List<Object> orders = (List<Object>)responseMap.get('orders');

                List<Map<String, Object>> orderNodes = new List<Map<String, Object>>();
                for (Object orderObj : orders) {
                    Map<String, Object> order = (Map<String, Object>)orderObj;
                    orderNodes.add(order);
                }

                System.debug('✅ Órdenes obtenidas: ' + orderNodes.size());
                return orderNodes;
            } else {
                throw new CalloutException('Error en API REST: ' + res.getStatusCode() + ' - ' + res.getBody());
            }
        } catch (Exception e) {
            System.debug('❌ ERROR obteniendo órdenes: ' + e.getMessage());
            throw new AuraHandledException('Error obteniendo órdenes: ' + e.getMessage());
        }
    }
}
