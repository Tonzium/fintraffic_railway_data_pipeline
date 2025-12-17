"""
Historical Data Ingestion Module for Finnish Railway Data
Fetches large volumes of historical train data with flexible organization

### Required Arguments

| Argument | Description | Example |
|----------|-------------|---------|
| `--start` | Start date (YYYY-MM-DD) | `--start 2024-01-01` |
| `--end` | End date (YYYY-MM-DD) | `--end 2024-01-31` |

### Optional Arguments

| Argument | Description | Default | Example |
|----------|-------------|---------|---------|
| `--station` | Filter by station code | None (all stations) | `--station HKI` |
| `--output-dir` | Base output directory | `data/staging` | `--output-dir my_data` |
| `--individual` | Save each train separately | False | `--individual` |
| `--compress` | Compress JSON with gzip | False | `--compress` |
| `--skip-existing` | Skip existing files | False | `--skip-existing` |
| `--rate-limit` | Delay between API calls (sec) | 0.5 | `--rate-limit 1.0` |

Usage examples:
    python data_ingestion.py --start 2024-01-01 --end 2024-01-31
    python data_ingestion.py --start 2024-01-01 --end 2024-01-31 --station HKI
    python data_ingestion.py --start 2024-01-01 --end 2024-01-31 --skip-existing
"""
import requests
from datetime import datetime, timedelta
from typing import List, Dict, Optional
import json
import time
from pathlib import Path
import logging
import argparse
import gzip

from config import BASE_URL, DATA_DIR, RAW_DATA_DIR

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class RailwayDataIngestion:
    """Data ingestion with organized file structure"""

    def __init__(
        self,
        base_dir: str = RAW_DATA_DIR,
        compress: bool = False,
        skip_existing: bool = False
    ):
        self.base_url = BASE_URL
        self.session = requests.Session()
        self.station_cache = None
        self.base_dir = Path(base_dir)
        self.compress = compress
        self.skip_existing = skip_existing

        # Create directory structure
        self.stations_dir = self.base_dir / "stations"
        self.trains_dir = self.base_dir / "trains"
        self.departures_dir = self.base_dir / "train_departure_date"

        self._create_directories()

    def _create_directories(self):
        """Create all necessary directories"""
        self.stations_dir.mkdir(parents=True, exist_ok=True)
        self.trains_dir.mkdir(parents=True, exist_ok=True)
        self.departures_dir.mkdir(parents=True, exist_ok=True)
        logger.info(f"Directory structure created at {self.base_dir}")

    def _save_json(self, data: any, filepath: Path):
        """Save data as JSON (optionally compressed)"""
        if self.compress:
            filepath = filepath.with_suffix(filepath.suffix + '.gz')
            with gzip.open(filepath, 'wt', encoding='utf-8') as f:
                json.dump(data, f, indent=2, ensure_ascii=False)
        else:
            with open(filepath, 'w', encoding='utf-8') as f:
                json.dump(data, f, indent=2, ensure_ascii=False)

    def _load_json(self, filepath: Path) -> any:
        """Load JSON data (handles compressed files)"""
        if filepath.suffix == '.gz':
            with gzip.open(filepath, 'rt', encoding='utf-8') as f:
                return json.load(f)
        else:
            with open(filepath, 'r', encoding='utf-8') as f:
                return json.load(f)

    def fetch_and_save_stations(self) -> Dict[str, any]:
        """
        Fetch all railway station information and save to staging.
        Saves to: data/staging/stations/stations.json
        """
        output_file = self.stations_dir / "stations.json"

        # Check if already exists and skip if requested
        if self.skip_existing and output_file.exists():
            logger.info(f"Skipping stations (already exists): {output_file}")
            return self._load_json(output_file)

        url = f"{self.base_url}/metadata/stations"
        response = self.session.get(url)
        response.raise_for_status()

        stations_data = response.json()

        # Save full station data
        self._save_json(stations_data, output_file)
        logger.info(f"Saved {len(stations_data)} stations to {output_file}")

        # Create lookup dictionary
        self.station_cache = {
            s['stationShortCode']: s['stationName']
            for s in stations_data
            if s.get('passengerTraffic', False)
        }

        return stations_data

    def fetch_trains_by_date(
        self,
        date: str,
        station_code: Optional[str] = None
    ) -> List[Dict]:
        """
        Fetch all trains for a specific departure date.

        Args:
            date: Date in YYYY-MM-DD format
            station_code: Optional station filter

        Returns:
            List of train objects
        """
        if station_code:
            url = f"{self.base_url}/trains/{date}/{station_code}"
        else:
            url = f"{self.base_url}/trains/{date}"

        try:
            response = self.session.get(url, timeout=30)
            response.raise_for_status()
            trains = response.json()
            logger.info(f"Fetched {len(trains)} trains for {date}" +
                       (f" at {station_code}" if station_code else ""))
            return trains
        except requests.exceptions.RequestException as e:
            logger.error(f"✗ Error fetching trains for {date}: {e}")
            return []

    def save_trains_by_date(
        self,
        trains: List[Dict],
        date: str,
        station_code: Optional[str] = None
    ):
        """
        Save trains organized by departure date: year/month/day.json

        Structure: data/staging/train_departure_date/YYYY/MM/YYYY-MM-DD.json
        """
        date_obj = datetime.strptime(date, '%Y-%m-%d')
        year = date_obj.strftime('%Y')
        month = date_obj.strftime('%m')

        # Create year/month directories
        year_dir = self.departures_dir / year
        month_dir = year_dir / month
        month_dir.mkdir(parents=True, exist_ok=True)

        # Save daily file
        filename = f"{date}.json"
        if station_code:
            filename = f"{date}_{station_code}.json"

        output_file = month_dir / filename
        self._save_json(trains, output_file)
        logger.info(f"Saved {len(trains)} trains to {output_file}")

    def save_individual_trains(self, trains: List[Dict], date: str):
        """
        Save each train as individual JSON file.

        Structure: data/staging/trains/train_NUMBER_YYYY-MM-DD.json
        """
        for train in trains:
            train_number = train['trainNumber']
            filename = f"train_{train_number}_{date}.json"
            output_file = self.trains_dir / filename

            if self.skip_existing and output_file.exists():
                continue

            self._save_json(train, output_file)

        logger.info(f"Saved {len(trains)} individual train files")


    def fetch_historical_data(
        self,
        start_date: str,
        end_date: str,
        station_code: Optional[str] = None,
        save_individual_trains: bool = False,
        rate_limit_delay: float = 0.5
    ) -> Dict:
        """
        Fetch historical train data for a date range.

        Args:
            start_date: Start date in YYYY-MM-DD format
            end_date: End date in YYYY-MM-DD format
            station_code: Optional station filter
            save_individual_trains: Save each train as separate file
            rate_limit_delay: Delay between API calls in seconds

        Returns:
            Summary statistics dictionary
        """
        start = datetime.strptime(start_date, '%Y-%m-%d')
        end = datetime.strptime(end_date, '%Y-%m-%d')

        total_days = (end - start).days + 1
        processed_days = 0
        total_trains = 0
        current_date = start

        logger.info("\n\n")
        logger.info(f"Starting historical data fetch")
        logger.info(f"Date range: {start_date} to {end_date}")
        logger.info(f"Total days: {total_days}")
        if station_code:
            logger.info(f"Station filter: {station_code}")
        logger.info("\n\n")

        while current_date <= end:
            date_str = current_date.strftime('%Y-%m-%d')
            year = current_date.strftime('%Y')
            month = current_date.strftime('%m')

            # Check if already exists
            month_dir = self.departures_dir / year / month
            daily_file = month_dir / f"{date_str}.json"
            if self.skip_existing and daily_file.exists():
                logger.info(f"Skipping {date_str} (already exists)")
                current_date += timedelta(days=1)
                processed_days += 1
                continue

            # Fetch trains for this date
            trains = self.fetch_trains_by_date(date_str, station_code)

            if trains:
                total_trains += len(trains)

                # Save by date
                self.save_trains_by_date(trains, date_str, station_code)

                # Optionally save individual train files
                if save_individual_trains:
                    self.save_individual_trains(trains, date_str)

            processed_days += 1
            if processed_days % 10 == 0:
                logger.info(f"Progress: {processed_days}/{total_days} days " +
                          f"({(processed_days/total_days)*100:.1f}%) - " +
                          f"Total trains: {total_trains:,}")

            # Rate limiting
            time.sleep(rate_limit_delay)
            current_date += timedelta(days=1)

        logger.info("\n\n")
        logger.info(f"Ingestion Complete!")
        logger.info(f"Total days processed: {processed_days}")
        logger.info(f"Total trains fetched: {total_trains:,}")
        logger.info(f"Data saved to: {self.base_dir}")
        logger.info("\n\n")

        return {
            'start_date': start_date,
            'end_date': end_date,
            'days_processed': processed_days,
            'total_trains': total_trains,
            'station_filter': station_code,
            'base_directory': str(self.base_dir)
        }


def parse_arguments():
    """
    Parse command line arguments
    """
    parser = argparse.ArgumentParser(
        description='Fetch Finnish Railway historical data',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
        Examples:
        # Fetch last 30 days
        python data_ingestion.py --start 2024-01-01 --end 2024-01-31

        # Fetch with station filter
        python data_ingestion.py --start 2024-01-01 --end 2024-01-31 --station HKI

        # Skip existing files
        python data_ingestion.py --start 2024-01-01 --end 2024-12-31 --skip-existing

        # Save individual train files with compression
        python data_ingestion.py --start 2024-01-01 --end 2024-01-31 --individual --compress
                """
    )

    parser.add_argument(
        '--start',
        type=str,
        required=True,
        help='Start date (YYYY-MM-DD)'
    )

    parser.add_argument(
        '--end',
        type=str,
        required=True,
        help='End date (YYYY-MM-DD)'
    )

    parser.add_argument(
        '--station',
        type=str,
        default=None,
        help='Filter by station code (e.g., HKI, TPE)'
    )

    parser.add_argument(
        '--output-dir',
        type=str,
        default=RAW_DATA_DIR,
        help=f'Base output directory (default: {RAW_DATA_DIR})'
    )

    parser.add_argument(
        '--individual',
        action='store_true',
        help='Save each train as individual JSON file'
    )

    parser.add_argument(
        '--compress',
        action='store_true',
        help='Compress JSON files with gzip'
    )

    parser.add_argument(
        '--skip-existing',
        action='store_true',
        help='Skip downloading files that already exist'
    )

    parser.add_argument(
        '--rate-limit',
        type=float,
        default=0.5,
        help='Delay between API calls in seconds (default: 0.5)'
    )

    return parser.parse_args()


def main():
    """Main entry point"""
    args = parse_arguments()

    # Validate dates
    try:
        start_date = datetime.strptime(args.start, '%Y-%m-%d')
        end_date = datetime.strptime(args.end, '%Y-%m-%d')

        if start_date > end_date:
            logger.error("Start date must be before end date")
            return

        if end_date > datetime.now():
            logger.warning("End date is in the future, using today's date")
            end_date = datetime.now()
            args.end = end_date.strftime('%Y-%m-%d')

    except ValueError as e:
        logger.error(f"Invalid date format: {e}")
        return

    # Initialize ingestion
    ingestion = RailwayDataIngestion(
        base_dir=args.output_dir,
        compress=args.compress,
        skip_existing=args.skip_existing
    )

    # Fetch and save stations first
    logger.info("Fetching station metadata...")
    ingestion.fetch_and_save_stations()

    # Fetch historical data
    summary = ingestion.fetch_historical_data(
        start_date=args.start,
        end_date=args.end,
        station_code=args.station,
        save_individual_trains=args.individual,
        rate_limit_delay=args.rate_limit
    )

    # Save summary report
    summary_file = Path(args.output_dir) / "ingestion_summary.json"
    with open(summary_file, 'w') as f:
        json.dump({
            **summary,
            'ingestion_time': datetime.now().isoformat(),
            'options': {
                'compress': args.compress,
                'skip_existing': args.skip_existing,
                'individual_files': args.individual
            }
        }, f, indent=2)

    logger.info(f"\nSummary saved to {summary_file}")


if __name__ == "__main__":
    main()
