@isTest
private class SecondaryNoteUploadControllerTest {

    @TestSetup
    static void setupData() {
        Account distributor = new Account(
            Name = 'Test Distributor',
            Customer_Type__c = 'Secondary Customer',
            State__c = 'Bihar',
            District__c = 'Patna'
        );
        insert distributor;

        List<Account> customers = new List<Account>{
            new Account(
                Name = 'Customer One',
                Customer_Type__c = 'Secondary Customer',
                State__c = 'Bihar',
                District__c = 'Patna'
            ),
            new Account(
                Name = 'Customer Two',
                Customer_Type__c = 'Secondary Customer',
                State__c = 'Bihar',
                District__c = 'Patna'
            )
        };
        insert customers;

        Contact con = new Contact(
            FirstName = 'Test',
            LastName = 'Partner',
            AccountId = distributor.Id
        );
        insert con;

        User adminUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs(adminUser) {
            Profile p = [SELECT Id FROM Profile WHERE Name = 'Partner Community User' LIMIT 1];
            String uniqueStr = String.valueOf(DateTime.now().getTime());
            User u = new User(
                FirstName = 'Upload', LastName = 'Partner',
                Email = 'snupload' + uniqueStr + '@test.com',
                Username = 'snupload' + uniqueStr + '@test.com.upload',
                Alias = 'snup', TimeZoneSidKey = 'Asia/Kolkata',
                LocaleSidKey = 'en_IN', EmailEncodingKey = 'UTF-8',
                LanguageLocaleKey = 'en_US', ProfileId = p.Id, ContactId = con.Id,
                Employee_Code__c = 'EMPUP' + uniqueStr
            );
            insert u;
        }
    }

    private static User getPartnerUser() {
        return [SELECT Id FROM User WHERE Username LIKE 'snupload%' AND IsActive = true LIMIT 1];
    }

    private static List<String> getCustomerCodes() {
        List<String> codes = new List<String>();
        for (Account a : [
            SELECT Customer_Code__c
            FROM Account
            WHERE Name IN ('Customer One', 'Customer Two')
            ORDER BY Name ASC
        ]) {
            codes.add(a.Customer_Code__c);
        }
        return codes;
    }

    // ─── uploadCreditNotes ─────────────────────────────────────────────────────

    @isTest
    static void testUploadCreditNotes_BlankInput() {
        Test.startTest();
        SecondaryNoteUploadController.uploadCreditNotes(null);
        SecondaryNoteUploadController.uploadCreditNotes('');
        Test.stopTest();
    }

    @isTest
    static void testUploadCreditNotes_AllSuccess() {
        User u = getPartnerUser();
        List<String> codes = getCustomerCodes();

        List<Map<String, Object>> rows = new List<Map<String, Object>>{
            new Map<String, Object>{
                'customerCode' => codes[0],
                'creditDate'   => '2025-01-15',
                'amount'       => '250.50',
                'reason'       => 'Price Difference',
                'description'  => 'Bulk credit note'
            },
            new Map<String, Object>{
                'customerCode' => codes[1],
                'creditDate'   => '15-01-2025',
                'amount'       => '99',
                'reason'       => 'Invoice Errors',
                'description'  => ''
            }
        };

        Test.startTest();
        System.runAs(u) {
            SecondaryNoteUploadController.uploadCreditNotes(JSON.serialize(rows));
        }
        Test.stopTest();
    }

    @isTest
    static void testUploadCreditNotes_DateFormat_DDMMYYYY_Slash() {
        User u = getPartnerUser();
        List<String> codes = getCustomerCodes();

        List<Map<String, Object>> rows = new List<Map<String, Object>>{
            new Map<String, Object>{
                'customerCode' => codes[0],
                'creditDate'   => '15/01/2025',
                'amount'       => '150',
                'reason'       => 'Price Difference',
                'description'  => 'slash format'
            }
        };

        Test.startTest();
        System.runAs(u) {
            SecondaryNoteUploadController.uploadCreditNotes(JSON.serialize(rows));
        }
        Test.stopTest();
    }

    @isTest
    static void testUploadCreditNotes_MixedValidAndInvalid() {
        List<String> codes = getCustomerCodes();

        List<Map<String, Object>> rows = new List<Map<String, Object>>{
            new Map<String, Object>{
                'customerCode' => codes[0],
                'creditDate'   => '15/01/2025',
                'amount'       => '150',
                'reason'       => 'Price Difference',
                'description'  => 'valid slash format'
            },
            new Map<String, Object>{
                'customerCode' => codes[1],
                'creditDate'   => '2025-02-20',
                'amount'       => '-5',
                'reason'       => 'Invoice Errors',
                'description'  => 'negative amount'
            }
        };

        Test.startTest();
        SecondaryNoteUploadController.uploadCreditNotes(JSON.serialize(rows));
        Test.stopTest();
    }

    @isTest
    static void testUploadCreditNotes_MissingCustomerCode() {
        List<Map<String, Object>> rows = new List<Map<String, Object>>{
            new Map<String, Object>{
                'customerCode' => '',
                'creditDate'   => '2025-01-15',
                'amount'       => '100',
                'reason'       => 'Price Difference',
                'description'  => 'no code'
            }
        };

        Test.startTest();
        SecondaryNoteUploadController.uploadCreditNotes(JSON.serialize(rows));
        Test.stopTest();
    }

    @isTest
    static void testUploadCreditNotes_MissingDate() {
        List<String> codes = getCustomerCodes();

        List<Map<String, Object>> rows = new List<Map<String, Object>>{
            new Map<String, Object>{
                'customerCode' => codes[0],
                'creditDate'   => '',
                'amount'       => '100',
                'reason'       => 'Price Difference',
                'description'  => 'no date'
            }
        };

        Test.startTest();
        SecondaryNoteUploadController.uploadCreditNotes(JSON.serialize(rows));
        Test.stopTest();
    }

    @isTest
    static void testUploadCreditNotes_InvalidDateFormats() {
        List<String> codes = getCustomerCodes();

        List<Map<String, Object>> rows = new List<Map<String, Object>>{
            new Map<String, Object>{
                'customerCode' => codes[0],
                'creditDate'   => '13|01|2025',
                'amount'       => '100',
                'reason'       => 'Price Difference',
                'description'  => 'pipe separator'
            },
            new Map<String, Object>{
                'customerCode' => codes[0],
                'creditDate'   => 'aa-bb-cccc',
                'amount'       => '100',
                'reason'       => 'Price Difference',
                'description'  => 'unparseable'
            },
            new Map<String, Object>{
                'customerCode' => codes[0],
                'creditDate'   => '2025-01',
                'amount'       => '100',
                'reason'       => 'Price Difference',
                'description'  => 'short date'
            },
            new Map<String, Object>{
                'customerCode' => codes[0],
                'creditDate'   => '25-01-25',
                'amount'       => '100',
                'reason'       => 'Price Difference',
                'description'  => 'ambiguous date'
            }
        };

        Test.startTest();
        SecondaryNoteUploadController.uploadCreditNotes(JSON.serialize(rows));
        Test.stopTest();
    }

    @isTest
    static void testUploadCreditNotes_InvalidAmount() {
        List<String> codes = getCustomerCodes();

        List<Map<String, Object>> rows = new List<Map<String, Object>>{
            new Map<String, Object>{
                'customerCode' => codes[0],
                'creditDate'   => '2025-01-15',
                'amount'       => '',
                'reason'       => 'Price Difference',
                'description'  => 'blank amount'
            },
            new Map<String, Object>{
                'customerCode' => codes[0],
                'creditDate'   => '2025-01-15',
                'amount'       => 'abc',
                'reason'       => 'Price Difference',
                'description'  => 'non-numeric amount'
            },
            new Map<String, Object>{
                'customerCode' => codes[0],
                'creditDate'   => '2025-01-15',
                'amount'       => '0',
                'reason'       => 'Price Difference',
                'description'  => 'zero amount'
            },
            new Map<String, Object>{
                'customerCode' => codes[0],
                'creditDate'   => '2025-01-15',
                'amount'       => '-10',
                'reason'       => 'Price Difference',
                'description'  => 'negative amount'
            }
        };

        Test.startTest();
        SecondaryNoteUploadController.uploadCreditNotes(JSON.serialize(rows));
        Test.stopTest();
    }

    @isTest
    static void testUploadCreditNotes_UnknownCustomerCode() {
        List<Map<String, Object>> rows = new List<Map<String, Object>>{
            new Map<String, Object>{
                'customerCode' => 'NOSUCH999',
                'creditDate'   => '2025-01-15',
                'amount'       => '100',
                'reason'       => 'Price Difference',
                'description'  => 'unknown code'
            }
        };

        Test.startTest();
        SecondaryNoteUploadController.uploadCreditNotes(JSON.serialize(rows));
        Test.stopTest();
    }

    @isTest
    static void testUploadCreditNotes_AllValidationErrorsCombined() {
        List<Map<String, Object>> rows = new List<Map<String, Object>>{
            new Map<String, Object>{
                'customerCode' => '',
                'creditDate'   => '',
                'amount'       => '',
                'reason'       => '',
                'description'  => 'all blank'
            }
        };

        Test.startTest();
        SecondaryNoteUploadController.uploadCreditNotes(JSON.serialize(rows));
        Test.stopTest();
    }

    @isTest
    static void testUploadCreditNotes_AsPartnerUserPopulatesDistributor() {
        User u = getPartnerUser();
        List<String> codes = getCustomerCodes();

        List<Map<String, Object>> rows = new List<Map<String, Object>>{
            new Map<String, Object>{
                'customerCode' => codes[0],
                'creditDate'   => '2025-03-01',
                'amount'       => '500',
                'reason'       => 'Discounts or Rebates',
                'description'  => 'partner upload'
            }
        };

        Test.startTest();
        System.runAs(u) {
            SecondaryNoteUploadController.uploadCreditNotes(JSON.serialize(rows));
        }
        Test.stopTest();
    }

    // ─── uploadDebitNotes ──────────────────────────────────────────────────────

    @isTest
    static void testUploadDebitNotes_BlankInput() {
        Test.startTest();
        SecondaryNoteUploadController.uploadDebitNotes(null);
        SecondaryNoteUploadController.uploadDebitNotes('');
        Test.stopTest();
    }

    @isTest
    static void testUploadDebitNotes_AllSuccess() {
        User u = getPartnerUser();
        List<String> codes = getCustomerCodes();

        List<Map<String, Object>> rows = new List<Map<String, Object>>{
            new Map<String, Object>{
                'customerCode' => codes[0],
                'noteDate'     => '2025-01-10',
                'amount'       => '300',
                'reason'       => 'Short Payment',
                'description'  => 'd1'
            },
            new Map<String, Object>{
                'customerCode' => codes[1],
                'noteDate'     => '10/01/2025',
                'amount'       => '450.75',
                'reason'       => 'Penalty',
                'description'  => ''
            }
        };

        Test.startTest();
        System.runAs(u) {
            SecondaryNoteUploadController.uploadDebitNotes(JSON.serialize(rows));
        }
        Test.stopTest();
    }

    @isTest
    static void testUploadDebitNotes_DateFormat_DDMMYYYY() {
        User u = getPartnerUser();
        List<String> codes = getCustomerCodes();

        List<Map<String, Object>> rows = new List<Map<String, Object>>{
            new Map<String, Object>{
                'customerCode' => codes[0],
                'noteDate'     => '10-01-2025',
                'amount'       => '200',
                'reason'       => 'Penalty',
                'description'  => 'dash format'
            }
        };

        Test.startTest();
        System.runAs(u) {
            SecondaryNoteUploadController.uploadDebitNotes(JSON.serialize(rows));
        }
        Test.stopTest();
    }

    @isTest
    static void testUploadDebitNotes_MissingCustomerCode() {
        List<Map<String, Object>> rows = new List<Map<String, Object>>{
            new Map<String, Object>{
                'customerCode' => '',
                'noteDate'     => '2025-01-15',
                'amount'       => '100',
                'reason'       => 'Penalty',
                'description'  => 'no code'
            }
        };

        Test.startTest();
        SecondaryNoteUploadController.uploadDebitNotes(JSON.serialize(rows));
        Test.stopTest();
    }

    @isTest
    static void testUploadDebitNotes_MissingDate() {
        List<String> codes = getCustomerCodes();

        List<Map<String, Object>> rows = new List<Map<String, Object>>{
            new Map<String, Object>{
                'customerCode' => codes[0],
                'noteDate'     => '',
                'amount'       => '100',
                'reason'       => 'Penalty',
                'description'  => 'no date'
            }
        };

        Test.startTest();
        SecondaryNoteUploadController.uploadDebitNotes(JSON.serialize(rows));
        Test.stopTest();
    }

    @isTest
    static void testUploadDebitNotes_InvalidDateFormat() {
        List<String> codes = getCustomerCodes();

        List<Map<String, Object>> rows = new List<Map<String, Object>>{
            new Map<String, Object>{
                'customerCode' => codes[0],
                'noteDate'     => '13|01|2025',
                'amount'       => '100',
                'reason'       => 'Penalty',
                'description'  => 'pipe separator'
            },
            new Map<String, Object>{
                'customerCode' => codes[0],
                'noteDate'     => '13-13-2025',
                'amount'       => '100',
                'reason'       => 'Penalty',
                'description'  => 'invalid month'
            }
        };

        Test.startTest();
        SecondaryNoteUploadController.uploadDebitNotes(JSON.serialize(rows));
        Test.stopTest();
    }

    @isTest
    static void testUploadDebitNotes_InvalidAmount() {
        List<String> codes = getCustomerCodes();

        List<Map<String, Object>> rows = new List<Map<String, Object>>{
            new Map<String, Object>{
                'customerCode' => codes[0],
                'noteDate'     => '2025-01-15',
                'amount'       => 'abc',
                'reason'       => 'Penalty',
                'description'  => 'non-numeric'
            },
            new Map<String, Object>{
                'customerCode' => codes[0],
                'noteDate'     => '2025-01-15',
                'amount'       => '0',
                'reason'       => 'Penalty',
                'description'  => 'zero'
            },
            new Map<String, Object>{
                'customerCode' => codes[0],
                'noteDate'     => '2025-01-15',
                'amount'       => '-50',
                'reason'       => 'Penalty',
                'description'  => 'negative'
            }
        };

        Test.startTest();
        SecondaryNoteUploadController.uploadDebitNotes(JSON.serialize(rows));
        Test.stopTest();
    }

    @isTest
    static void testUploadDebitNotes_UnknownCustomerCode() {
        List<Map<String, Object>> rows = new List<Map<String, Object>>{
            new Map<String, Object>{
                'customerCode' => 'UNKNOWN999',
                'noteDate'     => '2025-01-15',
                'amount'       => '100',
                'reason'       => 'Penalty',
                'description'  => 'unknown'
            }
        };

        Test.startTest();
        SecondaryNoteUploadController.uploadDebitNotes(JSON.serialize(rows));
        Test.stopTest();
    }

    @isTest
    static void testUploadDebitNotes_AllValidationErrorsCombined() {
        List<Map<String, Object>> rows = new List<Map<String, Object>>{
            new Map<String, Object>{
                'customerCode' => '',
                'noteDate'     => '',
                'amount'       => '',
                'reason'       => '',
                'description'  => 'all blank'
            }
        };

        Test.startTest();
        SecondaryNoteUploadController.uploadDebitNotes(JSON.serialize(rows));
        Test.stopTest();
    }

    @isTest
    static void testUploadDebitNotes_MixedValidAndInvalid() {
        List<String> codes = getCustomerCodes();

        List<Map<String, Object>> rows = new List<Map<String, Object>>{
            new Map<String, Object>{
                'customerCode' => codes[0],
                'noteDate'     => '2025-01-10',
                'amount'       => '300',
                'reason'       => 'Short Payment',
                'description'  => 'valid'
            },
            new Map<String, Object>{
                'customerCode' => 'BADCODE',
                'noteDate'     => '2025-01-11',
                'amount'       => '200',
                'reason'       => 'Penalty',
                'description'  => 'unknown code'
            }
        };

        Test.startTest();
        SecondaryNoteUploadController.uploadDebitNotes(JSON.serialize(rows));
        Test.stopTest();
    }

    @isTest
    static void testUploadDebitNotes_AsPartnerUserPopulatesDistributor() {
        User u = getPartnerUser();
        List<String> codes = getCustomerCodes();

        List<Map<String, Object>> rows = new List<Map<String, Object>>{
            new Map<String, Object>{
                'customerCode' => codes[0],
                'noteDate'     => '2025-04-01',
                'amount'       => '600',
                'reason'       => 'Short Payment',
                'description'  => 'partner debit upload'
            }
        };

        Test.startTest();
        System.runAs(u) {
            SecondaryNoteUploadController.uploadDebitNotes(JSON.serialize(rows));
        }
        Test.stopTest();
    }
}