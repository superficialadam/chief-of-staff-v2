# Chief of Staff v2

An AI assistant application with Model Context Protocol (MCP) integration for tool usage.

## Setup

### Prerequisites
* Ruby 3.4.2
* Rails 8.0.2
* Node.js (for npx and MCP servers)
* OpenAI API key

### Installation

1. Install dependencies:
```bash
bundle install
```

2. Set up environment variables:
```bash
export OPENAI_API_KEY="your-openai-api-key"
```

3. Configure MCP servers in `config/mcp.json` (currently configured with filesystem server)

### TODO(human)
Please implement the environment configuration for the OpenAI API key. You can either:
1. Create a `.env` file with `OPENAI_API_KEY=your-key-here` and use the dotenv-rails gem
2. Use Rails credentials: `rails credentials:edit` and add your OpenAI key
3. Export it in your shell: `export OPENAI_API_KEY="your-key"`

Choose the method that works best for your workflow.

## Usage

### Web Interface (Rails Server)

1. Start the Rails server:
```bash
rails s
```

2. Open your browser to http://localhost:3000
3. Chat with the AI assistant through the web interface

### Command Line Interface

Use the `bin/ai` script for a REPL interface:
```bash
ruby bin/ai
```

Type your messages and press Enter. Use Ctrl+C to exit.

## Architecture

- **Ai::Orchestrator** - Manages the AI agent and MCP integration
- **Ai::McpManager** - Handles MCP server connections and tool management
- **LlmAgent** - OpenAI integration with MCP tool support
- **AiController** - Web API endpoints for chat functionality

## MCP Integration

The application uses the `ruby-mcp-client` gem to connect to MCP servers. Tools are automatically:
- Discovered from configured MCP servers
- Converted to OpenAI tool format
- Made available to the LLM for execution
- Executed when the LLM requests them

### Configured MCP Servers

- **filesystem** - Provides file system access tools (read, write, list files)

You can add more MCP servers by editing `config/mcp.json`.

## Development

To add new MCP servers:
1. Edit `config/mcp.json`
2. Add server configuration (stdio, SSE, or HTTP)
3. Restart the Rails server or bin/ai script

The MCP manager will automatically discover and integrate new tools.
