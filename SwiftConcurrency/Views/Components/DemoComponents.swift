//
//  DemoComponents.swift
//  SwiftConcurrency
//
//  Reusable building blocks shared by the concurrency demo screens.
//

import SwiftUI

/// A titled card with an explanation, used to group each part of a demo.
struct DemoCard<Content: View>: View {
    let title: String
    var systemImage: String = "info.circle"
    var subtitle: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            content
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
    }
}

/// Shows a code sample in a monospaced, horizontally scrollable box.
struct CodeSnippetView: View {
    let code: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Text(code)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .padding(10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
    }
}

/// A label/value row for result summaries.
struct ResultRow: View {
    let title: String
    let value: String
    var valueColor: Color = .primary

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .foregroundStyle(valueColor)
                .monospacedDigit()
        }
        .font(.subheadline)
    }
}

// MARK: - Timeline chart

/// Draws the entries of a `TimelineRecorder` as horizontal bars on a shared time axis.
struct TimelineChartView: View {
    let recorder: TimelineRecorder
    var minimumDuration: Double = 2
    var rowHeight: CGFloat = 16
    var labelWidth: CGFloat = 96

    var body: some View {
        if recorder.entries.isEmpty {
            Text("Run the demo to see when each task starts and finishes.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            // Redraws every frame while recording so running bars grow live.
            TimelineView(.animation(paused: !recorder.isRecording)) { _ in
                chart(now: recorder.currentTime)
            }
        }
    }

    private func chart(now: Double) -> some View {
        let latestEnd = recorder.entries.map { $0.end ?? now }.max() ?? 0
        let scale = max(minimumDuration, latestEnd, now)

        return VStack(alignment: .leading, spacing: 6) {
            ForEach(recorder.entries) { entry in
                HStack(spacing: 8) {
                    Text(entry.label)
                        .font(.caption.monospaced())
                        .lineLimit(1)
                        .frame(width: labelWidth, alignment: .leading)

                    GeometryReader { geometry in
                        let width = geometry.size.width
                        let x = entry.start / scale * width
                        let length = max(3, ((entry.end ?? now) - entry.start) / scale * width)
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.primary.opacity(0.06))
                            RoundedRectangle(cornerRadius: 4)
                                .fill(entry.outcome.color.gradient)
                                .frame(width: length)
                                .offset(x: x)
                        }
                    }
                    .frame(height: rowHeight)

                    Image(systemName: entry.outcome.symbol)
                        .font(.caption)
                        .foregroundStyle(entry.outcome.color)
                        .frame(width: 16)
                }
            }

            HStack {
                Text("0s")
                Spacer()
                Text(String(format: "%.1fs", scale))
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.secondary)
            .padding(.leading, labelWidth + 8)
            .padding(.trailing, 24)

            HStack(spacing: 12) {
                legend(.running, "running")
                legend(.success, "done")
                legend(.failed, "failed")
                legend(.cancelled, "cancelled")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private func legend(_ outcome: TimelineOutcome, _ title: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(outcome.color).frame(width: 8, height: 8)
            Text(title)
        }
    }
}

extension TimelineOutcome {
    var color: Color {
        switch self {
        case .running: .blue
        case .success: .green
        case .failed: .red
        case .cancelled: .orange
        }
    }

    var symbol: String {
        switch self {
        case .running: "ellipsis"
        case .success: "checkmark.circle.fill"
        case .failed: "xmark.octagon.fill"
        case .cancelled: "stop.circle.fill"
        }
    }
}

// MARK: - Event log

struct EventLogView: View {
    let log: EventLog
    var maxVisible = 15

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if log.entries.isEmpty {
                Text("Nothing logged yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            ForEach(log.entries.prefix(maxVisible)) { entry in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(entry.time, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute().second())
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Circle()
                        .fill(entry.kind.color)
                        .frame(width: 6, height: 6)
                    Text(entry.message)
                        .font(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.default, value: log.entries.count)
    }
}

extension EventLog.Kind {
    var color: Color {
        switch self {
        case .info: .blue
        case .success: .green
        case .warning: .orange
        case .error: .red
        }
    }
}
