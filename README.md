# Fintraffic Railway data platform

**🚆 Live demo: [railway.tonikiuru.com](https://railway.tonikiuru.com)** — refreshed daily at 07:00 EET, built from this repo.

This repository contains a data platform setup for analyzing Finnish Railway data. It uses **uv** for Python management, **dbt** for data transformation, and **Evidence** for BI dashboards.

Business goal was to analyze On-Time Performance (OTP) and delays of VR trains in Finland. The analysis investigates time-based patterns, train type comparisons, and station-level metrics to identify performance trends.

**Dataset:** 3 months of data (September 2025 - December 2025) from Fintraffic Digitraffic API.

## Dashboard Previews

IC vs HDM train type performance comparison:

<p align="center">
  <img src="images/comparison.png" width="45%" alt="Comparison Dashboard" />
  <img src="images/ic_vs_hdm.png" width="35%" alt="IC vs HDM Analysis" />
</p>

Train type and delay pattern analysis:

<p align="center">
  <img src="images/type_analysis.png" width="40%" alt="Train Type Analysis" />
  <img src="images/delay.png" width="45%" alt="Delay Analysis" />
</p>

## Prerequisites

*   **Python 3.12+**
*   **uv** (Python package manager)
    *   Install: `pip install uv` or see [uv docs](https://github.com/astral-sh/uv)
*   **Docker** (for Evidence)

---

## 1. Environment Setup (uv)

Initialize the environment and install dependencies.

```bash
uv sync
```
*(Creates `.venv` and installs packages from `uv.lock`)*

Please, run commands inside the virtual environment using `uv run <command>`.

---

## 2. Ingestion (Fetch Data)

Download railway data (Digitraffic API) into the staging area.

*   **Quick Start (Menu):**
    *   **Windows:** `.\fetch_data.bat`
    *   **Mac/Linux:** `./fetch_data.sh`

*   **Manual Command:**
    ```bash
    uv run python src/data_ingestion.py --start 2024-11-01 --end 2024-12-01
    ```

---

## 3. Transformation (dbt)

Process raw data into structured tables (Bronze -> Silver -> Gold).

1.  **Navigate to dbt directory:**
    ```bash
    cd dbt_warehouse
    ```

2.  **Install dbt dependencies:**
    ```bash
    uv run dbt deps
    ```

3.  **Build & Test Models:**
    ```bash
    uv run dbt build
    ```

### Useful dbt Commands
*   **Generate & View Documentation:**
    ```bash
    uv run dbt docs generate
    uv run dbt docs serve
    ```
*   **Inspect Database (DuckDB CLI):**
    ```bash
    # Open the database in an interactive UI-like mode
    uv run duckdb -ui data/warehouse/warehouse.duckdb
    ```
    **DuckDB UI Dashboard:** http://localhost:4213/
    *(Note: Path may vary depending on where your .duckdb file is located. Check `profiles.yml`)*

---

## 4. Visualization (Evidence)

Evidence requires an initialization step on the first run to populate the workspace.

### First Time Setup (Init)
Run this once to scaffold the `bi/workspace` and install node modules:

First time launching?
Run this script to copy warehouse.duckdb file to docker volumes.
This script also handles data ingestion if not commented.

```bash
cd scripts
./update_data.sh
```

Run this only on first launch. This will default index.md file.

```bash
docker compose -f docker-compose.init.yml up --build
docker compose -f docker-compose.init.yml down
```

### Build evidence

Build the docker if first time ( this needs to be rebuilded again everytime if new .sql tables are added)

```bash
docker compose build
```

**Rebuild:** If you add new packages or tables, run `docker compose build`.

### Start Dashboard (Dev Mode)
Starts the server with hot-reloading (Watch Mode).

```bash
docker compose up --watch
```

*   **Access Dashboard:** [http://localhost:3000](http://localhost:3000)

---

## Project Structure

*   `src/`: Python scripts for ingestion and utility.
*   `dbt_warehouse/`: dbt project (SQL models, tests).
*   `bi/`: Evidence project (Markdown reports).
*   `data/`: Local data storage (ignored by git).
*   `logs/`: dbt logs.


## Alternative: Quick Cargo Workflow:
  1. Fresh clone
  2. cargo build --release -> Watch automated setup messages
  3. cargo run --release -> Evidence auto-initializes (first time only)
  4. TUI appears -> Press 2 (fetch 30 days)
  5. Dashboard launches automatically!

---

## 5. Self-Hosted Public Demo (railway.tonikiuru.com)

A production-style stack that serves the Evidence dashboard as a static site and refreshes the data automatically **every day at 07:00**:

```bash
cp .env.example .env   # add your Cloudflare Tunnel token
docker compose -f docker-compose.demo.yml up -d --build
```

See [`demo/README.md`](demo/README.md) for the full deployment guide (Proxmox + Cloudflare Tunnel).

---

## 6. Data Lake Demo

Explore DuckDB's data lake capabilities - query CSV, JSON, and Parquet files directly without ETL!

### Quick Start

```bash
# Generate sample data (first time only)
python scripts/generate_lake_data.py

# Launch demo notebook
uv run jupyter notebook notebooks/datalake_demo.ipynb
```

### What You'll Learn

- Query multiple file formats (CSV, JSON, Parquet) without loading into database
- Join different formats in single queries
- Combine data lake files + warehouse tables (hybrid architecture)
- Use wildcard patterns to query partitioned data
- Compare file format performance characteristics
- Apply real-world use cases (weather impact analysis, incident investigation)

### Demo Highlights

1. **Direct File Querying**: Query files without COPY or INSERT - zero ETL!
2. **Multi-Format Joins**: Mix CSV, JSON, Parquet in one query
3. **Hybrid Architecture**: Seamlessly combine data lake + warehouse
4. **Performance Analysis**: See why Parquet is 10-50x faster than CSV
5. **Real Use Cases**: Weather impact on delays, root cause analysis, data enrichment

### Datasets Included

- **Weather data** (CSV + Parquet): Correlate weather with train delays
- **Station attributes** (CSV): Extended metadata not in warehouse
- **Delay incidents** (JSON): Root cause analysis with nested structures
- **Major routes** (CSV): Journey and delay percentage calculations

See [`data/lake/README.md`](data/lake/README.md) for dataset details and schemas.

### Interactive Notebook

The notebook (`notebooks/datalake_demo.ipynb`) contains **12 demo queries** covering:
- Part 1: Direct file querying (CSV, Parquet, JSON)
- Part 2: Multi-format queries (cross-format joins)
- Part 3: Hybrid lake + warehouse integration
- Part 4: Wildcard & glob patterns
- Part 5: Performance comparisons & analytics

**Runtime**: 30-45 minutes for full walkthrough

---

## 7. DuckLake: Lakehouse Metadata Catalog Demo

Take your data lake to the next level with **DuckLake** - a "hold my beer" approach to lakehouse management that uses DuckDB itself as the metadata catalog!

### What is DuckLake?

DuckLake is a design pattern that simplifies lakehouse architecture:

- **Traditional Lakehouse (Iceberg/Delta)**: Parse complex JSON metadata files → Build file list → Read Parquet
- **DuckLake**: Query DuckDB catalog (SQL) → Read Parquet

**Result**: Simpler, faster, and more familiar!

### The Data Lake Evolution

1. **Stage 1 (2010s)**: Just Parquet files - No transactions, data corruption risks
2. **Stage 2 (2015)**: Hive Metastore - Phone book for paths, still no ACID
3. **Stage 3 (2017-2020)**: Iceberg & Delta Lake - ACID + time travel, but complex metadata
4. **Stage 4 (2020-2024)**: Proprietary cloud solutions
5. **Stage 5 (2025)**: DuckLake - "Hold my beer" - SQL database for metadata!

### Quick Start

```bash
# Create DuckLake metadata catalog
python scripts/setup_ducklake.py

# Launch interactive demo
uv run jupyter notebook notebooks/ducklake_demo.ipynb
```

### What You'll Learn

- The **2-step query pattern**: Metadata lookup → Data read
- **ACID transactions** for safe metadata updates
- **Time travel**: Query data as it existed in the past
- **Schema evolution**: Track schema changes over time
- **Partition pruning**: Use statistics for efficient queries
- **Comparison**: DuckLake vs Iceberg vs Delta Lake

### Key Features

| Feature | DuckLake | Iceberg/Delta Lake |
|---------|----------|-------------------|
| Metadata storage | DuckDB database | JSON/Avro files |
| Query pattern | 2 steps (SQL) | 3 steps (parse + read) |
| Learning curve | Low (just SQL) | Medium (new concepts) |
| Setup | Minimal (DuckDB only) | Medium (Spark/metastore) |
| Best for | <10TB analytics | >10TB enterprise |

### Metadata Catalog Tables

DuckLake uses 5 simple tables to manage your data lake:

1. **datasets** - Dataset registry
2. **partitions** - File tracking with statistics
3. **snapshots** - Time travel support
4. **schema_versions** - Schema evolution tracking
5. **partition_stats** - Partition pruning optimization

### Demo Highlights

1. **Metadata Exploration**: Understand the catalog structure
2. **2-Step Pattern**: Query metadata, then data
3. **Time Travel**: Query historical snapshots
4. **ACID Transactions**: Add new data safely
5. **Partition Pruning**: Skip irrelevant files efficiently
6. **Schema Evolution**: Handle schema changes gracefully
7. **Comparison**: See how DuckLake stacks up against industry standards

### Documentation

- **Comprehensive Guide**: [`docs/DUCKLAKE_GUIDE.md`](docs/DUCKLAKE_GUIDE.md)
- **Setup Script**: `scripts/setup_ducklake.py`
- **Demo Notebook**: `notebooks/ducklake_demo.ipynb`
- **Catalog Database**: `data/ducklake_catalog.duckdb`

**When to Use DuckLake**: Perfect for analytics teams who want lakehouse features (ACID, time travel, schema evolution) without the complexity of Iceberg/Delta Lake. Best for datasets <10TB.