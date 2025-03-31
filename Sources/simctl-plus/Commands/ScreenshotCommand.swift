import Foundation
import ArgumentParser

struct ScreenshotCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "screenshot",
        abstract: "Take a screenshot of a simulator"
    )

    @Argument(help: "The simulator device ID")
    var deviceId: String

    @Option(help: "Output path for the screenshot")
    var outputPath: String?

    func run() throws {
        let controller = SimulatorController()
        let path = outputPath ?? "simulator_\(deviceId)_\(Int(Date().timeIntervalSince1970)).png"
        try controller.takeScreenshot(deviceId: deviceId, outputPath: path)
        print("Screenshot saved to \(path)")
    }
}