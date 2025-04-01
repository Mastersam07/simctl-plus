import Foundation
import ArgumentParser

struct ShutdownCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "shutdown",
        abstract: "Shutdown a specific simulator"
    )

    @Argument(help: "The simulator device ID to shutdown")
    var deviceId: String

    func run() throws {
        let controller = SimulatorController()
        try controller.shutdownSimulator(deviceId: deviceId)
        print("Successfully shut down simulator \(deviceId)")
    }
}