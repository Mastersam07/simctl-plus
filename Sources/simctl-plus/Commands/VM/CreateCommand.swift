import ArgumentParser
import Foundation

struct CreateCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "create",
        abstract: "Create a new macOS VM"
    )

    @Option(help: "Name for the VM")
    var name: String

    @Option(help: "Memory size in GB (default: 4)")
    var memory: Int = 4

    @Option(help: "Number of CPU cores (default: 2)")
    var cpu: Int = 2

    @Option(help: "Disk size in GB (default: 64)")
    var disk: Int = 64

    @Option(help: "Path to store VM files (default: ~/Library/Application Support/simctl-plus/vms)")
    var path: String?

    func run() throws {
        let vmManager = VMManager()
        let config = VMConfiguration(
            name: name,
            memorySize: UInt64(memory) * 1024 * 1024 * 1024,
            cpuCount: UInt(cpu),
            diskSize: UInt64(disk) * 1024 * 1024 * 1024
        )

        // Create a semaphore to wait for the async operation
        let semaphore = DispatchSemaphore(value: 0)
        var asyncError: Error?

        Task {
            do {
                try await vmManager.createVM(config: config, path: path)
                print("VM '\(name)' created successfully")
            } catch {
                asyncError = error
            }
            semaphore.signal()
        }

        // Wait for the async operation to complete
        semaphore.wait()

        if let error = asyncError {
            throw error
        }
    }
}
