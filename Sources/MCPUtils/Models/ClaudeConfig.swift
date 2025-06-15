//
//  ClaudeConfig.swift
//  MCPUtils
//
//  Configuration management for Claude Desktop integration
//

import Foundation
import Logging

/// Configuration structure for Claude Desktop integration
public struct ClaudeConfig: Codable, Sendable {
    public static let empty = ClaudeConfig()
    public var mcpServers: [String: MCPServerConfig] = [:]
    
    public init(mcpServers: [String: MCPServerConfig] = [:]) {
        self.mcpServers = mcpServers
    }
}

/// Service for managing Claude configuration
public struct ClaudeConfigService {
    
    // MARK: - Properties
    
    private static let claudeFolderURL = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)
        .first?
        .appendingPathComponent("Claude", isDirectory: true)
    
    private static let claudeConfigFileURL = claudeFolderURL?
        .appendingPathComponent("claude_desktop_config.json", isDirectory: false)
    
    // MARK: - Public Methods
    
    /// Loads the Claude configuration from the standard location
    /// - Parameter logger: Logger instance for debugging
    /// - Returns: ClaudeConfig instance, or empty config if file doesn't exist
    public static func loadConfig(logger: Logger) throws -> ClaudeConfig {
        guard let configURL = claudeConfigFileURL else {
            logger.debug("Claude config file URL not available")
            return .empty
        }
        
        guard FileManager.default.fileExists(atPath: configURL.path) else {
            logger.debug("Claude config file not found at: \(configURL.path)")
            return .empty
        }
        
        do {
            let data = try Data(contentsOf: configURL)
            let config = try JSONDecoder().decode(ClaudeConfig.self, from: data)
            logger.debug("Loaded Claude config with \(config.mcpServers.count) MCP servers")
            return config
        } catch {
            logger.error("Failed to load Claude config: \(error.localizedDescription)")
            throw ConfigurationError.invalidConfigFile(error)
        }
    }
    
    /// Gets the configuration file path for debugging purposes
    public static var configPath: String? {
        return claudeConfigFileURL?.path
    }
}

// MARK: - Error Types

/// Configuration-related errors that can occur when loading config files
public enum ConfigurationError: LocalizedError {
    case invalidConfigFile(Swift.Error)
    case configFileNotFound
    
    public var errorDescription: String? {
        switch self {
        case .invalidConfigFile(let error):
            return "Invalid configuration file: \(error.localizedDescription)"
        case .configFileNotFound:
            return "Configuration file not found"
        }
    }
}
