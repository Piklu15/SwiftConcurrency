//
//  DetachedTaskDemoView.swift
//  SwiftConcurrency
//

import SwiftUI

struct DetachedTaskDemoView: View {
    @State private var viewModel = DetachedTaskViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    introCard
                    responsivenessCard
                    runCard
                    resultCard
                    codeCard
                }
                .padding()
            }
            .navigationTitle("Task.detached")
        }
    }

    private var introCard: some View {
        DemoCard(
            title: "What is Task.detached?",
            systemImage: "cpu",
            subtitle: "Task { } inherits the current actor, priority and task-local values. Task.detached { } inherits none of them, so it is a way to push heavy synchronous work off the main thread. Here we count prime numbers to keep the CPU busy."
        ) {
            EmptyView()
        }
    }

    private var responsivenessCard: some View {
        DemoCard(
            title: "Is the main thread free?",
            systemImage: "gauge.with.dots.needle.67percent",
            subtitle: "If the gear stops spinning or taps don't register, the main thread is blocked."
        ) {
            HStack(spacing: 16) {
                TimelineView(.animation) { context in
                    let angle = context.date.timeIntervalSinceReferenceDate
                        .truncatingRemainder(dividingBy: 2) * 180
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.tint)
                        .rotationEffect(.degrees(angle))
                }

                Button {
                    viewModel.tap()
                } label: {
                    Label("Tap me (\(viewModel.tapCount))", systemImage: "hand.tap")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var runCard: some View {
        DemoCard(title: "Run the work", systemImage: "play.circle") {
            @Bindable var viewModel = viewModel

            Picker("Workload", selection: $viewModel.limit) {
                ForEach(DetachedTaskViewModel.workloads, id: \.self) { limit in
                    Text("\(limit / 1_000_000)M numbers").tag(limit)
                }
            }
            .pickerStyle(.segmented)
            .disabled(viewModel.isRunning)

            ForEach(DetachedTaskViewModel.Strategy.allCases) { strategy in
                Button {
                    viewModel.run(strategy)
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: strategy.symbol)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(strategy.title)
                                .font(.subheadline.monospaced().bold())
                            Text(strategy.explanation)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                        }
                        Spacer()
                        if viewModel.running == strategy {
                            ProgressView()
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isRunning)
            }

            Button(role: .destructive) {
                viewModel.cancel()
            } label: {
                Label("Cancel", systemImage: "xmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(!viewModel.isRunning)

            Text("Notice: in the Task { } case you can't even tap Cancel, because the main thread is busy.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var resultCard: some View {
        if let result = viewModel.result, let strategy = viewModel.resultStrategy {
            DemoCard(title: "Result: \(strategy.title)", systemImage: "list.bullet.rectangle") {
                ResultRow(
                    title: "Ran on main thread",
                    value: result.ranOnMainThread ? "Yes ❌" : "No ✅",
                    valueColor: result.ranOnMainThread ? .red : .green
                )
                ResultRow(title: "Task priority", value: result.priority.name)
                ResultRow(title: "Time", value: String(format: "%.2fs", result.duration))
                ResultRow(title: "Primes found", value: result.primeCount.formatted())
                ResultRow(title: "Largest prime", value: result.largestPrime.formatted())
                ResultRow(
                    title: "Cancelled",
                    value: result.wasCancelled
                        ? "Yes, at \(result.checkedUpTo.formatted()) of \(result.limit.formatted())"
                        : "No",
                    valueColor: result.wasCancelled ? .orange : .primary
                )
            }
        }
    }

    private var codeCard: some View {
        DemoCard(title: "The code", systemImage: "chevron.left.forwardslash.chevron.right") {
            CodeSnippetView(code: """
            // ❌ Inherits @MainActor → blocks the UI
            Task {
                let r = PrimeCalculator.countPrimes(upTo: n)
            }

            // ✅ No actor → runs in the background
            let worker = Task.detached(priority: .userInitiated) {
                PrimeCalculator.countPrimes(upTo: n)
            }
            // Detached tasks are unstructured: forward cancellation yourself.
            let r = await withTaskCancellationHandler {
                await worker.value
            } onCancel: {
                worker.cancel()
            }

            // ✅ Preferred: an @concurrent function
            @concurrent
            static func countPrimesInBackground(upTo n: Int) async -> PrimeResult
            """)

            Text("Use Task.detached sparingly. It loses priority, task-local values and automatic cancellation. In most cases an @concurrent (or nonisolated) async function is the better choice.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    DetachedTaskDemoView()
}
