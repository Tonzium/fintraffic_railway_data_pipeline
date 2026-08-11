"""
Generate sample data lake files for DuckDB demo.
Creates realistic synthetic data complementing the railway dataset.

Usage:
    python scripts/generate_lake_data.py
"""

import pandas as pd
import numpy as np
import json
from pathlib import Path
from datetime import datetime, timedelta

class DataLakeGenerator:
    """Generate sample data for DuckDB data lake demo"""

    def __init__(self, base_dir='data/lake'):
        self.base_dir = Path(base_dir)
        self.start_date = datetime(2025, 9, 12)  # Match warehouse data
        self.end_date = datetime(2025, 12, 31)

        print(f"Initializing data lake generator at: {self.base_dir.absolute()}")

    def generate_weather_csv(self):
        """Generate realistic Finnish weather data as CSV"""
        print("\n1. Generating weather CSV files...")

        cities = {
            'Helsinki': {'base_temp': 12, 'precip_prob': 0.3, 'lat': 60.17},
            'Tampere': {'base_temp': 11, 'precip_prob': 0.35, 'lat': 61.50}
        }

        for city, params in cities.items():
            dates = pd.date_range(self.start_date, self.end_date, freq='D')
            np.random.seed(42 if city == 'Helsinki' else 43)

            data = []
            for date in dates:
                # Seasonal temperature variation
                day_of_year = date.timetuple().tm_yday
                seasonal_factor = -5 * np.cos(2 * np.pi * day_of_year / 365)

                temp = params['base_temp'] + seasonal_factor + np.random.randn() * 3
                precip = np.random.exponential(5) if np.random.rand() < params['precip_prob'] else 0
                wind = max(0, np.random.normal(15, 5))
                snow = max(0, int((20 - temp) * np.random.rand())) if temp < 0 else 0

                # Conditions logic
                if snow > 5:
                    conditions = 'Snowy'
                elif precip > 5:
                    conditions = 'Rainy'
                elif temp < 0:
                    conditions = 'Cold'
                elif np.random.rand() < 0.3:
                    conditions = 'Cloudy'
                else:
                    conditions = 'Partly Cloudy'

                data.append({
                    'date': date.strftime('%Y-%m-%d'),
                    'city': city,
                    'temperature_c': round(temp, 1),
                    'precipitation_mm': round(precip, 1),
                    'wind_speed_kmh': round(wind, 1),
                    'snow_depth_cm': snow,
                    'conditions': conditions
                })

            df = pd.DataFrame(data)
            output_file = self.base_dir / f'weather/csv/{city.lower()}_weather_2025.csv'
            df.to_csv(output_file, index=False)
            file_size = output_file.stat().st_size / 1024
            print(f"   > Created {output_file.name} ({len(df)} rows, {file_size:.1f} KB)")

    def generate_weather_parquet(self):
        """Generate historical weather archive as Parquet"""
        print("\n2. Generating weather Parquet archive...")

        # Generate 2-year historical archive
        start_hist = datetime(2023, 1, 1)
        end_hist = datetime(2024, 12, 31)
        dates = pd.date_range(start_hist, end_hist, freq='D')

        stations = ['HKI', 'TPE', 'TKU', 'OL', 'JY']
        data = []

        np.random.seed(42)
        for station in stations:
            for date in dates:
                day_of_year = date.timetuple().tm_yday
                seasonal = -5 * np.cos(2 * np.pi * day_of_year / 365)

                temp_avg = 12 + seasonal + np.random.randn() * 2
                temp_min = temp_avg - abs(np.random.randn() * 3)
                temp_max = temp_avg + abs(np.random.randn() * 3)

                data.append({
                    'date': date.date(),
                    'station_code': station,
                    'temp_avg_c': round(temp_avg, 1),
                    'temp_min_c': round(temp_min, 1),
                    'temp_max_c': round(temp_max, 1),
                    'precipitation_mm': round(np.random.exponential(3), 1),
                    'snow_depth_cm': int(max(0, (5 - temp_avg) * np.random.rand())),
                    'wind_speed_kmh': round(max(0, np.random.normal(12, 5)), 1),
                    'visibility_km': round(max(5, np.random.normal(20, 5)), 1)
                })

        df = pd.DataFrame(data)
        output_file = self.base_dir / 'weather/parquet/weather_archive.parquet'
        df.to_parquet(output_file, compression='snappy', index=False)
        file_size = output_file.stat().st_size / 1024
        print(f"   > Created weather_archive.parquet ({len(df)} rows, {file_size:.1f} KB compressed)")

    def generate_station_attributes_csv(self):
        """Generate extended station attributes"""
        print("\n3. Generating station attributes CSV...")

        stations = [
            {'station_code': 'HKI', 'population_nearby': 650000, 'platforms': 19,
             'has_restaurant': 'Yes', 'parking_spaces': 500, 'elevation_m': 5, 'region': 'Uusimaa'},
            {'station_code': 'TPE', 'population_nearby': 240000, 'platforms': 6,
             'has_restaurant': 'Yes', 'parking_spaces': 300, 'elevation_m': 76, 'region': 'Pirkanmaa'},
            {'station_code': 'TKU', 'population_nearby': 195000, 'platforms': 5,
             'has_restaurant': 'Yes', 'parking_spaces': 250, 'elevation_m': 7, 'region': 'Southwest Finland'},
            {'station_code': 'OL', 'population_nearby': 208000, 'platforms': 5,
             'has_restaurant': 'Yes', 'parking_spaces': 200, 'elevation_m': 105, 'region': 'North Ostrobothnia'},
            {'station_code': 'JY', 'population_nearby': 143000, 'platforms': 5,
             'has_restaurant': 'Yes', 'parking_spaces': 180, 'elevation_m': 140, 'region': 'Central Finland'},
            {'station_code': 'LH', 'population_nearby': 120000, 'platforms': 4,
             'has_restaurant': 'Yes', 'parking_spaces': 120, 'elevation_m': 101, 'region': 'Päijänne Tavastia'},
            {'station_code': 'KV', 'population_nearby': 96000, 'platforms': 4,
             'has_restaurant': 'No', 'parking_spaces': 100, 'elevation_m': 85, 'region': 'South Ostrobothnia'},
        ]

        df = pd.DataFrame(stations)
        output_file = self.base_dir / 'stations/csv/stations_extended.csv'
        df.to_csv(output_file, index=False)
        file_size = output_file.stat().st_size / 1024
        print(f"   > Created stations_extended.csv ({len(df)} stations, {file_size:.1f} KB)")

    def generate_delay_incidents_json(self):
        """Generate delay incident records"""
        print("\n4. Generating delay incidents JSON...")

        incidents = []
        np.random.seed(42)

        categories = {
            'technical': ['signal_failure', 'engine_issue', 'brake_problem'],
            'weather': ['heavy_snow', 'ice_on_tracks', 'storm'],
            'infrastructure': ['track_maintenance', 'power_outage'],
            'operational': ['crew_shortage', 'passenger_incident']
        }

        stations = ['HKI', 'TPE', 'TKU', 'OL', 'LH']
        train_numbers = [42, 105, 154, 72, 95, 11, 23, 67, 89, 101]

        for i in range(80):
            date_offset = np.random.randint(0, (self.end_date - self.start_date).days)
            incident_date = self.start_date + timedelta(days=date_offset)

            category = np.random.choice(list(categories.keys()))
            subcategory = np.random.choice(categories[category])

            delay = int(np.random.exponential(15) + 5)

            incidents.append({
                'incident_id': f"INC-2025-{incident_date.strftime('%m%d')}-{i+1:03d}",
                'date': incident_date.strftime('%Y-%m-%d'),
                'train_number': int(np.random.choice(train_numbers)),
                'station': np.random.choice(stations),
                'delay_minutes': delay,
                'category': category,
                'subcategory': subcategory,
                'weather_related': category == 'weather',
                'resolved_time_minutes': int(delay * np.random.uniform(2, 5)),
                'impact': {
                    'affected_trains': int(np.random.poisson(5) + 1),
                    'total_delay_minutes': int(delay * np.random.uniform(5, 15))
                }
            })

        output_file = self.base_dir / 'delays/json/delay_causes_2025.json'
        with open(output_file, 'w') as f:
            json.dump(incidents, f, indent=2)
        file_size = output_file.stat().st_size / 1024
        print(f"   > Created delay_causes_2025.json ({len(incidents)} incidents, {file_size:.1f} KB)")

    def generate_routes_csv(self):
        """Generate major route definitions"""
        print("\n5. Generating routes CSV...")

        routes = [
            {'route_id': 'R1', 'route_name': 'Helsinki-Tampere', 'origin': 'HKI',
             'destination': 'TPE', 'distance_km': 187, 'typical_duration_min': 105,
             'stops': 11, 'train_types': 'IC'},
            {'route_id': 'R2', 'route_name': 'Helsinki-Turku', 'origin': 'HKI',
             'destination': 'TKU', 'distance_km': 195, 'typical_duration_min': 115,
             'stops': 9, 'train_types': 'IC'},
            {'route_id': 'R3', 'route_name': 'Helsinki-Oulu', 'origin': 'HKI',
             'destination': 'OL', 'distance_km': 607, 'typical_duration_min': 390,
             'stops': 23, 'train_types': 'IC'},
            {'route_id': 'R4', 'route_name': 'Helsinki-Lahti', 'origin': 'HKI',
             'destination': 'LH', 'distance_km': 103, 'typical_duration_min': 58,
             'stops': 7, 'train_types': 'IC'},
            {'route_id': 'R5', 'route_name': 'Tampere-Jyväskylä', 'origin': 'TPE',
             'destination': 'JY', 'distance_km': 149, 'typical_duration_min': 102,
             'stops': 10, 'train_types': 'IC'},
        ]

        df = pd.DataFrame(routes)
        output_file = self.base_dir / 'routes/csv/major_routes.csv'
        df.to_csv(output_file, index=False)
        file_size = output_file.stat().st_size / 1024
        print(f"   > Created major_routes.csv ({len(df)} routes, {file_size:.1f} KB)")

    def calculate_total_size(self):
        """Calculate total size of generated files"""
        total_size = 0
        file_count = 0

        for file_path in self.base_dir.rglob('*'):
            if file_path.is_file() and file_path.suffix in ['.csv', '.json', '.parquet']:
                total_size += file_path.stat().st_size
                file_count += 1

        return total_size / 1024, file_count

    def generate_all(self):
        """Generate all data lake files"""
        print("\n" + "="*70)
        print("DuckDB Data Lake Demo - Generating Sample Datasets")
        print("="*70)

        self.generate_weather_csv()
        self.generate_weather_parquet()
        self.generate_station_attributes_csv()
        self.generate_delay_incidents_json()
        self.generate_routes_csv()

        total_size_kb, file_count = self.calculate_total_size()

        print("\n" + "="*70)
        print(f"SUCCESS: Data generation complete!")
        print(f"Total: {file_count} files, {total_size_kb:.1f} KB")
        print(f"Location: {self.base_dir.absolute()}")
        print("="*70)
        print("\nNext steps:")
        print("  1. Run: uv run jupyter notebook notebooks/datalake_demo.ipynb")
        print("  2. Explore the 12 demo queries")
        print("  3. See data/lake/README.md for dataset details\n")

if __name__ == '__main__':
    generator = DataLakeGenerator()
    generator.generate_all()
