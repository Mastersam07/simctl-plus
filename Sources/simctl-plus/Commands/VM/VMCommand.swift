import ArgumentParser

struct VMCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "vm",
        abstract: "Create and manage custom macOS VMs using Virtualization.framework",
        subcommands: [
            CreateCommand.self,
            VMListCommand.self,
            StartCommand.self,
            StopCommand.self,
        ]
    )
}