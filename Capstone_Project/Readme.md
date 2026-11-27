# EU Imports & Deforestation: Is the Data EUDR-Ready?

An end-to-end data analytics project on **EU-27 imports of EUDR commodities since 2020** and the deforestation linked to them, built with **Python, PostgreSQL, dbt and Tableau**.

> **Key question:** When the EU Deforestation Regulation (EUDR) applies on **30 December 2026**, could today's public trade data prove that EU imports are "deforestation-free"?

---

## Background: the EUDR

The **EU Deforestation Regulation** (Regulation (EU) 2023/1115) bans soy, palm oil, cocoa, coffee, cattle, wood and rubber from the EU market if they were produced on land **deforested after 31 December 2020**. Companies must prove compliance with a due diligence statement and the **geolocation of every production plot**. The rules apply from 30 December 2026 for large and medium companies, and from 30 June 2027 for micro and small companies.

---

## Key findings

| # | Learning | Evidence |
|---|---|---|
| 1 | **Volume is not the same as risk** | Soy causes the most deforestation in total, but beef carries ~4× more risk per dollar (59 vs 15 ha per $1M) |
| 2 | **Progress is uneven** | Palm oil −36% deforestation per tonne; soy +90% (4.2 → 8.0 ha per 1,000 t); beef flat at ~230 ha per 1,000 t |
| 3 | **Risk is highly concentrated** | Mostly from Brazil; Spain, Italy and the Netherlands carry 72% of non-cocoa exposure |
| 4 | **Mismatches flag audit priorities** | Soy volume fell in 2022 while its risk per tonne rose |
| 5 | **Data gaps change the picture** | Country rankings shift depending on which datasets are published |
| 6 | **Public data is not EUDR-ready** | Only **13 of 72** commodity-years are complete; **77%** of EU import volume since 2021 (30.2 of 39.4 M t) has no post-2020 deforestation measure |

> *A regulation is only as strong as the data behind it. Companies will need their own plot-level traceability.*

---

## Data

**Source:** [Trase](https://trase.earth), supply-chain datasets linking trade flows to production regions and deforestation.

**Scope:**
- **12 datasets**, **6 commodities**, **6 origin countries**
- **Destinations:** EU-27 only (the UK is removed; Trase still tags it as EU)
- **Trade years:** 2020 onward

| Commodity | Origin(s) | Deforestation metric |
|---|---|---|
| Soy | Brazil | 5-yr exposure |
| Beef | Brazil | 5-yr exposure |
| Palm oil | Indonesia | 10-yr exposure + annual (post-2020) |
| Wood pulp | Indonesia | 10-yr exposure + annual (post-2020) |
| Cocoa | Côte d'Ivoire, Ecuador, Peru, Colombia, Indonesia | 15-yr exposure (Côte d'Ivoire only) |
| Coffee | Colombia, Peru, Indonesia | None published |

Raw files are **not included** in this repository (size and licensing). Download them from Trase and place them in `eudr_project/raw/`.

---

## Pipeline

```
Trase CSVs ──► Python (pandas) ──► PostgreSQL ──► dbt ──► Tableau
   raw          extract & clean      load          transform    presentation
```

| Phase | Tool | What happens |
|---|---|---|
| **Extract & clean** | Python / pandas | Filter to EU-27 and 2020+, remove the UK, merge 12 files into one standard schema, add quality flags (outliers, missing values, duplicates, origin known) |
| **Load** | PostgreSQL | Bulk-load **336,492 rows** into `raw.fact_trade_flows` with `COPY` |
| **Transform** | dbt | Staging → prep → marts, with **37 data tests**, all passing |
| **Present** | Tableau | Dashboards and a story built only on mart tables |

### dbt layers

| Layer | Materialisation | Models |
|---|---|---|
| **staging** | view | `stg_trade_flows` |
| **prep** | view | `prep_coverage` (data availability per dataset-year), `prep_projections` |
| **marts** | table | `mart_kpi_yearly`, `mart_trade_flows`, `mart_sankey_flows`, `mart_geo_origins`, `mart_data_gaps` |
| **seeds** | table | `dim_country` (EU-27 + origins), `dataset_catalog` |

**Custom tests** include:
- only EU-27 destinations
- one coverage row per dataset-year
- projections never overwrite actuals and are never negative
- no internal gaps in year coverage
- marts reconcile with staging

### Projections
Years Trase hasn't published yet are filled with a **simple carry-forward**, not a forecast:
- **Volume** = average of the last 3 reported years (at least 3 years needed)
- **Deforestation** = average ha per tonne over the last ≤3 reported years × projected volume

Projections are shown as dashed lines in Tableau and can be switched off.

---

## Dashboards

1. **EU Import Volume vs. Deforestation Intensity (2020–2025)**: trends in volume and ha per 1,000 t
2. **EU Import Flows**: Sankey diagrams from origin and commodity to EU destination
3. **EU Supply Countries: Origin to Deforestation Exposure**: supplier and exposure maps
4. **Deforestation Exposure by EU Member State**: exposure by country and per $1M of imports
5. **Post-2020 Deforestation**: data-availability heatmap (the EUDR readiness test)

---

## Repository structure

```
Capstone/
├── README.md
├── .gitignore
└── Capstone_Project/
    ├── requirements.txt
    └── eudr_project/
        ├── raw/                  # Trase CSVs (not tracked)
        ├── clean/                # cleaned output (not tracked)
        ├── python/
        │   ├── clean_trase.ipynb
        │   ├── clean_trase.py
        │   └── load_to_postgres.ipynb
        ├── eudr_dbt/
        │   ├── dbt_project.yml
        │   ├── seeds/            # dim_country.csv, dataset_catalog.csv
        │   ├── models/
        │   │   ├── staging/
        │   │   ├── prep/
        │   │   └── marts/
        │   └── tests/            # custom data tests
        └── tableau/              # workbook and icons
```

---

## How to run

**Requirements:** Python 3.12, PostgreSQL, dbt-core 1.12 with dbt-postgres, Tableau Desktop or Tableau Public.

```bash
# 1. Set up the environment
cd Capstone_Project
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# 2. Create the database
createdb eudr
psql -d eudr -c "CREATE SCHEMA raw;"

# 3. Clean and load the data
#    Put the Trase CSVs in eudr_project/raw/, then run:
#    - python/clean_trase.ipynb      (or: python python/clean_trase.py)
#    - python/load_to_postgres.ipynb

# 4. Build and test the warehouse
cd eudr_project/eudr_dbt
dbt seed
dbt run
dbt test        # 37 tests
```

dbt reads connection details from `~/.dbt/profiles.yml`. Keep passwords there, **never in this repository**.

Finally, open the Tableau workbook and connect it to the `analytics_marts` schema.

---

## Limitations

- **Selected origins only:** 12 Trase datasets do not cover all EU imports of these commodities (e.g., Malaysian palm oil, Ghanaian cocoa)
- **Different exposure windows** (5 / 10 / 15 years): compare trends within a commodity, not across commodities
- **Modelled estimates:** Trase links trade to deforestation at regional level, not plot level, so exposure shows a risk link, not proof
- **Publication lag:** most 2023–2025 data is not yet published
- **Port effect:** destination is the first EU country of entry, not where goods are consumed
- **Deforestation only:** the EUDR's legality and human-rights requirements are not assessed

The project measures **data readiness**, not the legal compliance of individual shipments.

---

## Author

**Aparna Dixit**: Data Analytics & AI program, neue fische | SPICED (2026)

Data: Trase (trase.earth). This is an independent student project, not affiliated with Trase or the European Commission.