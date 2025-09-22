public with sharing class DC_LogUtil {
    public static void logResults(DC_UpsertBundle bundle, Database.UpsertResult[] results) {
        if (bundle == null || bundle.records == null) return;
        for (Integer i = 0; i < results.size(); i++) {
            Database.UpsertResult r = results[i];
            SObject rec = bundle.records[i];
            String extVal = '';
            try { extVal = String.valueOf(rec.get(bundle.externalIdField)); } catch (Exception e) {}
            if (r.isSuccess()) {
                System.debug(LoggingLevel.INFO,
                    '[UPSERT OK] ext=' + extVal + ' → Id=' + r.getId());
            } else {
                for (Database.Error e : r.getErrors()) {
                    System.debug(LoggingLevel.ERROR,
                        '[UPSERT FAIL] ext=' + extVal + ' → ' + e.getMessage());
                }
            }
        }
    }
}
