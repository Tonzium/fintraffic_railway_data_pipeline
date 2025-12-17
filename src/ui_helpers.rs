// UI Helper functions for professional rendering

use ratatui::{
    layout::{Alignment, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, BorderType, Paragraph, Wrap},
    Frame,
};

use crate::App;

pub fn render_status_bar(f: &mut Frame, area: Rect, app: &App) {
    let is_busy = app.is_pipeline_busy();

    let status_text = if is_busy {
        "⏳ Processing - Please Wait"
    } else if app.pipeline_status.all_completed() {
        "✓ Pipeline Complete"
    } else if app.pipeline_status.has_failures() {
        "✖ Pipeline Failed"
    } else {
        "⚡ Ready"
    };

    let status_color = if is_busy {
        Color::Yellow
    } else if app.pipeline_status.all_completed() {
        Color::Green
    } else if app.pipeline_status.has_failures() {
        Color::Red
    } else {
        Color::Cyan
    };

    let status_spans = vec![
        Span::styled(
            format!(" {} ", status_text),
            Style::default().fg(status_color).add_modifier(Modifier::BOLD),
        ),
        Span::raw(" │ "),
        Span::styled(
            "💾 Fintraffic Digitraffic API",
            Style::default().fg(Color::Rgb(150, 150, 150)),
        ),
        Span::raw(" │ "),
        Span::styled(
            format!("📊 {} trains processed", app.total_trains_processed),
            Style::default().fg(Color::Rgb(100, 200, 255)),
        ),
        Span::raw(" │ "),
        Span::styled(
            "Press 'h' for help",
            Style::default().fg(Color::Yellow),
        ),
    ];

    let status_bar = Paragraph::new(Line::from(status_spans))
        .alignment(Alignment::Left)
        .block(
            Block::default()
                .borders(Borders::ALL)
                .border_type(BorderType::Rounded)
                .border_style(Style::default().fg(Color::Rgb(80, 80, 80))),
        );

    f.render_widget(status_bar, area);
}

pub fn render_help_screen(f: &mut Frame) {
    let area = f.area();

    // Create centered help dialog
    let popup_width = 80.min(area.width.saturating_sub(4));
    let popup_height = 30.min(area.height.saturating_sub(4));

    let popup_area = Rect {
        x: (area.width.saturating_sub(popup_width)) / 2,
        y: (area.height.saturating_sub(popup_height)) / 2,
        width: popup_width,
        height: popup_height,
    };

    let help_text = vec![
        Line::from(""),
        Line::from(Span::styled("🚂 Fintraffic Railway Data Pipeline - Help", Style::default().fg(Color::Cyan).add_modifier(Modifier::BOLD))),
        Line::from(""),
        Line::from(Span::styled("═══ Data Ingestion ═══", Style::default().fg(Color::Rgb(100, 200, 255)).add_modifier(Modifier::BOLD))),
        Line::from("  1  │  Fetch last 7 days    (Quick test, ~1-2 minutes)"),
        Line::from("  2  │  Fetch last 30 days   (Standard analysis, ~3-5 minutes)"),
        Line::from("  3  │  Fetch last 90 days   (Full quarter, ~15-20 minutes)"),
        Line::from(""),
        Line::from(Span::styled("═══ Pipeline Steps ═══", Style::default().fg(Color::Rgb(255, 200, 100)).add_modifier(Modifier::BOLD))),
        Line::from("  4  │  Run dbt transformation  (Bronze→Silver→Gold layers)"),
        Line::from("  5  │  Update Evidence dashboard (Copy DuckDB to workspace)"),
        Line::from(""),
        Line::from(Span::styled("═══ Full Pipeline ═══", Style::default().fg(Color::Rgb(100, 255, 150)).add_modifier(Modifier::BOLD))),
        Line::from("  6  │  Run complete pipeline (30 days)"),
        Line::from("  7  │  Run complete pipeline (90 days)"),
        Line::from(""),
        Line::from(Span::styled("═══ Navigation ═══", Style::default().fg(Color::Rgb(255, 150, 255)).add_modifier(Modifier::BOLD))),
        Line::from("  ↑  │  Scroll logs up"),
        Line::from("  ↓  │  Scroll logs down"),
        Line::from("  h  │  Toggle this help screen"),
        Line::from("  ?  │  Toggle this help screen"),
        Line::from("  q  │  Quit application"),
        Line::from(""),
    ];

    let help_paragraph = Paragraph::new(help_text)
        .block(
            Block::default()
                .borders(Borders::ALL)
                .border_type(BorderType::Double)
                .border_style(Style::default().fg(Color::Cyan))
                .title(Span::styled(" ❓ Help & Documentation ", Style::default().fg(Color::Cyan).add_modifier(Modifier::BOLD))),
        )
        .wrap(Wrap { trim: false })
        .scroll((0, 0));

    // Clear background
    let clear_block = Block::default().style(Style::default().bg(Color::Black));
    f.render_widget(clear_block, area);

    // Render help dialog
    f.render_widget(help_paragraph, popup_area);
}
