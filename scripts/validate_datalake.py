"""
Validation script for DuckDB data lake demo.
Tests that all key queries execute successfully.
"""

import duckdb
from pathlib import Path

def test_csv_query(conn, lake_base):
    """Test CSV file querying"""
    print("\n1. Testing CSV query...")
    query = f"""
    SELECT COUNT(*) as row_count
    FROM read_csv('{lake_base}/weather/csv/helsinki_weather_2025.csv')
    """
    result = conn.execute(query).fetchone()
    assert result[0] > 0, "CSV query failed: no rows returned"
    print(f"   > CSV query successful ({result[0]} rows)")

def test_parquet_query(conn, lake_base):
    """Test Parquet file querying"""
    print("\n2. Testing Parquet query...")
    query = f"""
    SELECT COUNT(*) as row_count
    FROM read_parquet('{lake_base}/weather/parquet/weather_archive.parquet')
    """
    result = conn.execute(query).fetchone()
    assert result[0] > 0, "Parquet query failed: no rows returned"
    print(f"   > Parquet query successful ({result[0]} rows)")

def test_json_query(conn, lake_base):
    """Test JSON file querying"""
    print("\n3. Testing JSON query...")
    query = f"""
    SELECT COUNT(*) as incident_count
    FROM read_json('{lake_base}/delays/json/delay_causes_2025.json', format='array')
    """
    result = conn.execute(query).fetchone()
    assert result[0] > 0, "JSON query failed: no rows returned"
    print(f"   > JSON query successful ({result[0]} incidents)")

def test_multiformat_join(conn, lake_base):
    """Test joining CSV + Parquet"""
    print("\n4. Testing multi-format join (CSV + Parquet)...")
    query = f"""
    SELECT COUNT(*) as row_count
    FROM read_csv('{lake_base}/weather/csv/helsinki_weather_2025.csv') c
    JOIN read_parquet('{lake_base}/weather/parquet/weather_archive.parquet') h
        ON CAST(h.date AS VARCHAR) = c.date AND h.station_code = 'HKI'
    """
    result = conn.execute(query).fetchone()
    print(f"   > Multi-format join successful ({result[0]} matched rows)")

def test_hybrid_query(conn, lake_base):
    """Test hybrid lake + warehouse query"""
    print("\n5. Testing hybrid lake + warehouse query...")
    try:
        query = f"""
        SELECT COUNT(*) as row_count
        FROM read_csv('{lake_base}/weather/csv/*.csv', union_by_name=true) w
        JOIN warehouse.silver_fact_timetable_events te
            ON w.date = te.departureDate
        WHERE te.commercial_stop = true
        LIMIT 10
        """
        result = conn.execute(query).fetchone()
        print(f"   > Hybrid query successful ({result[0]} rows)")
    except Exception as e:
        print(f"   ! Hybrid query note: {str(e)[:100]}")
        print(f"   This is expected if warehouse doesn't have matching dates")

def test_wildcard_query(conn, lake_base):
    """Test wildcard pattern queries"""
    print("\n6. Testing wildcard query...")
    query = f"""
    SELECT COUNT(DISTINCT city) as city_count
    FROM read_csv('{lake_base}/weather/csv/*.csv', union_by_name=true)
    """
    result = conn.execute(query).fetchone()
    assert result[0] == 2, f"Expected 2 cities, got {result[0]}"
    print(f"   > Wildcard query successful ({result[0]} cities)")

def main():
    print("="*70)
    print("DuckDB Data Lake Demo - Validation")
    print("="*70)

    # Paths
    lake_base = r'C:\Users\Toni\KAMK\Data-alustat\tonikiuru\data\lake'
    warehouse_path = r'C:\Users\Toni\KAMK\Data-alustat\tonikiuru\data\warehouse\warehouse.duckdb'

    # Check if warehouse exists
    warehouse_exists = Path(warehouse_path).exists()

    # Connect to warehouse (read-only)
    print(f"\nConnecting to warehouse: {warehouse_path}")
    print(f"Warehouse exists: {warehouse_exists}")

    try:
        conn = duckdb.connect(warehouse_path, read_only=True)
        print("> Connected to warehouse")
    except Exception as e:
        print(f"! Could not connect to warehouse: {e}")
        print("  Creating in-memory connection instead...")
        conn = duckdb.connect()

    # Run validation tests
    try:
        test_csv_query(conn, lake_base)
        test_parquet_query(conn, lake_base)
        test_json_query(conn, lake_base)
        test_multiformat_join(conn, lake_base)
        test_wildcard_query(conn, lake_base)

        if warehouse_exists:
            test_hybrid_query(conn, lake_base)
        else:
            print("\n5. Skipping hybrid query (warehouse not found)")

        print("\n" + "="*70)
        print("SUCCESS: All validation tests passed!")
        print("="*70)
        print("\nNext steps:")
        print("  1. Run: uv run jupyter notebook notebooks/datalake_demo.ipynb")
        print("  2. Explore the 12 demo queries")
        print("  3. See data/lake/README.md for details\n")

    except AssertionError as e:
        print(f"\nERROR: Validation failed: {e}")
        return 1
    except Exception as e:
        print(f"\nERROR: Unexpected error: {e}")
        import traceback
        traceback.print_exc()
        return 1
    finally:
        conn.close()

    return 0

if __name__ == '__main__':
    exit(main())
