//
//  GTNWWidget.swift
//  GTNW Widget
//
//  WidgetKit widget for Global Thermal Nuclear War
//  Shows DEFCON level, current turn, president, and war status
//  Created by Jordan Koch
//

import WidgetKit
import SwiftUI

// MARK: - Widget Provider

struct GTNWWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> GTNWWidgetEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (GTNWWidgetEntry) -> Void) {
        let data = SharedDataManager.shared.loadWidgetData()
        let entry = GTNWWidgetEntry(date: Date(), data: data)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GTNWWidgetEntry>) -> Void) {
        let data = SharedDataManager.shared.loadWidgetData()
        let entry = GTNWWidgetEntry(date: Date(), data: data)

        // Refresh every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Widget Views

/// Small widget view - DEFCON indicator
struct GTNWWidgetSmallView: View {
    let entry: GTNWWidgetEntry

    var body: some View {
        ZStack {
            // Background gradient based on DEFCON
            LinearGradient(
                gradient: Gradient(colors: [
                    entry.data.defconColor.opacity(0.3),
                    Color.black
                ]),
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 4) {
                // DEFCON Level
                Text("DEFCON")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))

                Text("\(entry.data.defconLevel)")
                    .font(.system(size: 48, weight: .heavy, design: .monospaced))
                    .foregroundColor(entry.data.defconColor)
                    .shadow(color: entry.data.defconColor.opacity(0.8), radius: 10)

                Text(entry.data.defconDescription)
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .foregroundColor(entry.data.defconColor)

                Spacer().frame(height: 4)

                // War status indicator
                HStack(spacing: 4) {
                    Circle()
                        .fill(entry.data.warStatusColor)
                        .frame(width: 6, height: 6)
                    Text(entry.data.warStatusText)
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(entry.data.warStatusColor)
                }

                // Turn number
                Text("TURN \(entry.data.turn)")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(8)
        }
    }
}

/// Medium widget view - Full status
struct GTNWWidgetMediumView: View {
    let entry: GTNWWidgetEntry

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black,
                    entry.data.defconColor.opacity(0.2)
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )

            HStack(spacing: 12) {
                // Left side - DEFCON
                VStack(spacing: 2) {
                    Text("DEFCON")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))

                    Text("\(entry.data.defconLevel)")
                        .font(.system(size: 56, weight: .heavy, design: .monospaced))
                        .foregroundColor(entry.data.defconColor)
                        .shadow(color: entry.data.defconColor.opacity(0.6), radius: 8)

                    Text(entry.data.defconDescription)
                        .font(.system(size: 7, weight: .semibold, design: .monospaced))
                        .foregroundColor(entry.data.defconColor)
                }
                .frame(width: 80)

                // Divider
                Rectangle()
                    .fill(entry.data.defconColor.opacity(0.3))
                    .frame(width: 1)

                // Right side - Details
                VStack(alignment: .leading, spacing: 6) {
                    // President
                    VStack(alignment: .leading, spacing: 1) {
                        Text("COMMANDER IN CHIEF")
                            .font(.system(size: 7, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.5))
                        Text(entry.data.presidentName)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }

                    // Status row
                    HStack(spacing: 12) {
                        // Turn
                        VStack(alignment: .leading, spacing: 1) {
                            Text("TURN")
                                .font(.system(size: 7, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.5))
                            Text("\(entry.data.turn)")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        }

                        // War Status
                        VStack(alignment: .leading, spacing: 1) {
                            Text("STATUS")
                                .font(.system(size: 7, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.5))
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(entry.data.warStatusColor)
                                    .frame(width: 6, height: 6)
                                Text(entry.data.warStatusText)
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundColor(entry.data.warStatusColor)
                            }
                        }
                    }

                    // Metrics row
                    HStack(spacing: 12) {
                        // Casualties
                        VStack(alignment: .leading, spacing: 1) {
                            Text("CASUALTIES")
                                .font(.system(size: 6, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.5))
                            Text(entry.data.formattedCasualties)
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundColor(entry.data.totalCasualties > 0 ? .red : .green)
                        }

                        // Radiation
                        VStack(alignment: .leading, spacing: 1) {
                            Text("RADIATION")
                                .font(.system(size: 6, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.5))
                            Text(entry.data.radiationLevel)
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundColor(entry.data.radiationColor)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(10)
        }
    }
}

/// Large widget view - Command center style
struct GTNWWidgetLargeView: View {
    let entry: GTNWWidgetEntry

    var body: some View {
        ZStack {
            // Background
            Color.black

            VStack(spacing: 0) {
                // Header
                HStack {
                    Image(systemName: "shield.fill")
                        .foregroundColor(entry.data.defconColor)
                    Text("GTNW SITUATION ROOM")
                        .font(.system(size: 12, weight: .heavy, design: .monospaced))
                        .foregroundColor(.white)
                    Spacer()
                    Text("TURN \(entry.data.turn)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(entry.data.defconColor.opacity(0.2))

                // Main content
                HStack(spacing: 16) {
                    // DEFCON Display
                    VStack(spacing: 4) {
                        Text("DEFENSE CONDITION")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.6))

                        ZStack {
                            Circle()
                                .stroke(entry.data.defconColor.opacity(0.3), lineWidth: 8)
                                .frame(width: 100, height: 100)

                            Circle()
                                .trim(from: 0, to: CGFloat(6 - entry.data.defconLevel) / 5.0)
                                .stroke(entry.data.defconColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                .frame(width: 100, height: 100)
                                .rotationEffect(.degrees(-90))

                            VStack(spacing: 0) {
                                Text("\(entry.data.defconLevel)")
                                    .font(.system(size: 40, weight: .heavy, design: .monospaced))
                                    .foregroundColor(entry.data.defconColor)
                                Text(entry.data.defconDescription)
                                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                                    .foregroundColor(entry.data.defconColor.opacity(0.8))
                            }
                        }
                        .shadow(color: entry.data.defconColor.opacity(0.5), radius: 10)
                    }
                    .frame(width: 120)

                    // Details Panel
                    VStack(alignment: .leading, spacing: 10) {
                        // President
                        DetailRow(
                            icon: "person.fill",
                            label: "PRESIDENT",
                            value: entry.data.presidentName,
                            color: .white
                        )

                        // Administration
                        DetailRow(
                            icon: "building.columns.fill",
                            label: "ADMINISTRATION",
                            value: entry.data.administrationName,
                            color: .white.opacity(0.8)
                        )

                        // War Status
                        DetailRow(
                            icon: entry.data.isAtWar ? "flame.fill" : "leaf.fill",
                            label: "WAR STATUS",
                            value: entry.data.warStatusText,
                            color: entry.data.warStatusColor
                        )

                        Divider()
                            .background(Color.white.opacity(0.2))

                        // Metrics
                        HStack(spacing: 16) {
                            MetricBox(
                                label: "CASUALTIES",
                                value: entry.data.formattedCasualties,
                                color: entry.data.totalCasualties > 0 ? .red : .green
                            )

                            MetricBox(
                                label: "RADIATION",
                                value: "\(entry.data.globalRadiation)%",
                                color: entry.data.radiationColor
                            )

                            MetricBox(
                                label: "WARS",
                                value: "\(entry.data.activeWarsCount)",
                                color: entry.data.isAtWar ? .orange : .green
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(12)

                Spacer()

                // Footer
                HStack {
                    if entry.data.gameOver {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text("GAME OVER: \(entry.data.gameOverReason)")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.red)
                    } else {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.white.opacity(0.5))
                        Text("Last updated: \(entry.data.lastUpdated.formatted(date: .omitted, time: .shortened))")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    Spacer()
                    Text("GLOBAL THERMAL NUCLEAR WAR")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.3))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.05))
            }
        }
    }
}

// MARK: - Helper Views

struct DetailRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(color.opacity(0.7))
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
                Text(value)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(color)
                    .lineLimit(1)
            }
        }
    }
}

struct MetricBox: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 6, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(color)
        }
        .frame(minWidth: 50)
    }
}

// MARK: - Widget Configuration

struct GTNWWidget: Widget {
    let kind: String = "GTNWWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GTNWWidgetProvider()) { entry in
            GTNWWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("GTNW Status")
        .description("Monitor your DEFCON level, current turn, and war status.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

/// Entry view that switches based on widget family
struct GTNWWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    let entry: GTNWWidgetEntry

    var body: some View {
        switch family {
        case .systemSmall:
            GTNWWidgetSmallView(entry: entry)
        case .systemMedium:
            GTNWWidgetMediumView(entry: entry)
        case .systemLarge:
            GTNWWidgetLargeView(entry: entry)
        default:
            GTNWWidgetSmallView(entry: entry)
        }
    }
}

// MARK: - Widget Bundle

@main
struct GTNWWidgetBundle: WidgetBundle {
    var body: some Widget {
        GTNWWidget()
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    GTNWWidget()
} timeline: {
    GTNWWidgetEntry(date: Date(), data: .sample)
    GTNWWidgetEntry(date: Date(), data: .criticalSample)
}

#Preview("Medium", as: .systemMedium) {
    GTNWWidget()
} timeline: {
    GTNWWidgetEntry(date: Date(), data: .sample)
    GTNWWidgetEntry(date: Date(), data: .criticalSample)
}

#Preview("Large", as: .systemLarge) {
    GTNWWidget()
} timeline: {
    GTNWWidgetEntry(date: Date(), data: .sample)
    GTNWWidgetEntry(date: Date(), data: .criticalSample)
}
