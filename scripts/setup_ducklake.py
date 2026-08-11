#!/usr/bin/env python3
"""
DuckLake: Using DuckDB as a Metadata Catalog for Data Lakes
============================================================

This script demonstrates the "DuckLake" concept:
- Data stored in Parquet files (open format, in data lake)
- Metadata stored in DuckDB database (catalog)
- Simple 2-step query: metadata lookup → file read

Advantages over Iceberg/Delta Lake:
- Simpler: No complex metadata JSON files
- Faster: Direct SQL queries for metadata
- Familiar: Standard SQL, no new APIs to learn
- Lightweight: Just DuckDB, no external dependencies
"""

import duckdb
from pathlib import Path
from datetime import datetime, timedelta
import json

# Paths
PROJECT_ROOT = Path(__file__).parent.parent
LAKE_PATH = PROJECT_ROOT / "data" / "lake"
CATALOG_PATH = PROJECT_ROOT / "data" / "ducklake_catalog.duckdb"

def setup_catalog():
    """Create the DuckLake metadata catalog."""

    print("=" * 70)
    print("DuckLake Setup: Creating Metadata Catalog")
    print("=" * 70)
    print()

    # Remove existing catalog for fresh start
    if CATALOG_PATH.exists():
        CATALOG_PATH.unlink()
        print(f"Removed existing catalog: {CATALOG_PATH}")

    # Create catalog database
    conn = duckdb.connect(str(CATALOG_PATH))

    print("Creating metadata tables...")

    # Create catalog schema
    conn.execute("CREATE SCHEMA IF NOT EXISTS catalog")

    # 1. Datasets registry - what datasets exist
    conn.execute("""
        CREATE TABLE IF NOT EXISTS catalog.datasets (
            dataset_id VARCHAR PRIMARY KEY,
            dataset_name VARCHAR NOT NULL,
            description VARCHAR,
            storage_location VARCHAR NOT NULL,
            file_format VARCHAR DEFAULT 'parquet',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    """)
    print("  > Created 'datasets' table")

    # 2. Partitions - which files belong to which partitions
    conn.execute("""
        CREATE TABLE IF NOT EXISTS catalog.partitions (
            partition_id VARCHAR PRIMARY KEY,
            dataset_id VARCHAR NOT NULL,
            partition_key VARCHAR,      -- e.g., 'year=2025/month=12'
            file_path VARCHAR NOT NULL,
            row_count BIGINT,
            file_size_bytes BIGINT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (dataset_id) REFERENCES catalog.datasets(dataset_id)
        )
    """)
    print("  > Created 'partitions' table")

    # 3. Schema versions - track schema evolution
    conn.execute("""
        CREATE TABLE IF NOT EXISTS catalog.schema_versions (
            version_id INTEGER PRIMARY KEY,
            dataset_id VARCHAR NOT NULL,
            schema_json VARCHAR NOT NULL,   -- JSON representation of schema
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (dataset_id) REFERENCES catalog.datasets(dataset_id)
        )
    """)
    print("  > Created 'schema_versions' table")

    # 4. Snapshots - time travel support
    conn.execute("""
        CREATE TABLE IF NOT EXISTS catalog.snapshots (
            snapshot_id BIGINT PRIMARY KEY,
            dataset_id VARCHAR NOT NULL,
            snapshot_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            operation VARCHAR,              -- INSERT, UPDATE, DELETE, MERGE
            partition_ids VARCHAR[],        -- Array of partition IDs in this snapshot
            row_count BIGINT,
            FOREIGN KEY (dataset_id) REFERENCES catalog.datasets(dataset_id)
        )
    """)
    print("  > Created 'snapshots' table")

    # 5. Statistics - for partition pruning and query optimization
    conn.execute("""
        CREATE TABLE IF NOT EXISTS catalog.partition_stats (
            partition_id VARCHAR NOT NULL,
            column_name VARCHAR NOT NULL,
            min_value VARCHAR,
            max_value VARCHAR,
            null_count BIGINT,
            distinct_count BIGINT,
            PRIMARY KEY (partition_id, column_name),
            FOREIGN KEY (partition_id) REFERENCES catalog.partitions(partition_id)
        )
    """)
    print("  > Created 'partition_stats' table")

    conn.close()

    print()
    print("=" * 70)
    print(f"SUCCESS: DuckLake catalog created at {CATALOG_PATH}")
    print(f"Size: {CATALOG_PATH.stat().st_size / 1024:.1f} KB")
    print("=" * 70)
    print()

    return CATALOG_PATH


def register_weather_dataset():
    """Register the existing weather dataset in the catalog."""

    print("=" * 70)
    print("Registering Weather Dataset in DuckLake Catalog")
    print("=" * 70)
    print()

    conn = duckdb.connect(str(CATALOG_PATH))

    # Register dataset
    dataset_id = "weather_history"
    dataset_name = "Weather Historical Archive"
    description = "Historical weather data (2023-2024) for Finnish stations"
    storage_location = str(LAKE_PATH / "weather" / "parquet")

    conn.execute("""
        INSERT INTO catalog.datasets (dataset_id, dataset_name, description, storage_location)
        VALUES (?, ?, ?, ?)
    """, [dataset_id, dataset_name, description, storage_location])

    print(f"  > Registered dataset: {dataset_name}")
    print(f"  > Dataset ID: {dataset_id}")
    print(f"  > Storage location: {storage_location}")

    # Register partition (single file for now)
    parquet_file = LAKE_PATH / "weather" / "parquet" / "weather_archive.parquet"

    if parquet_file.exists():
        file_size = parquet_file.stat().st_size

        # Get row count from parquet file
        row_count = conn.execute(f"""
            SELECT COUNT(*) FROM read_parquet('{parquet_file}')
        """).fetchone()[0]

        partition_id = f"{dataset_id}_p1"

        conn.execute("""
            INSERT INTO catalog.partitions (partition_id, dataset_id, partition_key, file_path, row_count, file_size_bytes)
            VALUES (?, ?, ?, ?, ?, ?)
        """, [partition_id, dataset_id, "all", str(parquet_file), row_count, file_size])

        print(f"  > Registered partition: {partition_id}")
        print(f"  > File: {parquet_file.name}")
        print(f"  > Rows: {row_count:,}")
        print(f"  > Size: {file_size / 1024:.1f} KB")

        # Create initial snapshot
        snapshot_id = 1
        conn.execute("""
            INSERT INTO catalog.snapshots (snapshot_id, dataset_id, operation, partition_ids, row_count)
            VALUES (?, ?, ?, ?, ?)
        """, [snapshot_id, dataset_id, "INSERT", [partition_id], row_count])

        print(f"  > Created snapshot #{snapshot_id}")

        # Register schema version
        schema = {
            "columns": [
                {"name": "date", "type": "DATE"},
                {"name": "station_code", "type": "VARCHAR"},
                {"name": "temp_avg_c", "type": "DOUBLE"},
                {"name": "temp_min_c", "type": "DOUBLE"},
                {"name": "temp_max_c", "type": "DOUBLE"},
                {"name": "precipitation_mm", "type": "DOUBLE"},
                {"name": "snow_depth_cm", "type": "INTEGER"},
                {"name": "wind_speed_kmh", "type": "DOUBLE"},
                {"name": "visibility_km", "type": "DOUBLE"}
            ]
        }

        conn.execute("""
            INSERT INTO catalog.schema_versions (version_id, dataset_id, schema_json)
            VALUES (?, ?, ?)
        """, [1, dataset_id, json.dumps(schema)])

        print(f"  > Registered schema version #1 (9 columns)")

        # Collect statistics for partition pruning
        print()
        print("  Collecting statistics for partition pruning...")

        stats_query = f"""
            SELECT
                MIN(date) as min_date,
                MAX(date) as max_date,
                COUNT(DISTINCT station_code) as distinct_stations,
                MIN(temp_avg_c) as min_temp,
                MAX(temp_avg_c) as max_temp
            FROM read_parquet('{parquet_file}')
        """

        stats = conn.execute(stats_query).fetchone()

        # Insert stats
        conn.execute("""
            INSERT INTO catalog.partition_stats (partition_id, column_name, min_value, max_value)
            VALUES
                (?, 'date', ?, ?),
                (?, 'temp_avg_c', ?, ?)
        """, [
            partition_id, str(stats[0]), str(stats[1]),
            partition_id, str(stats[3]), str(stats[4])
        ])

        print(f"    > Date range: {stats[0]} to {stats[1]}")
        print(f"    > Stations: {stats[2]}")
        print(f"    > Temp range: {stats[3]:.1f}°C to {stats[4]:.1f}°C")

    conn.close()

    print()
    print("=" * 70)
    print("SUCCESS: Weather dataset registered in catalog")
    print("=" * 70)
    print()


def demo_query_with_metadata():
    """Demonstrate the 2-step DuckLake query pattern."""

    print("=" * 70)
    print("DuckLake Query Demo: The 2-Step Pattern")
    print("=" * 70)
    print()

    conn = duckdb.connect(str(CATALOG_PATH))

    # Step 1: Query metadata to find which files to read
    print("STEP 1: Query metadata catalog")
    print("-" * 70)

    query_metadata = """
        SELECT
            d.dataset_name,
            d.storage_location,
            p.file_path,
            p.row_count,
            ps.min_value as date_min,
            ps.max_value as date_max
        FROM catalog.datasets d
        JOIN catalog.partitions p ON d.dataset_id = p.dataset_id
        JOIN catalog.partition_stats ps ON p.partition_id = ps.partition_id
        WHERE d.dataset_id = 'weather_history'
          AND ps.column_name = 'date'
    """

    print("SQL Query:")
    print(query_metadata)
    print()

    result = conn.execute(query_metadata).fetchone()

    if result:
        dataset_name, storage_loc, file_path, row_count, date_min, date_max = result

        print("Metadata Result:")
        print(f"  Dataset: {dataset_name}")
        print(f"  File: {Path(file_path).name}")
        print(f"  Rows: {row_count:,}")
        print(f"  Date range: {date_min} to {date_max}")
        print()

        # Step 2: Read the Parquet files identified in step 1
        print("STEP 2: Read data from Parquet files")
        print("-" * 70)

        data_query = f"""
            SELECT
                station_code,
                AVG(temp_avg_c) as avg_temp,
                AVG(precipitation_mm) as avg_precip,
                COUNT(*) as days
            FROM read_parquet('{file_path}')
            WHERE date BETWEEN '2024-01-01' AND '2024-12-31'
            GROUP BY station_code
            ORDER BY avg_temp DESC
        """

        print("SQL Query:")
        print(data_query)
        print()

        print("Results:")
        results = conn.execute(data_query).fetchall()

        print(f"{'Station':<10} {'Avg Temp (°C)':<15} {'Avg Precip (mm)':<18} {'Days':<10}")
        print("-" * 70)

        for row in results:
            station, avg_temp, avg_precip, days = row
            print(f"{station:<10} {avg_temp:>13.1f} {avg_precip:>16.1f} {days:>8,}")

    conn.close()

    print()
    print("=" * 70)
    print("SUCCESS: 2-step query pattern demonstrated")
    print("=" * 70)
    print()


def demo_time_travel():
    """Demonstrate time travel using snapshots."""

    print("=" * 70)
    print("DuckLake Time Travel Demo")
    print("=" * 70)
    print()

    conn = duckdb.connect(str(CATALOG_PATH))

    # Show available snapshots
    print("Available Snapshots:")
    print("-" * 70)

    snapshots = conn.execute("""
        SELECT
            snapshot_id,
            dataset_id,
            snapshot_timestamp,
            operation,
            row_count
        FROM catalog.snapshots
        ORDER BY snapshot_id
    """).fetchall()

    print(f"{'ID':<5} {'Dataset':<20} {'Timestamp':<20} {'Operation':<10} {'Rows':<10}")
    print("-" * 70)

    for snapshot in snapshots:
        snap_id, dataset_id, timestamp, operation, row_count = snapshot
        print(f"{snap_id:<5} {dataset_id:<20} {str(timestamp)[:19]:<20} {operation:<10} {row_count:>8,}")

    print()
    print("To query a specific snapshot, use:")
    print("  SELECT * FROM read_parquet(get_partition_files(snapshot_id))")

    conn.close()

    print()
    print("=" * 70)
    print("SUCCESS: Time travel metadata ready")
    print("=" * 70)
    print()


if __name__ == "__main__":
    # Create catalog
    catalog_path = setup_catalog()

    # Register existing weather dataset
    register_weather_dataset()

    # Demo the 2-step query pattern
    demo_query_with_metadata()

    # Demo time travel
    demo_time_travel()

    print()
    print("=" * 70)
    print("DuckLake Setup Complete!")
    print("=" * 70)
    print()
    print("Next steps:")
    print("  1. Open notebooks/ducklake_demo.ipynb for interactive demo")
    print("  2. Try queries using the 2-step pattern")
    print("  3. Explore time travel and schema evolution")
    print()
    print(f"Catalog location: {catalog_path}")
    print()
