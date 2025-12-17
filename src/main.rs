use anyhow::Result;
use chrono::Local;
use crossterm::{
    event::{self, DisableMouseCapture, EnableMouseCapture, Event, KeyCode, KeyEventKind},
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};
use ratatui::{
    backend::CrosstermBackend,
    layout::{Alignment, Constraint, Direction, Layout, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, BorderType, Gauge, List, ListItem, Paragraph},
    Frame, Terminal,
};
use std::{
    io,
    process::{Command, Stdio},
    time::{Duration, Instant},
};

mod pipeline;
mod ui_helpers;

use pipeline::{PipelineStage, PipelineStatus};
use ui_helpers::{render_help_screen, render_status_bar};

/// Main application state
struct App {
    pipeline_status: PipelineStatus,
    logs: Vec<String>,
    should_quit: bool,
    show_confirmation: bool,
    pending_action: Option<PendingAction>,
    show_help: bool,
    log_scroll: usize,
    total_trains_processed: u32,
    execute_next_tick: bool,
}

#[derive(Clone)]
enum PendingAction {
    Fetch7Days,
    Fetch30Days,
    Fetch90Days,
    Transform,
    UpdateDashboard,
    FullPipeline30,
    FullPipeline90,
}

impl App {
    fn new() -> Self {
        Self {
            pipeline_status: PipelineStatus::new(),
            logs: vec![
                "Welcome to Railway Pipeline TUI! Press 'h' for help.".to_string(),
                "Ready to process Finnish railway data.".to_string(),
            ],
            should_quit: false,
            show_confirmation: false,
            pending_action: None,
            show_help: false,
            log_scroll: 0,
            total_trains_processed: 0,
            execute_next_tick: false,
        }
    }

    fn get_action_description(&self) -> String {
        match &self.pending_action {
            Some(PendingAction::Fetch7Days) => "Fetch last 7 days of data".to_string(),
            Some(PendingAction::Fetch30Days) => "Fetch last 30 days of data".to_string(),
            Some(PendingAction::Fetch90Days) => "Fetch last 90 days of data (this may take 15-20 min)".to_string(),
            Some(PendingAction::Transform) => "Run dbt transformation pipeline".to_string(),
            Some(PendingAction::UpdateDashboard) => "Update Evidence dashboard".to_string(),
            Some(PendingAction::FullPipeline30) => "Run FULL pipeline with 30 days of data".to_string(),
            Some(PendingAction::FullPipeline90) => "Run FULL pipeline with 90 days of data (this may take 20-30 min)".to_string(),
            None => String::new(),
        }
    }

    pub fn is_pipeline_busy(&self) -> bool {
        // Check if we're about to execute or currently executing
        self.execute_next_tick
            || self.pipeline_status.ingestion == pipeline::StageStatus::Running
            || self.pipeline_status.transformation == pipeline::StageStatus::Running
            || self.pipeline_status.dashboard == pipeline::StageStatus::Running
    }

    fn execute_pending_action(&mut self) -> Result<()> {
        if let Some(action) = self.pending_action.take() {
            match action {
                PendingAction::Fetch7Days => self.run_fetch_data(7)?,
                PendingAction::Fetch30Days => self.run_fetch_data(30)?,
                PendingAction::Fetch90Days => self.run_fetch_data(90)?,
                PendingAction::Transform => self.run_transform()?,
                PendingAction::UpdateDashboard => self.run_update_dashboard()?,
                PendingAction::FullPipeline30 => self.run_full_pipeline(30)?,
                PendingAction::FullPipeline90 => self.run_full_pipeline(90)?,
            }
        }
        Ok(())
    }

    fn add_log(&mut self, message: String) {
        let timestamp = Local::now().format("%H:%M:%S");
        self.logs.push(format!("[{}] {}", timestamp, message));

        // Keep only last 100 log entries
        if self.logs.len() > 100 {
            self.logs.remove(0);
        }
    }

    fn run_fetch_data(&mut self, days: u32) -> Result<()> {
        self.add_log(format!("Starting data ingestion (last {} days)...", days));
        self.pipeline_status.set_stage_running(PipelineStage::Ingestion);

        // Calculate date range
        let now = Local::now();
        let end_date = now.format("%Y-%m-%d").to_string();
        let start_date = (now - chrono::Duration::days(days as i64)).format("%Y-%m-%d").to_string();

        let dates = vec![start_date.as_str(), end_date.as_str()];

        // Run ingestion script (capture output to prevent TUI interference)
        let output = Command::new("uv")
            .args(&[
                "run",
                "python",
                "src/data_ingestion.py",
                "--start",
                dates[0],
                "--end",
                dates[1],
                "--skip-existing",
            ])
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .status()?;

        if output.success() {
            self.pipeline_status.set_stage_completed(PipelineStage::Ingestion);
            self.add_log("Data ingestion completed successfully".to_string());
        } else {
            self.pipeline_status.set_stage_failed(PipelineStage::Ingestion);
            self.add_log("Data ingestion failed - check logs/dbt.log for details".to_string());
        }

        Ok(())
    }

    fn run_transform(&mut self) -> Result<()> {
        self.add_log("Starting dbt transformation...".to_string());
        self.pipeline_status.set_stage_running(PipelineStage::Transformation);

        // Run dbt deps (capture output to prevent TUI interference)
        self.add_log("Running dbt deps...".to_string());
        let deps_status = Command::new("uv")
            .current_dir("dbt_warehouse")
            .args(&["run", "dbt", "deps"])
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .status()?;

        if !deps_status.success() {
            self.pipeline_status.set_stage_failed(PipelineStage::Transformation);
            self.add_log("dbt deps failed - check logs/dbt.log for details".to_string());
            return Ok(());
        }

        // Run dbt run (capture output to prevent TUI interference)
        self.add_log("Running dbt run...".to_string());
        let run_status = Command::new("uv")
            .current_dir("dbt_warehouse")
            .args(&["run", "dbt", "run"])
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .status()?;

        if !run_status.success() {
            self.pipeline_status.set_stage_failed(PipelineStage::Transformation);
            self.add_log("dbt run failed - check logs/dbt.log for details".to_string());
            return Ok(());
        }

        // Run dbt docs generate (capture output to prevent TUI interference)
        self.add_log("Generating dbt docs...".to_string());
        let docs_status = Command::new("uv")
            .current_dir("dbt_warehouse")
            .args(&["run", "dbt", "docs", "generate"])
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .status()?;

        if docs_status.success() {
            self.pipeline_status.set_stage_completed(PipelineStage::Transformation);
            self.add_log("dbt transformation completed successfully".to_string());
            self.add_log("Check logs/dbt.log for detailed results".to_string());
        } else {
            // Don't fail the whole transformation if docs generation fails
            self.pipeline_status.set_stage_completed(PipelineStage::Transformation);
            self.add_log("dbt transformation completed (docs generation failed)".to_string());
            self.add_log("Check logs/dbt.log for detailed results".to_string());
        }

        Ok(())
    }

    fn run_update_dashboard(&mut self) -> Result<()> {
        self.add_log("Updating dashboard...".to_string());
        self.pipeline_status.set_stage_running(PipelineStage::Dashboard);

        // Create directory and copy database (capture output to prevent TUI interference)
        #[cfg(target_os = "windows")]
        {
            Command::new("cmd")
                .args(&["/C", "if not exist bi\\workspace\\sources\\warehouse\\ mkdir bi\\workspace\\sources\\warehouse\\"])
                .stdout(Stdio::null())
                .stderr(Stdio::null())
                .status()?;

            let copy_status = Command::new("cmd")
                .args(&["/C", "copy /Y data\\warehouse\\warehouse.duckdb bi\\workspace\\sources\\warehouse\\warehouse.duckdb"])
                .stdout(Stdio::null())
                .stderr(Stdio::null())
                .status()?;

            if copy_status.success() {
                self.pipeline_status.set_stage_completed(PipelineStage::Dashboard);
                self.add_log("Dashboard updated successfully".to_string());
                
                self.add_log("Launching dashboard environment...".to_string());
                
                // Launch Docker Compose in a new terminal window
                Command::new("cmd")
                    .args(&["/C", "start cmd /k docker compose up --watch"])
                    .spawn()?;
                    
                // Open Browser
                Command::new("cmd")
                    .args(&["/C", "start http://localhost:3000"])
                    .spawn()?;
                    
            } else {
                self.pipeline_status.set_stage_failed(PipelineStage::Dashboard);
                self.add_log("Dashboard update failed - check file permissions".to_string());
            }
        }

        #[cfg(not(target_os = "windows"))]
        {
            Command::new("mkdir")
                .args(&["-p", "bi/workspace/sources/warehouse/"])
                .stdout(Stdio::null())
                .stderr(Stdio::null())
                .status()?;

            let copy_status = Command::new("cp")
                .args(&["data/warehouse/warehouse.duckdb", "bi/workspace/sources/warehouse/warehouse.duckdb"])
                .stdout(Stdio::null())
                .stderr(Stdio::null())
                .status()?;

            if copy_status.success() {
                self.pipeline_status.set_stage_completed(PipelineStage::Dashboard);
                self.add_log("Dashboard updated successfully".to_string());
                self.add_log("Run 'docker compose up --watch' to view changes".to_string());
            } else {
                self.pipeline_status.set_stage_failed(PipelineStage::Dashboard);
                self.add_log("Dashboard update failed - check file permissions".to_string());
            }
        }

        Ok(())
    }

    fn run_full_pipeline(&mut self, days: u32) -> Result<()> {
        self.add_log("=== Starting Full Pipeline ===".to_string());
        self.pipeline_status.reset();

        self.run_fetch_data(days)?;
        if !self.pipeline_status.is_stage_completed(PipelineStage::Ingestion) {
            self.add_log("Pipeline stopped: Ingestion failed".to_string());
            return Ok(());
        }

        self.run_transform()?;
        if !self.pipeline_status.is_stage_completed(PipelineStage::Transformation) {
            self.add_log("Pipeline stopped: Transformation failed".to_string());
            return Ok(());
        }

        self.run_update_dashboard()?;

        if self.pipeline_status.all_completed() {
            self.add_log("=== Pipeline Completed Successfully! ===".to_string());
        } else {
            self.add_log("=== Pipeline Completed with Errors ===".to_string());
        }

        Ok(())
    }
}

fn main() -> Result<()> {
    // Check and handle Evidence initialization before starting TUI
    handle_evidence_setup()?;

    // Setup terminal
    enable_raw_mode()?;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen, EnableMouseCapture)?;
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend)?;

    // Create app
    let mut app = App::new();
    let tick_rate = Duration::from_millis(250);
    let res = run_app(&mut terminal, &mut app, tick_rate);

    // Restore terminal
    disable_raw_mode()?;
    execute!(
        terminal.backend_mut(),
        LeaveAlternateScreen,
        DisableMouseCapture
    )?;
    terminal.show_cursor()?;

    if let Err(err) = res {
        println!("{:?}", err)
    }

    Ok(())
}

fn handle_evidence_setup() -> Result<()> {
    use std::path::Path;
    use std::fs;

    let marker_file = Path::new("bi/workspace/.initialized");

    println!("🔍 Checking Evidence initialization status...");
    println!("   Marker file: {}", marker_file.display());
    println!("   Exists: {}", marker_file.exists());
    println!();

    // Check if this is first time setup
    if !marker_file.exists() {
        println!("╔══════════════════════════════════════════════════════════╗");
        println!("║  🎬 First-Time Evidence Setup Detected                  ║");
        println!("╚══════════════════════════════════════════════════════════╝");
        println!();
        println!("This will initialize Evidence workspace (one-time setup)");
        println!("Running: docker compose -f docker-compose.init.yml up --build");
        println!();

        // Run Evidence initialization
        let init_status = Command::new("docker")
            .args(&["compose", "-f", "docker-compose.init.yml", "up", "--build"])
            .status()?;

        if !init_status.success() {
            eprintln!("⚠️  Evidence initialization failed!");
            eprintln!("You may need to run manually:");
            eprintln!("  docker compose -f docker-compose.init.yml up --build");
            std::process::exit(1);
        }

        // Shutdown init containers
        Command::new("docker")
            .args(&["compose", "-f", "docker-compose.init.yml", "down"])
            .status()?;

        println!();
        println!("✅ Evidence initialized successfully!");
        println!();

        // Build Evidence Docker image
        println!("Building Evidence Docker image...");
        let build_status = Command::new("docker")
            .args(&["compose", "build"])
            .status()?;

        if !build_status.success() {
            eprintln!("⚠️  Docker build failed!");
            std::process::exit(1);
        }

        // Create marker file
        if let Some(parent) = marker_file.parent() {
            fs::create_dir_all(parent)?;
        }
        fs::write(marker_file, "initialized")?;

        println!();
        println!("✅ Setup complete! Starting TUI...");
        println!();
        std::thread::sleep(Duration::from_secs(2));
    } else {
        println!("✅ Evidence already initialized. Skipping setup.");
        println!();
    }

    Ok(())
}

fn run_app(
    terminal: &mut Terminal<CrosstermBackend<std::io::Stdout>>,
    app: &mut App,
    tick_rate: Duration,
) -> Result<()> {
    let mut last_tick = Instant::now();

    loop {
        // Execute pending action BEFORE drawing, so user sees the updated state
        if app.execute_next_tick {
            app.execute_next_tick = false;
            // Force one redraw to remove confirmation dialog
            terminal.draw(|f| ui(f, app))?;
            // Now execute the blocking command
            app.execute_pending_action()?;
        }

        terminal.draw(|f| ui(f, app))?;

        let timeout = tick_rate
            .checked_sub(last_tick.elapsed())
            .unwrap_or_else(|| Duration::from_secs(0));

        if crossterm::event::poll(timeout)? {
            if let Event::Key(key) = event::read()? {
                // Only handle key press events, not release or repeat
                if key.kind != KeyEventKind::Press {
                    continue;
                }

                if app.show_confirmation {
                    // Handle confirmation dialog
                    match key.code {
                        KeyCode::Char('y') | KeyCode::Char('Y') => {
                            app.show_confirmation = false;
                            app.execute_next_tick = true;
                            // Action will execute on next loop iteration after UI redraws
                        }
                        KeyCode::Char('n') | KeyCode::Char('N') | KeyCode::Esc => {
                            app.show_confirmation = false;
                            app.pending_action = None;
                            app.add_log("Action cancelled".to_string());
                        }
                        _ => {}
                    }
                } else if app.show_help {
                    // Handle help screen
                    match key.code {
                        KeyCode::Char('h') | KeyCode::Char('?') | KeyCode::Esc => {
                            app.show_help = false;
                        }
                        _ => {}
                    }
                } else {
                    // Check if pipeline is busy
                    let is_busy = app.is_pipeline_busy();

                    // Handle main menu
                    match key.code {
                        KeyCode::Char('q') => app.should_quit = true,
                        KeyCode::Char('h') | KeyCode::Char('?') => {
                            if !is_busy {
                                app.show_help = true;
                            }
                        }
                        KeyCode::Char('1') => {
                            if !is_busy {
                                app.pending_action = Some(PendingAction::Fetch7Days);
                                app.show_confirmation = true;
                            } else {
                                app.add_log("⚠️  Pipeline busy - please wait for current operation to complete".to_string());
                            }
                        }
                        KeyCode::Char('2') => {
                            if !is_busy {
                                app.pending_action = Some(PendingAction::Fetch30Days);
                                app.show_confirmation = true;
                            } else {
                                app.add_log("⚠️  Pipeline busy - please wait for current operation to complete".to_string());
                            }
                        }
                        KeyCode::Char('3') => {
                            if !is_busy {
                                app.pending_action = Some(PendingAction::Fetch90Days);
                                app.show_confirmation = true;
                            } else {
                                app.add_log("⚠️  Pipeline busy - please wait for current operation to complete".to_string());
                            }
                        }
                        KeyCode::Char('4') => {
                            if !is_busy {
                                app.pending_action = Some(PendingAction::Transform);
                                app.show_confirmation = true;
                            } else {
                                app.add_log("⚠️  Pipeline busy - please wait for current operation to complete".to_string());
                            }
                        }
                        KeyCode::Char('5') => {
                            if !is_busy {
                                app.pending_action = Some(PendingAction::UpdateDashboard);
                                app.show_confirmation = true;
                            } else {
                                app.add_log("⚠️  Pipeline busy - please wait for current operation to complete".to_string());
                            }
                        }
                        KeyCode::Char('6') => {
                            if !is_busy {
                                app.pending_action = Some(PendingAction::FullPipeline30);
                                app.show_confirmation = true;
                            } else {
                                app.add_log("⚠️  Pipeline busy - please wait for current operation to complete".to_string());
                            }
                        }
                        KeyCode::Char('7') => {
                            if !is_busy {
                                app.pending_action = Some(PendingAction::FullPipeline90);
                                app.show_confirmation = true;
                            } else {
                                app.add_log("⚠️  Pipeline busy - please wait for current operation to complete".to_string());
                            }
                        }
                        KeyCode::Up => {
                            app.log_scroll = app.log_scroll.saturating_sub(1);
                        }
                        KeyCode::Down => {
                            if app.log_scroll < app.logs.len().saturating_sub(1) {
                                app.log_scroll += 1;
                            }
                        }
                        _ => {}
                    }
                }
            }
        }

        if last_tick.elapsed() >= tick_rate {
            last_tick = Instant::now();
        }

        if app.should_quit {
            return Ok(());
        }
    }
}

fn ui(f: &mut Frame, app: &App) {
    // Render help screen if active
    if app.show_help {
        render_help_screen(f);
        return;
    }

    // Render confirmation dialog on top if active
    if app.show_confirmation {
        render_confirmation_dialog(f, app);
        return;
    }

    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3),   // Title
            Constraint::Min(10),     // Main content (flexible)
            Constraint::Length(3),   // Status bar
        ])
        .split(f.area());

    // Split main content area
    let main_chunks = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([
            Constraint::Percentage(40),  // Left panel (menu + status)
            Constraint::Percentage(60),  // Right panel (logs)
        ])
        .split(chunks[1]);

    // Split left panel vertically
    let left_chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(18),  // Menu
            Constraint::Min(8),      // Pipeline Status
        ])
        .split(main_chunks[0]);

    // Title bar with gradient effect
    let title = Paragraph::new("🚂  Fintraffic Railway Data Pipeline  │  Professional Data Engineering TUI")
        .style(Style::default()
            .fg(Color::Rgb(100, 200, 255))
            .add_modifier(Modifier::BOLD))
        .alignment(Alignment::Center)
        .block(Block::default()
            .borders(Borders::ALL)
            .border_style(Style::default().fg(Color::Rgb(50, 150, 255)))
            .border_type(ratatui::widgets::BorderType::Rounded));
    f.render_widget(title, chunks[0]);

    // Menu (left panel top)
    let is_busy = app.is_pipeline_busy();
    let menu_style = if is_busy {
        Style::default().fg(Color::Rgb(100, 100, 100)) // Dimmed when busy
    } else {
        Style::default().fg(Color::White)
    };

    let mut menu_items = vec![
        Line::from(Span::styled("📋 Data Ingestion", Style::default().fg(Color::Rgb(100, 200, 255)).add_modifier(Modifier::BOLD))),
        Line::from(Span::styled("  1│ Last 7 days  (Quick)", menu_style)),
        Line::from(Span::styled("  2│ Last 30 days (Standard)", menu_style)),
        Line::from(Span::styled("  3│ Last 90 days (Quarter)", menu_style)),
        Line::from(""),
        Line::from(Span::styled("⚙️  Pipeline Steps", Style::default().fg(Color::Rgb(255, 200, 100)).add_modifier(Modifier::BOLD))),
        Line::from(Span::styled("  4│ dbt Transform", menu_style)),
        Line::from(Span::styled("  5│ Update Dashboard", menu_style)),
        Line::from(""),
        Line::from(Span::styled("🚀 Full Pipeline", Style::default().fg(Color::Rgb(100, 255, 150)).add_modifier(Modifier::BOLD))),
        Line::from(Span::styled("  6│ Run All (30 days)", menu_style)),
        Line::from(Span::styled("  7│ Run All (90 days)", menu_style)),
        Line::from(""),
    ];

    // Add busy indicator or normal help text
    if is_busy {
        menu_items.push(Line::from(Span::styled("  ⏳ PIPELINE RUNNING...", Style::default().fg(Color::Yellow).add_modifier(Modifier::BOLD | Modifier::SLOW_BLINK))));
    } else {
        menu_items.push(Line::from(Span::styled("  h│Help  q│Quit", Style::default().fg(Color::Gray))));
    }

    let menu_widget = Paragraph::new(menu_items)
        .block(Block::default()
            .borders(Borders::ALL)
            .border_type(BorderType::Rounded)
            .border_style(Style::default().fg(Color::Rgb(80, 80, 80)))
            .title(Span::styled("╢ Commands ╟", Style::default().fg(Color::Cyan).add_modifier(Modifier::BOLD))))
        .style(Style::default().fg(Color::White));
    f.render_widget(menu_widget, left_chunks[0]);

    // Pipeline Status (left panel bottom)
    render_pipeline_status(f, left_chunks[1], &app.pipeline_status);

    // Logs (right panel) with scrollbar
    let log_height = main_chunks[1].height.saturating_sub(2) as usize;
    let log_start = app.log_scroll;
    let log_end = (log_start + log_height).min(app.logs.len());

    let logs: Vec<ListItem> = app.logs[log_start..log_end]
        .iter()
        .map(|log| {
            // Color-code logs based on content
            let style = if log.contains("completed successfully") || log.contains("Complete") {
                Style::default().fg(Color::Green)
            } else if log.contains("failed") || log.contains("Error") {
                Style::default().fg(Color::Red)
            } else if log.contains("Starting") || log.contains("Running") {
                Style::default().fg(Color::Yellow)
            } else if log.contains("cancelled") {
                Style::default().fg(Color::Rgb(200, 200, 100))
            } else {
                Style::default().fg(Color::White)
            };
            ListItem::new(log.as_str()).style(style)
        })
        .collect();

    let logs_widget = List::new(logs)
        .block(Block::default()
            .borders(Borders::ALL)
            .border_type(BorderType::Rounded)
            .border_style(Style::default().fg(Color::Rgb(80, 80, 80)))
            .title(Span::styled(
                format!("╢ Activity Log ({}/{}) - Use ↑↓ to scroll ╟", log_end, app.logs.len()),
                Style::default().fg(Color::Cyan).add_modifier(Modifier::BOLD)
            )))
        .style(Style::default());
    f.render_widget(logs_widget, main_chunks[1]);

    // Status bar (bottom)
    render_status_bar(f, chunks[2], app);
}

fn render_pipeline_status(f: &mut Frame, area: Rect, status: &PipelineStatus) {
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(2),
            Constraint::Length(2),
            Constraint::Length(2),
        ])
        .margin(1)
        .split(area);

    let block = Block::default()
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)
        .border_style(Style::default().fg(Color::Rgb(80, 80, 80)))
        .title(Span::styled("╢ Pipeline Status ╟", Style::default().fg(Color::Magenta).add_modifier(Modifier::BOLD)));
    f.render_widget(block, area);

    // Ingestion
    let ingestion_gauge = create_stage_gauge("📥 Ingestion   ", &status.ingestion);
    f.render_widget(ingestion_gauge, chunks[0]);

    // Transformation
    let transform_gauge = create_stage_gauge("⚙️  Transform   ", &status.transformation);
    f.render_widget(transform_gauge, chunks[1]);

    // Dashboard
    let dashboard_gauge = create_stage_gauge("📊 Dashboard   ", &status.dashboard);
    f.render_widget(dashboard_gauge, chunks[2]);
}

fn create_stage_gauge<'a>(label: &'a str, stage: &pipeline::StageStatus) -> Gauge<'a> {
    let (ratio, color, status_text, symbol) = match stage {
        pipeline::StageStatus::Pending => (0.0, Color::Rgb(100, 100, 100), "Pending   ", "○"),
        pipeline::StageStatus::Running => (0.5, Color::Rgb(255, 200, 50), "Running...", "◐"),
        pipeline::StageStatus::Completed => (1.0, Color::Rgb(50, 255, 100), "Completed ", "●"),
        pipeline::StageStatus::Failed => (1.0, Color::Rgb(255, 80, 80), "Failed    ", "✖"),
    };

    Gauge::default()
        .block(Block::default())
        .gauge_style(Style::default().fg(color).bg(Color::Rgb(30, 30, 30)))
        .ratio(ratio)
        .label(format!("{} {} {}", symbol, label, status_text))
        .use_unicode(true)
}

fn render_confirmation_dialog(f: &mut Frame, app: &App) {
    // Create a centered popup
    let area = f.area();
    let popup_width = 60;
    let popup_height = 10;

    let popup_area = Rect {
        x: (area.width.saturating_sub(popup_width)) / 2,
        y: (area.height.saturating_sub(popup_height)) / 2,
        width: popup_width.min(area.width),
        height: popup_height.min(area.height),
    };

    // Background block
    let block = Block::default()
        .borders(Borders::ALL)
        .border_style(Style::default().fg(Color::Yellow))
        .title("⚠️  Confirmation Required")
        .style(Style::default().bg(Color::Black));

    f.render_widget(block, popup_area);

    // Inner content area
    let inner_area = Rect {
        x: popup_area.x + 2,
        y: popup_area.y + 2,
        width: popup_area.width.saturating_sub(4),
        height: popup_area.height.saturating_sub(4),
    };

    // Create the description text with proper lifetime
    let description = format!("  {}", app.get_action_description());

    let text = vec![
        Line::from(""),
        Line::from(Span::styled(&description, Style::default().fg(Color::Yellow))),
        Line::from(""),
        Line::from("  Are you sure you want to continue?"),
        Line::from(""),
        Line::from(Span::styled("  [Y] Yes, continue", Style::default().fg(Color::Green))),
        Line::from(Span::styled("  [N] No, cancel (or press ESC)", Style::default().fg(Color::Red))),
        Line::from(""),
    ];

    let paragraph = Paragraph::new(text)
        .style(Style::default().fg(Color::White))
        .alignment(Alignment::Left);

    f.render_widget(paragraph, inner_area);
}
