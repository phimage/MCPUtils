//
//  VSCodeConfig.swift
//  MCPUtils
//
//  Configuration management for VS Code MCP servers integration
//

import Foundation
import Logging

/// Configuration structure for VS Code MCP servers
public struct VSCodeConfig: Codable, Sendable {
    public static let empty = VSCodeConfig()
    public var mcp: VSCodeMCPConfig?
    
    public init(mcp: VSCodeMCPConfig? = nil) {
        self.mcp = mcp
    }
    
    public struct VSCodeMCPConfig: Codable, Sendable {
        public var servers: [String: MCPServerConfig] = [:]
        
        public init(servers: [String: MCPServerConfig] = [:]) {
            self.servers = servers
        }
    }
}

/// Service for managing VS Code configuration
public struct VSCodeConfigService {
    
    // MARK: - Properties
    
    private static let vscodeConfigPaths: [String] = [
        // User settings
        "~/Library/Application Support/Code/User/settings.json",
        // Workspace settings (current directory)
        ".vscode/settings.json"
    ]
    
    // MARK: - Public Methods
    
    /// Loads VS Code configuration from standard locations
    /// - Parameter logger: Logger instance for debugging
    /// - Returns: VSCodeConfig instance, or empty config if no files exist
    public static func loadConfig(logger: Logger) throws -> VSCodeConfig {
        var combinedConfig = VSCodeConfig.empty
        
        for configPath in vscodeConfigPaths {
            do {
                let expandedPath = NSString(string: configPath).expandingTildeInPath
                let configURL = URL(fileURLWithPath: expandedPath)
                
                guard FileManager.default.fileExists(atPath: configURL.path) else {
                    logger.debug("VS Code config file not found at: \(configURL.path)")
                    continue
                }
                
                let config = try loadConfigFromFile(at: configURL, logger: logger)
                combinedConfig = merge(config: combinedConfig, with: config)
                logger.debug("Loaded VS Code config from: \(configURL.path)")
                
            } catch {
                logger.warning("Failed to load VS Code config from \(configPath): \(error.localizedDescription)")
            }
        }
        
        let serverCount = combinedConfig.mcp?.servers.count ?? 0
        if serverCount > 0 {
            logger.debug("Loaded VS Code config with \(serverCount) MCP servers")
        }
        
        return combinedConfig
    }
    
    /// Gets all available configuration file paths for debugging
    public static var configPaths: [String] {
        return vscodeConfigPaths.map { NSString(string: $0).expandingTildeInPath }
    }
    
    // MARK: - Private Methods
    
    private static func loadConfigFromFile(at url: URL, logger: Logger) throws -> VSCodeConfig {
        let data = try Data(contentsOf: url)
        
        // VS Code settings.json may contain comments (JSONC format)
        // We'll need to strip comments before parsing
        let cleanedData = try stripJSONComments(from: data)
        
        do {
            return try JSONDecoder().decode(VSCodeConfig.self, from: cleanedData)
        } catch {
            // If full decode fails, try to extract just the MCP section
            return try extractMCPConfig(from: cleanedData, logger: logger)
        }
    }
    
    private static func stripJSONComments(from data: Data) throws -> Data {
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw ConfigurationError.invalidConfigFile(NSError(domain: "JSONParsing", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to convert data to string"]))
        }
        
        // Simple comment stripping - remove lines starting with //
        let lines = jsonString.components(separatedBy: .newlines)
        let cleanedLines = lines.compactMap { line -> String? in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("//") {
                return nil
            }
            return line
        }
        
        let cleanedString = cleanedLines.joined(separator: "\n")
        guard let cleanedData = cleanedString.data(using: .utf8) else {
            throw ConfigurationError.invalidConfigFile(NSError(domain: "JSONParsing", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to convert cleaned string to data"]))
        }
        
        return cleanedData
    }
    
    private static func extractMCPConfig(from data: Data, logger: Logger) throws -> VSCodeConfig {
        // Try to extract just the MCP configuration from the JSON
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let mcpSection = json["mcp"] as? [String: Any],
              let servers = mcpSection["servers"] as? [String: Any] else {
            return VSCodeConfig.empty
        }
        
        var mcpServers: [String: MCPServerConfig] = [:]
        
        for (serverName, serverData) in servers {
            guard let serverDict = serverData as? [String: Any] else { continue }
            
            do {
                let serverConfigData = try JSONSerialization.data(withJSONObject: serverDict)
                let serverConfig = try JSONDecoder().decode(MCPServerConfig.self, from: serverConfigData)
                mcpServers[serverName] = serverConfig
            } catch {
                logger.warning("Failed to parse MCP server config for '\(serverName)': \(error.localizedDescription)")
            }
        }
        
        let mcpConfig = VSCodeConfig.VSCodeMCPConfig(servers: mcpServers)
        return VSCodeConfig(mcp: mcpConfig)
    }
    
    private static func merge(config: VSCodeConfig, with newConfig: VSCodeConfig) -> VSCodeConfig {
        var merged = config
        
        if let newMCP = newConfig.mcp {
            if merged.mcp == nil {
                merged.mcp = VSCodeConfig.VSCodeMCPConfig()
            }
            
            // Merge servers (newer configs override older ones)
            for (serverName, serverConfig) in newMCP.servers {
                merged.mcp?.servers[serverName] = serverConfig
            }
        }
        
        return merged
    }
}
