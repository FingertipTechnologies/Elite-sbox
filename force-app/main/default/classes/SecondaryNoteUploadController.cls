public without sharing class SecondaryNoteUploadController {

    public class RowError {
        @AuraEnabled public Integer rowNumber { get; set; }
        @AuraEnabled public String customerCode { get; set; }
        @AuraEnabled public String message { get; set; }

        public RowError(Integer rowNumber, String customerCode, String message) {
            this.rowNumber = rowNumber;
            this.customerCode = customerCode;
            this.message = message;
        }
    }

    public class RowSuccess {
        @AuraEnabled public Integer rowNumber { get; set; }
        @AuraEnabled public String customerCode { get; set; }
        @AuraEnabled public String customerName { get; set; }
        @AuraEnabled public String recordId { get; set; }
        @AuraEnabled public String recordName { get; set; }
        @AuraEnabled public String noteDate { get; set; }
        @AuraEnabled public Decimal amount { get; set; }

        public RowSuccess(Integer rowNumber, String customerCode, String customerName, String recordId, String recordName, String noteDate, Decimal amount) {
            this.rowNumber = rowNumber;
            this.customerCode = customerCode;
            this.customerName = customerName;
            this.recordId = recordId;
            this.recordName = recordName;
            this.noteDate = noteDate;
            this.amount = amount;
        }
    }

    public class UploadResult {
        @AuraEnabled public Integer totalRecords { get; set; }
        @AuraEnabled public Integer successCount { get; set; }
        @AuraEnabled public Integer failedCount { get; set; }
        @AuraEnabled public List<RowError> errors { get; set; }
        @AuraEnabled public List<RowSuccess> successes { get; set; }

        public UploadResult() {
            this.totalRecords = 0;
            this.successCount = 0;
            this.failedCount = 0;
            this.errors = new List<RowError>();
            this.successes = new List<RowSuccess>();
        }
    }

    private static Id getDistributorAccountId() {
        Id accountId;
        List<User> partnerUser = [
            SELECT ContactId
            FROM User
            WHERE Id = :UserInfo.getUserId()
        ];
        if (!partnerUser.isEmpty() && partnerUser[0].ContactId != null) {
            List<Contact> contact = [
                SELECT AccountId
                FROM Contact
                WHERE Id = :partnerUser[0].ContactId
                LIMIT 1
            ];
            if (!contact.isEmpty()) {
                accountId = contact[0].AccountId;
            }
        }
        return accountId;
    }

    private static Map<String, Id> resolveCustomers(Set<String> customerCodes, Id distributorId) {
        Map<String, Id> codeToId = new Map<String, Id>();
        if (customerCodes.isEmpty()) {
            return codeToId;
        }
        for (Account a : [
            SELECT Id, Customer_Code__c
            FROM Account
            WHERE Customer_Code__c IN :customerCodes
        ]) {
            if (a.Customer_Code__c != null) {
                codeToId.put(a.Customer_Code__c, a.Id);
            }
        }
        return codeToId;
    }

    private static Date parseDate(String value) {
        if (String.isBlank(value)) {
            return null;
        }
        String trimmed = value.trim();
        String sep = null;
        if (trimmed.contains('-')) {
            sep = '-';
        } else if (trimmed.contains('/')) {
            sep = '/';
        }
        if (sep == null) {
            return null;
        }
        List<String> parts = trimmed.split(sep == '/' ? '/' : '-');
        if (parts.size() != 3) {
            return null;
        }
        try {
            Integer y;
            Integer m;
            Integer d;
            if (parts[0].length() == 4) {
                // YYYY-MM-DD
                y = Integer.valueOf(parts[0]);
                m = Integer.valueOf(parts[1]);
                d = Integer.valueOf(parts[2]);
            } else if (parts[2].length() == 4) {
                // DD-MM-YYYY or DD/MM/YYYY
                d = Integer.valueOf(parts[0]);
                m = Integer.valueOf(parts[1]);
                y = Integer.valueOf(parts[2]);
            } else {
                return null;
            }
            return Date.newInstance(y, m, d);
        } catch (Exception e) {
            return null;
        }
    }

    private static Decimal parseAmount(String value) {
        if (String.isBlank(value)) {
            return null;
        }
        try {
            return Decimal.valueOf(value.trim());
        } catch (Exception e) {
            return null;
        }
    }

    @AuraEnabled
    public static UploadResult uploadCreditNotes(String rowsJson) {
        UploadResult result = new UploadResult();
        if (String.isBlank(rowsJson)) {
            return result;
        }
        List<Object> raw = (List<Object>) JSON.deserializeUntyped(rowsJson);
        result.totalRecords = raw.size();

        Id distributorId = getDistributorAccountId();

        Set<String> codes = new Set<String>();
        List<Map<String, Object>> rows = new List<Map<String, Object>>();
        for (Object o : raw) {
            Map<String, Object> row = (Map<String, Object>) o;
            rows.add(row);
            String code = row.get('customerCode') != null ? String.valueOf(row.get('customerCode')).trim() : '';
            if (String.isNotBlank(code)) {
                codes.add(code);
            }
        }
        Map<String, Id> codeToId = resolveCustomers(codes, distributorId);

        List<Secondary_Credit_Note__c> toInsert = new List<Secondary_Credit_Note__c>();
        List<Integer> rowIndexFor = new List<Integer>();
        List<String> codeFor = new List<String>();

        for (Integer i = 0; i < rows.size(); i++) {
            Map<String, Object> row = rows[i];
            Integer rowNum = i + 2;
            String code = row.get('customerCode') != null ? String.valueOf(row.get('customerCode')).trim() : '';
            String dateStr = row.get('creditDate') != null ? String.valueOf(row.get('creditDate')) : '';
            String amountStr = row.get('amount') != null ? String.valueOf(row.get('amount')) : '';
            String reason = row.get('reason') != null ? String.valueOf(row.get('reason')) : '';
            String description = row.get('description') != null ? String.valueOf(row.get('description')) : '';

            List<String> errs = new List<String>();
            if (String.isBlank(code)) {
                errs.add('Customer Code is required');
            }
            Date creditDate = parseDate(dateStr);
            if (String.isBlank(dateStr)) {
                errs.add('Credit Date is required');
            } else if (creditDate == null) {
                errs.add('Invalid Credit Date format (use YYYY-MM-DD, DD-MM-YYYY or DD/MM/YYYY)');
            }
            Decimal amount = parseAmount(amountStr);
            if (String.isBlank(amountStr)) {
                errs.add('Amount is required');
            } else if (amount == null) {
                errs.add('Invalid Amount value');
            } else if (amount <= 0) {
                errs.add('Amount must be greater than zero');
            }
            Id customerId = codeToId.get(code);
            if (String.isNotBlank(code) && customerId == null) {
                errs.add('Customer not found for Customer Code: ' + code);
            }

            if (!errs.isEmpty()) {
                result.errors.add(new RowError(rowNum, code, String.join(errs, '; ')));
                result.failedCount++;
                continue;
            }

            Secondary_Credit_Note__c cn = new Secondary_Credit_Note__c();
            cn.Customer__c = customerId;
            cn.Credit_Date__c = creditDate;
            cn.Amount__c = amount;
            cn.Reason__c = String.isBlank(reason) ? null : reason;
            cn.Description__c = String.isBlank(description) ? null : description;
            cn.Distributor__c = distributorId;
            toInsert.add(cn);
            rowIndexFor.add(rowNum);
            codeFor.add(code);
        }

        if (!toInsert.isEmpty()) {
            Database.SaveResult[] sr = Database.insert(toInsert, false);
            Set<Id> successIds = new Set<Id>();
            for (Integer i = 0; i < sr.size(); i++) {
                if (sr[i].isSuccess()) {
                    successIds.add(sr[i].getId());
                }
            }
            Map<Id, Secondary_Credit_Note__c> insertedById = new Map<Id, Secondary_Credit_Note__c>();
            if (!successIds.isEmpty()) {
                for (Secondary_Credit_Note__c rec : [
                    SELECT Id, Name, Customer__c, Customer__r.Name, Credit_Date__c, Amount__c
                    FROM Secondary_Credit_Note__c
                    WHERE Id IN :successIds
                ]) {
                    insertedById.put(rec.Id, rec);
                }
            }
            for (Integer i = 0; i < sr.size(); i++) {
                if (sr[i].isSuccess()) {
                    result.successCount++;
                    Secondary_Credit_Note__c rec = insertedById.get(sr[i].getId());
                    String custName = rec != null && rec.Customer__r != null ? rec.Customer__r.Name : '';
                    String recName = rec != null ? rec.Name : '';
                    String dateStr = rec != null && rec.Credit_Date__c != null ? String.valueOf(rec.Credit_Date__c) : '';
                    Decimal amt = rec != null ? rec.Amount__c : null;
                    result.successes.add(new RowSuccess(rowIndexFor[i], codeFor[i], custName, sr[i].getId(), recName, dateStr, amt));
                } else {
                    result.failedCount++;
                    String msg = '';
                    for (Database.Error err : sr[i].getErrors()) {
                        msg += err.getMessage() + ' ';
                    }
                    result.errors.add(new RowError(rowIndexFor[i], codeFor[i], msg.trim()));
                }
            }
        }

        return result;
    }

    @AuraEnabled
    public static UploadResult uploadDebitNotes(String rowsJson) {
        UploadResult result = new UploadResult();
        if (String.isBlank(rowsJson)) {
            return result;
        }
        List<Object> raw = (List<Object>) JSON.deserializeUntyped(rowsJson);
        result.totalRecords = raw.size();

        Id distributorId = getDistributorAccountId();

        Set<String> codes = new Set<String>();
        List<Map<String, Object>> rows = new List<Map<String, Object>>();
        for (Object o : raw) {
            Map<String, Object> row = (Map<String, Object>) o;
            rows.add(row);
            String code = row.get('customerCode') != null ? String.valueOf(row.get('customerCode')).trim() : '';
            if (String.isNotBlank(code)) {
                codes.add(code);
            }
        }
        Map<String, Id> codeToId = resolveCustomers(codes, distributorId);

        List<Secondary_Debit_Note__c> toInsert = new List<Secondary_Debit_Note__c>();
        List<Integer> rowIndexFor = new List<Integer>();
        List<String> codeFor = new List<String>();

        for (Integer i = 0; i < rows.size(); i++) {
            Map<String, Object> row = rows[i];
            Integer rowNum = i + 2;
            String code = row.get('customerCode') != null ? String.valueOf(row.get('customerCode')).trim() : '';
            String dateStr = row.get('noteDate') != null ? String.valueOf(row.get('noteDate')) : '';
            String amountStr = row.get('amount') != null ? String.valueOf(row.get('amount')) : '';
            String reason = row.get('reason') != null ? String.valueOf(row.get('reason')) : '';
            String description = row.get('description') != null ? String.valueOf(row.get('description')) : '';

            List<String> errs = new List<String>();
            if (String.isBlank(code)) {
                errs.add('Customer Code is required');
            }
            Date noteDate = parseDate(dateStr);
            if (String.isBlank(dateStr)) {
                errs.add('Note Date is required');
            } else if (noteDate == null) {
                errs.add('Invalid Note Date format (use YYYY-MM-DD, DD-MM-YYYY or DD/MM/YYYY)');
            }
            Decimal amount = parseAmount(amountStr);
            if (String.isBlank(amountStr)) {
                errs.add('Amount is required');
            } else if (amount == null) {
                errs.add('Invalid Amount value');
            } else if (amount <= 0) {
                errs.add('Amount must be greater than zero');
            }
            Id customerId = codeToId.get(code);
            if (String.isNotBlank(code) && customerId == null) {
                errs.add('Customer not found for Customer Code: ' + code);
            }

            if (!errs.isEmpty()) {
                result.errors.add(new RowError(rowNum, code, String.join(errs, '; ')));
                result.failedCount++;
                continue;
            }

            Secondary_Debit_Note__c dn = new Secondary_Debit_Note__c();
            dn.Customer__c = customerId;
            dn.Note_Date__c = noteDate;
            dn.Amount__c = amount;
            dn.Reason__c = String.isBlank(reason) ? null : reason;
            dn.Description__c = String.isBlank(description) ? null : description;
            dn.Distributor__c = distributorId;
            toInsert.add(dn);
            rowIndexFor.add(rowNum);
            codeFor.add(code);
        }

        if (!toInsert.isEmpty()) {
            Database.SaveResult[] sr = Database.insert(toInsert, false);
            Set<Id> successIds = new Set<Id>();
            for (Integer i = 0; i < sr.size(); i++) {
                if (sr[i].isSuccess()) {
                    successIds.add(sr[i].getId());
                }
            }
            Map<Id, Secondary_Debit_Note__c> insertedById = new Map<Id, Secondary_Debit_Note__c>();
            if (!successIds.isEmpty()) {
                for (Secondary_Debit_Note__c rec : [
                    SELECT Id, Name, Customer__c, Customer__r.Name, Note_Date__c, Amount__c
                    FROM Secondary_Debit_Note__c
                    WHERE Id IN :successIds
                ]) {
                    insertedById.put(rec.Id, rec);
                }
            }
            for (Integer i = 0; i < sr.size(); i++) {
                if (sr[i].isSuccess()) {
                    result.successCount++;
                    Secondary_Debit_Note__c rec = insertedById.get(sr[i].getId());
                    String custName = rec != null && rec.Customer__r != null ? rec.Customer__r.Name : '';
                    String recName = rec != null ? rec.Name : '';
                    String dateStr = rec != null && rec.Note_Date__c != null ? String.valueOf(rec.Note_Date__c) : '';
                    Decimal amt = rec != null ? rec.Amount__c : null;
                    result.successes.add(new RowSuccess(rowIndexFor[i], codeFor[i], custName, sr[i].getId(), recName, dateStr, amt));
                } else {
                    result.failedCount++;
                    String msg = '';
                    for (Database.Error err : sr[i].getErrors()) {
                        msg += err.getMessage() + ' ';
                    }
                    result.errors.add(new RowError(rowIndexFor[i], codeFor[i], msg.trim()));
                }
            }
        }

        return result;
    }
}