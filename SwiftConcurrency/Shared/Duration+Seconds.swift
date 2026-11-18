//
//  Duration+Seconds.swift
//  SwiftConcurrency
//

import Foundation

extension Duration {
    /// The duration as fractional seconds, handy for display and for drawing timelines.
    nonisolated var seconds: Double {
        Double(components.seconds) + Double(components.attoseconds) / 1e18
    }
}

/// `true` for both kinds of cancellation error you'll meet in practice:
/// Swift's `CancellationError` and `URLSession`'s `URLError(.cancelled)`.
nonisolated func isCancellation(_ error: any Error) -> Bool {
    if error is CancellationError { return true }
    if let urlError = error as? URLError, urlError.code == .cancelled { return true }
    return false
}
