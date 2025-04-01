import Virtualization

enum VMState {
    case running
    case stopped

    var description: String {
        switch self {
        case .running:
            return "Running"
        case .stopped:
            return "Stopped"
        }
    }
}

struct VMInfo {
    let name: String
    let state: VMState
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
    private var runningVMs: [String: VZVirtualMachine] = [:]

    init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
        defaultVMPath = appSupport.appendingPathComponent("simctl-plus/vms")
        try? fileManager.createDirectory(at: defaultVMPath, withIntermediateDirectories: true)
    }

    func createVM(config: VMConfiguration, path: String?) async throws {
        let vmPath =
            path.map { URL(fileURLWithPath: $0) }
            ?? defaultVMPath.appendingPathComponent(config.name)
        print("Creating VM at path: \(vmPath.path)")

        if fileManager.fileExists(atPath: vmPath.path) {
            print("Removing existing VM files...")
            try fileManager.removeItem(at: vmPath)
        }

        print("Creating VM directory...")
        try fileManager.createDirectory(at: vmPath, withIntermediateDirectories: true)

        print("Creating VM configuration...")
        let vmConfig = VZVirtualMachineConfiguration()

        let platform = VZMacPlatformConfiguration()
        platform.machineIdentifier = VZMacMachineIdentifier()
        vmConfig.platform = platform

        print("Configuring boot loader...")
        let bootLoader = VZMacOSBootLoader()
        vmConfig.bootLoader = bootLoader

        vmConfig.cpuCount = Int(config.cpuCount)
        vmConfig.memorySize = config.memorySize

        print("Creating disk image...")
        let diskImageURL = vmPath.appendingPathComponent("disk.img")
        let sparseImageURL = try createDiskImage(at: diskImageURL, size: config.diskSize)

        print("Configuring storage...")
        let attachment = try VZDiskImageStorageDeviceAttachment(
            url: sparseImageURL, readOnly: false)
        let storage = VZVirtioBlockDeviceConfiguration(attachment: attachment)
        vmConfig.storageDevices = [storage]

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

        print("Configuring network...")
        let network = VZVirtioNetworkDeviceConfiguration()
        network.attachment = VZNATNetworkDeviceAttachment()
        vmConfig.networkDevices = [network]

        print("Creating auxiliary storage...")
        let auxiliaryStorageURL = vmPath.appendingPathComponent("auxiliary.storage")
        try fileManager.createDirectory(
            at: auxiliaryStorageURL.deletingLastPathComponent(), withIntermediateDirectories: true)

        print("Getting hardware model from restore image...")
        let restoreImage = try await VZMacOSRestoreImage.latestSupported
        guard let configuration = restoreImage.mostFeaturefulSupportedConfiguration else {
            throw SimulatorError.vmCreationFailed("No supported configuration found")
        }

        let hardwareModel = configuration.hardwareModel
        guard hardwareModel.isSupported else {
            throw SimulatorError.vmCreationFailed("Hardware model not supported on this host")
        }

        let auxiliaryStorage = VZMacAuxiliaryStorage(url: auxiliaryStorageURL)
        platform.auxiliaryStorage = auxiliaryStorage
        platform.hardwareModel = hardwareModel

        if let macPlatform = vmConfig.platform as? VZMacPlatformConfiguration {
            macPlatform.auxiliaryStorage = auxiliaryStorage
            macPlatform.hardwareModel = hardwareModel
        }

        print("Validating configuration...")
        try vmConfig.validate()

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
            url.path,
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

            return url.appendingPathExtension("sparseimage")
        } catch {
            print("Error running hdiutil: \(error)")
            throw error
        }
    }

    private func saveVMConfiguration(_ config: VZVirtualMachineConfiguration, to url: URL) throws {

        let configDict: [String: Any] = [
            "cpuCount": config.cpuCount,
            "memorySize": config.memorySize,
            "platform": "macOS",
        ]

        let data = try JSONSerialization.data(withJSONObject: configDict, options: .prettyPrinted)
        try data.write(to: url)
    }

    func listVMs() throws -> [VMInfo] {
        let vmPath = defaultVMPath
        guard fileManager.fileExists(atPath: vmPath.path) else {
            return []
        }

        let contents = try fileManager.contentsOfDirectory(
            at: vmPath, includingPropertiesForKeys: nil)
        return contents.compactMap { url in

            let filename = url.lastPathComponent
            if filename.hasPrefix(".") || !url.hasDirectoryPath {
                return nil
            }

            let configURL = url.appendingPathComponent("vm.json")
            guard fileManager.fileExists(atPath: configURL.path) else {
                return nil
            }

            let state: VMState = isVMRunning(name: filename) ? .running : .stopped
            return VMInfo(name: filename, state: state)
        }
    }

    private func isVMRunning(name: String) -> Bool {
        return runningVMs[name] != nil
    }

    func startVM(name: String) async throws {
        do {

            if isVMRunning(name: name) {
                print("VM '\(name)' is already running")
                return
            }

            let vmPath = defaultVMPath.appendingPathComponent(name)
            let vmConfigURL = vmPath.appendingPathComponent("vm.json")

            guard fileManager.fileExists(atPath: vmConfigURL.path) else {
                throw SimulatorError.vmNotFound(name)
            }

            print("Loading VM configuration from \(vmConfigURL.path)...")
            let configData = try Data(contentsOf: vmConfigURL)
            let configDict = try JSONSerialization.jsonObject(with: configData) as? [String: Any]

            guard let configDict = configDict,
                let cpuCount = configDict["cpuCount"] as? Int,
                let memorySize = configDict["memorySize"] as? UInt64
            else {
                throw SimulatorError.vmStartFailed("Invalid VM configuration")
            }

            print(
                "Creating VM configuration with \(cpuCount) CPUs and \(memorySize) bytes of memory..."
            )
            let vmConfig = VZVirtualMachineConfiguration()
            vmConfig.cpuCount = cpuCount
            vmConfig.memorySize = memorySize

            print("Configuring platform...")
            let platform = VZMacPlatformConfiguration()
            platform.machineIdentifier = VZMacMachineIdentifier()

            print("Getting hardware model...")
            let restoreImage = try await VZMacOSRestoreImage.latestSupported
            guard let configuration = restoreImage.mostFeaturefulSupportedConfiguration else {
                throw SimulatorError.vmStartFailed("No supported configuration found")
            }

            let hardwareModel = configuration.hardwareModel
            guard hardwareModel.isSupported else {
                throw SimulatorError.vmStartFailed("Hardware model not supported on this host")
            }
            print("Using hardware model: \(hardwareModel)")

            print("Loading auxiliary storage...")
            let auxiliaryStorageURL = vmPath.appendingPathComponent("auxiliary.storage")
            guard fileManager.fileExists(atPath: auxiliaryStorageURL.path) else {
                throw SimulatorError.vmStartFailed(
                    "Auxiliary storage not found at \(auxiliaryStorageURL.path)")
            }

            let auxiliaryStorage = VZMacAuxiliaryStorage(url: auxiliaryStorageURL)
            platform.auxiliaryStorage = auxiliaryStorage
            platform.hardwareModel = hardwareModel
            vmConfig.platform = platform
            print("Auxiliary storage loaded successfully")

            print("Configuring boot loader...")
            let bootLoader = VZMacOSBootLoader()
            vmConfig.bootLoader = bootLoader

            print("Configuring storage...")
            let diskImageURL = vmPath.appendingPathComponent("disk.img.sparseimage")
            guard fileManager.fileExists(atPath: diskImageURL.path) else {
                throw SimulatorError.vmStartFailed("Disk image not found at \(diskImageURL.path)")
            }

            do {
                let attachment = try VZDiskImageStorageDeviceAttachment(
                    url: diskImageURL, readOnly: false)
                let storage = VZVirtioBlockDeviceConfiguration(attachment: attachment)
                vmConfig.storageDevices = [storage]
                print("Storage configured successfully")
            } catch {
                throw SimulatorError.vmStartFailed(
                    "Failed to configure storage: \(error.localizedDescription)")
            }

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

            print("Configuring network...")
            let network = VZVirtioNetworkDeviceConfiguration()
            network.attachment = VZNATNetworkDeviceAttachment()
            vmConfig.networkDevices = [network]

            print("Validating configuration...")
            do {
                try vmConfig.validate()
                print("Configuration validated successfully")
            } catch {
                throw SimulatorError.vmStartFailed(
                    "Configuration validation failed: \(error.localizedDescription)")
            }

            print("Creating virtual machine...")
            let vm = VZVirtualMachine(configuration: vmConfig)

            print("Starting VM...")
            do {
                try await vm.start()
                runningVMs[name] = vm
                print("VM started successfully")
            } catch {
                throw SimulatorError.vmStartFailed(
                    "Failed to start VM: \(error.localizedDescription)")
            }
        } catch {
            print("Error starting VM: \(error.localizedDescription)")
            throw error
        }
    }

    func stopVM(name: String) async throws {
        guard let vm = runningVMs[name] else {
            print("VM '\(name)' is not running")
            return
        }

        print("Stopping VM...")
        try await vm.stop()
        runningVMs.removeValue(forKey: name)
        print("VM stopped successfully")
    }
}
