# MCP rules-server Server

MCP server for retrieving coding rules from GitHub

## Overview

MCP rules-server Server is a lightweight MCP server built using the chuk-mcp-runtime framework. It provides standardized tools and resources through the Model Context Protocol (MCP) interface.

## Features

- Built on chuk-mcp-runtime for robust MCP support
- [Key feature 1]
- [Key feature 2]
- [Key feature 3]
- Standardized MCP interface for easy integration
- Lightweight and modular design

## Installation

### Prerequisites

- Python 3.11 or higher
- uv package manager (recommended) or pip
- make (for using Makefile commands)

### Quick Start

```bash
# Clone the repository
git clone [repository-url]/mcp-rules_server.git
cd mcp-rules_server

# Setup development environment and install dependencies
make install

# Or manually:
# uv venv .venv
# source .venv/bin/activate  # On Windows: .venv\Scripts\activate
# uv pip install -e ".[dev]"
```

## Configuration

The server can be configured using the `config.yaml` file in the project root. Key configuration options include:

- **host**: Server name and log level
- **server**: Transport type (stdio, sse, streamable-http) and authentication
- **sse**: SSE server settings (if using SSE transport)
- **proxy**: Proxy feature configuration
- **mcp_servers**: Server-specific settings and tool module paths

### Configuration Example

```yaml
host:
  name: "mcp-rules-server"
  log_level: "INFO"

server:
  type: "streamable-http"
  auth: "none"

mcp_servers:
  rules_server:
    enabled: true
    location: "."
    tools:
      enabled: true
      module: "mcp_rules_server.tools.example_tools"
```

## Usage

### Running the server

```bash
# Using Make (recommended)
make run

# Or as a command (after installation)
mcp-rules-server

# Or run as a module
python -m mcp_rules_server.main
```

### Available Tools

The server provides the following tools:

#### `rules_server_search`

[Description of the search tool]

Parameters:
- `query` (str): The search query
- `limit` (int, optional): Maximum number of results to return. Defaults to 5.

#### `rules_server_item`

[Description of the item retrieval tool]

Parameters:
- `item_id` (int): The ID of the item to retrieve

#### `rules_server_process`

[Description of the processing tool]

Parameters:
- `data` (str): The data to process
- `option` (str, optional): Processing option. Defaults to "default".

## Project Structure

```
mcp-rules_server/
├── Makefile            # Development commands
├── config.yaml         # Server configuration
├── pyproject.toml      # Project configuration
├── README.md          # This file
├── src/
│   └── mcp_rules_server/
│       ├── __init__.py
│       ├── main.py         # Entry point
│       └── tools/
│           ├── __init__.py
│           └── example_tools.py  # Tool implementations
└── test/
    └── __init__.py
```

## Development

### Setting up a development environment

This project includes a Makefile with convenient commands for development:

```bash
# Quick setup (creates venv and installs dependencies)
make dev

# Activate the virtual environment
source .venv/bin/activate  # On Windows: .venv\Scripts\activate
```

### Available Make Commands

| Command | Description |
|---------|-------------|
| `make help` | Show all available commands |
| `make dev` | Setup complete development environment |
| `make venv` | Create virtual environment |
| `make install` | Install project dependencies |
| `make run` | Run the MCP server |
| `make test` | Run unit tests |
| `make lint` | Run code linting |
| `make format` | Auto-format code |
| `make check` | Run linting and tests |
| `make clean` | Clean up build artifacts and caches |

### Running tests

```bash
# Using Make (recommended)
make test

# Or manually with pytest
pytest test/ -v
```

### Code Quality

```bash
# Check code quality
make lint

# Auto-format code
make format

# Run all checks (lint + test)
make check
```

### Manual Setup (without Make)

If you prefer not to use Make:

```bash
# Create a virtual environment
uv venv .venv
source .venv/bin/activate  # On Windows: .venv\Scripts\activate

# Install development dependencies
uv pip install -e ".[dev]"

# Run the server
python -m mcp_rules_server.main

# Run tests
pytest test/ -v
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes and ensure tests pass (`make check`)
4. Commit your changes (`git commit -m 'Add some amazing feature'`)
5. Push to the branch (`git push origin feature/amazing-feature`)
6. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.