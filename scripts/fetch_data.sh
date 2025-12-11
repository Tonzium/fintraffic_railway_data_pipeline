#!/bin/bash
# Quick data fetching helper script for Finnish Railway Data

# Navigate to project root
cd "$(dirname "$0")/.." || exit 1

# Colors for output
BLACK='\033[0;30m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
NC='\033[0m' # No Color

echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   Finnish Railway Data Fetcher - Quick Start${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo ""

# Function to fetch data
fetch_data() {
    echo -e "${GREEN}Fetching data: $1${NC}"
    python src/data_ingestion.py "$@"
    echo ""
}

# Show menu
echo -e "${MAGENTA}Select an option:${NC}"
echo -e "${YELLOW}1) Test - Last 7 days${NC}"
echo -e "${YELLOW}2) Recent - Last 30 days${NC}"
echo -e "${YELLOW}3) Quarter - Last 3 months${NC}"
echo -e "${YELLOW}4) Year - Last 12 months${NC}"
echo -e "${YELLOW}5) Custom date range${NC}"
echo -e "${YELLOW}6) Station specific (Helsinki)${NC}"
echo -e "${MAGENTA}7) Exit${NC}"
echo -e ""
read -p "Enter choice [1-7]: " choice

case $choice in
    1)
        END_DATE=$(date +%Y-%m-%d)
        START_DATE=$(date -d "7 days ago" +%Y-%m-%d)
        echo -e "${MAGENTA}Fetching last 7 days: $START_DATE to $END_DATE${NC}"
        fetch_data --start "$START_DATE" --end "$END_DATE"
        ;;
    2)
        END_DATE=$(date +%Y-%m-%d)
        START_DATE=$(date -d "30 days ago" +%Y-%m-%d)
        echo -e "${GREEN}Fetching last 30 days: $START_DATE to $END_DATE${NC}"
        fetch_data --start "$START_DATE" --end "$END_DATE" --skip-existing
        ;;
    3)
        END_DATE=$(date +%Y-%m-%d)
        START_DATE=$(date -d "3 months ago" +%Y-%m-%d)
        echo -e "${MAGENTA}Fetching last 3 months: $START_DATE to $END_DATE${NC}"
        echo -e "${MAGENTA}This will take approximately 10-15 minutes...${NC}"
        fetch_data --start "$START_DATE" --end "$END_DATE" --skip-existing
        ;;
    4)
        END_DATE=$(date +%Y-%m-%d)
        START_DATE=$(date -d "1 year ago" +%Y-%m-%d)
        echo -e "${MAGENTA}Fetching last year: $START_DATE to $END_DATE${NC}"
        echo -e "${MAGENTA}This will take approximately 30-60 minutes...${NC}"
        fetch_data --start "$START_DATE" --end "$END_DATE" --skip-existing --rate-limit 0.5
        ;;
    5)
        read -p "Enter start date (YYYY-MM-DD): " START_DATE
        read -p "Enter end date (YYYY-MM-DD): " END_DATE
        echo -e "${MAGENTA}Fetching custom range: $START_DATE to $END_DATE${NC}"
        fetch_data --start "$START_DATE" --end "$END_DATE" --skip-existing
        ;;
    6)
        END_DATE=$(date +%Y-%m-%d)
        START_DATE=$(date -d "30 days ago" +%Y-%m-%d)
        echo -e "${MAGENTA}Fetching Helsinki (HKI) trains: $START_DATE to $END_DATE${NC}"
        fetch_data --start "$START_DATE" --end "$END_DATE" --station HKI --skip-existing
        ;;
    7)
        echo "Exiting..."
        exit 0
        ;;
    *)
        echo -e "${YELLOW}Invalid choice. Exiting...${NC}"
        exit 1
        ;;
esac

echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}   Data fetching complete!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo ""
echo "Data location: data/staging/"
echo ""
echo "Next steps:"
echo "  - View data: ls data/staging/train_departure_date/"
