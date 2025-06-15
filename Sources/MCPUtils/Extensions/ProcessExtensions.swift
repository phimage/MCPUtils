//
//  ProcessExtensions.swift
//  MCPUtils
//
//  Extensions for Process to support MCP transport
//

import Foundation
import MCP
import Logging

#if canImport(System)
    import System
#else
    @preconcurrency import SystemPackage
#endif

extension Process {
    /// Creates a stdio transport for MCP communication
    /// - Parameter logger: Optional logger for debugging transport issues
    /// - Returns: Configured StdioTransport for MCP client communication
    public func stdioTransport(logger: Logger? = nil) -> StdioTransport {
        let input = Pipe()
        let output = Pipe()
        
        self.standardInput = input
        self.standardOutput = output
        // Note: stderr is not redirected - MCP servers may log there
        
        return StdioTransport(
            input: FileDescriptor(rawValue: output.fileHandleForReading.fileDescriptor),
            output: FileDescriptor(rawValue: input.fileHandleForWriting.fileDescriptor)
        )
    }
}
