import Foundation
import ArgumentParser

struct RecordCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "record",
        abstract: "Record video of a simulator"
    )

    @Argument(help: "The simulator device ID")
    var deviceId: String

    @Option(help: "Output path for the video")
    var outputPath: String?

    func run() throws {
        let controller = SimulatorController()
        let path = outputPath ?? "simulator_\(deviceId)_\(Int(Date().timeIntervalSince1970)).mp4"
        try controller.startRecording(deviceId: deviceId, outputPath: path)
        print("Recording started. Press Ctrl+C to stop recording.")
    }
}