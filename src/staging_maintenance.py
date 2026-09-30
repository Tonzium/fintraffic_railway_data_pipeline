"""
Housekeeping for the raw staging files. demo/run_pipeline.sh runs it after
ingestion and before dbt, inside the pipeline lock.

What it does, in order:
  1. Removes *.tmp files left by an interrupted write.
  2. Deletes daily files (and quarantined files) older than the retention window.
  3. Compresses daily train files still stored as plain JSON (*.json -> *.json.gz).
     A plain file that does not parse (cut off by a crash or a full disk) is moved to
     staging/quarantine/ instead, so it can never break a dbt run.
  4. Removes month and year folders that became empty.

Usage:
    python staging_maintenance.py                      # retention from $RETENTION_DAYS, default 365
    python staging_maintenance.py --retention-days 30
    python staging_maintenance.py --dry-run
"""
import argparse
import gzip
import json
import logging
import os
import re
import shutil
from datetime import date, timedelta
from pathlib import Path

from config import RAW_DATA_DIR

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

DAILY_FILE = re.compile(r'^(\d{4}-\d{2}-\d{2})\.json(\.gz)?$')


def file_date(path: Path):
    """Departure date encoded in a daily file name, or None for other files."""
    m = DAILY_FILE.match(path.name)
    return date.fromisoformat(m.group(1)) if m else None


def remove_tmp_files(staging: Path, dry_run: bool) -> int:
    count = 0
    for tmp in staging.rglob('*.tmp'):
        logger.info(f"Removing leftover temp file {tmp}")
        if not dry_run:
            tmp.unlink()
        count += 1
    return count


def compress_plain_files(departures: Path, quarantine: Path, dry_run: bool):
    """gzip every plain daily .json that parses; quarantine the ones that don't."""
    compressed, quarantined, bytes_before, bytes_after = 0, 0, 0, 0
    for plain in sorted(departures.glob('*/*/*.json')):
        if file_date(plain) is None:
            continue
        gz = plain.with_name(plain.name + '.gz')
        if gz.exists():
            # Ingestion writes one format per day; a plain twin is a stale leftover.
            logger.info(f"Removing plain duplicate {plain} (a .gz exists)")
            if not dry_run:
                plain.unlink()
            continue
        try:
            with open(plain, 'r', encoding='utf-8') as f:
                json.load(f)
        except (ValueError, UnicodeDecodeError) as e:
            logger.warning(f"Unreadable file {plain} ({e}); moving it to {quarantine}")
            if not dry_run:
                quarantine.mkdir(parents=True, exist_ok=True)
                shutil.move(str(plain), str(quarantine / plain.name))
            quarantined += 1
            continue
        size = plain.stat().st_size
        if not dry_run:
            tmp = gz.with_name(gz.name + '.tmp')
            with open(plain, 'rb') as src, gzip.open(tmp, 'wb', compresslevel=6) as dst:
                shutil.copyfileobj(src, dst)
            os.replace(tmp, gz)
            plain.unlink()
            bytes_after += gz.stat().st_size
        bytes_before += size
        compressed += 1
    return compressed, quarantined, bytes_before, bytes_after


def delete_old_files(departures: Path, quarantine: Path, cutoff: date, dry_run: bool) -> int:
    count = 0
    candidates = list(departures.glob('*/*/*.json*'))
    if quarantine.exists():
        candidates += list(quarantine.glob('*.json*'))
    for path in candidates:
        d = file_date(path)
        if d is not None and d < cutoff:
            if not dry_run:
                path.unlink()
            count += 1
    return count


def remove_empty_dirs(departures: Path, dry_run: bool) -> int:
    count = 0
    for d in sorted(departures.glob('*/*'), reverse=True) + sorted(departures.glob('*'), reverse=True):
        if d.is_dir() and not any(d.iterdir()):
            if not dry_run:
                d.rmdir()
            count += 1
    return count


def main():
    parser = argparse.ArgumentParser(description='Compress and prune raw staging files')
    parser.add_argument('--staging-dir', default=RAW_DATA_DIR, help=f'Staging root (default: {RAW_DATA_DIR})')
    parser.add_argument('--retention-days', type=int, default=int(os.environ.get('RETENTION_DAYS', 365)),
                        help='Keep this many days of history (default: $RETENTION_DAYS or 365)')
    parser.add_argument('--dry-run', action='store_true', help='Report what would change, change nothing')
    args = parser.parse_args()

    staging = Path(args.staging_dir)
    departures = staging / 'train_departure_date'
    quarantine = staging / 'quarantine'
    if not departures.exists():
        logger.info(f"Nothing to do: {departures} does not exist")
        return

    cutoff = date.today() - timedelta(days=args.retention_days)
    tmp_removed = remove_tmp_files(staging, args.dry_run)
    deleted = delete_old_files(departures, quarantine, cutoff, args.dry_run)
    compressed, quarantined, before, after = compress_plain_files(departures, quarantine, args.dry_run)
    empty = remove_empty_dirs(departures, args.dry_run)

    days_kept = len({file_date(p) for p in departures.glob('*/*/*.json*')} - {None})
    size_mb = sum(p.stat().st_size for p in departures.rglob('*') if p.is_file()) / 1e6
    prefix = '[dry run] ' if args.dry_run else ''
    logger.info(
        f"{prefix}Staging tidy: compressed {compressed} files ({before / 1e6:.0f} MB -> {after / 1e6:.0f} MB), "
        f"quarantined {quarantined}, deleted {deleted} older than {cutoff}, removed {tmp_removed} temp files "
        f"and {empty} empty folders. Now {days_kept} days, {size_mb:.0f} MB."
    )


if __name__ == '__main__':
    main()
