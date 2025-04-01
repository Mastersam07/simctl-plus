import Foundation
import ArgumentParser

struct UninstallCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "uninstall",
        abstract: "Uninstall an app from a simulator"
    )

    @Argument(help: "Bundle ID of the app to uninstall")
    var bundleId: String

    @Option(help: "The simulator device ID to uninstall from")
    var deviceId: String

    func run() throws {
        let controller = SimulatorController()
        try controller.uninstallApp(bundleId: bundleId, deviceId: deviceId)
        print("Successfully uninstalled \(bundleId) from simulator \(deviceId)")
    }
}