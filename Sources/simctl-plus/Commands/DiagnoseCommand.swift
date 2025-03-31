import Foundation
import ArgumentParser

struct DiagnoseCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "diagnose",
        abstract: "Generate diagnostics report for a simulator"
    )

    @Argument(help: "The simulator device ID")
    var deviceId: String

    func run() throws {
        let controller = SimulatorController()
        let report = try controller.getDiagnostics(deviceId: deviceId)
        print(report)
    }
}
