# MCPUtils - Model Context Protocol Utilities Framework

MCPUtils allow to get MCP tools from various sources.

## Overview

This framework provides:
- **Configuration Management**: Load MCP server configurations from Claude Desktop and VS Code
- **Tool Loading**: Automatically discover and load tools from configured MCP servers  
- **Foundation Models Integration**: Seamless integration with Apple's Foundation Models framework
- **Logging Support**: Configurable logging throughout the framework

## Usage

```swift
import MCPUtils
import Logging

// Create a logger
let logger = Logger(label: "your.app.mcp")

// Create tool service
let toolService = ToolService()

// Load all available tools
let tools = await toolService.loadTools(logger: logger)

// Use tools with Foundation Models
for tool in tools {
    print("Available tool: \(tool.name) - \(tool.description)")
}
```
### Loading Tools from Specific Sources

```swift
// Load only Claude MCP tools
let claudeTools = await toolService.loadClaudeMCPTools(logger: logger)

// Load only VS Code MCP tools
let vscodeTools = await toolService.loadVSCodeMCPTools(logger: logger)
```

## Configuration Files

MCPUtils automatically discovers MCP servers from standard configuration locations:

### Claude Desktop
- `~/Library/Application Support/Claude/claude_desktop_config.json`

### VS Code
- `~/Library/Application Support/Code/User/settings.json`
- `.vscode/settings.json` (workspace-specific)

## Requirements

- macOS 26.0+
- Swift 6.2+
