--[[
* parser.lua
* 负责代码解析，使用Treesitter提取函数信息
* 提供函数定位、结构分析等功能
]]

local ts_utils = require("nvim-treesitter.ts_utils")
local parsers = require("nvim-treesitter.parsers")
local logger = require("coztrail.core.logger")
local M = {}

--[[
* get_current_function函数
* 获取光标所在位置的函数
* @return 函数文本内容和函数节点
]]
function M.get_current_function()
  logger.debug("Getting current function at cursor position", "parser")
  local bufnr = 0
  local parser = parsers.get_parser(bufnr)
  if not parser then
    logger.error("Failed to get treesitter parser for current buffer", "parser")
    return nil, nil
  end
  
  local tree = parser:parse()[1]
  if not tree then
    logger.error("Failed to parse syntax tree", "parser")
    return nil, nil
  end
  
  local root = tree:root()
  local node = ts_utils.get_node_at_cursor()
  
  logger.debug("Searching for function node from cursor position", "parser")
  while node do
    if node:type():match("function") then
      local start_row, _, end_row, _ = node:range()
      logger.info("Function found at lines " .. start_row .. "-" .. end_row, "parser")
      local lines = vim.api.nvim_buf_get_lines(bufnr, start_row, end_row + 1, false)
      return table.concat(lines, "\n"), node
    end
    node = node:parent()
  end
  
  return nil, nil
end

--[[
* get_function_at_pos 函数
* 获取指定 buffer 和位置处的函数节点与其文本内容
* @param bufnr number - buffer 编号
* @param pos table - 位置 {row, col}，0-based
* @return string|nil - 函数文本
* @return TSNode|nil - 函数节点
]]
function M.get_function_at_pos(bufnr, pos)
  logger.debug("Getting function at specified buffer and position", "parser")

  local parser = parsers.get_parser(bufnr)
  if not parser then
    logger.error("Failed to get treesitter parser for buffer " .. bufnr, "parser")
    return nil, nil
  end

  local tree = parser:parse()[1]
  if not tree then
    logger.error("Failed to parse syntax tree", "parser")
    return nil, nil
  end

  local root = tree:root()
  local root_type = root:type()
  local row, col = pos[1], pos[2]
  local node = vim.treesitter.get_node({
    bufnr = bufnr,
    pos = { row, col },
  })
  local node_type = node and node:type() or "nil"
  local filename = vim.api.nvim_buf_get_name(bufnr)

  logger.warn(string.format(
    "root: %s, node_type: %s at (file: %s, line: %d, col: %d)",
    root_type, node_type, filename, row, col), "parser"
  )

  logger.debug(string.format("Searching for function node from position [%d, %d]", row, col), "parser")

  -- Language-specific function node types
  local function_node_types_by_lang = {
    go = {
      function_declaration = true,
      method_declaration = true,
      method_elem = true, -- interface method
    }
  }

  -- Determine language
  local lang = vim.treesitter.language.get_lang(vim.bo[bufnr].filetype) or "go"
  local function_node_types = function_node_types_by_lang[lang] or {}

  while node do
    if function_node_types[node:type()] then
      local start_row, _, end_row, _ = node:range()
      logger.info(string.format("Function/method found at lines %d-%d", start_row, end_row), "parser")
      local lines = vim.api.nvim_buf_get_lines(bufnr, start_row, end_row + 1, false)
      return table.concat(lines, "\n"), node
    end
    node = node:parent()
  end

  logger.warn(string.format("No function found at (file: %s, line: %d, col: %d)", filename, row, col), "parser")
  return nil, nil
end

--[[
* analyze_structure函数
* 分析函数结构，提取函数调用信息
* @param func_node 函数节点
* @return 包含函数调用和全局变量的结构信息
]]
function M.analyze_structure(bufnr, func_node)
  logger.debug("Starting function structure analysis", "parser")
  local structure = {
    calls = {},
    globals = M.extract_globals(func_node),
  }

  -- 获取缓冲区的语言类型
  local language = parsers.get_buf_lang(bufnr) or "unknown"
  logger.debug("Analyzing " .. language .. " code structure", "parser")
  
  -- 语言特定的AST节点类型配置
  local language_config = {
    go = {
      call_node_types = {"call_expression"},
      function_field = "function"
    },
    -- TODO: 添加对其他语言的支持
    default = {
      call_node_types = {"call_expression"},
      function_field = "function"
    }
  }
  
  local config = language_config[language] or language_config.default

  local extract_text_content
  local extract_selector_chain
  local extract_go_calls
  local walk

  -- 提取文本内容的辅助函数
  function extract_text_content(text_data)
    if type(text_data) == "table" and text_data[1] then
      return text_data[1]
    elseif type(text_data) == "string" then
      return text_data
    end
    return nil
  end
  
  -- 递归提取选择器链中的所有调用
  function extract_selector_chain(selector_node, calls_list)
    -- 先处理左侧的操作数（可能是另一个选择器或调用）
    local operand = selector_node:field("operand")
    if operand and operand[1] then
      local operand_type = operand[1]:type()
      if operand_type == "call_expression" then
        -- 递归处理链式调用的前一部分
        local nested_func = operand[1]:field("function")
        if nested_func and nested_func[1] then
          extract_go_calls(nested_func[1], calls_list)
        end
      elseif operand_type == "selector_expression" then
        -- 继续处理更深层的选择器
        extract_selector_chain(operand[1], calls_list)
      end
    end
    
    -- 然后处理当前选择器的字段（方法名）
    local field_node = selector_node:field("field")
    if field_node and field_node[1] then
      local name_text = vim.treesitter.get_node_text(field_node[1], bufnr)
      local method_name = extract_text_content(name_text)
      if method_name then
        local row, col = field_node[1]:range()
        table.insert(calls_list, {
          name = method_name,
          line = row,
          col = col,
          text = method_name .. "(...)",
          language = language,
          call_type = "method"
        })
      end
    end
  end
  
  function extract_go_calls(func_node, calls_list)
    local node_type = func_node:type()
    
    if node_type == "identifier" then
      -- 情况1: 普通函数调用 fmt.Println -> Println
      local name_text = ts_utils.get_node_text(func_node, 0)
      local function_name = extract_text_content(name_text)
      if function_name then
        local row, col = func_node:range()
        table.insert(calls_list, {
          name = function_name,
          line = row,
          col = col,
          text = function_name .. "(...)",
          language = language,
          call_type = "function"
        })
      end
    elseif node_type == "selector_expression" then
      -- 情况2和3: 方法调用和链式调用
      extract_selector_chain(func_node, calls_list)
    end
  end

  function walk(node)
    local node_type = node:type()
    
    -- 检查是否为函数调用节点
    local is_call = false
    for _, call_type in ipairs(config.call_node_types) do
      if node_type == call_type then
        is_call = true
        break
      end
    end
    
    if is_call then
      logger.trace("Found function call node: " .. node_type, "parser")
      local func_node = node:field("function")
      if func_node and func_node[1] then
        if language == "go" then
          extract_go_calls(func_node[1], structure.calls)
        else
          -- 处理其他语言的标准函数调用
          local name_text = vim.treesitter.get_node_text(func_node[1], bufnr)
          local function_name = extract_text_content(name_text)
          if function_name then
            local row, col = func_node[1]:range()
            table.insert(structure.calls, {
              name = function_name,
              line = row,
              col = col,
              text = function_name .. "(...)",
              language = language,
              call_type = "function"
            })
          end
        end
      end
    end
    
    -- 递归遍历子节点
    for child in node:iter_children() do
      walk(child)
    end
  end
  
  walk(func_node)
  
  logger.info("Structure analysis completed: found " .. #structure.calls .. " function calls and " .. #structure.globals .. " global variables", "parser")
  
  -- 打印structure内部结构的详细信息
  logger.debug("Structure details:", "parser")
  
  -- 打印函数调用详情
  if #structure.calls > 0 then
    logger.debug("Function calls:", "parser")
    for i, call in ipairs(structure.calls) do
      logger.debug(string.format("  [%d] %s (line: %d, col: %d, type: %s)", 
                                i, call.name, call.line, call.col, call.call_type), "parser")
    end
  end
  
  -- 打印全局变量详情
  if #structure.globals > 0 then
    logger.debug("Global variables:", "parser")
    for i, global in ipairs(structure.globals) do
      logger.debug(string.format("  [%d] %s", i, vim.inspect(global)), "parser")
    end
  end
  
  return structure
end

--[[
* extract_globals函数
* 提取函数中使用的全局变量
* @param func_node 函数节点
* @return 全局变量列表
* 注意：当前实现返回空表，需要完善此功能
]]
function M.extract_globals(func_node)
  -- TODO: 实现全局变量提取功能
  -- 可以通过遍历AST节点，识别全局变量引用来实现
  return {}
end

return M