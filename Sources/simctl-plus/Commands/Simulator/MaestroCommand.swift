import ArgumentParser
import Foundation

struct MaestroCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "maestro",
        abstract: "Run Maestro test suites on simulators",
        subcommands: [
            RunTestCommand.self,
            ListTestsCommand.self,
        ]
    )
}

struct RunTestCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "run",
        abstract: "Run a Maestro test suite on specified simulators"
    )

    @Argument(help: "Path to the Maestro test suite")
    var testSuitePath: String

    @Option(help: "Comma-separated list of simulator device IDs (optional)")
    var deviceIds: String?

    @Option(help: "Path to Maestro executable (optional)")
    var maestroPath: String?

    @Flag(name: .long, help: "Run tests in parallel")
    var parallel: Bool = false

    private func findMaestroPath() throws -> String {
        if let path = maestroPath {
            return path
        }

        let possiblePaths = [
            "/usr/local/bin/maestro",
            "/opt/homebrew/bin/maestro",
            "/usr/bin/maestro",
        ]

        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["maestro"]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus == 0,
            let outputData = try? outputPipe.fileHandleForReading.readToEnd(),
            let path = String(data: outputData, encoding: .utf8)?.trimmingCharacters(
                in: .whitespacesAndNewlines),
            !path.isEmpty
        {
            return path
        }

        throw SimulatorError.commandFailed(
            "Maestro not found. Please install Maestro or specify its path using --maestro-path")
    }

    func run() async throws {
        let controller = SimulatorController()

        var targetSimulators: [SimulatorDevice] = []
        if let deviceIds = deviceIds {
            let ids = deviceIds.split(separator: ",").map(String.init)
            let allSimulators = try controller.listSimulators()
            targetSimulators = allSimulators.filter { ids.contains($0.udid) }

            if targetSimulators.isEmpty {
                throw SimulatorError.deviceNotFound("No simulators found with the specified IDs")
            }
        } else {
            targetSimulators = try controller.listSimulators().filter { $0.state == .booted }
            if targetSimulators.isEmpty {
                throw SimulatorError.simulatorNotFound("No booted simulators found")
            }
        }

        print("Running Maestro test suite on \(targetSimulators.count) simulator(s)...")

        if parallel {
            var errors: [Error] = []

            await withTaskGroup(of: Void.self) { group in
                for simulator in targetSimulators {
                    group.addTask {
                        do {
                            try await runTestOnSimulator(
                                simulator: simulator, testSuitePath: testSuitePath)
                        } catch {
                            errors.append(error)
                        }
                    }
                }
                await group.waitForAll()
            }

            if !errors.isEmpty {
                print("\nErrors encountered:")
                for error in errors {
                    print("- \(error.localizedDescription)")
                }
                throw SimulatorError.commandFailed("Some tests failed")
            }
        } else {

            for simulator in targetSimulators {
                do {
                    try await runTestOnSimulator(simulator: simulator, testSuitePath: testSuitePath)
                } catch {
                    throw error
                }
            }
        }

        print("\nAll tests completed successfully!")
    }

    private func runTestOnSimulator(simulator: SimulatorDevice, testSuitePath: String) async throws
    {
        print("\nRunning tests on \(simulator.name) (\(simulator.udid))...")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: try findMaestroPath())
        process.arguments = ["test", testSuitePath, "--device", simulator.udid]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errorData = try errorPipe.fileHandleForReading.readToEnd() ?? Data()
            let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw SimulatorError.commandFailed("Maestro test failed: \(errorString)")
        }

        let outputData = try outputPipe.fileHandleForReading.readToEnd() ?? Data()
        let outputString = String(data: outputData, encoding: .utf8) ?? ""
        print(outputString)
    }
}

struct ListTestsCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List available Maestro test suites"
    )

    @Option(help: "Directory to scan for test suites (default: current directory)")
    var directory: String = "."

    func run() throws {
        let fileManager = FileManager.default
        let directoryURL = URL(fileURLWithPath: directory)

        guard
            let contents = try? fileManager.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: nil
            )
        else {
            throw SimulatorError.commandFailed("Failed to read directory: \(directory)")
        }

        let testSuites = contents.filter { $0.pathExtension == "yaml" || $0.pathExtension == "yml" }

        if testSuites.isEmpty {
            print("No Maestro test suites found in \(directory)")
            return
        }

        print("Available Maestro test suites:")
        for suite in testSuites {
            print("- \(suite.lastPathComponent)")
        }
    }
}
