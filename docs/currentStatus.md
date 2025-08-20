# Chief of Staff v2 - Current Implementation Status

**Last Updated**: August 17, 2025  
**Status**: ✅ Fully Functional with MCP Integration

## Table of Contents

1. [Overview](#overview)
2. [Architecture Flow](#architecture-flow)
3. [Core Components](#core-components)
4. [MCP Integration](#mcp-integration)
5. [Entry Points](#entry-points)
6. [Data Flow Examples](#data-flow-examples)
7. [Current Capabilities](#current-capabilities)
8. [Known Issues & Limitations](#known-issues--limitations)

## Overview

Chief of Staff v2 is a Rails 8.0.2 application that provides an AI assistant with tool-calling capabilities through the Model Context Protocol (MCP). The system integrates OpenAI's GPT-4 with multiple MCP servers to provide file system access and Google Calendar functionality.

## Architecture Flow

```
┌─────────────────────────────────────────────────────────────┐
│                      User Interfaces                         │
├───────────────────────┬─────────────────────────────────────┤
│     Web Interface     │          CLI Interface              │
│  (localhost:3000)     │         (bin/ai REPL)               │
│                       │                                      │
│  app/controllers/     │     bin/ai                          │
│    ai_controller.rb   │       ├── readline input            │
│  app/views/ai/        │       └── colored output            │
│    index.html.erb     │           (console_colors)          │
└───────────┬───────────┴──────────────┬──────────────────────┘
            │                          │
            ▼                          ▼
┌──────────────────────────────────────────────────────────────┐
│              Ai::Orchestrator (Service Layer)                │
│              app/services/ai/orchestrator.rb                 │
│                                                               │
│  - Manages agent lifecycle                                   │
│  - Boots MCP Manager on first use                           │
│  - Routes requests to LlmAgent                              │
│  - Returns structured responses                              │
└───────────────────────┬──────────────────────────────────────┘
                        │
                        ▼
┌──────────────────────────────────────────────────────────────┐
│                  LlmAgent (AI Agent)                         │
│                app/agents/llm_agent.rb                       │
│                                                               │
│  - Integrates with OpenAI API                                │
│  - Manages tool calling loop                                 │
│  - Handles multi-round conversations                         │
│  - Formats tool results for LLM                              │
└────────┬─────────────────────────────────┬───────────────────┘
         │                                 │
         ▼                                 ▼
┌─────────────────────┐          ┌─────────────────────────────┐
│   OpenAI API        │          │    Ai::McpManager           │
│   (GPT-4)           │          │ app/services/ai/            │
│                     │          │   mcp_manager.rb            │
│ config/initializers/│          │                             │
│   openai.rb         │          │ - Singleton instance        │
└─────────────────────┘          │ - Manages MCP clients       │
                                 │ - Tool discovery            │
                                 │ - Tool execution            │
                                 └──────────┬──────────────────┘
                                            │
                                            ▼
┌──────────────────────────────────────────────────────────────┐
│              ruby-mcp-client (Gem)                          │
│                                                               │
│  MCPClient.create_client                                     │
│  - Handles stdio/SSE/HTTP transports                        │
│  - Manages JSON-RPC communication                           │
│  - Provides tool format conversions                         │
└───────────┬────────────────────────┬─────────────────────────┘
            │                        │
            ▼                        ▼
┌───────────────────────┐  ┌──────────────────────────────────┐
│  Filesystem Server    │  │    Google Calendar Server        │
│  (@modelcontextprotocol│  │   (@cocal/google-calendar-mcp)  │
│   /server-filesystem) │  │                                  │
│                       │  │   Configured in:                 │
│  Tools:               │  │   config/mcp.json                │
│  - read_file          │  │   credentials.json               │
│  - write_file         │  │                                  │
│  - list_directory     │  │   Tools:                         │
│  - search_files       │  │   - list-events                  │
│  - edit_file          │  │   - create-event                 │
│  - etc. (14 tools)    │  │   - get-current-time             │
│                       │  │   - etc. (9 tools)               │
└───────────────────────┘  └──────────────────────────────────┘
```

## Core Components

### 1. **Ai::Orchestrator** (`app/services/ai/orchestrator.rb`)

The central coordinator that:

- Initializes with a default LlmAgent
- Manages the MCP Manager boot process (lazy initialization)
- Provides `run!(input)` method for processing user queries
- Returns structured responses: `{ agent: "llm_agent", text: "response" }`
- Exposes health check via `health` method

**Key Methods**:

- `initialize(agent: default_agent)` - Sets up with LlmAgent by default
- `run!(input)` - Main entry point for processing requests
- `boot_once!` - Ensures MCP Manager is initialized only once
- `health` - Returns MCP status and available tools

### 2. **Ai::McpManager** (`app/services/ai/mcp_manager.rb`)

Singleton service that manages all MCP server connections:

- Loads configuration from `config/mcp.json`
- Creates MCPClient instances for each configured server
- Provides tool discovery and execution
- Converts tools to OpenAI/Anthropic formats

**Key Methods**:

- `boot!(strict: false)` - Initializes all MCP servers
- `list_tools` - Returns all available tools from all servers
- `openai_tools` - Converts tools to OpenAI function calling format
- `call_tool(name, parameters)` - Executes a specific tool
- `expand_env(hash)` - Handles environment variable expansion and file paths

**Configuration Processing**:

- Supports `env:VAR_NAME` for environment variables
- Supports `file:relative/path` for Rails.root relative paths
- Supports absolute paths starting with `/`
- Handles stdio, SSE, and HTTP transport types

### 3. **LlmAgent** (`app/agents/llm_agent.rb`)

The AI agent that interfaces with OpenAI:

- Inherits from `BaseAgent` (`app/agents/base_agent.rb`)
- Manages the conversation flow with tool calling
- Implements multi-round tool execution loop
- Handles error recovery

**Key Methods**:

- `step!(input)` - Processes a single user input
- `call_with_tools(messages, tools)` - Handles tool-enabled conversations
- `execute_tool_calls(tool_calls)` - Executes requested tools via MCP Manager
- `build_system_prompt` - Constructs system prompt with available tools

**Tool Calling Loop**:

1. Send user query to OpenAI with available tools
2. If OpenAI requests tools, execute them
3. Send tool results back to OpenAI
4. Repeat until OpenAI provides final answer (max 5 iterations)

### 4. **AiController** (`app/controllers/ai_controller.rb`)

Rails controller providing HTTP API endpoints:

- `GET /ai` - Renders the web chat interface
- `POST /ai/chat` - Processes chat messages via JSON API
- `GET /ai/health` - Returns system health status

**Security**:

- Skips CSRF protection for chat endpoint (API usage)
- Returns structured JSON responses
- Handles errors gracefully

### 5. **Web Interface** (`app/views/ai/index.html.erb`)

Single-page chat application:

- Pure JavaScript (no framework dependencies)
- Real-time chat UI with message history
- Async fetch API for communication
- Styled with inline CSS for simplicity
- Auto-scrolling chat container
- Loading states and error handling

## MCP Integration

### Configuration (`config/mcp.json`)

```json
{
  "servers": [
    {
      "alias": "filesystem",
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem", "/path"],
      "env": {}
    },
    {
      "alias": "calendar",
      "type": "stdio", 
      "command": "npx",
      "args": ["-y", "@cocal/google-calendar-mcp"],
      "env": {
        "GOOGLE_OAUTH_CREDENTIALS": "/path/to/credentials.json"
      }
    }
  ]
}
```

### MCP Server Communication

1. **Stdio Transport**: Used for local Node.js MCP servers
   - Spawns process with command + args
   - Communicates via stdin/stdout JSON-RPC
   - Environment variables passed to subprocess

2. **Tool Discovery**: On boot, MCP Manager:
   - Connects to each configured server
   - Calls `tools/list` RPC method
   - Caches available tools
   - Formats for OpenAI consumption

3. **Tool Execution Flow**:

   ```
   LlmAgent.execute_tool_calls
     → McpManager.call_tool(name, params)
       → MCPClient.call_tool(name, params)
         → JSON-RPC to MCP server
         → Tool execution
       ← JSON-RPC response
     ← Formatted result
   ← Tool result to OpenAI
   ```

## Entry Points

### 1. **CLI Interface** (`bin/ai`)

```ruby
#!/usr/bin/env ruby
require_relative "../config/environment"
require "readline"
require_relative "../app/lib/ai/console_colors"

orchestrator = Ai::Orchestrator.new
loop do
  input = Readline.readline("> ", true)
  result = orchestrator.run!(input)
  # Display with colored agent name
end
```

**Features**:

- REPL interface with readline support
- Colored output via Pastel gem
- Ctrl+C handling for graceful exit
- Command history

### 2. **Rails Server**

Standard Rails startup:

```bash
rails s
```

Routes (`config/routes.rb`):

- `root "ai#index"` - Default to chat interface
- `get "ai" => "ai#index"` - Chat UI
- `post "ai/chat" => "ai#chat"` - API endpoint
- `get "ai/health" => "ai#health"` - Health check

### 3. **Console Colors** (`app/lib/ai/console_colors.rb`)

Utility module for CLI formatting:

- Uses Pastel gem for terminal colors
- Deterministic color assignment based on agent name
- Methods: `colored_badge`, `colored_title`, `dim`

## Data Flow Examples

### Example 1: Simple Query (No Tools)

```
User: "Hello, how are you?"
         ↓
    Orchestrator.run!
         ↓
    LlmAgent.step!
         ↓
    OpenAI API (no tools needed)
         ↓
    Direct response
         ↓
    { agent: "llm_agent", text: "I'm doing well..." }
```

### Example 2: Tool-Using Query

```
User: "What time is it?"
         ↓
    Orchestrator.run!
         ↓
    LlmAgent.step!
         ↓
    OpenAI API (with tools list)
         ↓
    Tool request: get-current-time
         ↓
    McpManager.call_tool("get-current-time", {})
         ↓
    MCP Calendar Server
         ↓
    Returns: { time: "2025-08-17T23:03:28", timezone: "Europe/Stockholm" }
         ↓
    Back to OpenAI with tool result
         ↓
    Final response formatting
         ↓
    { agent: "llm_agent", text: "The current time is..." }
```

### Example 3: Multi-Tool Query

```
User: "What events do I have tomorrow?"
         ↓
    Orchestrator.run!
         ↓
    LlmAgent.step! (iteration 1)
         ↓
    OpenAI → Tool: get-current-time
         ↓
    McpManager → MCP Server → Result
         ↓
    LlmAgent.step! (iteration 2)
         ↓
    OpenAI → Tool: list-events (with tomorrow's date)
         ↓
    McpManager → MCP Server → Result
         ↓
    LlmAgent.step! (iteration 3)
         ↓
    OpenAI → Final formatted response
         ↓
    { agent: "llm_agent", text: "You have 1 event tomorrow..." }
```

## Current Capabilities

### ✅ Implemented Features

1. **Core AI Functionality**
   - OpenAI GPT-4 integration
   - Multi-round tool calling
   - System prompt customization
   - Error handling and recovery

2. **MCP Integration**
   - Filesystem tools (14 operations)
   - Google Calendar tools (9 operations)
   - Dynamic tool discovery
   - Tool result formatting

3. **User Interfaces**
   - Web chat interface with real-time updates
   - CLI REPL with colored output
   - JSON API for programmatic access
   - Health check endpoint

4. **Architecture**
   - Clean separation of concerns
   - Singleton MCP Manager
   - Lazy initialization
   - Proper error propagation

### 📊 Available Tools

**Filesystem (14 tools)**:

- File operations: read, write, edit, move
- Directory operations: list, create, tree view
- Search: find files by pattern
- Metadata: file info, permissions

**Google Calendar (9 tools)**:

- Calendar management: list calendars
- Event operations: create, update, delete, search
- Time queries: current time, free/busy
- Color schemes for events

## Known Issues & Limitations

### Current Limitations

1. **Tool Calling**:
   - Maximum 5 iterations per query
   - No streaming responses
   - Tool errors may not be user-friendly

2. **MCP Servers**:
   - No automatic retry on server crash

## Testing

Test scripts available:

- `test_mcp.rb` - Tests MCP Manager functionality
- `test_calendar.rb` - Tests calendar integration

Run tests:

```bash
ruby test_mcp.rb
ruby test_calendar.rb
```

## Environment Requirements

- Ruby 3.4.2
- Rails 8.0.2
- Node.js (for npx and MCP servers)
- OpenAI API key
- Google OAuth credentials (for calendar)

## File Structure Summary

```
chief-of-staff-v2/
├── app/
│   ├── agents/
│   │   ├── base_agent.rb         # Base class for agents
│   │   └── llm_agent.rb           # OpenAI integration
│   ├── controllers/
│   │   └── ai_controller.rb       # Web API endpoints
│   ├── lib/ai/
│   │   └── console_colors.rb      # CLI formatting
│   ├── services/ai/
│   │   ├── mcp_manager.rb         # MCP server management
│   │   └── orchestrator.rb        # Main coordinator
│   └── views/ai/
│       └── index.html.erb         # Web chat interface
├── bin/
│   └── ai                         # CLI REPL script
├── config/
│   ├── initializers/
│   │   └── openai.rb              # OpenAI client setup
│   ├── mcp.json                   # MCP server configuration
│   └── routes.rb                  # Rails routes
├── prompts/agents/
│   └── assistant.md               # System prompt
└── credentials.json               # Google OAuth credentials
```

## Configuration Files

- `Gemfile`: Dependencies including `ruby-mcp-client`, `openai`, `pastel`
- `config/mcp.json`: MCP server definitions
- `credentials.json`: Google OAuth credentials
- `.env` or environment: OPENAI_API_KEY

---

## Changelog

### August 17, 2025 - 23:42 CET

**🔄 CLI Architecture Transformation: Standalone to Client-Server**

**Changes Made:**
- **Transformed `bin/ai` from standalone process to HTTP client**
  - Before: Loaded entire Rails environment in REPL session
  - After: Lightweight HTTP client connecting to running Rails server
  - Added command-line options: `--host`, `--port`, `--ssl`, `--help`
  - Added built-in commands: `health`, `help`, `exit`
  - Improved error handling for network issues and server errors

- **Enhanced AiController for persistent connections**
  - Implemented singleton Orchestrator pattern to maintain state
  - MCP server connections now persist across requests
  - Better error logging and debugging support

- **Fixed Rails 8 logging compatibility issue**
  - Resolved `undefined method 'push_tags'` error in development environment
  - Added custom logger configuration to bypass problematic tagged logging
  - Chat functionality now works end-to-end

- **Improved client features**
  - Connection health checking with configurable timeouts
  - Colored output with graceful fallback when Pastel gem unavailable
  - Proper handling of server responses and error states
  - Maintained original REPL user experience

**New Workflow:**
1. Start Rails server: `rails s`
2. Connect client: `bin/ai` (in separate terminal)
3. Chat with AI assistant using full MCP tool capabilities

**Benefits:**
- Reduced memory footprint (client no longer loads Rails environment)
- Faster startup time for REPL sessions
- Persistent MCP server connections improve response times
- Multiple clients can connect to same server simultaneously
- Clear separation between server and client concerns

**Files Modified:**
- `bin/ai` - Complete rewrite as HTTP client
- `app/controllers/ai_controller.rb` - Added singleton Orchestrator
- `config/environments/development.rb` - Fixed Rails 8 logging
- `credentials.json` - Added for MCP calendar server testing

### August 18, 2025 - 15:30 CET

**🔍 Performance Investigation & UI Improvements**

**Problem Identified:**
- Users experienced 10-15 second delays in REPL with no feedback
- Server logs showed immediate processing, but responses appeared much later
- Both web and CLI interfaces affected equally

**Root Cause Analysis:**
- Added detailed timing logs to LlmAgent
- Discovered delay breakdown:
  - OpenAI API call 1: ~2 seconds (decides to call tools)
  - MCP tool execution: <1 second (calendar data retrieved quickly) 
  - OpenAI API call 2: ~6-8 seconds (processes tool results and generates response)
- Total delay was legitimate processing time, not a buffering issue

**Solution Implemented:**
- **Simple "Processing..." indicator in CLI client**
  - Shows immediately after user input
  - Provides visual feedback during the 8+ second OpenAI processing
  - Much simpler than complex SSE streaming initially attempted

**Files Modified:**
- `bin/ai` - Added immediate "Processing..." feedback indicator
- `app/agents/llm_agent.rb` - Added detailed timing logs for performance analysis
- `app/controllers/ai_controller.rb` - Prepared SSE streaming endpoint (not needed)
- `config/routes.rb` - Added `/ai/stream` route (kept for future use)
- `config/environments/development.rb` - Added streaming configuration

**Key Learnings:**
- Not all delays are technical bottlenecks - sometimes it's just processing time
- Simple UX improvements (like "Processing...") can be more effective than complex technical solutions
- Always measure first before optimizing - the logs revealed the true source of delay

**Current Performance:**
- MCP tools execute in <1 second
- OpenAI API calls take 2-8 seconds depending on complexity
- User now sees immediate feedback instead of silent waiting

---

This documentation represents the current state of the Chief of Staff v2 implementation as of August 18, 2025.

