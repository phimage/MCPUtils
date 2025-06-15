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
let result = await toolService.loadTools(logger: logger)

// Use tools with Foundation Models
for (clientName, tools) in result.tools {
    print("Client: \(clientName)")
    for tool in tools {
        print("  Tool: \(tool.name) - \(tool.description)")
    }
}
```
### Loading Tools from Specific Sources

```swift
// Load only Claude MCP tools
let claudeResult = await toolService.loadClaudeMCPTools(logger: logger)

// Load only VS Code MCP tools
let vscodeResult = await toolService.loadVSCodeMCPTools(logger: logger)
```

### Get tools ready for Apple's FoundationModels

```swift
let tools: [any FoundationModels.Tool] = result.foundationModelsTools
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
