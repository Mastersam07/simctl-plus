import ArgumentParser
import Foundation

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