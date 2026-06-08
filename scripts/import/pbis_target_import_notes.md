# PBIS Target — Data Import Wizard notes (Task 3)

Load `scripts/import/pbis_target_template.csv` into **PBIS Target** (`PBIS_Target__c`)
using the standard **Setup → Data Import Wizard → Custom objects → PBIS Targets**.

## Operation
- **Add new and update existing records**, matched on the **External Id** field
  (`External_Id__c`). Use a stable key per user+period, e.g. `EMP1001-2026-04-Monthly`.

## Column → field mapping
| CSV column | Target field | Match / notes |
|---|---|---|
| `External_Id` | `External_Id__c` | upsert key (unique) |
| `Sales_Channel` | `Sales_Channel__c` | picklist value (Chanel) |
| `Employee_Code` | `Employee_Code__c` | plain text |
| `User_Username` | `User__c` | lookup to User — match **by Username** |
| `Gross_Salary` | `Gross_Salary__c` | currency |
| `Incentive_Period` | `Incentive_Period__c` | Monthly / Quarterly |
| `Start_Date` / `End_Date` | `Start_Date__c` / `End_Date__c` | yyyy-mm-dd |
| `PBIS_Policy_Name` | `PBIS_Policy__c` | lookup — match **by Name** |
| `Is_Active` | `Is_Active__c` | true / false |
| `S_D_Parameter_N_ExtId` | `S_D_Parameter_N__c` | lookup to S&D Parameter — match **by External Id** (`Sales Channel | Name`) |
| `S_D_Parameter_N_Weightage` | `S_D_Parameter_N_Weightage__c` | percent (the ten must total 100) |
| `S_D_Parameter_N_Target` | `S_D_Parameter_N_Target__c` | number |

`Designation__c` is a formula (`TEXT(User__r.Title)`) and is **not** imported — it
populates from the matched User. The achievement / slab / incentive amount columns are
computed in Task 4 and are left blank on import.

## Validation that fires on save
- **Weightage Must Total 100** — the ten S&D Parameter weightages must sum to 100% (when any
  is entered).
- **Mandatory Parameter Required** — at least one selected S&D Parameter must be a mandatory
  (value/volume gate) parameter (`Is_Mandatory__c = true`), surfaced through the
  `Has_Mandatory_Parameter__c` formula.

## Prerequisite
Run `scripts/apex/seed_sd_parameters.apex` first so each S&D Parameter has its
`External_Id__c` populated (`Sales Channel | Name`) for the S&D Parameter lookups to match.
