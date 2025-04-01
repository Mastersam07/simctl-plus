import ArgumentParser
import Foundation

struct SimulatorDiagnosticsCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "diagnostics",
        abstract: "Generate diagnostic reports and measure performance for iOS simulators",
        subcommands: [
            SimulatorReportCommand.self,
            SimulatorStartupTimeCommand.self
        ]
    )
}

struct SimulatorReportCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "report",
        abstract: "Generate a diagnostic report for a simulator"
    )

    @Argument(help: "Device ID of the simulator")
    var deviceId: String

    func run() throws {
        let controller = SimulatorController()
        let report = try controller.generateReport(deviceId: deviceId)
        print(report)
    }
}

struct SimulatorStartupTimeCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "startup-time",
        abstract: "Measure simulator startup time"
    )

    @Argument(help: "Device ID of the simulator")
    var deviceId: String

    func run() throws {
        let controller = SimulatorController()
        
        // Create a semaphore to wait for the async operation
        let semaphore = DispatchSemaphore(value: 0)
        var asyncError: Error?
        var startupTime: TimeInterval = 0

        Task {
            do {
                startupTime = try await controller.measureStartupTime(deviceId: deviceId)
                print("Simulator startup time: \(String(format: "%.2f", startupTime)) seconds")
            } catch {
                asyncError = error
            }
            semaphore.signal()
        }

        semaphore.wait()

        if let error = asyncError {
            throw error
        }
    }
} 