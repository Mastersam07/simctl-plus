import ArgumentParser

struct SimulatorCommand: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "simulator",
        abstract: "Control and manage simulators",
        subcommands: [
            ListCommand.self,
            BootCommand.self,
            ShutdownCommand.self,
            InstallCommand.self,
            UninstallCommand.self,
            ScreenshotCommand.self,
            RecordCommand.self,
            DiagnoseCommand.self,
            SimulatorDiagnosticsCommand.self,
        ]
    )
}
