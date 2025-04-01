import Foundation
import ArgumentParser
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
            print("- \(vm.name) (\(vm.state))")
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

class VMManager {
    private let fileManager = FileManager.default
    private let defaultVMPath: URL
    
    init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        defaultVMPath = appSupport.appendingPathComponent("simctl-plus/vms")
        try? fileManager.createDirectory(at: defaultVMPath, withIntermediateDirectories: true)
    }
    
    func createVM(config: VMConfiguration, path: String?) async throws {
        let vmPath = path.map { URL(fileURLWithPath: $0) } ?? defaultVMPath.appendingPathComponent(config.name)
        print("Creating VM at path: \(vmPath.path)")
        
        // Clean up existing VM files if they exist
        if fileManager.fileExists(atPath: vmPath.path) {
            print("Removing existing VM files...")
            try fileManager.removeItem(at: vmPath)
        }
        
        // Create VM directory
        print("Creating VM directory...")
        try fileManager.createDirectory(at: vmPath, withIntermediateDirectories: true)
        
        // Create VM configuration
        print("Creating VM configuration...")
        let vmConfig = VZVirtualMachineConfiguration()
        
        // Configure platform
        let platform = VZMacPlatformConfiguration()
        platform.machineIdentifier = VZMacMachineIdentifier()
        vmConfig.platform = platform
        
        // Configure boot loader
        print("Configuring boot loader...")
        let bootLoader = VZMacOSBootLoader()
        vmConfig.bootLoader = bootLoader
        
        // Configure CPU and memory
        vmConfig.cpuCount = Int(config.cpuCount)
        vmConfig.memorySize = config.memorySize
        
        // Configure storage
        print("Creating disk image...")
        let diskImageURL = vmPath.appendingPathComponent("disk.img")
        let sparseImageURL = try createDiskImage(at: diskImageURL, size: config.diskSize)
        
        print("Configuring storage...")
        let attachment = try VZDiskImageStorageDeviceAttachment(url: sparseImageURL, readOnly: false)
        let storage = VZVirtioBlockDeviceConfiguration(attachment: attachment)
        vmConfig.storageDevices = [storage]
        
        // Configure graphics
        print("Configuring graphics...")
        let graphics = VZMacGraphicsDeviceConfiguration()
        graphics.displays = [
            VZMacGraphicsDisplayConfiguration(
                widthInPixels: 1920,
                heightInPixels: 1080,
                pixelsPerInch: 80
            )
        ]
        vmConfig.graphicsDevices = [graphics]
        
        // Configure network
        print("Configuring network...")
        let network = VZVirtioNetworkDeviceConfiguration()
        network.attachment = VZNATNetworkDeviceAttachment()
        vmConfig.networkDevices = [network]
        
        // Create and configure auxiliary storage
        print("Creating auxiliary storage...")
        let auxiliaryStorageURL = vmPath.appendingPathComponent("auxiliary.storage")
        try fileManager.createDirectory(at: auxiliaryStorageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        
        // Get the hardware model from the restore image
        print("Getting hardware model from restore image...")
        let restoreImage = try await VZMacOSRestoreImage.latestSupported
        guard let configuration = restoreImage.mostFeaturefulSupportedConfiguration else {
            throw SimulatorError.vmCreationFailed("No supported configuration found")
        }
        
        let hardwareModel = configuration.hardwareModel
        guard hardwareModel.isSupported else {
            throw SimulatorError.vmCreationFailed("Hardware model not supported on this host")
        }
        
        let auxiliaryStorage = try VZMacAuxiliaryStorage(creatingStorageAt: auxiliaryStorageURL, hardwareModel: hardwareModel)
        
        if let macPlatform = vmConfig.platform as? VZMacPlatformConfiguration {
            macPlatform.auxiliaryStorage = auxiliaryStorage
            macPlatform.hardwareModel = hardwareModel
        }
        
        // Validate configuration
        print("Validating configuration...")
        try vmConfig.validate()
        
        // Save VM configuration
        print("Saving VM configuration...")
        let vmURL = vmPath.appendingPathComponent("vm.json")
        try saveVMConfiguration(vmConfig, to: vmURL)
        
        print("VM configuration saved to: \(vmPath.path)")
    }
    
    private func createDiskImage(at url: URL, size: UInt64) throws -> URL {
        print("Creating disk image at: \(url.path)")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = [
            "create",
            "-size", "\(size)b",
            "-fs", "APFS",
            "-volname", "VM Disk",
            "-type", "SPARSE",
            url.path
        ]
        
        print("Running hdiutil with arguments: \(process.arguments?.joined(separator: " ") ?? "")")
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let outputData = try outputPipe.fileHandleForReading.readToEnd() ?? Data()
            let outputString = String(data: outputData, encoding: .utf8) ?? ""
            print("hdiutil output: \(outputString)")
            
            if process.terminationStatus != 0 {
                let errorData = try errorPipe.fileHandleForReading.readToEnd() ?? Data()
                let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                print("hdiutil error: \(errorString)")
                throw SimulatorError.vmCreationFailed("Failed to create disk image: \(errorString)")
            }
            
            // Return the .sparseimage file URL
            return url.appendingPathExtension("sparseimage")
        } catch {
            print("Error running hdiutil: \(error)")
            throw error
        }
    }
    
    private func saveVMConfiguration(_ config: VZVirtualMachineConfiguration, to url: URL) throws {
        // Since VZVirtualMachineConfiguration doesn't conform to Codable,
        // we'll save the essential configuration parameters as JSON
        let configDict: [String: Any] = [
            "cpuCount": config.cpuCount,
            "memorySize": config.memorySize,
            "platform": "macOS"
        ]
        
        let data = try JSONSerialization.data(withJSONObject: configDict, options: .prettyPrinted)
        try data.write(to: url)
    }
    
    func listVMs() throws -> [(name: String, state: String)] {
        let vms = try fileManager.contentsOfDirectory(at: defaultVMPath, includingPropertiesForKeys: nil)
        return vms.map { url in
            let name = url.lastPathComponent
            let state = isVMRunning(name: name) ? "Running" : "Stopped"
            return (name: name, state: state)
        }
    }
    
    func startVM(name: String) async throws {
        let vmPath = defaultVMPath.appendingPathComponent(name)
        let vmConfigURL = vmPath.appendingPathComponent("vm.json")
        
        guard fileManager.fileExists(atPath: vmConfigURL.path) else {
            throw SimulatorError.vmNotFound(name)
        }
        
        // Create a new VM configuration
        let vmConfig = VZVirtualMachineConfiguration()
        let platform = VZMacPlatformConfiguration()
        platform.machineIdentifier = VZMacMachineIdentifier()
        vmConfig.platform = platform
        
        // Load saved configuration
        let configData = try Data(contentsOf: vmConfigURL)
        let configDict = try JSONSerialization.jsonObject(with: configData) as? [String: Any]
        
        guard let configDict = configDict,
              let cpuCount = configDict["cpuCount"] as? Int,
              let memorySize = configDict["memorySize"] as? UInt64 else {
            throw SimulatorError.vmStartFailed("Invalid VM configuration")
        }
        
        vmConfig.cpuCount = cpuCount
        vmConfig.memorySize = memorySize
        
        // Configure storage
        let diskImageURL = vmPath.appendingPathComponent("disk.img")
        let attachment = try VZDiskImageStorageDeviceAttachment(url: diskImageURL, readOnly: false)
        let storage = VZVirtioBlockDeviceConfiguration(attachment: attachment)
        vmConfig.storageDevices = [storage]
        
        // Configure graphics
        let graphics = VZMacGraphicsDeviceConfiguration()
        graphics.displays = [
            VZMacGraphicsDisplayConfiguration(
                widthInPixels: 1920,
                heightInPixels: 1080,
                pixelsPerInch: 80
            )
        ]
        vmConfig.graphicsDevices = [graphics]
        
        // Configure network
        let network = VZVirtioNetworkDeviceConfiguration()
        network.attachment = VZNATNetworkDeviceAttachment()
        vmConfig.networkDevices = [network]
        
        try vmConfig.validate()
        let vm = VZVirtualMachine(configuration: vmConfig)
        try await vm.start()
    }
    
    func stopVM(name: String) async throws {
        let vmPath = defaultVMPath.appendingPathComponent(name)
        let vmConfigURL = vmPath.appendingPathComponent("vm.json")
        
        guard fileManager.fileExists(atPath: vmConfigURL.path) else {
            throw SimulatorError.vmNotFound(name)
        }
        
        // Create a new VM configuration (similar to startVM)
        let vmConfig = VZVirtualMachineConfiguration()
        let platform = VZMacPlatformConfiguration()
        platform.machineIdentifier = VZMacMachineIdentifier()
        vmConfig.platform = platform
        
        // Load saved configuration
        let configData = try Data(contentsOf: vmConfigURL)
        let configDict = try JSONSerialization.jsonObject(with: configData) as? [String: Any]
        
        guard let configDict = configDict,
              let cpuCount = configDict["cpuCount"] as? Int,
              let memorySize = configDict["memorySize"] as? UInt64 else {
            throw SimulatorError.vmStopFailed("Invalid VM configuration")
        }
        
        vmConfig.cpuCount = cpuCount
        vmConfig.memorySize = memorySize
        
        // Configure storage
        let diskImageURL = vmPath.appendingPathComponent("disk.img")
        let attachment = try VZDiskImageStorageDeviceAttachment(url: diskImageURL, readOnly: false)
        let storage = VZVirtioBlockDeviceConfiguration(attachment: attachment)
        vmConfig.storageDevices = [storage]
        
        // Configure graphics
        let graphics = VZMacGraphicsDeviceConfiguration()
        graphics.displays = [
            VZMacGraphicsDisplayConfiguration(
                widthInPixels: 1920,
                heightInPixels: 1080,
                pixelsPerInch: 80
            )
        ]
        vmConfig.graphicsDevices = [graphics]
        
        // Configure network
        let network = VZVirtioNetworkDeviceConfiguration()
        network.attachment = VZNATNetworkDeviceAttachment()
        vmConfig.networkDevices = [network]
        
        try vmConfig.validate()
        let vm = VZVirtualMachine(configuration: vmConfig)
        try await vm.stop()
    }
    
    private func isVMRunning(name: String) -> Bool {
        // TODO: Implement VM state checking
        return false
    }
} 