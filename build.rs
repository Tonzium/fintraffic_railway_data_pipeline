// Build script - runs during `cargo build`
// Automatically sets up Python environment and dbt

use std::process::Command;
use std::env;

fn main() {
    println!("cargo:rerun-if-changed=pyproject.toml");
    println!("cargo:rerun-if-changed=dbt_warehouse/dbt_project.yml");

    // Only run setup in release mode or if BUILD_SETUP env var is set
    let should_setup = env::var("PROFILE").unwrap_or_default() == "release"
        || env::var("BUILD_SETUP").is_ok();

    if !should_setup {
        println!("cargo:warning=Skipping build setup (debug mode). Set BUILD_SETUP=1 to run setup.");
        return;
    }

    println!("cargo:warning=🚀 Running automated setup...");

    // Step 1: uv sync
    println!("cargo:warning=📦 Step 1/3: Installing Python dependencies (uv sync)...");
    let uv_status = Command::new("uv")
        .arg("sync")
        .status();

    match uv_status {
        Ok(status) if status.success() => {
            println!("cargo:warning=✅ Python dependencies installed");
        }
        Ok(_) => {
            println!("cargo:warning=⚠️  uv sync failed - continuing anyway");
        }
        Err(e) => {
            println!("cargo:warning=⚠️  uv not found: {} - continuing anyway", e);
        }
    }

    // Step 2: dbt deps
    println!("cargo:warning=📦 Step 2/3: Installing dbt dependencies...");
    let dbt_deps_status = Command::new("uv")
        .current_dir("dbt_warehouse")
        .args(&["run", "dbt", "deps"])
        .status();

    match dbt_deps_status {
        Ok(status) if status.success() => {
            println!("cargo:warning=✅ dbt dependencies installed");
        }
        Ok(_) => {
            println!("cargo:warning=⚠️  dbt deps failed - continuing anyway");
            println!("cargo:warning=   You can run manually: cd dbt_warehouse && uv run dbt deps");
        }
        Err(e) => {
            println!("cargo:warning=⚠️  dbt deps error: {} - continuing anyway", e);
        }
    }

    // Step 3: dbt run
    println!("cargo:warning=📦 Step 3/3: Building dbt models...");
    let dbt_run_status = Command::new("uv")
        .current_dir("dbt_warehouse")
        .args(&["run", "dbt", "run"])
        .status();

    match dbt_run_status {
        Ok(status) if status.success() => {
            println!("cargo:warning=✅ dbt models built successfully");
        }
        Ok(_) => {
            println!("cargo:warning=⚠️  dbt run failed - you may need to run it manually");
            println!("cargo:warning=   Run: cd dbt_warehouse && uv run dbt run");
        }
        Err(e) => {
            println!("cargo:warning=⚠️  dbt run error: {} - you may need to run it manually", e);
        }
    }

    println!("cargo:warning=🎉 Automated setup complete!");
    println!("cargo:warning=💡 Next: Run the TUI with 'cargo run --release'");
}
