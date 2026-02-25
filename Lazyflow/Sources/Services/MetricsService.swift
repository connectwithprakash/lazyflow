import Foundation
import MetricKit
import os

/// Collects runtime performance metrics and crash diagnostics via MetricKit
/// Subscribes to MXMetricManager for daily metric payloads and immediate crash reports
final class MetricsService: NSObject, MXMetricManagerSubscriber {
    static let shared = MetricsService()

    private let logger = Logger(subsystem: "com.lazyflow.app", category: "Metrics")
    private var isCollecting = false

    private override init() {
        super.init()
    }

    /// Subscribe to MetricKit payloads — call once at app launch (idempotent)
    func startCollecting() {
        guard !isCollecting else { return }
        isCollecting = true
        MXMetricManager.shared.add(self)
        logger.info("MetricKit subscriber registered")
    }

    /// Unsubscribe (typically not needed, but available for testing)
    func stopCollecting() {
        MXMetricManager.shared.remove(self)
    }

    // MARK: - MXMetricManagerSubscriber

    /// Called once per day with aggregated performance metrics
    func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            processMetricPayload(payload)
        }
    }

    /// Called immediately when a crash or diagnostic event occurs
    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            processDiagnosticPayload(payload)
        }
    }

    // MARK: - Metric Processing

    private func processMetricPayload(_ payload: MXMetricPayload) {
        logger.info("Received MetricKit payload for \(payload.timeStampBegin, privacy: .public) – \(payload.timeStampEnd, privacy: .public)")

        // Memory metrics
        if let memoryMetrics = payload.memoryMetrics {
            let peakMB = memoryMetrics.peakMemoryUsage.converted(to: .megabytes).value
            logger.info("Peak memory: \(peakMB, privacy: .public) MB")
        }

        // Disk write metrics
        if let diskMetrics = payload.diskIOMetrics {
            let writesMB = diskMetrics.cumulativeLogicalWrites.converted(to: .megabytes).value
            logger.info("Cumulative disk writes: \(writesMB, privacy: .public) MB")
        }

        // CPU metrics
        if let cpuMetrics = payload.cpuMetrics {
            let cpuTimeSec = cpuMetrics.cumulativeCPUTime.converted(to: .seconds).value
            logger.info("Cumulative CPU time: \(cpuTimeSec, privacy: .public)s")
        }

        // Log full JSON for detailed analysis in Console.app
        let jsonData = payload.jsonRepresentation()
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            logger.debug("Full metric payload: \(jsonString, privacy: .private)")
        }
    }

    private func processDiagnosticPayload(_ payload: MXDiagnosticPayload) {
        logger.error("Received diagnostic payload at \(payload.timeStampBegin, privacy: .public)")

        if let crashDiagnostics = payload.crashDiagnostics {
            for crash in crashDiagnostics {
                logger.error("Crash: \(crash.applicationVersion, privacy: .public), signal: \(crash.signal, privacy: .public)")
            }
        }

        if let hangDiagnostics = payload.hangDiagnostics {
            logger.warning("Hang diagnostics count: \(hangDiagnostics.count, privacy: .public)")
        }

        if let diskWriteDiagnostics = payload.diskWriteExceptionDiagnostics {
            logger.warning("Disk write exceptions: \(diskWriteDiagnostics.count, privacy: .public)")
        }

        if let cpuDiagnostics = payload.cpuExceptionDiagnostics {
            logger.warning("CPU exceptions: \(cpuDiagnostics.count, privacy: .public)")
        }

        // Log full JSON for detailed crash analysis
        let jsonData = payload.jsonRepresentation()
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            logger.error("Full diagnostic payload: \(jsonString, privacy: .private)")
        }
    }
}
