import Foundation
import ArgumentParser

struct InstallCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "install",
        abstract: "Install an app to a simulator"
    )

    @Argument(help: "Path to the .ipa or .app file")
    var appPath: String

    @Option(help: "The simulator device ID to install to")
    var deviceId: String

    func run() throws {
        let controller = SimulatorController()
        try controller.installApp(appPath: appPath, deviceId: deviceId)
        print("Successfully installed \(appPath) to simulator \(deviceId)")
    }
}