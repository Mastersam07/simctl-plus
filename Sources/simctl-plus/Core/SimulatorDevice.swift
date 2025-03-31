import Foundation

struct SimulatorDevice: Codable {
    let udid: String
    let name: String
    let state: DeviceState
    let isAvailable: Bool
    let deviceTypeIdentifier: String
    let dataPath: String
    let dataPathSize: Int64
    let logPath: String
    let logPathSize: Int64?
    let lastBootedAt: String?
    let availabilityError: String?
    
    enum DeviceState: String, Codable {
        case booted = "Booted"
        case shutdown = "Shutdown"
        case unknown = "Unknown"
    }
}

struct SimulatorRuntime: Codable {
    let name: String
    let identifier: String
    let version: String
    let buildversion: String
    let isAvailable: Bool
    
    enum CodingKeys: String, CodingKey {
        case name
        case identifier
        case version
        case buildversion
        case isAvailable = "isAvailable"
    }
}

struct SimulatorListResponse: Codable {
    let devices: [String: [SimulatorDevice]]
} 