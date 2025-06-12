# CozTrail

[English](README.md) | [中文](README_CN.md)

一个基于LLM的Neovim代码分析插件，帮助开发者快速理解函数功能和调用关系。

## 项目概述

CozTrail是一个Neovim插件，它利用大语言模型(LLM)和Treesitter技术，帮助开发者快速理解代码功能和调用关系。插件可以分析当前光标所在的函数，提取其结构信息，并使用LLM生成简洁明了的功能描述，同时展示函数调用图，帮助开发者更高效地阅读和理解代码。

## 核心功能

### 函数分析
分析当前光标所在函数的功能，生成简洁的功能描述

### 调用图展开
自动分析函数调用关系，构建调用图

### 缓存机制
缓存分析结果，提高重复查询效率

### 多语言支持
基于Treesitter，支持多种编程语言

### 友好界面
在浮动窗口中展示分析结果

## 安装方法

### 依赖项

- Neovim 0.8.0+
- [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter)
- Go语言环境（用于编译LLM交互组件）
- OpenAI API密钥（或兼容的API）

### 使用包管理器安装

使用[packer.nvim](https://github.com/wbthomason/packer.nvim)：

```lua
use {
  "mikewong23571/coztrail",
  requires = {"nvim-treesitter/nvim-treesitter"},
  config = function()
    require("coztrail").setup({
      -- 配置选项
      log_level = "INFO",
      log_to_file = true,
      log_to_console = true,
    })
  end
}
```

使用[lazy.nvim](https://github.com/folke/lazy.nvim)：

```lua
{
  "mikewong23571/coztrail",
  dependencies = {"nvim-treesitter/nvim-treesitter"},
  config = function()
    require("coztrail").setup({
      -- 配置选项
      log_level = "INFO",
      log_to_file = true,
      log_to_console = true,
    })
  end
}
```

### 编译LLM组件

安装插件后，需要编译Go语言组件：

```bash
cd ~/.local/share/nvim/site/pack/packer/start/coztrail/lua/coztrail/llm
# 或者lazy.nvim的路径
# cd ~/.local/share/nvim/lazy/coztrail/lua/coztrail/llm
go build -o summary summary.go
```

### 设置环境变量

```bash
export OPENAI_API_KEY="your-api-key-here"
```

## 使用方法

### 基本命令

- `:CozTrail analyze` - 分析当前光标所在函数（默认命令）
- `:CozTrail setup` - 重新设置插件配置
- `:CozTrail clear` - 清除函数分析缓存
- `:CozTrail config` - 显示当前配置
- `:CozTrail help` - 显示帮助信息

### 快速开始

1. 打开一个代码文件
2. 将光标放在任意函数内
3. 执行`:CozTrail`命令
4. 查看分析结果和调用图

## 工作原理

CozTrail的工作流程如下：

1. **函数定位**：使用Treesitter定位当前光标所在的函数
2. **结构分析**：提取函数的结构信息，包括函数调用、全局变量等
3. **调用图展开**：使用LSP查找被调用函数的定义，并递归分析
4. **LLM分析**：将函数代码和结构信息发送给LLM，生成功能描述
5. **缓存管理**：将分析结果缓存到本地，提高重复查询效率
6. **结果展示**：在浮动窗口中展示函数功能描述和调用图

### 核心模块

- [**core/orchestrator.lua**](lua/coztrail/core/orchestrator.lua)：核心协调模块，管理整个分析流程
- [**ts/parser.lua**](lua/coztrail/ts/parser.lua)：代码解析模块，使用Treesitter提取函数信息
- [**llm/runner.lua**](lua/coztrail/llm/runner.lua)：LLM交互模块，负责与大语言模型通信
- [**storage/db.lua**](lua/coztrail/storage/db.lua)：存储模块，管理分析结果的缓存
- [**ui/render.lua**](lua/coztrail/ui/render.lua)：UI渲染模块，展示分析结果

## 配置选项

```lua
require("coztrail").setup({
  log_level = "INFO", -- 日志级别：TRACE, DEBUG, INFO, WARN, ERROR, OFF
  log_to_file = true, -- 是否将日志写入文件
  log_to_console = true, -- 是否在控制台显示日志
  max_call_depth = 2, -- 调用图展开的最大深度
  -- 其他配置项...
})
```

## LICENSE

MIT License

Copyright (c) 2025 mikewong23571

本项目基于MIT许可证开源，详见[LICENSE](LICENSE)文件。