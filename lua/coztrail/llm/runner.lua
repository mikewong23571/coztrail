--[[
* runner.lua
* 负责与LLM交互，生成函数总结
* 构建提示并调用外部Python脚本处理LLM请求
]]

local logger = require('coztrail.core.logger')
local template = require('coztrail.llm.template')

local M = {}

--[[
* create_safe_callback函数
* 创建一个安全的回调包装器，确保回调只被调用一次
* @param callback 原始回调函数
* @param context 可选的上下文信息
* @return 包装后的安全回调函数
]]
function M.create_safe_callback(callback)
  local called = false
  return function(success, error_code, error_message, content)
    if not called then
      called = true
      callback({
        success = success, -- 布尔值，表示是否成功
        error_code = error_code, -- 错误码，成功时为 nil
        error_message = error_message, -- 错误信息，成功时为 nil
        content = content, -- 摘要内容，失败时为 nil
      })
    end
  end
end

--[[
* create_temp_file函数
* 创建临时文件并写入内容
* @param content 要写入的内容
* @return 成功时返回临时文件路径，失败时返回nil和错误信息
]]
function M.create_temp_file(content)
  local tmpfile = os.tmpname()
  logger.debug('Created temporary file: ' .. tmpfile, 'runner')

  local write_success = pcall(vim.fn.writefile, { content }, tmpfile)
  if not write_success then
    logger.error('Failed to write to temporary file: ' .. tmpfile, 'runner')
    return nil, 'Failed to write prompt to file'
  end

  return tmpfile
end

--[[
* get_binary_path函数
* 获取LLM二进制文件的路径
* @return 成功时返回二进制文件路径，失败时返回nil和错误信息
]]
function M.get_binary_path()
  local source = debug.getinfo(1).source:sub(2)
  local base_path = source:match('(.*/)') or source:match('(.*)\\')

  if not base_path then
    base_path = ''
  end

  local binary_name = 'summary'
  if vim.fn.has('win32') == 1 or vim.fn.has('win64') == 1 then
    binary_name = 'summary.exe'
  end

  local binary_path = base_path .. binary_name
  logger.debug('Using LLM binary: ' .. binary_path, 'runner')

  if vim.fn.executable(binary_path) == 0 then
    logger.error('LLM binary not found or not executable: ' .. binary_path, 'runner')
    vim.notify(
      '[LLM Error] ' .. binary_name .. ' not found at ' .. binary_path,
      vim.log.levels.ERROR
    )
    return nil, 'LLM binary not found. Please compile the Go program first.'
  end

  return binary_path
end

--[[
* execute_llm_process函数
* 执行LLM进程并处理结果
* @param binary_path 二进制文件路径
* @param input_file 输入文件路径
* @param func_name 函数名称（用于日志）
* @param safe_callback 安全回调函数
]]
function M.execute_llm_process(binary_path, input_file, func_name, safe_callback)
  logger.info('Starting LLM process for function: ' .. func_name, 'runner')

  local job_id = vim.fn.jobstart({ binary_path, input_file }, {
    stdout_buffered = true,
    on_stdout = function(_, data)
      if data and #data > 0 then
        logger.info('LLM process completed successfully for function: ' .. func_name, 'runner')
        logger.debug(
          'LLM output length: ' .. string.len(table.concat(data, '\n')) .. ' characters',
          'runner'
        )
        safe_callback(true, nil, nil, table.concat(data, '\n'))
      else
        logger.warn('LLM process returned empty output for function: ' .. func_name, 'runner')
        safe_callback(false, 'EMPTY_OUTPUT', 'No summary generated.', nil)
      end
    end,
    on_stderr = function(_, data)
      if data and #data > 0 and #data[1] > 0 then
        local error_msg = table.concat(data, '\n')
        logger.error('LLM process stderr for function ' .. func_name .. ': ' .. error_msg, 'runner')
        vim.notify('[LLM Error] ' .. error_msg, vim.log.levels.ERROR)
        safe_callback(false, 'STDERR_ERROR', error_msg, nil)
      end
    end,
    on_exit = function(_, code)
      logger.debug('Cleaning up temporary file: ' .. input_file, 'runner')
      os.remove(input_file)
      if code ~= 0 then
        logger.error(
          'LLM process exited with non-zero code ' .. code .. ' for function: ' .. func_name,
          'runner'
        )
        safe_callback(false, 'EXIT_CODE_' .. code, 'LLM process exited with code ' .. code, nil)
      else
        logger.debug('LLM process exited successfully for function: ' .. func_name, 'runner')
      end
    end,
  })

  if job_id <= 0 then
    logger.error('Failed to start LLM process for function: ' .. func_name, 'runner')
    safe_callback(false, 'JOB_START_ERROR', 'Failed to start LLM process', nil)
    return false
  end

  logger.debug(
    'LLM process started with job ID: ' .. job_id .. ' for function: ' .. func_name,
    'runner'
  )
  return true
end

--[[  
* summarize函数
* 调用LLM总结函数功能
* @param func_name 函数名称
* @param func_text 函数文本内容
* @param structure 函数结构信息
* @param callee_summaries 被调用函数的摘要
* @param callback 回调函数，处理总结结果，接收以下参数：
*   - 参数为一个表，包含以下字段：
*     - success: boolean - 操作是否成功
*     - error_code: string|nil - 错误代码，成功时为nil，可能的值包括：
*       - "WRITE_ERROR" - 写入临时文件失败
*       - "BINARY_NOT_FOUND" - 找不到LLM二进制文件
*       - "EMPTY_OUTPUT" - LLM输出为空
*       - "STDERR_ERROR" - LLM进程输出错误信息
*       - "EXIT_CODE_X" - LLM进程以非零退出码X退出
*       - "JOB_START_ERROR" - 启动LLM进程失败
*     - error_message: string|nil - 错误信息，成功时为nil
*     - content: string|nil - 摘要内容，失败时为nil
]]
function M.summarize(func_name, func_text, structure, callee_summaries, callback)
  logger.info('Starting LLM summarization for function: ' .. func_name, 'runner')

  -- 创建安全回调
  local safe_callback = M.create_safe_callback(callback)

  -- 渲染提示模板
  logger.debug('Rendering user prompt template', 'runner')
  local user_prompt = template.render_user_prompt(func_name, func_text, structure, callee_summaries)

  -- 创建临时文件
  local tmpfile, err = M.create_temp_file(user_prompt)
  if not tmpfile then
    safe_callback(false, 'WRITE_ERROR', err, nil)
    return
  end

  -- 获取二进制路径
  local binary_path, bin_err = M.get_binary_path()
  if not binary_path then
    safe_callback(false, 'BINARY_NOT_FOUND', bin_err, nil)
    return
  end

  -- 执行LLM进程
  M.execute_llm_process(binary_path, tmpfile, func_name, safe_callback)
end

return M
