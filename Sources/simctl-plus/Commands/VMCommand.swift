import ArgumentParser
import Foundation
import Virtualization

struct VMCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "vm",
        abstract: "Create and manage custom macOS VMs using Virtualization.framework",
        subcommands: [CreateCommand.self, VMListCommand.self, StartCommand.self, StopCommand.self]
    )
}

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

struct VMListCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List all available VMs"
    )

    func run() throws {
        let vmManager = VMManager()
        let vms = try vmManager.listVMs()

        if vms.isEmpty {
            print("No VMs found")
            return
        }

        print("Available VMs:")
        for vm in vms {
            print("- \(vm.name) (\(vm.state.description))")
        }
    }
}

struct StartCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "start",
        abstract: "Start a VM"
    )

    @Argument(help: "Name of the VM to start")
    var name: String

    func run() throws {
        let vmManager = VMManager()

        // Create a semaphore to wait for the async operation
        let semaphore = DispatchSemaphore(value: 0)
        var asyncError: Error?

        Task {
            do {
                try await vmManager.startVM(name: name)
                print("VM '\(name)' started successfully")
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

struct StopCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "stop",
        abstract: "Stop a VM"
    )

    @Argument(help: "Name of the VM to stop")
    var name: String

    func run() throws {
        let vmManager = VMManager()

        // Create a semaphore to wait for the async operation
        let semaphore = DispatchSemaphore(value: 0)
        var asyncError: Error?

        Task {
            do {
                try await vmManager.stopVM(name: name)
                print("VM '\(name)' stopped successfully")
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

struct VMConfiguration {
    let name: String
    let memorySize: UInt64
    let cpuCount: UInt
    let diskSize: UInt64
}
