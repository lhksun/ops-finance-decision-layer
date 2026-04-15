# ops-finance-decision-layer

Sales segmentation logic was scattered across reports.
Commercial reporting required manual merges that no one fully owned.
STIP and CPDash couldn't be joined cleanly because SoldTo-level data
caused row explosion at the reporting grain.

This repo consolidates that into a validated, single-source decision layer
built on Microsoft Fabric.

---

## What This Is

A collection of SQL views, Fabric notebooks, and architecture documentation
covering three connected finance analytics systems:

1. **Combined Sales & Segmentation** — unified sales view with deterministic customer segment classification
2. **STIP / CPDash Integration** — Medline Brand sales analytics joined with cost profitability KPIs
3. **Non-Payroll Expense Reporting** — automated expense pipeline replacing manual Alteryx-based processing

All three share the same design principle:
find the source of complexity, establish a clean grain, rebuild from there.

---

## 1. Combined Sales & Segmentation

### The Problem

Customer segment classification existed in multiple places with inconsistent rules.
Sales and freight data used different segmentation logic,
so cross-domain analysis produced numbers that didn't tie.

### The Solution

A single `segmented_rows` CTE with explicit, ordered precedence rules:

```sql
CASE
    WHEN CustomerGroupCode = 'HU' THEN 'CGC_HU'   -- CGC codes first
    WHEN CustomerGroupCode = 'UM' THEN 'CGC_UM'
    WHEN CustomerGroupCode = 'OP' THEN 'CGC_OP'
    WHEN [health system rule A]   THEN 'HEALTH_SYSTEM_A'
    WHEN [health system rule B]   THEN 'HEALTH_SYSTEM_B'
    ...
    ELSE 'General'
END AS Segment
```

One segment per row. No ambiguity. Precedence is documented, not implicit.

The output ties exactly to Generic totals — validated via EXCEPT tests
before any dashboard consumed it.

---

## 2. STIP / CPDash Integration

### The Problem

STIP (sales profitability) and CPDash (cost profitability) both needed
customer-level filtering, but keeping `SoldToNumber` in the output grain
caused row explosion and performance degradation.

### The Architecture

Six layers, each with a single responsibility:

```
Layer 0  CustomerMaster → Customer Segment Set
         (derive segments, define valid SoldTo filter set)

Layer 1  STIP Source Fact
         → filter by customer segment set
         → apply base filters (period, office, product division)

Layer 2  STIP Aggregated
         → remove SoldTo, aggregate to reporting grain
         (Period · SalesOffice · ProdDiv · MatGrp · CustomerSegment)

Layer 3  CPDash Source Fact
         → same customer join logic as STIP
         → numeric normalization

Layer 4  CPDash Aggregated + KPI Calculation
         → same grain as STIP
         → PPDWriteOff% · COGSManAdj% · Absorption% · OutboundFreight%

Layer 5  MaterialMaster dimension
         → deduplicated at MaterialGroup level
         → joined only after fact aggregation

Layer 6  Final Consumption View
         → single flat dataset for Excel / Power BI
         → no Power Query merges required at consumption layer
```

**Key design decision:** SoldTo is used for filtering upstream and dropped before aggregation.
Dimensions are joined last. Facts are aggregated before being joined together.
This eliminates join explosion and makes the output grain stable and predictable.

---

## 3. Non-Payroll Expense Reporting

Automated weekly expense dashboard replacing an Alteryx-based pipeline.

The original Alteryx flow required manual intervention at month-end
and produced results that didn't reconcile cleanly with GL data.
The replacement runs in Fabric with Power Query,
validated against the source on initial deployment.

*Note: Dashboard file contains modified data for confidentiality.*

---

## Contents

```
ops-finance-decision-layer/
├── sql/
│   └── CombinedSales_Reference.sql       # Segmentation logic reference implementation
├── notebooks/
│   ├── Combined_Sales.ipynb              # vw_CombinedSales view definition (Fabric/Spark SQL)
│   ├── CombinedSales_Validation.ipynb    # Validation: segment totals vs Generic totals
│   ├── Sales_PV_Deal_Model_Medline_Brand.ipynb  # STIP filtered + aggregated views
│   ├── STIP_Sales_PV.ipynb               # MatGrp dedup dimension + STIP summary current
│   ├── STIPxCPDash.ipynb                 # Final consumption view: STIP × CPDash join
│   └── CP_dash_Profitability_Filtered.ipynb     # CPDash filtered pipeline
├── diagrams/
│   ├── stip_cpdash_architecture.svg      # 6-layer architecture flowchart
│   └── combined_sales_flow.svg           # Combined Sales data flow
└── README.md
```

---

## Context

Built at a national healthcare distribution company.

The Combined Sales segmentation work came out of a cross-functional request —
the commercial analytics team needed freight and sales data to align
on a shared customer classification. The logic didn't exist in a single place.
This implementation established that canonical definition.

The STIP/CPDash architecture was designed in response to a performance problem:
an earlier version kept SoldTo in the output grain, which caused the query
to time out in production. The 6-layer approach resolved it by separating
filtering, aggregation, and dimension enrichment into distinct stages.

**Stack:** Microsoft Fabric · Synapse SQL · Spark SQL · Power Query · Power BI

---

## Related

- [`freight-canonical-model`](https://github.com/lhksun/freight-canonical-model) — Canonical freight data layer with FedEx SafeLayer
- [`gap-trading-engine`](https://github.com/lhksun/gap-trading-engine) — Rule-based intraday trading system
