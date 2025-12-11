@echo off
REM Quick data fetching helper script for Finnish Railway Data (Windows)
cd /d "%~dp0.."

echo ============================================================
echo    Finnish Railway Data Fetcher - Quick Start
echo ============================================================
echo.

REM --- Dynamic Date Calculation using Python ---
REM We use Python because Windows Batch date math is unreliable/complex
for /f "tokens=*" %%i in ('python -c "import datetime; print(datetime.date.today())"') do set TODAY=%%i
for /f "tokens=*" %%i in ('python -c "import datetime; print(datetime.date.today() - datetime.timedelta(days=7))"') do set DAYS7=%%i
for /f "tokens=*" %%i in ('python -c "import datetime; print(datetime.date.today() - datetime.timedelta(days=30))"') do set DAYS30=%%i
for /f "tokens=*" %%i in ('python -c "import datetime; print(datetime.date.today() - datetime.timedelta(days=90))"') do set DAYS90=%%i
REM ---------------------------------------------

echo Today is: %TODAY%
echo.

echo Select an option:
echo 1) Test - Last 7 days    (%DAYS7% to %TODAY%)
echo 2) Recent - Last 30 days (%DAYS30% to %TODAY%)
echo 3) Quarter - Last 3 months (%DAYS90% to %TODAY%)
echo 4) Custom date range
echo 5) Station specific (Helsinki - Last 30 days)
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
echo.

echo Fetching last 7 days (%DAYS7% to %TODAY%)...
python src/data_ingestion.py --start %DAYS7% --end %TODAY%
goto done

:recent
echo.

echo Fetching last 30 days (%DAYS30% to %TODAY%)...
echo This will take approximately 3-5 minutes...
python src/data_ingestion.py --start %DAYS30% --end %TODAY% --skip-existing
goto done

:quarter
echo.

echo Fetching last 3 months (%DAYS90% to %TODAY%)...
echo This will take approximately 15-20 minutes...
python src/data_ingestion.py --start %DAYS90% --end %TODAY% --skip-existing
goto done

:custom
echo.
set /p start_date="Enter start date (YYYY-MM-DD): "
set /p end_date="Enter end date (YYYY-MM-DD): "
echo Fetching custom range: %start_date% to %end_date%
python src/data_ingestion.py --start %start_date% --end %end_date% --skip-existing
goto done

:station
echo.

echo Fetching Helsinki (HKI) trains for last 30 days (%DAYS30% to %TODAY%)...
python src/data_ingestion.py --start %DAYS30% --end %TODAY% --station HKI --skip-existing
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
echo View data: data\staging\train_departure_date\

:end
pause