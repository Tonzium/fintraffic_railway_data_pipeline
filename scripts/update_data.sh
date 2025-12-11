#!/bin/bash

# If any errors stop this script
set -e

# Check that the first argument exists. If not, print usage:
#if [ -z "$1" ]; then
#    echo "Usage: $0 <start-date-ISO-format>"
#    exit 1
#fi

# Run ingestor script
uv run python ../src/data_ingestion.py --start 2025-01-01 --end 2025-01-31

# Run the dbt commands
cd ../dbt_warehouse
uv run dbt run
uv run dbt docs generate
cd ..

# # Copy the duckdb database file to Evidence's sources directory
SOURCE_FILE=data/warehouse/warehouse.duckdb
DEST_FILE=bi/workspace/sources/warehouse/warehouse.duckdb
mkdir -p bi/workspace/sources/warehouse/
cp $SOURCE_FILE $DEST_FILE

