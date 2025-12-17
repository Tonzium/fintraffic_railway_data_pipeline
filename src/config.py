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

import os

# Get the directory of the current file (src/config.py)
CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))
# Navigate up one level to get the project root
PROJECT_ROOT = os.path.dirname(CURRENT_DIR)

# Data Directories
DATA_DIR = os.path.join(PROJECT_ROOT, "data")
RAW_DATA_DIR = os.path.join(DATA_DIR, "staging")
WAREHOUSE_DIR = os.path.join(DATA_DIR, "warehouse")
WAREHOUSE_DB = f"{WAREHOUSE_DIR}/warehouse.duckdb"
WAREHOUSE_TEMP_DIR = f"{WAREHOUSE_DIR}/temp"

# dbt Configuration
DBT_PROJECT_DIR = "dbt_warehouse"
DBT_PROFILES_DIR = DBT_PROJECT_DIR