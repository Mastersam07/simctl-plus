import ArgumentParser
import Foundation

struct StopCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "stop",
        abstract: "Stop a VM"
    )

    @Argument(help: "Name of the VM to stop")
    var name: String

    func run() throws {
        let vmManager = VMManager()

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

        semaphore.wait()

        if let error = asyncError {
            throw error
        }
    }
}
