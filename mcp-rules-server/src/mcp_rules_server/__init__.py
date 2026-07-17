"""mcp-rules-server - MCP Server using chuk-mcp-runtime"""
__version__ = "0.1.0"

# Import tools to register them with the MCP runtime
from mcp_rules_server.tools.example_tools import (
    rules_server_search,
    rules_server_item,
    rules_server_process,
)

__all__ = [
    "rules_server_search",
    "rules_server_item",
    "rules_server_process",
]