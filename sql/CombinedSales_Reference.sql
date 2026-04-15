/*
Reference implementation only (snapshot).
Author: Heagon Lee
Query: Combined Sales Segments (must tie to Generic totals)
Date: 2026-01-19

Usage / Ownership:
- This script is shared for BI reference and reuse.
- BI Team owns any adaptation, validation, and production maintenance going forward.
- Segment precedence is intentional (HU/UM/OP first, then health-system rules, else General).
*/

/* Combined (segments) that MUST tie to Generic totals */

WITH universe AS (  -- row-level universe: same WHERE and joins as Generic
    SELECT
        -- grouping keys used in Generic
        P.FiscalYearPeriodDate,
        C.SalesOfficeCode,
        C.CustomerGroupCode,
        P.BranchNumber,
        CASE WHEN M.PackagingMaterialCode = 'RPCK' THEN 'RPCK' ELSE 'CASE' END AS PackagingMaterialCode,

        -- fields used ONLY to compute Segment
        C.PrimeVendorDealNumber,
        P.BuyingGroupCode,
        C.CustomerNumber,
        C.RgnPostAcuteSaleGrpNumber,

        -- measures kept at row level (no sums here)
        P.RevenueAmount,
        P.SampleSalesAmount,
        P.EmbroiderySalesAmount,
        P.DistributorRebateAccrualAmt,
        P.GroupRebateAccrualAmount,
        P.CustomerIncentiveRebateAmt,
        P.CorporateRebateAccrualAmount,
        P.InvoiceLineNumber,          -- used for Lines
        P.SalesOrderNumber            -- keep if you later need distinct orders
    FROM ProfitabilityAnalysis P
    INNER JOIN MaterialMaster M ON M.MaterialNumber = P.MaterialNumber
    INNER JOIN CustomerMaster C ON C.CustomerNumber = P.CustomerNumber
    WHERE P.FiscalYearDate IN ('2025','2024')
      AND C.SalesOfficeCode NOT IN ('IC')
      AND P.BranchNumber NOT IN ('DIR','B52','RDM','PDM','B04','LRD','S02','TEM','SAMP','SHR','K44')
      AND P.ProdDivCd NOT IN ('12','95','83','11','98','13','01')
      AND P.VendorRebateAccrualAmount = '0.00'
      AND P.BillingTypeCode IN ('F2')
      AND P.MaterialCategoryGroupCode IN ('NORM')
      AND P.CostElementCode NOT IN ('0000410998')
      AND P.ReferenceProcedureCode NOT IN ('XIPAC','XIPST')
),
segmented_rows AS (   -- assign exactly ONE segment per row (ordered precedence)
    SELECT
        u.*,
        CASE
            -- If you want HU/UM/OP to be carved out first, keep these on top.
            -- If you want health-systems to win, move these three BELOW the 5 rules.
            WHEN u.CustomerGroupCode = 'HU' THEN 'CGC_HU'
            WHEN u.CustomerGroupCode = 'UM' THEN 'CGC_UM'
            WHEN u.CustomerGroupCode = 'OP' THEN 'CGC_OP'

            -- Health systems (most specific → broader)
            WHEN u.BuyingGroupCode IN ('GRP_A','GRP_B')
                 AND u.CustomerNumber IN ('CUSTOMER_A','CUSTOMER_B','CUSTOMER_C','CUSTOMER_D','CUSTOMER_E','CUSTOMER_F')
                 THEN 'HEALTH_SYSTEM_A'
            WHEN u.BuyingGroupCode IN ('GRP_C','GRP_D')
                 AND u.RgnPostAcuteSaleGrpNumber = 'SEG_CODE_A'
                 THEN 'HEALTH_SYSTEM_B'
            WHEN u.PrimeVendorDealNumber LIKE '%XXXXXX' THEN 'HEALTH_SYSTEM_C'
            WHEN u.BuyingGroupCode = 'GRP_E'  THEN 'HEALTH_SYSTEM_D'
            WHEN u.BuyingGroupCode = 'GRP_F' THEN 'HEALTH_SYSTEM_E'

            ELSE 'General'
        END AS Segment
    FROM universe u
)
SELECT
    FiscalYearPeriodDate,
    SalesOfficeCode,
    CustomerGroupCode,
    BranchNumber,
    PackagingMaterialCode,
    Segment,
    SUM(RevenueAmount + SampleSalesAmount + EmbroiderySalesAmount) AS GrossSales,
    SUM(RevenueAmount + SampleSalesAmount + EmbroiderySalesAmount
        + DistributorRebateAccrualAmt + GroupRebateAccrualAmount
        + CustomerIncentiveRebateAmt + CorporateRebateAccrualAmount) AS NetSales,
    COUNT(InvoiceLineNumber) AS Lines
FROM segmented_rows
GROUP BY
    FiscalYearPeriodDate, SalesOfficeCode, CustomerGroupCode,
    BranchNumber, PackagingMaterialCode, Segment;
/*
Reference implementation only (snapshot).
Author: <YOUR NAME>
Query: Combined Sales Segments (must tie to Generic totals)
Date: 2026-01-19

Usage / Ownership:
- This script is shared for BI reference and reuse.
- BI Team owns any adaptation, validation, and production maintenance going forward.
- Segment precedence is intentional (HU/UM/OP first, then health-system rules, else General).
*/

/* Combined (segments) that MUST tie to Generic totals */

WITH universe AS (  -- row-level universe: same WHERE and joins as Generic
    SELECT
        -- grouping keys used in Generic
        P.FiscalYearPeriodDate,
        C.SalesOfficeCode,
        C.CustomerGroupCode,
        P.BranchNumber,
        CASE WHEN M.PackagingMaterialCode = 'RPCK' THEN 'RPCK' ELSE 'CASE' END AS PackagingMaterialCode,

        -- fields used ONLY to compute Segment
        C.PrimeVendorDealNumber,
        P.BuyingGroupCode,
        C.CustomerNumber,
        C.RgnPostAcuteSaleGrpNumber,

        -- measures kept at row level (no sums here)
        P.RevenueAmount,
        P.SampleSalesAmount,
        P.EmbroiderySalesAmount,
        P.DistributorRebateAccrualAmt,
        P.GroupRebateAccrualAmount,
        P.CustomerIncentiveRebateAmt,
        P.CorporateRebateAccrualAmount,
        P.InvoiceLineNumber,          -- used for Lines
        P.SalesOrderNumber            -- keep if you later need distinct orders
    FROM ProfitabilityAnalysis P
    INNER JOIN MaterialMaster M ON M.MaterialNumber = P.MaterialNumber
    INNER JOIN CustomerMaster C ON C.CustomerNumber = P.CustomerNumber
    WHERE P.FiscalYearDate IN ('2025','2024')
      AND C.SalesOfficeCode NOT IN ('IC')
      AND P.BranchNumber NOT IN ('DIR','B52','RDM','PDM','B04','LRD','S02','TEM','SAMP','SHR','K44')
      AND P.ProdDivCd NOT IN ('12','95','83','11','98','13','01')
      AND P.VendorRebateAccrualAmount = '0.00'
      AND P.BillingTypeCode IN ('F2')
      AND P.MaterialCategoryGroupCode IN ('NORM')
      AND P.CostElementCode NOT IN ('0000410998')
      AND P.ReferenceProcedureCode NOT IN ('XIPAC','XIPST')
),
segmented_rows AS (   -- assign exactly ONE segment per row (ordered precedence)
    SELECT
        u.*,
        CASE
            -- If you want HU/UM/OP to be carved out first, keep these on top.
            -- If you want health-systems to win, move these three BELOW the 5 rules.
            WHEN u.CustomerGroupCode = 'HU' THEN 'CGC_HU'
            WHEN u.CustomerGroupCode = 'UM' THEN 'CGC_UM'
            WHEN u.CustomerGroupCode = 'OP' THEN 'CGC_OP'

            -- Health systems (most specific → broader)
            WHEN u.BuyingGroupCode IN ('GRP_A','GRP_B')
                 AND u.CustomerNumber IN ('CUSTOMER_A','CUSTOMER_B','CUSTOMER_C','CUSTOMER_D','CUSTOMER_E','CUSTOMER_F')
                 THEN 'HEALTH_SYSTEM_A'
            WHEN u.BuyingGroupCode IN ('GRP_C','GRP_D')
                 AND u.RgnPostAcuteSaleGrpNumber = 'SEG_CODE_A'
                 THEN 'HEALTH_SYSTEM_B'
            WHEN u.PrimeVendorDealNumber LIKE '%XXXXXX' THEN 'HEALTH_SYSTEM_C'
            WHEN u.BuyingGroupCode = 'GRP_E'  THEN 'HEALTH_SYSTEM_D'
            WHEN u.BuyingGroupCode = 'GRP_F' THEN 'HEALTH_SYSTEM_E'

            ELSE 'General'
        END AS Segment
    FROM universe u
)
SELECT
    FiscalYearPeriodDate,
    SalesOfficeCode,
    CustomerGroupCode,
    BranchNumber,
    PackagingMaterialCode,
    Segment,
    SUM(RevenueAmount + SampleSalesAmount + EmbroiderySalesAmount) AS GrossSales,
    SUM(RevenueAmount + SampleSalesAmount + EmbroiderySalesAmount
        + DistributorRebateAccrualAmt + GroupRebateAccrualAmount
        + CustomerIncentiveRebateAmt + CorporateRebateAccrualAmount) AS NetSales,
    COUNT(InvoiceLineNumber) AS Lines
FROM segmented_rows
GROUP BY
    FiscalYearPeriodDate, SalesOfficeCode, CustomerGroupCode,
    BranchNumber, PackagingMaterialCode, Segment;
