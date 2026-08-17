# CourseForge: End-to-End Data Warehouse & Analytics Pipeline

A complete data warehouse lifecycle built for a fictional online learning platform — from a normalized transactional schema through an automated ETL pipeline to a live BI dashboard.

Built for CS779 (Advanced Database Management), Boston University.

## Overview

CourseForge simulates an online learning platform (think Udemy) where students enroll in instructor-authored courses, complete quizzes, and make payments. This project takes that domain through the full OLTP → ETL → OLAP lifecycle:

- **20-table normalized OLTP schema** (3NF/BCNF), modeling content, assessment, commerce, and supporting entities
- **Star schema data warehouse** — `fact_quiz_attempt` (grain: one row per quiz attempt, 5 measures) surrounded by 5 dimensions
- **Type 2 Slowly Changing Dimension** logic on `dim_course`, preserving historical pricing/category accuracy
- **Fully automated ETL** via 7 PostgreSQL stored procedures — no external tooling
- **Analytical SQL** covering `ROLLUP`, `CUBE`, and three window-function techniques
- **Power BI dashboard** connected directly to the warehouse, validated against SQL output

## Architecture

```
OLTP (20 tables, normalized)
        │
        ▼
  ETL Pipeline (7 stored procedures)
        │
        ▼
Star Schema Warehouse (1 fact + 5 dimensions)
        │
        ▼
Analytical SQL (ROLLUP / CUBE / Window Functions)
        │
        ▼
   Power BI Dashboard
```

## Repository structure

```
├── sql/
│   ├── 1_create_oltp_tables_v2.sql       # 20-table normalized OLTP schema
│   ├── create_dw_tables.sql              # Star schema (fact + 5 dimensions)
│   ├── stored_procedures.sql             # 7-procedure ETL pipeline (incl. SCD2)
│   ├── analytical_queries.sql            # ROLLUP, CUBE, window functions
│   └── 2_star-schema_proof_queries.sql   # Grain / join / SCD2 verification
├── diagrams/
│   ├── oltp_erd.png                      # Full OLTP entity-relationship diagram
│   └── star_schema_erd.png               # Fact/dimension star schema diagram
├── docs/
│   └── CS779_TermProject_Final.pdf       # Full written project report
└── dashboard/
    └── powerbi_screenshots/              # Dashboard visuals, mapped to queries
```

## Key design decisions

**Grain-first design.** `fact_quiz_attempt` was designed around a single, explicit grain — one row per quiz attempt — before anything else was built. Every dimension and every analytical query traces back to that decision.

**Type 2 SCD on `dim_course` only.** Price and category are attributes where losing history would make past facts look wrong when reported today; other dimensions (`dim_student`, `dim_instructor`, `dim_quiz`) stay Type 1, since their attributes don't carry the same historical-reporting risk.

**Stored-procedure ETL, not external tooling.** Keeping transformation logic in the database, close to the data, made the entire pipeline runnable with a single `CALL sp_run_full_etl()`.

## A real debugging story

The first version of the ETL pipeline produced **zero rows** in `fact_quiz_attempt`. Root cause: new `dim_course` rows were stamped with `effective_date = CURRENT_DATE`, while historical quiz attempts occurred before today — so the fact table's effective-date range join could never find a match.

**Fix:** a course's first-ever version is backdated to a fixed point safely before any real data (`2000-01-01`), and `CURRENT_DATE` is reserved specifically for genuine, detected changes. This is documented in detail in `docs/CS779_TermProject_Final.pdf`, Section 4.2.

## Sample results

**Query 1 — Pass rate by category (ROLLUP):**

| Category | Pass Rate |
|---|---|
| Marketing | 76.1% |
| Programming | 72.9% |
| ... | ... |
| **All Categories** | **69.2%** |
| Data Science | 60.3% |

**Query 5 — Attempt drop-off funnel:**

| Attempt # | % of First Attempts |
|---|---|
| 1st | 100.0% |
| 2nd | 76.3% |
| 3rd | 39.6% |

Full query set and findings are in `sql/analytical_queries.sql` and the project report.

## Tech stack

`PostgreSQL` · `SQL (stored procedures, window functions, ROLLUP/CUBE)` · `Python (Faker)` for synthetic data generation · `Power BI`

## Author

Sharmila Gopal — [LinkedIn](#) · MS Applied Data Analytics, Boston University
