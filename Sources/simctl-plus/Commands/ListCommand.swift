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
    
    func run() throws {
        let controller = SimulatorController()
        let simulators = try controller.listSimulators()
        
        // Filter simulators based on flags
        let filteredSimulators = simulators.filter { simulator in
            if bootedOnly && simulator.state != .booted { return false }
            if shutdownOnly && simulator.state != .shutdown { return false }
            return true
        }
        
        // Print simulators in a formatted table
        print("\nAvailable Simulators:")
        print("-------------------")
        print("UDID\t\tName\t\tState\t\tRuntime")
        print("----------------------------------------")
        
        for simulator in filteredSimulators {
            print("\(simulator.udid)\t\(simulator.name)\t\(simulator.state.rawValue)\t\(simulator.runtime)")
        }
        
        print("\nTotal: \(filteredSimulators.count) simulator(s)")
    }
} 