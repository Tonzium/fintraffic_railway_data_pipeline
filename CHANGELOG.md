# Changelog

## 2026-01-01 - DuckLake: Lakehouse Metadata Catalog Demo

### New Feature: DuckLake

Implemented **DuckLake** - a simplified lakehouse architecture that uses DuckDB as the metadata catalog instead of complex JSON metadata files like Iceberg/Delta Lake.

### What is DuckLake?

**The Evolution**: Stage 5 of data lake evolution - "Hold my beer"
- Stage 1 (2010s): Just Parquet files (chaos)
- Stage 2 (2015): Hive Metastore (phone book)
- Stage 3 (2017): Iceberg/Delta Lake (complex metadata files)
- Stage 4 (2020): Proprietary cloud solutions
- **Stage 5 (2025): DuckLake** - SQL database for metadata!

### Files Added

1. **Setup Script**: `scripts/setup_ducklake.py`
   - Creates metadata catalog database (`data/ducklake_catalog.duckdb`)
   - Creates 5 metadata tables (datasets, partitions, snapshots, schema_versions, partition_stats)
   - Registers existing weather dataset
   - Demonstrates 2-step query pattern

2. **Demo Notebook**: `notebooks/ducklake_demo.ipynb`
   - Interactive exploration of DuckLake concepts
   - 7 parts covering all features:
     - Part 1: Metadata catalog exploration
     - Part 2: 2-step query pattern
     - Part 3: Time travel
     - Part 4: ACID transactions
     - Part 5: Partition pruning
     - Part 6: Comparison with Iceberg/Delta Lake
     - Part 7: Conclusion and next steps

3. **Comprehensive Guide**: `docs/DUCKLAKE_GUIDE.md`
   - Complete reference documentation
   - Evolution history explained
   - Metadata catalog structure
   - Query pattern examples
   - Use case demonstrations
   - Comparison tables
   - When to use DuckLake

4. **Updated README**: Added Section 6 - DuckLake Demo

### Metadata Catalog Tables

DuckLake uses 5 simple tables:

| Table | Purpose |
|-------|---------|
| `catalog.datasets` | Dataset registry |
| `catalog.partitions` | File tracking with row counts and sizes |
| `catalog.snapshots` | Time travel support |
| `catalog.schema_versions` | Schema evolution tracking |
| `catalog.partition_stats` | Partition pruning statistics |

### Key Features Demonstrated

✅ **2-Step Query Pattern**: Query metadata → Read Parquet (vs 3 steps for Iceberg/Delta)
✅ **ACID Transactions**: Safe metadata updates via DuckDB
✅ **Time Travel**: Query data as it existed at any snapshot
✅ **Schema Evolution**: Track schema changes over time
✅ **Partition Pruning**: Skip irrelevant files using statistics
✅ **Simplicity**: Standard SQL, no JSON parsing, no Spark

### Comparison

| Feature | DuckLake | Iceberg/Delta |
|---------|----------|---------------|
| Metadata Storage | DuckDB database | JSON/Avro files |
| Query Steps | 2 (SQL query) | 3 (parse + query) |
| Learning Curve | Low (just SQL) | Medium (new concepts) |
| Setup | Minimal (DuckDB) | Medium (Spark/metastore) |
| Best For | <10TB analytics | >10TB enterprise |

### When to Use DuckLake

**Use DuckLake when:**
- Dataset < 10TB
- Simplicity is priority
- Team familiar with SQL, not Spark
- Don't need multi-engine access
- Want to prototype quickly

**Use Iceberg/Delta when:**
- Dataset > 10TB
- Need Spark/Flink/Trino integration
- Enterprise governance required
- Industry standard is critical

### Quick Start

```bash
# Create DuckLake catalog
python scripts/setup_ducklake.py

# Launch interactive demo
uv run jupyter notebook notebooks/ducklake_demo.ipynb
```

### Demo Runtime

- Setup script: ~30 seconds
- Interactive notebook: 30-45 minutes

### Files Created/Modified

**New Files (4)**:
1. `scripts/setup_ducklake.py`
2. `notebooks/ducklake_demo.ipynb`
3. `docs/DUCKLAKE_GUIDE.md`
4. `data/ducklake_catalog.duckdb` (generated)

**Modified Files (1)**:
1. `README.md` - Added Section 6

---

## Version 0.2.0 - Rust TUI Interactive Data Selection ✨

### New Features

**Expanded Menu with Multiple Options:**
- `1` - Fetch Last **7 days** (Quick Test) 🏃
- `2` - Fetch Last **30 days** (Standard) 📊
- `3` - Fetch Last **90 days** (Full Quarter) 📈
- `4` - Run dbt Transformation
- `5` - Update Dashboard
- `6` - Run Full Pipeline (**30 days**)
- `7` - Run Full Pipeline (**90 days**)
- `q` - Quit

### What Changed

**Before:**
- Only one ingestion option (hard-coded 30 days)
- Limited flexibility

**After:**
- ✅ User can choose 7, 30, or 90 days
- ✅ Different full pipeline options (30 or 90 days)
- ✅ Better organized menu with categories
- ✅ More demo-friendly (quick 7-day test option)

### Benefits for Presentation

1. **Shows Interactivity**: "Users can choose their preferred time range"
2. **Flexibility**: "Quick 7-day test for development, 90 days for analysis"
3. **Professional UX**: Categorized menu looks polished
4. **Live Demo**: Can demo quick 7-day fetch without waiting

---

## How to Use

### Quick Test (7 days)
```bash
cargo run --release
# Press '1' for 7 days of data
```

### Standard Analysis (30 days)
```bash
cargo run --release
# Press '2' for 30 days of data
```

### Full Quarter Analysis (90 days)
```bash
cargo run --release
# Press '3' for 90 days of data
```

### Full Pipeline
```bash
cargo run --release
# Press '6' for complete pipeline with 30 days
# Or press '7' for complete pipeline with 90 days
```

---

## Next Update Ideas

- [ ] Add custom date input dialog
- [ ] Show estimated time for each option
- [ ] Add station filter option
- [ ] Export logs to file
- [ ] Add progress percentage
