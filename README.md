# CozTrail

[English](README.md) | [中文](README_CN.md)

A LLM-based Neovim plugin for code analysis, helping developers quickly understand function functionality and call relationships.

## Project Overview

CozTrail is a Neovim plugin that utilizes Large Language Models (LLM) and Treesitter technology to help developers quickly understand code functionality and call relationships. The plugin analyzes the function at the current cursor position, extracts its structural information, and uses LLM to generate concise functional descriptions while displaying function call graphs, helping developers read and understand code more efficiently.

## Core Features

### Function Analysis
Analyze the functionality of the function at the current cursor position and generate a concise functional description

### Call Graph Expansion
Automatically analyze function call relationships and build call graphs

### Caching Mechanism
Cache analysis results to improve efficiency of repeated queries

### Multi-language Support
Based on Treesitter, supporting multiple programming languages

### Friendly Interface
Display analysis results in floating windows

## Installation

### Dependencies

- Neovim 0.8.0+
- [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter)
- Go language environment (for compiling LLM interaction components)
- OpenAI API key (or compatible API)

### Install with Package Manager

Using [packer.nvim](https://github.com/wbthomason/packer.nvim):

```lua
use {
  "mikewong23571/coztrail",
  requires = {"nvim-treesitter/nvim-treesitter"},
  config = function()
    require("coztrail").setup({
      -- Configuration options
      log_level = "INFO",
      log_to_file = true,
      log_to_console = true,
    })
  end
}
```

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "mikewong23571/coztrail",
  dependencies = {"nvim-treesitter/nvim-treesitter"},
  config = function()
    require("coztrail").setup({
      -- Configuration options
      log_level = "INFO",
      log_to_file = true,
      log_to_console = true,
    })
  end
}
```

### Compile LLM Component

After installing the plugin, you need to compile the Go language component:

```bash
cd ~/.local/share/nvim/site/pack/packer/start/coztrail/lua/coztrail/llm
# Or lazy.nvim path
# cd ~/.local/share/nvim/lazy/coztrail/lua/coztrail/llm
go build -o summary summary.go
```

### Set Environment Variables

```bash
export OPENAI_API_KEY="your-api-key-here"
```

## Usage

### Basic Commands

- `:CozTrail analyze` - Analyze the function at the current cursor position (default command)
- `:CozTrail setup` - Reconfigure the plugin
- `:CozTrail clear` - Clear function analysis cache
- `:CozTrail config` - Display current configuration
- `:CozTrail help` - Display help information

### Quick Start

1. Open a code file
2. Place the cursor inside any function
3. Execute the `:CozTrail` command
4. View the analysis results and call graph

## How It Works

CozTrail's workflow is as follows:

1. **Function Location**: Use Treesitter to locate the function at the current cursor position
2. **Structure Analysis**: Extract the function's structural information, including function calls, global variables, etc.
3. **Call Graph Expansion**: Use LSP to find definitions of called functions and recursively analyze them
4. **LLM Analysis**: Send function code and structural information to LLM to generate functional descriptions
5. **Cache Management**: Cache analysis results locally to improve efficiency of repeated queries
6. **Result Display**: Display function descriptions and call graphs in floating windows

### Core Modules

- [**core/orchestrator.lua**](lua/coztrail/core/orchestrator.lua): Core coordination module, managing the entire analysis process
- [**ts/parser.lua**](lua/coztrail/ts/parser.lua): Code parsing module, using Treesitter to extract function information
- [**llm/runner.lua**](lua/coztrail/llm/runner.lua): LLM interaction module, responsible for communicating with large language models
- [**storage/db.lua**](lua/coztrail/storage/db.lua): Storage module, managing caching of analysis results
- [**ui/render.lua**](lua/coztrail/ui/render.lua): UI rendering module, displaying analysis results

## Configuration Options

```lua
require("coztrail").setup({
  log_level = "INFO", -- Log levels: TRACE, DEBUG, INFO, WARN, ERROR, OFF
  log_to_file = true, -- Whether to write logs to file
  log_to_console = true, -- Whether to display logs in console
  -- Other configuration options...
})
```

## LICENSE

MIT License

Copyright (c) 2025 mikewong23571

This project is open-sourced under the MIT License, see the [LICENSE](LICENSE) file for details.