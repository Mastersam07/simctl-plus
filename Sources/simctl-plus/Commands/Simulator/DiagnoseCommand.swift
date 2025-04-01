import ArgumentParser
import Foundation

struct DiagnoseCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "diagnose",
        abstract: "Generate diagnostics report for a simulator"
    )

    @Argument(help: "The simulator device ID")
    var deviceId: String

    @Option(help: "Output directory for diagnostics")
    var output: String?

    @Option(help: "Timeout in seconds for log collection")
    var timeout: Int?

    @Flag(help: "Include all device logs, even for non-booted devices")
    var allLogs = false

    @Flag(help: "Include booted device(s) data directory")
    var dataContainers = false

    func run() throws {
        // First, check if the device exists
        let listProcess = Process()
        listProcess.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        listProcess.arguments = ["simctl", "list", "devices", "--json"]

        let listOutputPipe = Pipe()
        listProcess.standardOutput = listOutputPipe

        try listProcess.run()
        listProcess.waitUntilExit()

        let listOutputData = try listOutputPipe.fileHandleForReading.readToEnd() ?? Data()
        let listOutputString = String(data: listOutputData, encoding: .utf8) ?? ""

        if !listOutputString.contains(deviceId) {
            throw SimulatorError.deviceNotFound(deviceId)
        }

        var args = ["simctl", "diagnose", "-b", "--udid=\(deviceId)"]

        if let output = output {
            args.append(contentsOf: ["--output=\(output)"])
        }

        if let timeout = timeout {
            args.append(contentsOf: ["--timeout=\(String(timeout))"])
        }

        // Always include --all-logs since we want to collect logs for non-booted devices
        args.append("--all-logs")

        if dataContainers {
            args.append("--data-container")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = args

        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()

        // Force non-interactive mode, send newline to proceed with prompts
        if let inputData = "\n".data(using: .utf8) {
            try inputPipe.fileHandleForWriting.write(contentsOf: inputData)
            try inputPipe.fileHandleForWriting.close()
        }

        process.waitUntilExit()

        // Add a small delay to ensure files are written
        Thread.sleep(forTimeInterval: 1.0)

        let errorData = try errorPipe.fileHandleForReading.readToEnd() ?? Data()
        let errorString = String(data: errorData, encoding: .utf8) ?? ""

        let outputData = try outputPipe.fileHandleForReading.readToEnd() ?? Data()
        let outputString = String(data: outputData, encoding: .utf8) ?? ""

        // Print both output and error as they might contain useful information
        if !outputString.isEmpty {
            print(outputString)
        }
        if !errorString.isEmpty {
            print(errorString)
        }

        // If output directory was specified, check if files were generated
        if let output = output {
            let fileManager = FileManager.default
            let contents = try? fileManager.contentsOfDirectory(atPath: output)
            if let contents = contents, !contents.isEmpty {
                print("Diagnostics collected in: \(output)")
            } else {
                throw SimulatorError.commandFailed("No diagnostic files were generated")
            }
        }
    }
}
