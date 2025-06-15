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

#if canImport(Network)
    import Network
#endif

/// Configuration for an MCP server
public struct MCPServerConfig: Codable, Sendable {
    public let type: String?
    public let command: String?
    public let args: [String]?
    public let env: [String: String]?
    public let url: String?
    public let headers: [String: String]?
    
    public init(
        type: String? = nil, 
        command: String? = nil, 
        args: [String]? = [],
        env: [String: String]? = nil,
        url: String? = nil,
        headers: [String: String]? = nil
    ) {
        self.type = type
        self.command = command
        self.args = args
        self.env = env
        self.url = url
        self.headers = headers
    }
}

// MARK: - Configuration Errors
public enum MCPConfigurationError: LocalizedError {
    case invalidConfiguration(String)
    case missingRequiredField(String)
    case unsupportedTransportType(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidConfiguration(let message):
            return "Invalid configuration: \(message)"
        case .missingRequiredField(let field):
            return "Missing required field: \(field)"
        case .unsupportedTransportType(let type):
            return "Unsupported transport type: \(type)"
        }
    }
}

// MARK: - Transport Creation
extension MCPServerConfig {
    
    func createTransport(logger: Logger) throws -> MCP.Transport {
        let type = self.type ?? "stdio"
        switch type.lowercased() {
        case "stdio":
            let process = try createProcess()
            let transport = process.stdioTransport(logger: logger)
            try process.run()
            return transport
            
        case "sse", "http":
            guard let urlString = url, let endpoint = URL(string: urlString) else {
                throw MCPConfigurationError.missingRequiredField("url is required for \(type) transport")
            }
            
            #if canImport(Network)
            let configuration = URLSessionConfiguration.default.copy() as? URLSessionConfiguration ?? .default
            configuration.httpAdditionalHeaders = headers
            return MCP.HTTPClientTransport(
                endpoint: endpoint,
                configuration: configuration,
                streaming: type.lowercased() == "sse", // For SSE, we use HTTP transport with streaming enabled
                logger: logger
            )
            #else
            throw MCPConfigurationError.unsupportedTransportType("Network transports not available on this platform")
            #endif
            
        case "tcp", "websocket":
            guard let urlString = url, let endpoint = URL(string: urlString) else {
                throw MCPConfigurationError.missingRequiredField("url is required for \(type) transport")
            }
            
            #if canImport(Network)
            // Parse host and port from URL
            guard let host = endpoint.host else {
                throw MCPConfigurationError.invalidConfiguration("Invalid host in URL: \(urlString)")
            }
            
            let port = endpoint.port ?? (endpoint.scheme == "wss" || endpoint.scheme == "https" ? 443 : 80)
            
            let nwHost = NWEndpoint.Host(host)
            guard let nwPort = NWEndpoint.Port(rawValue: UInt16(port)) else {
                throw MCPConfigurationError.invalidConfiguration("Invalid port: \(port)")
            }
            
            let connection = NWConnection(
                host: nwHost,
                port: nwPort,
                using: type.lowercased() == "tcp" ? .tcp : .tcp // WebSocket would need additional setup
            )
            
            return MCP.NetworkTransport(connection: connection, logger: logger)
            #else
            throw MCPConfigurationError.unsupportedTransportType("Network transports not available on this platform")
            #endif
            
        default:
            throw MCPConfigurationError.unsupportedTransportType(type)
        }
    }
    
    /// Creates tools from this MCP server configuration
    /// - Parameters:
    ///   - name: The name identifier for this server
    ///   - logger: Logger instance for debugging
    /// - Returns: Array of tools provided by the server
    public func createTools(named name: String, logger: Logger) async throws -> (MCP.Client, [MCP.Tool]) {
        logger.debug("Starting MCP server: \(name)")
        let transport = try createTransport(logger: logger)
        let client = Client(name: name, version: "1.0.0")
        try await client.connect(transport: transport)
        
        return try await loadToolsFromClient(client, logger: logger)
    }
    
    // MARK: - Private Methods
    
    private func createProcess() throws -> Process {
        guard let command = command else {
            throw MCPConfigurationError.missingRequiredField("command is required for stdio transport")
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        
        // Construct arguments: command followed by its arguments
        var processArgs = [command]
        processArgs.append(contentsOf: args ?? [])
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
    
    private func loadToolsFromClient(_ client: Client, logger: Logger) async throws -> (MCP.Client, [MCP.Tool])  {
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
        return (client, allTools)
    }
}
