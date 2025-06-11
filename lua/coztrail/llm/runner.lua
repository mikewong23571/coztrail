--[[
* runner.lua
* 负责与LLM交互，生成函数总结
* 构建提示并调用外部Python脚本处理LLM请求
]]

local logger = require("coztrail.core.logger")
local template = require('coztrail.llm.template')

local M = {}

--[[
* summarize函数
* 调用LLM总结函数功能
* @param func_name 函数名称
* @param func_text 函数文本内容
* @param structure 函数结构信息
* @param callback 回调函数，处理总结结果
]]
function M.summarize(func_name, func_text, structure, callee_summaries, callback)
  logger.info("Starting LLM summarization for function: " .. func_name, "runner")
  local called = false
  local safe_callback = function(success, error_code, error_message, content)
    if not called then
      called = true
      callback({
        success = success,       -- 布尔值，表示是否成功
        error_code = error_code, -- 错误码，成功时为 nil
        error_message = error_message, -- 错误信息，成功时为 nil
        content = content       -- 摘要内容，失败时为 nil
      })
    end
  end
  
  -- 使用模板渲染prompt
  logger.debug("Rendering user prompt template", "runner")
  local user_prompt = template.render_user_prompt(func_name, func_text, structure, callee_summaries)
  local tmpfile = os.tmpname()
  logger.debug("Created temporary file: " .. tmpfile, "runner")
  
  local write_success = pcall(vim.fn.writefile, { user_prompt }, tmpfile)
  if not write_success then
    logger.error("Failed to write prompt to temporary file: " .. tmpfile, "runner")
    safe_callback(false, "WRITE_ERROR", "Failed to write prompt to file", nil)
    return
  end

  local source = debug.getinfo(1).source:sub(2)
  local base_path = source:match("(.*/)")
  
  if not base_path then
    base_path = source:match("(.*)\\")
    if not base_path then
      base_path = ""
    else
      base_path = base_path .. "\\"
    end
  end
  
  local binary_name = "summary"
  if vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1 then
    binary_name = "summary.exe"
  end
  
  local binary_path = base_path .. binary_name
  logger.debug("Using LLM binary: " .. binary_path, "runner")
  
  if vim.fn.executable(binary_path) == 0 then
    logger.error("LLM binary not found or not executable: " .. binary_path, "runner")
    vim.notify("[LLM Error] " .. binary_name .. " not found at " .. binary_path, vim.log.levels.ERROR)
    safe_callback(false, "BINARY_NOT_FOUND", "LLM binary not found. Please compile the Go program first.", nil)
    return
  end

  logger.info("Starting LLM process for function: " .. func_name, "runner")
  local job_id = vim.fn.jobstart({ binary_path, tmpfile }, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      if data and #data > 0 then
        logger.info("LLM process completed successfully for function: " .. func_name, "runner")
        logger.debug("LLM output length: " .. string.len(table.concat(data, "\n")) .. " characters", "runner")
        safe_callback(true, nil, nil, table.concat(data, "\n"))
      else
        logger.warn("LLM process returned empty output for function: " .. func_name, "runner")
        safe_callback(false, "EMPTY_OUTPUT", "No summary generated.", nil)
      end
    end,
    on_stderr = function(_, data)
      if data and #data > 0 and #data[1] > 0 then
        local error_msg = table.concat(data, "\n")
        logger.error("LLM process stderr for function " .. func_name .. ": " .. error_msg, "runner")
        vim.notify("[LLM Error] " .. error_msg, vim.log.levels.ERROR)
        safe_callback(false, "STDERR_ERROR", error_msg, nil)
      end
    end,
    on_exit = function(_, code)
      logger.debug("Cleaning up temporary file: " .. tmpfile, "runner")
      os.remove(tmpfile)
      if code ~= 0 then
        logger.error("LLM process exited with non-zero code " .. code .. " for function: " .. func_name, "runner")
        safe_callback(false, "EXIT_CODE_" .. code, "LLM process exited with code " .. code, nil)
      else
        logger.debug("LLM process exited successfully for function: " .. func_name, "runner")
      end
    end
  })
  
  if job_id <= 0 then
    logger.error("Failed to start LLM process for function: " .. func_name, "runner")
    safe_callback(false, "JOB_START_ERROR", "Failed to start LLM process", nil)
  else
    logger.debug("LLM process started with job ID: " .. job_id .. " for function: " .. func_name, "runner")
  end
end

return M