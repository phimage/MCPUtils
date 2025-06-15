//
//  ToolService.swift
//  MCPUtils
//
//  Service for loading and managing tools from various sources
//

import Foundation
import Logging
import MCP

/// Service responsible for loading tools from various sources
public struct ToolService {
    
    public init() {}
    
    /// Loads all available tools from configured sources
    /// - Parameter logger: Logger instance for debugging
    /// - Returns: Array of ttools
    public func loadTools(logger: Logger) async -> [MCP.Tool] {
        var tools: [MCP.Tool] = []
        
        // Load tools from Claude MCP servers
        tools.append(contentsOf: await loadClaudeMCPTools(logger: logger))
        
        // Load tools from VS Code MCP servers
        tools.append(contentsOf: await loadVSCodeMCPTools(logger: logger))
        
        // TODO: Add other tool sources here (local tools, APIs, etc.)
        
        logger.debug("Loaded \(tools.count) tools total")
        return tools
    }
                                                                                 
    // MARK: - Internal Methods (for testing and diagnostics)
    
    public func loadClaudeMCPTools(logger: Logger) async -> [MCP.Tool] {
        var tools: [MCP.Tool] = []
        
        do {
            let claudeConfig = try ClaudeConfigService.loadConfig(logger: logger)
            
            for (serverName, serverConfig) in claudeConfig.mcpServers {
                do {
                    let serverTools = try await serverConfig.createTools(named: serverName, logger: logger)
                    tools.append(contentsOf: serverTools)
                    logger.debug("Loaded \(serverTools.count) tools from Claude MCP server: \(serverName)")
                } catch {
                    logger.error("Failed to load tools from Claude MCP server '\(serverName)': \(error.localizedDescription)")
                }
            }
            
            if !claudeConfig.mcpServers.isEmpty {
                logger.debug("Loaded \(tools.count) Claude MCP tools from \(claudeConfig.mcpServers.count) servers")
            }
            
        } catch {
            logger.error("Error loading Claude configuration: \(error.localizedDescription)")
        }
        
        return tools
    }
    
    public func loadVSCodeMCPTools(logger: Logger) async -> [MCP.Tool] {
        var tools: [MCP.Tool] = []
        
        do {
            let vsCodeConfig = try VSCodeConfigService.loadConfig(logger: logger)
            
            guard let mcpServers = vsCodeConfig.mcp?.servers else {
                logger.debug("No MCP servers found in VS Code configuration")
                return tools
            }
            
            for (serverName, serverConfig) in mcpServers {
                do {
                    let serverTools = try await serverConfig.createTools(named: serverName, logger: logger)
                    tools.append(contentsOf: serverTools)
                    logger.debug("Loaded \(serverTools.count) tools from VS Code MCP server: \(serverName)")
                } catch {
                    logger.error("Failed to load tools from VS Code MCP server '\(serverName)': \(error.localizedDescription)")
                }
            }
            
            if !mcpServers.isEmpty {
                logger.debug("Loaded \(tools.count) VS Code MCP tools from \(mcpServers.count) servers")
            }
            
        } catch {
            logger.error("Error loading VS Code configuration: \(error.localizedDescription)")
        }
        
        return tools
    }
}
