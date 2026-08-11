#!/bin/bash
# Quick setup script for Rust TUI application

set -e

echo "============================================================"
echo "  Railway Pipeline TUI - Setup Script"
echo "============================================================"
echo ""

# Check if Rust is installed
if ! command -v cargo &> /dev/null; then
    echo "[ERROR] Cargo not found!"
    echo ""
    echo "Please install Rust from: https://rustup.rs/"
    echo ""
    echo "Run this command:"
    echo "  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
    echo ""
    echo "After installation:"
    echo "  1. Restart your terminal (or run: source ~/.cargo/env)"
    echo "  2. Run this script again"
    echo ""
    exit 1
fi

echo "[OK] Cargo found"
cargo --version
rustc --version
echo ""

echo "============================================================"
echo "  Building Rust TUI Application..."
echo "============================================================"
echo ""
echo "This may take a few minutes on first build..."
echo ""

cargo build --release

echo ""
echo "============================================================"
echo "  [OK] Build Successful!"
echo "============================================================"
echo ""
echo "The executable is located at:"
echo "  target/release/railway-tui"
echo ""
echo "To run the TUI:"
echo "  cargo run --release"
echo ""
echo "Or run the executable directly:"
echo "  ./target/release/railway-tui"
echo ""
