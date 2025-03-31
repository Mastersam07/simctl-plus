// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import ArgumentParser

public struct SimctlPlus: ParsableCommand {
    public static var configuration = CommandConfiguration(
        commandName: "simctl-plus",
        abstract: "Enhanced simulator control tool",
        subcommands: [
            ListCommand.self,
            BootCommand.self,
            ShutdownCommand.self,
            InstallCommand.self,
            UninstallCommand.self,
            ScreenshotCommand.self,
            RecordCommand.self,
            DiagnoseCommand.self
        ]
    )
    
    public init() {}
}

SimctlPlus.main()
