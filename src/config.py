"""
Configuration for Finnish Railway On-Time Performance Analytics
"""
from datetime import datetime, timedelta

# API Configuration
BASE_URL = "https://rata.digitraffic.fi/api/v1"

# Data Collection Settings
DEFAULT_START_DATE = (datetime.now() - timedelta(days=365)).strftime('%Y-%m-%d')  # 1 year back
DEFAULT_END_DATE = datetime.now().strftime('%Y-%m-%d')

# Performance Thresholds (in minutes)
ON_TIME_THRESHOLD = 5  # Train is "on time" if delay <= 5 minutes
LATE_THRESHOLD = 15    # Train is "significantly late" if delay > 15 minutes

# Data Storage
DATA_DIR = "data"
RAW_DATA_DIR = f"{DATA_DIR}/staging"

# Data Warehouse Configuration
WAREHOUSE_DIR = f"{DATA_DIR}/warehouse"
WAREHOUSE_DB = f"{WAREHOUSE_DIR}/warehouse.duckdb"
WAREHOUSE_TEMP_DIR = f"{WAREHOUSE_DIR}/temp"

# dbt Configuration
DBT_PROJECT_DIR = "dbt_warehouse"
DBT_PROFILES_DIR = DBT_PROJECT_DIR