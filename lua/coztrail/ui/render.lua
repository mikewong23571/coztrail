--[[
* render.lua
* 负责UI渲染，显示函数总结结果
* 当前实现简单地使用echo显示，可以扩展为更丰富的UI
]]

local logger = require("coztrail.core.logger")

local M = {}

-- 辅助函数：将可能包含换行符的字符串拆分成多行
local function split_lines(text)
  if not text then return {} end
  local result = {}
  for line in (text.."\n"):gmatch("([^\n]*)\n") do
    table.insert(result, line)
  end
  return result
end

--[[
* show_summary函数
* 显示函数总结和调用图信息
* @param summary 函数总结文本
* @param callee_summaries 被调用函数的总结信息（可选）
]]
function M.show_summary(summary, callee_summaries)
  logger.info("Displaying function summary in UI", "render")
  
  -- 创建浮动窗口显示结果
  local buf = vim.api.nvim_create_buf(false, true)
  if not buf then
    logger.error("Failed to create buffer for summary display", "render")
    return
  end
  
  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.8)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  
  logger.debug("Creating floating window: " .. width .. "x" .. height .. " at (" .. row .. "," .. col .. ")", "render")
  
  local lines = {"# 函数总结", ""}
  
  -- 处理主函数摘要，确保它是字符串
  local summary_content = ""
  if type(summary) == "table" and summary.content then
    summary_content = summary.content
  else
    summary_content = tostring(summary)
  end
  
  -- 将可能包含换行符的内容拆分成多行
  local summary_lines = split_lines(summary_content)
  for _, line in ipairs(summary_lines) do
    table.insert(lines, line)
  end
  
  -- 添加调用图信息（如果有）
  if callee_summaries and #callee_summaries > 0 then
    logger.debug("Adding " .. #callee_summaries .. " callee summaries to display", "render")
    table.insert(lines, "")
    table.insert(lines, "# 调用图")
    table.insert(lines, "")
    
    for _, callee in ipairs(callee_summaries) do
      table.insert(lines, "## " .. callee.name)
      if callee.summary.error then
        logger.debug("Callee " .. callee.name .. " has error: " .. callee.summary.error, "render")
        table.insert(lines, "*无法解析函数定义*")
      else
        -- 确保我们使用字符串内容而不是整个对象
        local callee_content = ""
        if type(callee.summary) == "table" and callee.summary.content then
          callee_content = callee.summary.content
        else
          callee_content = tostring(callee.summary)
        end
        
        -- 将可能包含换行符的内容拆分成多行
        local callee_lines = split_lines(callee_content)
        for _, line in ipairs(callee_lines) do
          table.insert(lines, line)
        end
      end
      table.insert(lines, "")
    end
  end
  
  -- 添加详细日志记录，检查lines中的每一项
  logger.info("Total lines to set: " .. #lines, "render")
  for i, line in ipairs(lines) do
    if type(line) ~= "string" then
      logger.error("Line " .. i .. " is not a string but " .. type(line), "render")
    elseif line:find("\n") then
      logger.error("Line " .. i .. " contains newline character: '" .. line:gsub("\n", "<newline>") .. "'", "render")
    elseif #line > 100 then
      logger.info("Line " .. i .. " (truncated): '" .. line:sub(1, 100) .. "...'", "render")
    else
      logger.info("Line " .. i .. ": '" .. line .. "'", "render")
    end
  end
  
  -- 使用pcall来捕获可能的错误
  local success, err = pcall(function()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  end)
  
  if not success then
    logger.error("Failed to set buffer lines: " .. tostring(err), "render")
    return
  end
  
  -- 设置缓冲区选项
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  vim.api.nvim_buf_set_option(buf, "filetype", "markdown")
  
  -- 创建浮动窗口
  local opts = {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded"
  }
  
  local win = vim.api.nvim_open_win(buf, true, opts)
  if win then
    logger.info("Successfully displayed summary in floating window", "render")
  else
    logger.error("Failed to create floating window", "render")
  end
end

return M