local M = {}
local logger = require('coztrail.core.logger')

local cache_dir = vim.fn.stdpath('cache') .. '/coztrail_fs'
vim.fn.mkdir(cache_dir, 'p')

local function sanitize_path(path)
  return path:gsub('[/:]', '|')
end

-- 基于文件路径和位置的缓存键生成函数
local function get_cache_key_by_position(file_path, start_line, end_line)
  if not file_path or not start_line or not end_line then
    logger.error('Invalid parameters for get_cache_key_by_position', 'fs')
    return nil, nil
  end

  local key = sanitize_path(file_path) .. ':' .. start_line .. ':' .. end_line .. '.txt'
  local path = cache_dir .. '/' .. key

  return key, path
end

-- 基于位置的保存函数
function M.save_summary_by_position(file_path, start_line, end_line, text)
  if not file_path or not start_line or not end_line or type(text) ~= 'string' then
    logger.warn('Invalid parameters for save_summary_by_position', 'fs')
    return {
      success = false,
      error_code = 'INVALID_PARAMS',
      error_message = 'Invalid parameters: file_path, start_line, end_line or text is invalid',
    }
  end

  local _, path = get_cache_key_by_position(file_path, start_line, end_line)
  if not path then
    logger.warn('Cannot determine cache path', 'fs')
    return {
      success = false,
      error_code = 'INVALID_PATH',
      error_message = 'Cannot determine cache path',
    }
  end

  local fd, err = io.open(path, 'w')
  if not fd then
    logger.error('Failed to open file for writing: ' .. tostring(err), 'fs')
    return {
      success = false,
      error_code = 'WRITE_ERROR',
      error_message = 'Failed to open file for writing: ' .. tostring(err),
    }
  end

  fd:write(text)
  fd:close()
  logger.info('Summary saved to ' .. path, 'fs')
  return {
    success = true,
    content = text,
  }
end

-- 基于位置的获取函数
function M.get_summary_by_position(file_path, start_line, end_line)
  if not file_path or not start_line or not end_line then
    logger.warn('Invalid parameters for get_summary_by_position', 'fs')
    return {
      success = false,
      error_code = 'INVALID_PARAMS',
      error_message = 'Invalid parameters: file_path, start_line or end_line is invalid',
    }
  end

  local _, path = get_cache_key_by_position(file_path, start_line, end_line)
  if not path then
    return {
      success = false,
      error_code = 'INVALID_PATH',
      error_message = 'Cannot determine cache path',
    }
  end

  local fd, err = io.open(path, 'r')
  if not fd then
    logger.debug('Cache miss: ' .. path .. ' not found', 'fs')
    return {
      success = false,
      error_code = 'FILE_NOT_FOUND',
      error_message = 'Cache miss: file not found',
    }
  end

  local content = fd:read('*a')
  fd:close()
  return {
    success = true,
    content = content,
  }
end

return M
