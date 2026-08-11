@echo off
REM Quick setup script for Rust TUI application
echo ============================================================
echo   Railway Pipeline TUI - Setup Script
echo ============================================================
echo.

REM Check if Rust is installed
where cargo >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Cargo not found!
    echo.
    echo Please install Rust from: https://rustup.rs/
    echo.
    echo After installation:
    echo   1. Restart your terminal
    echo   2. Run this script again
    echo.
    pause
    exit /b 1
)

echo [OK] Cargo found
cargo --version
rustc --version
echo.

echo ============================================================
echo   Building Rust TUI Application...
echo ============================================================
echo.
echo This may take a few minutes on first build...
echo.

cargo build --release

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] Build failed!
    echo Check the error messages above.
    pause
    exit /b 1
)

echo.
echo ============================================================
echo   [OK] Build Successful!
echo ============================================================
echo.
echo The executable is located at:
echo   target\release\railway-tui.exe
echo.
echo To run the TUI:
echo   cargo run --release
echo.
echo Or run the executable directly:
echo   .\target\release\railway-tui.exe
echo.

pause
