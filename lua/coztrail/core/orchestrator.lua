--[[
* orchestrator.lua
* 核心协调模块，负责整合各个组件的功能
* 处理函数分析、调用图展开和结果展示的流程
]]

local parser = require('coztrail.ts.parser')
local runner = require('coztrail.llm.runner')
local db = require('coztrail.storage.db')
local ui = require('coztrail.ui.render')
local logger = require('coztrail.core.logger')

local M = {}

--[[
* run函数
* 主入口函数，分析当前光标所在的函数
* 流程：获取函数 -> 分析结构 -> 展开调用图 -> 总结函数 -> 显示结果
]]
function M.run()
  local start_time = logger.time_start()
  logger.info('Starting function analysis', 'orchestrator')

  local func_text, func_node = parser.get_current_function()
  if not func_node then
    logger.warn('No function found at cursor', 'orchestrator')
    vim.notify('No function found at cursor.', vim.log.levels.WARN)
    return
  end

  logger.debug('Function found, analyzing structure', 'orchestrator')
  local bufnr = vim.api.nvim_get_current_buf()
  local structure = parser.analyze_structure(bufnr, func_node)
  M.expand_call_graph(bufnr, func_node, structure, function(callee_summaries)
    M.summarize_with_cache(
      bufnr,
      'current_function',
      func_text,
      func_node,
      structure,
      callee_summaries,
      function(summary)
        logger.time_end(start_time, 'complete function analysis', 'orchestrator')
        ui.show_summary(summary, callee_summaries)
      end
    )
  end)
end

--[[
* summarize_with_cache函数
* 使用缓存机制总结函数功能
* 如果缓存中存在，直接返回；否则调用LLM进行总结
* @param func_name 函数名称
* @param func_text 函数文本内容
* @param func_node 函数节点
* @param structure 函数结构信息
* @param callback 回调函数，处理总结结果
]]
function M.summarize_with_cache(
  bufnr,
  func_name,
  func_text,
  func_node,
  structure,
  callee_summaries,
  callback
)
  logger.debug('Checking cache for function: ' .. func_name, 'orchestrator')
  local cached = db.get_summary(bufnr, func_node)
  if cached then
    logger.info('Cache hit for function: ' .. func_name, 'orchestrator')
    -- 修改这里，返回统一的字典格式
    callback({
      success = true,
      content = cached,
      source = 'cache',
    })
    return
  end

  logger.info('Cache miss, generating summary for function: ' .. func_name, 'orchestrator')
  runner.summarize(func_name, func_text, structure, callee_summaries, function(result)
    if result.success then
      logger.debug('Summary generated, saving to cache for function: ' .. func_name, 'orchestrator')
      local save_success = db.save_summary(bufnr, func_node, result.content)
      if save_success then
        logger.debug(
          'Successfully saved summary to cache for function: ' .. func_name,
          'orchestrator'
        )
      else
        logger.warn('Failed to save summary to cache for function: ' .. func_name, 'orchestrator')
      end
      -- 保持原有的结果结构，添加来源信息
      result.source = 'llm'
      callback(result)
    else
      logger.warn('Failed to generate summary: ' .. result.error_message, 'orchestrator')
      callback(result) -- 已经是字典格式，直接传递
    end
  end)
end

--[[
* resolve_function_definition函数
* 使用LSP解析函数定义
* @param call 函数调用信息
* @param on_resolve 解析完成后的回调函数
]]
function M.resolve_function_definition(bufnr, call, on_resolve)
  logger.debug(
    'Resolving definition for function: ' .. (call.name or 'unknown') .. ' at line ' .. call.line,
    'orchestrator'
  )

  -- 参数验证
  if not call or type(call.line) ~= 'number' or type(call.col) ~= 'number' then
    logger.error('Invalid call parameters for function resolution', 'orchestrator')
    on_resolve({
      success = false,
      error = 'Invalid call parameters',
    })
    return
  end

  if type(on_resolve) ~= 'function' then
    error('on_resolve must be a function')
    return
  end

  -- 检查是否为Go内建函数
  if call.language == 'go' then
    -- Go内建函数列表
    local go_builtins = {
      -- 基本内建函数
      ['append'] = true,
      ['cap'] = true,
      ['close'] = true,
      ['complex'] = true,
      ['copy'] = true,
      ['delete'] = true,
      ['imag'] = true,
      ['len'] = true,
      ['make'] = true,
      ['new'] = true,
      ['panic'] = true,
      ['print'] = true,
      ['println'] = true,
      ['real'] = true,
      ['recover'] = true,
      -- 类型转换函数可以根据需要添加
    }

    if go_builtins[call.name] then
      logger.debug('Skipping built-in Go function: ' .. call.name, 'orchestrator')
      on_resolve({
        success = true,
        skip = true,
        type = 'builtin',
        content = 'Go built-in function: ' .. call.name,
        message = 'Go built-in function',
      })
      return
    end
  end

  vim.lsp.buf_request(0, 'textDocument/definition', {
    textDocument = { uri = vim.uri_from_bufnr(bufnr) },
    position = { line = call.line, character = call.col },
  }, function(err, result)
    if err or not result or vim.tbl_isempty(result) or not result[1] then
      logger.warn(
        'LSP definition request failed for: '
          .. (call.name or 'unknown')
          .. ', error: '
          .. (err and err.message or 'no result'),
        'orchestrator'
      )
      vim.notify(
        'Unable to resolve definition for: ' .. (call.name or 'unknown'),
        vim.log.levels.WARN
      )
      on_resolve({
        success = false,
        error = 'Unable to resolve definition',
      })
      return
    end

    logger.debug('LSP definition found for: ' .. call.name, 'orchestrator')

    local def = result[1]
    if
      not def
      or (not def.uri and not def.targetUri)
      or (not def.range and not def.targetRange)
    then
      on_resolve({
        success = false,
        error = 'Invalid definition result',
      })
      return
    end
    local uri = def.uri or def.targetUri

    -- 检查是否为Go标准库路径
    if call.language == 'go' and uri:match('/go/src/') then
      logger.debug(
        'Skipping Go standard library function: ' .. call.name .. ' at ' .. uri,
        'orchestrator'
      )
      on_resolve({
        success = true,
        skip = true,
        type = 'stdlib',
        content = 'Go standard library function: ' .. call.name,
        message = 'Go standard library function',
      })
      return
    end

    local range = def.range or def.targetRange
    local nbufnr = vim.uri_to_bufnr(uri)
    vim.fn.bufload(nbufnr)

    vim.api.nvim_buf_call(nbufnr, function()
      vim.cmd('filetype detect')
    end)

    local start_row = range.start.line
    local cursor_pos = { start_row, range.start.character or 0 }

    local func_text, func_node = parser.get_function_at_pos(nbufnr, cursor_pos)
    if func_node then
      logger.debug('Function node found, analyzing structure for: ' .. call.name, 'orchestrator')
      local structure = parser.analyze_structure(nbufnr, func_node)
      M.expand_call_graph(nbufnr, func_node, structure, function(callee_summaries)
        M.summarize_with_cache(
          nbufnr,
          call.name,
          func_text,
          func_node,
          structure,
          callee_summaries,
          function(summary)
            -- summary已经是字典格式，直接传递
            on_resolve(summary)
          end
        )
      end)
    else
      on_resolve({
        success = false,
        error = 'Function node not found',
      })
    end
  end)
end

--[[
* expand_call_graph函数
* 展开函数调用图，分析所有被调用的函数
* @param func_node 函数节点
* @param structure 函数结构信息
* @param on_complete 完成后的回调函数
]]
function M.expand_call_graph(bufnr, func_node, structure, on_complete)
  logger.info('Starting call graph expansion with ' .. #structure.calls .. ' calls', 'orchestrator')
  local summaries = {}
  local total = #structure.calls
  if total == 0 then
    logger.debug('No function calls found, skipping call graph expansion', 'orchestrator')
    return on_complete(summaries)
  end

  local remaining = total
  local resolved_count = 0
  for _, call in ipairs(structure.calls) do
    logger.debug('Resolving function definition for: ' .. call.name, 'orchestrator')
    M.resolve_function_definition(bufnr, call, function(summary)
      resolved_count = resolved_count + 1
      if not summary.success then
        logger.warn(
          'Failed to resolve function: '
            .. call.name
            .. ', error: '
            .. (summary.error or 'unknown error'),
          'orchestrator'
        )
      elseif summary.skip then
        logger.debug(
          'Skipped function: ' .. call.name .. ', reason: ' .. (summary.message or 'unknown'),
          'orchestrator'
        )
      else
        logger.debug('Successfully resolved function: ' .. call.name, 'orchestrator')
      end

      table.insert(summaries, {
        name = call.name,
        summary = summary,
      })
      remaining = remaining - 1

      logger.debug(
        'Call graph progress: ' .. resolved_count .. '/' .. total .. ' completed',
        'orchestrator'
      )

      if remaining == 0 then
        logger.info(
          'Call graph expansion completed, resolved ' .. resolved_count .. ' functions',
          'orchestrator'
        )
        on_complete(summaries)
      end
    end)
  end
end

return M
