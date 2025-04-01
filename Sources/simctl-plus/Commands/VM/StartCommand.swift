import ArgumentParser
import Foundation

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