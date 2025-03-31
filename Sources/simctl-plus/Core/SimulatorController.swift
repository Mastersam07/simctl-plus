import Foundation

enum SimulatorError: Error {
    case commandFailed(String)
    case invalidDeviceId(String)
    case invalidAppPath(String)
    case simulatorNotFound(String)
    case jsonParsingError(String)
}

class SimulatorController {
    private let simctlPath = "/usr/bin/xcrun"
    
    func listSimulators() throws -> [SimulatorDevice] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: simctlPath)
        process.arguments = ["simctl", "list", "devices", "--json"]
        
        let output = try runProcess(process)
        guard let data = output.data(using: .utf8) else {
            throw SimulatorError.jsonParsingError("Failed to convert output to data")
        }
        
        let decoder = JSONDecoder()
        let response = try decoder.decode(SimulatorListResponse.self, from: data)
        
        return response.devices.values.flatMap { $0 }
    }
    
    func bootSimulator(deviceId: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: simctlPath)
        process.arguments = ["simctl", "boot", deviceId]
        
        _ = try runProcess(process)
    }
    
    func shutdownSimulator(deviceId: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: simctlPath)
        process.arguments = ["simctl", "shutdown", deviceId]
        
        _ = try runProcess(process)
    }
    
    func installApp(appPath: String, deviceId: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: simctlPath)
        process.arguments = ["simctl", "install", deviceId, appPath]
        
        _ = try runProcess(process)
    }
    
    func uninstallApp(bundleId: String, deviceId: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: simctlPath)
        process.arguments = ["simctl", "uninstall", deviceId, bundleId]
        
        _ = try runProcess(process)
    }
    
    func takeScreenshot(deviceId: String, outputPath: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: simctlPath)
        process.arguments = ["simctl", "io", deviceId, "screenshot", outputPath]
        
        _ = try runProcess(process)
    }
    
    func startRecording(deviceId: String, outputPath: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: simctlPath)
        process.arguments = ["simctl", "io", deviceId, "record", outputPath]
        
        _ = try runProcess(process)
    }
    
    func getDiagnostics(deviceId: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: simctlPath)
        process.arguments = ["simctl", "diagnose", deviceId]
        
        return try runProcess(process)
    }
    
    private func runProcess(_ process: Process) throws -> String {
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            let errorData = try errorPipe.fileHandleForReading.readToEnd() ?? Data()
            let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw SimulatorError.commandFailed(errorString)
        }
        
        let outputData = try outputPipe.fileHandleForReading.readToEnd() ?? Data()
        return String(data: outputData, encoding: .utf8) ?? ""
    }
} 