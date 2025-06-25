//
//  CurrentAppConfig.swift
//  MCPUtils
//
//  Configuration management for current application MCP servers
//

import Foundation
import Logging

/// Configuration structure for current application MCP integration
public struct CurrentAppConfig: Codable, Sendable {
    public static let empty = CurrentAppConfig()
    public var servers: [String: MCPServerConfig] = [:]
    
    public init(servers: [String: MCPServerConfig] = [:]) {
        self.servers = servers
    }
}

/// Service for managing current application MCP configuration
public struct CurrentAppConfigService {
    
    // MARK: - Properties
    
    private static let appSupportURL: URL? = {
        guard let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        // Get current app name from Bundle
        let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "CurrentApp"
        let appFolder = appSupportDir.appendingPathComponent(appName, isDirectory: true)
        return appFolder.appendingPathComponent("mcp.json", isDirectory: false)
    }()
    
    // MARK: - Public Methods
    
    /// Loads the MCP configuration from the application support directory
    /// - Parameter logger: Logger instance for debugging
    /// - Returns: CurrentAppConfig instance, or empty config if file doesn't exist
    public static func loadConfig(logger: Logger) throws -> CurrentAppConfig {
        guard let configURL = appSupportURL else {
            logger.debug("App support directory not available")
            return .empty
        }
        
        guard FileManager.default.fileExists(atPath: configURL.path) else {
            logger.debug("MCP config file not found at: \(configURL.path)")
            return .empty
        }
        
        do {
            let data = try Data(contentsOf: configURL)
            let config = try JSONDecoder().decode(CurrentAppConfig.self, from: data)
            logger.debug("Loaded MCP config with \(config.servers.count) servers")
            return config
        } catch {
            logger.error("Failed to load MCP config: \(error.localizedDescription)")
            throw ConfigurationError.invalidConfigFile(error)
        }
    }
    
    /// Saves the MCP configuration to the application support directory
    /// - Parameters:
    ///   - config: Configuration to save
    ///   - logger: Logger instance for debugging
    public static func saveConfig(_ config: CurrentAppConfig, logger: Logger) throws {
        guard let configURL = appSupportURL else {
            throw ConfigurationError.configFileNotFound
        }
        
        // Create directory if it doesn't exist
        let directory = configURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(config)
            try data.write(to: configURL)
            logger.debug("Saved MCP config with \(config.servers.count) servers to: \(configURL.path)")
        } catch {
            logger.error("Failed to save MCP config: \(error.localizedDescription)")
            throw ConfigurationError.invalidConfigFile(error)
        }
    }
    
    /// Adds a new MCP server to the configuration
    /// - Parameters:
    ///   - serverName: Name of the server
    ///   - serverConfig: Configuration for the server
    ///   - logger: Logger instance for debugging
    public static func addServer(name serverName: String, config serverConfig: MCPServerConfig, logger: Logger) throws {
        var config = try loadConfig(logger: logger)
        config.servers[serverName] = serverConfig
        try saveConfig(config, logger: logger)
        logger.info("Added MCP server: \(serverName)")
    }
    
    /// Removes an MCP server from the configuration
    /// - Parameters:
    ///   - serverName: Name of the server to remove
    ///   - logger: Logger instance for debugging
    /// - Returns: True if server was removed, false if it didn't exist
    @discardableResult
    public static func removeServer(name serverName: String, logger: Logger) throws -> Bool {
        var config = try loadConfig(logger: logger)
        let wasRemoved = config.servers.removeValue(forKey: serverName) != nil
        
        if wasRemoved {
            try saveConfig(config, logger: logger)
            logger.info("Removed MCP server: \(serverName)")
        } else {
            logger.warning("Attempted to remove non-existent MCP server: \(serverName)")
        }
        
        return wasRemoved
    }
    
    /// Updates an existing MCP server configuration
    /// - Parameters:
    ///   - serverName: Name of the server to update
    ///   - serverConfig: New configuration for the server
    ///   - logger: Logger instance for debugging
    /// - Returns: True if server was updated, false if it didn't exist
    @discardableResult
    public static func updateServer(name serverName: String, config serverConfig: MCPServerConfig, logger: Logger) throws -> Bool {
        var config = try loadConfig(logger: logger)
        
        guard config.servers[serverName] != nil else {
            logger.warning("Attempted to update non-existent MCP server: \(serverName)")
            return false
        }
        
        config.servers[serverName] = serverConfig
        try saveConfig(config, logger: logger)
        logger.info("Updated MCP server: \(serverName)")
        return true
    }
    
    /// Lists all configured MCP servers
    /// - Parameter logger: Logger instance for debugging
    /// - Returns: Dictionary of server names and their configurations
    public static func listServers(logger: Logger) throws -> [String: MCPServerConfig] {
        let config = try loadConfig(logger: logger)
        logger.debug("Listed \(config.servers.count) MCP servers")
        return config.servers
    }
    
    /// Checks if a server with the given name exists
    /// - Parameters:
    ///   - serverName: Name of the server to check
    ///   - logger: Logger instance for debugging
    /// - Returns: True if server exists, false otherwise
    public static func serverExists(name serverName: String, logger: Logger) throws -> Bool {
        let config = try loadConfig(logger: logger)
        return config.servers[serverName] != nil
    }
    
    /// Gets configuration for a specific server
    /// - Parameters:
    ///   - serverName: Name of the server
    ///   - logger: Logger instance for debugging
    /// - Returns: Server configuration if it exists, nil otherwise
    public static func getServer(name serverName: String, logger: Logger) throws -> MCPServerConfig? {
        let config = try loadConfig(logger: logger)
        return config.servers[serverName]
    }
    
    /// Clears all MCP server configurations
    /// - Parameter logger: Logger instance for debugging
    public static func clearAllServers(logger: Logger) throws {
        let emptyConfig = CurrentAppConfig.empty
        try saveConfig(emptyConfig, logger: logger)
        logger.info("Cleared all MCP servers")
    }
    
    /// Gets the configuration file path for debugging purposes
    public static var configPath: String? {
        return appSupportURL?.path
    }
    
    /// Imports servers from another configuration
    /// - Parameters:
    ///   - servers: Dictionary of servers to import
    ///   - overwriteExisting: Whether to overwrite existing servers with same names
    ///   - logger: Logger instance for debugging
    /// - Returns: Number of servers imported
    @discardableResult
    public static func importServers(_ servers: [String: MCPServerConfig], overwriteExisting: Bool = false, logger: Logger) throws -> Int {
        var config = try loadConfig(logger: logger)
        var importedCount = 0
        
        for (serverName, serverConfig) in servers {
            let serverExists = config.servers[serverName] != nil
            
            if !serverExists || overwriteExisting {
                config.servers[serverName] = serverConfig
                importedCount += 1
                
                if serverExists {
                    logger.info("Overwritten existing MCP server: \(serverName)")
                } else {
                    logger.info("Imported new MCP server: \(serverName)")
                }
            } else {
                logger.warning("Skipped existing MCP server: \(serverName)")
            }
        }
        
        if importedCount > 0 {
            try saveConfig(config, logger: logger)
            logger.info("Imported \(importedCount) MCP servers")
        }
        
        return importedCount
    }
}
