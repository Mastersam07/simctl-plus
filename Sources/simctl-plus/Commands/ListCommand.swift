import Foundation
import ArgumentParser

struct ListCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List all available simulators"
    )
    
    @Flag(name: .shortAndLong, help: "Show only booted simulators")
    var bootedOnly = false
    
    @Flag(name: .shortAndLong, help: "Show only shutdown simulators")
    var shutdownOnly = false
    
    @Flag(name: .shortAndLong, help: "Show only available simulators")
    var availableOnly = false
    
    func run() throws {
        let controller = SimulatorController()
        let simulators = try controller.listSimulators()
        
        // Filter simulators based on flags
        let filteredSimulators = simulators.filter { simulator in
            if bootedOnly && simulator.state != .booted { return false }
            if shutdownOnly && simulator.state != .shutdown { return false }
            if availableOnly && !simulator.isAvailable { return false }
            return true
        }
        
        // Print simulators in a formatted table
        print("\nAvailable Simulators:")
        print("----------------------------------------")
        print("Name\t\tState\t\tAvailable\tDevice Type")
        print("----------------------------------------")
        
        for simulator in filteredSimulators {
            let deviceType = simulator.deviceTypeIdentifier.split(separator: ".").last ?? ""
            print("\(simulator.name)\t\(simulator.state.rawValue)\t\(simulator.isAvailable ? "Yes" : "No")\t\(deviceType)")
        }
        
        print("\nTotal: \(filteredSimulators.count) simulator(s)")
    }
} 