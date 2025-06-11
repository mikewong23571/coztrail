--[[
* logger.lua
* 日志模块，提供统一的日志记录功能
* 支持多级别日志、文件输出、性能监控等功能
]]

local M = {}

-- 日志级别定义
M.levels = {
  TRACE = 1,
  DEBUG = 2,
  INFO = 3,
  WARN = 4,
  ERROR = 5,
  OFF = 6
}

-- 日志级别名称
local level_names = {
  [M.levels.TRACE] = "TRACE",
  [M.levels.DEBUG] = "DEBUG",
  [M.levels.INFO] = "INFO",
  [M.levels.WARN] = "WARN",
  [M.levels.ERROR] = "ERROR"
}

-- 默认配置
M.config = {
  level = M.levels.INFO,
  file_enabled = true,
  console_enabled = true,
  log_dir = vim.fn.stdpath("data") .. "/coztrail",
  log_file = "coztrail.log",
  max_file_size = 5 * 1024 * 1024, -- 5MB
  max_backup_files = 3,
  date_format = "%Y-%m-%d %H:%M:%S",
  include_location = true
}

-- 内部状态
local log_file_handle = nil
local current_log_size = 0

--[[
* 初始化日志系统
]]
local function init_logger()
  if M.config.file_enabled then
    -- 创建日志目录
    vim.fn.mkdir(M.config.log_dir, "p")
    
    -- 获取当前日志文件大小
    local log_path = M.config.log_dir .. "/" .. M.config.log_file
    local stat = vim.loop.fs_stat(log_path)
    if stat then
      current_log_size = stat.size
    end
  end
end

--[[
* 日志轮转
]]
local function rotate_log_if_needed()
  if current_log_size > M.config.max_file_size then
    if log_file_handle then
      log_file_handle:close()
      log_file_handle = nil
    end
    
    local log_path = M.config.log_dir .. "/" .. M.config.log_file
    
    -- 轮转备份文件
    for i = M.config.max_backup_files, 1, -1 do
      local old_file = log_path .. "." .. i
      local new_file = log_path .. "." .. (i + 1)
      if vim.loop.fs_stat(old_file) then
        if i == M.config.max_backup_files then
          os.remove(old_file)
        else
          os.rename(old_file, new_file)
        end
      end
    end
    
    -- 移动当前日志文件
    if vim.loop.fs_stat(log_path) then
      os.rename(log_path, log_path .. ".1")
    end
    
    current_log_size = 0
  end
end

--[[
* 获取调用位置信息
]]
local function get_caller_info()
  if not M.config.include_location then
    return ""
  end
  
  local info = debug.getinfo(4, "Sl")
  if info and info.source and info.currentline then
    local source = info.source:match("@?(.+)$") or info.source
    local filename = vim.fn.fnamemodify(source, ":t")
    return string.format(" [%s:%d]", filename, info.currentline)
  end
  return ""
end

--[[
* 格式化日志消息
]]
local function format_message(level, message, module)
  local timestamp = os.date(M.config.date_format)
  local level_name = level_names[level] or "UNKNOWN"
  local location = get_caller_info()
  local module_part = module and ("[" .. module .. "] ") or ""
  
  return string.format("[%s] %s %s%s%s",
    timestamp, level_name, module_part, message, location)
end

--[[
* 写入日志到文件
]]
local function write_to_file(formatted_message)
  if not M.config.file_enabled then
    return
  end
  
  rotate_log_if_needed()
  
  if not log_file_handle then
    local log_path = M.config.log_dir .. "/" .. M.config.log_file
    log_file_handle = io.open(log_path, "a")
    if not log_file_handle then
      vim.notify("Failed to open log file: " .. log_path, vim.log.levels.ERROR)
      return
    end
  end
  
  local log_line = formatted_message .. "\n"
  log_file_handle:write(log_line)
  log_file_handle:flush()
  current_log_size = current_log_size + #log_line
end

--[[
* 写入日志到控制台
]]
local function write_to_console(level, message)
  if not M.config.console_enabled then
    return
  end
  
  local vim_level = vim.log.levels.INFO
  if level >= M.levels.ERROR then
    vim_level = vim.log.levels.ERROR
  elseif level >= M.levels.WARN then
    vim_level = vim.log.levels.WARN
  elseif level >= M.levels.INFO then
    vim_level = vim.log.levels.INFO
  end
  
  vim.notify("[coztrail] " .. message, vim_level)
end

--[[
* 核心日志函数
]]
local function log(level, message, module)
  if level < M.config.level then
    return
  end
  
  local formatted = format_message(level, message, module)
  
  write_to_file(formatted)
  
  -- 只有重要消息才显示在控制台
  if level >= M.levels.WARN then
    write_to_console(level, message)
  end
end

-- 公共接口
function M.trace(message, module)
  log(M.levels.TRACE, message, module)
end

function M.debug(message, module)
  log(M.levels.DEBUG, message, module)
end

function M.info(message, module)
  log(M.levels.INFO, message, module)
end

function M.warn(message, module)
  log(M.levels.WARN, message, module)
end

function M.error(message, module)
  log(M.levels.ERROR, message, module)
end

--[[
* 性能监控辅助函数
]]
function M.time_start(operation)
  return vim.loop.hrtime()
end

function M.time_end(start_time, operation, module)
  local duration = (vim.loop.hrtime() - start_time) / 1000000 -- 转换为毫秒
  M.debug(string.format("%s completed in %.2fms", operation, duration), module)
  return duration
end

--[[
* 函数执行包装器
]]
function M.wrap_function(func, func_name, module)
  return function(...)
    local start_time = M.time_start()
    M.trace("Starting " .. func_name, module)
    
    local success, result = pcall(func, ...)
    
    if success then
      M.time_end(start_time, func_name, module)
      return result
    else
      M.error(string.format("%s failed: %s", func_name, result), module)
      error(result)
    end
  end
end

--[[
* 配置更新
]]
function M.set_level(level)
  M.config.level = level
  M.info("Log level set to " .. (level_names[level] or "UNKNOWN"))
end

function M.set_file_enabled(enabled)
  M.config.file_enabled = enabled
  if not enabled and log_file_handle then
    log_file_handle:close()
    log_file_handle = nil
  end
end

function M.set_console_enabled(enabled)
  M.config.console_enabled = enabled
end

--[[
* 清理资源
]]
function M.cleanup()
  if log_file_handle then
    log_file_handle:close()
    log_file_handle = nil
  end
end

-- 初始化
init_logger()

-- 注册清理函数
vim.api.nvim_create_autocmd("VimLeavePre", {
  callback = M.cleanup,
  desc = "Cleanup coztrail logger"
})

return M