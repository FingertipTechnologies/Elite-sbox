@isTest
public class SecondaryCreditNoteAllocationHandlerTest {

    @TestSetup
    static void setupTestData() {

        // ── Step 1: Setup Objects (User) — must be done first, separately ──
        Profile tseProfile = [SELECT Id FROM Profile WHERE Name = 'TSE' LIMIT 1];
        UserRole testRole  = [SELECT Id FROM UserRole LIMIT 1];

        User tseUser = new User(
            Alias             = 'tuser3',
            Employee_Code__c  = 'TSE555666777',
            Email             = 'tse1@cnalloctest.com',
            EmailEncodingKey  = 'UTF-8',
            LastName          = 'TSEUser',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey      = 'en_US',
            ProfileId         = tseProfile.Id,
            TimeZoneSidKey    = 'America/Los_Angeles',
            Username          = 'tse1@cnalloctest.com' + System.currentTimeMillis(),
            userroleId        = testRole.Id,
            Sales_Channel__c  = 'Cake'
        );
        insert tseUser;

        // ── Step 2: Non-Setup Objects inside System.runAs() ──
        System.runAs(tseUser) {

            Account distributor = new Account(
                Name                    = 'Alloc Test Distributor',
                OwnerId                 = tseUser.Id,
                Customer_Type__c        = 'Primary Customer',
                Pincode__c              = '500001',
                Primary_Phone_Number__c = '9876543210',
                State__c                = 'Telangana',
                District__c             = 'Hyderabad'
            );
            insert distributor;

            Account secondaryCustomer = new Account(
                Name                    = 'Alloc Test Secondary Customer',
                OwnerId                 = tseUser.Id,
                Customer_Type__c        = 'Secondary Customer',
                Pincode__c              = '500002',
                Primary_Phone_Number__c = '9876543211',
                State__c                = 'Telangana',
                District__c             = 'Hyderabad'
            );
            insert secondaryCustomer;
        }
    }

    // ── Helpers ──
    static Account getDistributor() {
        return [SELECT Id FROM Account WHERE Name = 'Alloc Test Distributor' LIMIT 1];
    }

    static Account getSecondaryCustomer() {
        return [SELECT Id FROM Account WHERE Name = 'Alloc Test Secondary Customer' LIMIT 1];
    }

    static Secondary_Invoice__c makeInvoice(Id distributorId, Id customerId, Decimal amount, Date invDate) {
        return new Secondary_Invoice__c(
            Store__c        = distributorId,
            Customer__c     = customerId,
            Invoice_Date__c = invDate,
            Status__c       = 'Raised',
            Grand_Total__c  = amount
        );
    }

    static Secondary_Debit_Note__c makeDebitNote(Id distributorId, Id customerId, Decimal amount, Date noteDate) {
        return new Secondary_Debit_Note__c(
            Customer__c    = customerId,
            Distributor__c = distributorId,
            Note_Date__c   = noteDate,
            Amount__c      = amount,
            Reason__c      = 'Price Difference',
            Status__c      = 'Draft'
        );
    }

    static Secondary_Credit_Note__c makeCreditNote(Id distributorId, Id customerId, Decimal amount) {
        return new Secondary_Credit_Note__c(
            Customer__c    = customerId,
            Distributor__c = distributorId,
            Credit_Date__c = Date.today(),
            Amount__c      = amount,
            Reason__c      = 'Price Difference',
            Status__c      = 'Open'
        );
    }

    // ─────────────────────────────────────────
    // Test 1: CN smaller than pending invoice -> fully applied, status Paid
    // ─────────────────────────────────────────
    @isTest
    static void testAllocation_FullyApplied() {
        Account dist = getDistributor();
        Account cust = getSecondaryCustomer();

        insert makeInvoice(dist.Id, cust.Id, 500, Date.today().addDays(-10));

        Test.startTest();
        Secondary_Credit_Note__c cn = makeCreditNote(dist.Id, cust.Id, 200);
        insert cn;
        Test.stopTest();

        cn = [SELECT Status__c, Applied_Invoice_Amount__c, Unapplied_Amount__c
              FROM Secondary_Credit_Note__c WHERE Id = :cn.Id];
        System.assertEquals('Paid', cn.Status__c, 'Fully applied CN should be Paid');
        System.assertEquals(200, cn.Applied_Invoice_Amount__c);
        System.assertEquals(0, cn.Unapplied_Amount__c);

        Secondary_Invoice__c inv = [SELECT Credit_Adjusted_Amount__c, Pending_Amount__c
                                    FROM Secondary_Invoice__c WHERE Customer__c = :cust.Id];
        System.assertEquals(200, inv.Credit_Adjusted_Amount__c);
        System.assertEquals(300, inv.Pending_Amount__c, 'Invoice pending should be net of credit');
    }

    // ─────────────────────────────────────────
    // Test 2: CN spans two invoices and a debit note, oldest-first
    // ─────────────────────────────────────────
    @isTest
    static void testAllocation_SpansInvoicesThenDebitNotes() {
        Account dist = getDistributor();
        Account cust = getSecondaryCustomer();

        Secondary_Invoice__c inv1 = makeInvoice(dist.Id, cust.Id, 100, Date.today().addDays(-20));
        Secondary_Invoice__c inv2 = makeInvoice(dist.Id, cust.Id, 150, Date.today().addDays(-10));
        insert new List<Secondary_Invoice__c>{ inv1, inv2 };
        Secondary_Debit_Note__c dn = makeDebitNote(dist.Id, cust.Id, 150, Date.today().addDays(-5));
        insert dn;

        Test.startTest();
        Secondary_Credit_Note__c cn = makeCreditNote(dist.Id, cust.Id, 300);
        insert cn;
        Test.stopTest();

        inv1 = [SELECT Pending_Amount__c FROM Secondary_Invoice__c WHERE Id = :inv1.Id];
        inv2 = [SELECT Pending_Amount__c FROM Secondary_Invoice__c WHERE Id = :inv2.Id];
        dn   = [SELECT Pending_Amount__c FROM Secondary_Debit_Note__c WHERE Id = :dn.Id];
        System.assertEquals(0, inv1.Pending_Amount__c, 'Oldest invoice cleared first');
        System.assertEquals(0, inv2.Pending_Amount__c, 'Second invoice cleared next');
        System.assertEquals(100, dn.Pending_Amount__c, 'Remaining 50 applied to debit note');

        cn = [SELECT Status__c, Applied_Invoice_Amount__c, Applied_Debit_Amount__c, Unapplied_Amount__c
              FROM Secondary_Credit_Note__c WHERE Id = :cn.Id];
        System.assertEquals('Paid', cn.Status__c);
        System.assertEquals(250, cn.Applied_Invoice_Amount__c);
        System.assertEquals(50, cn.Applied_Debit_Amount__c);
        System.assertEquals(0, cn.Unapplied_Amount__c);
    }

    // ─────────────────────────────────────────
    // Test 3: CN larger than all pending -> leftover stays, Partially Paid
    // ─────────────────────────────────────────
    @isTest
    static void testAllocation_LeftoverCredit() {
        Account dist = getDistributor();
        Account cust = getSecondaryCustomer();

        insert makeInvoice(dist.Id, cust.Id, 100, Date.today().addDays(-10));

        Test.startTest();
        Secondary_Credit_Note__c cn = makeCreditNote(dist.Id, cust.Id, 300);
        insert cn;
        Test.stopTest();

        cn = [SELECT Status__c, Applied_Invoice_Amount__c, Unapplied_Amount__c
              FROM Secondary_Credit_Note__c WHERE Id = :cn.Id];
        System.assertEquals('Partially Paid', cn.Status__c);
        System.assertEquals(100, cn.Applied_Invoice_Amount__c);
        System.assertEquals(200, cn.Unapplied_Amount__c, 'Leftover credit stays on the note');
    }

    // ─────────────────────────────────────────
    // Test 4: No pending docs -> nothing applied, stays Open
    // ─────────────────────────────────────────
    @isTest
    static void testAllocation_NoPendingDocs() {
        Account dist = getDistributor();
        Account cust = getSecondaryCustomer();

        Test.startTest();
        Secondary_Credit_Note__c cn = makeCreditNote(dist.Id, cust.Id, 200);
        insert cn;
        Test.stopTest();

        cn = [SELECT Status__c, Unapplied_Amount__c FROM Secondary_Credit_Note__c WHERE Id = :cn.Id];
        System.assertEquals('Open', cn.Status__c);
        System.assertEquals(200, cn.Unapplied_Amount__c);
        System.assertEquals(0, [SELECT COUNT() FROM Secondary_Credit_Note_Item__c
                                WHERE Secondary_Credit_Note__c = :cn.Id]);
    }

    // ─────────────────────────────────────────
    // Test 5: Two CNs in one insert -> no over-allocation of the same invoice
    // ─────────────────────────────────────────
    @isTest
    static void testBulk_TwoCreditNotesSameCustomer() {
        Account dist = getDistributor();
        Account cust = getSecondaryCustomer();

        insert makeInvoice(dist.Id, cust.Id, 250, Date.today().addDays(-10));

        Test.startTest();
        Secondary_Credit_Note__c cn1 = makeCreditNote(dist.Id, cust.Id, 150);
        Secondary_Credit_Note__c cn2 = makeCreditNote(dist.Id, cust.Id, 150);
        insert new List<Secondary_Credit_Note__c>{ cn1, cn2 };
        Test.stopTest();

        Secondary_Invoice__c inv = [SELECT Credit_Adjusted_Amount__c, Pending_Amount__c
                                    FROM Secondary_Invoice__c WHERE Customer__c = :cust.Id];
        System.assertEquals(250, inv.Credit_Adjusted_Amount__c, 'Invoice must not be over-credited');
        System.assertEquals(0, inv.Pending_Amount__c);

        cn1 = [SELECT Status__c, Applied_Invoice_Amount__c FROM Secondary_Credit_Note__c WHERE Id = :cn1.Id];
        cn2 = [SELECT Status__c, Applied_Invoice_Amount__c, Unapplied_Amount__c
               FROM Secondary_Credit_Note__c WHERE Id = :cn2.Id];
        System.assertEquals('Paid', cn1.Status__c);
        System.assertEquals(150, cn1.Applied_Invoice_Amount__c);
        System.assertEquals('Partially Paid', cn2.Status__c);
        System.assertEquals(100, cn2.Applied_Invoice_Amount__c);
        System.assertEquals(50, cn2.Unapplied_Amount__c);
    }

    // ─────────────────────────────────────────
    // Test 6: Auto-apply — open credit consumed by a NEW invoice
    // ─────────────────────────────────────────
    @isTest
    static void testAutoApply_NewInvoiceConsumesOpenCredit() {
        Account dist = getDistributor();
        Account cust = getSecondaryCustomer();

        Secondary_Credit_Note__c cn = makeCreditNote(dist.Id, cust.Id, 200);
        insert cn; // no pending docs -> stays Open

        Test.startTest();
        Secondary_Invoice__c inv = makeInvoice(dist.Id, cust.Id, 500, Date.today());
        insert inv;
        Test.stopTest();

        inv = [SELECT Credit_Adjusted_Amount__c, Pending_Amount__c
               FROM Secondary_Invoice__c WHERE Id = :inv.Id];
        System.assertEquals(200, inv.Credit_Adjusted_Amount__c, 'Open credit auto-applied to new invoice');
        System.assertEquals(300, inv.Pending_Amount__c);

        cn = [SELECT Status__c, Unapplied_Amount__c FROM Secondary_Credit_Note__c WHERE Id = :cn.Id];
        System.assertEquals('Paid', cn.Status__c);
        System.assertEquals(0, cn.Unapplied_Amount__c);
    }

    // ─────────────────────────────────────────
    // Test 7: Auto-apply — open credit consumed by a NEW debit note
    // ─────────────────────────────────────────
    @isTest
    static void testAutoApply_NewDebitNoteConsumesOpenCredit() {
        Account dist = getDistributor();
        Account cust = getSecondaryCustomer();

        Secondary_Credit_Note__c cn = makeCreditNote(dist.Id, cust.Id, 200);
        insert cn;

        Test.startTest();
        Secondary_Debit_Note__c dn = makeDebitNote(dist.Id, cust.Id, 150, Date.today());
        insert dn;
        Test.stopTest();

        dn = [SELECT Credit_Adjusted_Amount__c, Pending_Amount__c
              FROM Secondary_Debit_Note__c WHERE Id = :dn.Id];
        System.assertEquals(150, dn.Credit_Adjusted_Amount__c);
        System.assertEquals(0, dn.Pending_Amount__c);

        cn = [SELECT Status__c, Applied_Debit_Amount__c, Unapplied_Amount__c
              FROM Secondary_Credit_Note__c WHERE Id = :cn.Id];
        System.assertEquals('Partially Paid', cn.Status__c);
        System.assertEquals(150, cn.Applied_Debit_Amount__c);
        System.assertEquals(50, cn.Unapplied_Amount__c);
    }

    // ─────────────────────────────────────────
    // Test 8: Outstanding report shows unapplied credit as a negative row
    // ─────────────────────────────────────────
    @isTest
    static void testOutstandingReport_IncludesCreditNote() {
        Account dist = getDistributor();
        Account cust = getSecondaryCustomer();

        insert makeInvoice(dist.Id, cust.Id, 500, Date.today().addDays(-10));
        Secondary_Credit_Note__c cn = makeCreditNote(dist.Id, cust.Id, 700); // 500 applied, 200 open

        Test.startTest();
        insert cn;
        List<DMSPortalLwc.OutstandingReportItem> report = DMSPortalLwc.getOutstandingReport(cust.Id);
        Test.stopTest();

        Decimal total = 0;
        Boolean creditRowFound = false;
        for (DMSPortalLwc.OutstandingReportItem item : report) {
            total += item.outstandingAmount;
            if (item.documentType == 'Credit Note') {
                creditRowFound = true;
                System.assertEquals(-200, item.outstandingAmount,
                    'Unapplied credit should appear as a negative outstanding row');
            }
        }
        System.assert(creditRowFound, 'Report should contain the credit note row');
        System.assertEquals(-200, total,
            'Invoice fully credited; net outstanding is the open credit only');
    }
}
