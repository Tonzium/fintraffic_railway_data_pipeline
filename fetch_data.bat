@echo off
REM Quick data fetching helper script for Finnish Railway Data (Windows)

echo ============================================================
echo    Finnish Railway Data Fetcher - Quick Start
echo ============================================================
echo.

echo Select an option:
echo 1) Test - Last 7 days
echo 2) Recent - Last 30 days
echo 3) Quarter - Last 3 months
echo 4) Custom date range
echo 5) Station specific (Helsinki)
echo 6) Exit
echo.

set /p choice="Enter choice [1-6]: "

if "%choice%"=="1" goto test
if "%choice%"=="2" goto recent
if "%choice%"=="3" goto quarter
if "%choice%"=="4" goto custom
if "%choice%"=="5" goto station
if "%choice%"=="6" goto exit
goto invalid

:test
echo Fetching last 7 days...
python src/data_ingestion.py --start 2024-11-25 --end 2024-12-02
goto done

:recent
echo Fetching last 30 days...
echo This will take approximately 3-5 minutes...
python src/data_ingestion.py --start 2024-11-02 --end 2024-12-02 --skip-existing
goto done

:quarter
echo Fetching last 3 months...
echo This will take approximately 15-20 minutes...
python src/data_ingestion.py --start 2024-09-02 --end 2024-12-02 --skip-existing
goto done

:custom
set /p start_date="Enter start date (YYYY-MM-DD): "
set /p end_date="Enter end date (YYYY-MM-DD): "
echo Fetching custom range: %start_date% to %end_date%
python src/data_ingestion.py --start %start_date% --end %end_date% --skip-existing
goto done

:station
echo Fetching Helsinki (HKI) trains for last 30 days...
python src/data_ingestion.py --start 2024-11-02 --end 2024-12-02 --station HKI --skip-existing
goto done

:invalid
echo Invalid choice. Exiting...
goto end

:exit
echo Exiting...
goto end

:done
echo.
echo ============================================================
echo    Data fetching complete!
echo ============================================================
echo.
echo Data location: data\staging\
echo View monthly manifests: data\staging\train_departure_date\YYYY\MM\
echo.
echo Next steps:
echo   - View data: dir data\staging\train_departure_date\
echo   - Run analytics: python src\analytics.py
echo   - Launch dashboard: streamlit run src\dashboard.py
echo.

:end
pause
