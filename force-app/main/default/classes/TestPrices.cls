public class TestPrices {
    public static void testPrices() {
        try {
            System.debug('Ì∑™ PROBANDO OBTENCI√ìN DE PRECIOS');
            
            String shopDomain = 'michelltemp.myshopify.com';
            String apiVersion = '2025-07';
            String endpoint = 'https://' + shopDomain + '/admin/api/' + apiVersion + '/graphql.json';
            
            // Query solo para precios
            String query = '{"query": "{ products(first: 2) { edges { node { id title variants(first: 1) { edges { node { price } } } } } }"}';
            System.debug('Ì≥ù Query: ' + query);
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('X-Shopify-Access-Token', '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');
            req.setBody(query);
            req.setTimeout(30000);
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            System.debug('Ì≥ä Status: ' + res.getStatusCode());
            System.debug('Ì≥ä Body: ' + res.getBody());
            
            if (res.getStatusCode() == 200) {
                Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
                Map<String, Object> data = (Map<String, Object>)responseMap.get('data');
                Map<String, Object> products = (Map<String, Object>)data.get('products');
                List<Object> edges = (List<Object>)products.get('edges');
                
                System.debug('Ì≥ä Productos encontrados: ' + edges.size());
                
                for (Object edgeObj : edges) {
                    Map<String, Object> edge = (Map<String, Object>)edgeObj;
                    Map<String, Object> node = (Map<String, Object>)edge.get('node');
                    
                    String title = (String)node.get('title');
                    String id = (String)node.get('id');
                    
                    System.debug('Ì≥¶ Producto: ' + title + ' - ID: ' + id);
                    
                    // Extraer precio
                    Map<String, Object> variants = (Map<String, Object>)node.get('variants');
                    if (variants != null) {
                        List<Object> variantEdges = (List<Object>)variants.get('edges');
                        if (variantEdges != null && !variantEdges.isEmpty()) {
                            Map<String, Object> variantEdge = (Map<String, Object>)variantEdges[0];
                            Map<String, Object> variant = (Map<String, Object>)variantEdge.get('node');
                            Object price = variant.get('price');
                            System.debug('Ì≤∞ Precio: ' + price);
                        }
                    }
                }
            }
        } catch (Exception e) {
            System.debug('‚ùå ERROR: ' + e.getMessage());
            System.debug('‚ùå Stack trace: ' + e.getStackTraceString());
        }
    }
}
