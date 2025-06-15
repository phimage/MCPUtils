//
//  MCPServerConfig.swift
//  MCPUtils
//
//  Configuration and implementation for MCP servers
//

import Foundation
import MCP
import Logging

#if canImport(System)
    import System
#else
    @preconcurrency import SystemPackage
#endif

/// Configuration for an MCP server
public struct MCPServerConfig: Codable, Sendable {
    public let type: String?
    public let command: String
    public let args: [String]
    public let env: [String: String]?
    
    public init(type: String? = nil, command: String, args: [String], env: [String: String]? = nil) {
        self.type = type
        self.command = command
        self.args = args
        self.env = env
    }
    
    /// Creates tools from this MCP server configuration
    /// - Parameters:
    ///   - name: The name identifier for this server
    ///   - logger: Logger instance for debugging
    /// - Returns: Array of tools provided by the server
    public func createTools(named name: String, logger: Logger) async throws -> [MCP.Tool] {
        logger.debug("Starting MCP server: \(name)")
        
        let process = try createProcess()
        let transport = process.stdioTransport(logger: logger)
        
        try process.run()
        
        let client = Client(name: name, version: "1.0.0")
        try await client.connect(transport: transport)
        
        return try await loadToolsFromClient(client, logger: logger)
    }
    
    // MARK: - Private Methods
    
    private func createProcess() throws -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        
        // Construct arguments: command followed by its arguments
        var processArgs = [command]
        processArgs.append(contentsOf: args)
        process.arguments = processArgs
        
        // Set environment variables if specified
        if let serverEnv = env {
            var environment = ProcessInfo.processInfo.environment
            for (key, value) in serverEnv {
                environment[key] = value
            }
            process.environment = environment
        }
        
        return process
    }
    
    private func loadToolsFromClient(_ client: Client, logger: Logger) async throws -> [MCP.Tool] {
        var allTools: [MCP.Tool] = []
        var cursor: String? = nil
        
        repeat {
            let (listedTools, nextCursor) = try await client.listTools(cursor: cursor)
            allTools.append(contentsOf: listedTools)
            cursor = nextCursor
            
            if cursor != nil {
                logger.debug("Fetching next page of tools with cursor: \(cursor!)")
            }
        } while cursor != nil
        
        logger.debug("Loaded \(allTools.count) tools from MCP server")
        return allTools
    }
}
