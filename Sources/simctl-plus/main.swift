// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import ArgumentParser

struct SimctlPlus: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "simctl-plus",
        abstract: "Enhanced simulator control tool with additional features",
        version: "1.0.0",
        subcommands: [
            ListCommand.self,
            BootCommand.self,
            ShutdownCommand.self,
            InstallCommand.self,
            UninstallCommand.self,
            ScreenshotCommand.self,
            RecordCommand.self,
            DiagnoseCommand.self,
            VMCommand.self
        ]
    )
}

SimctlPlus.main()
