local M = {}
local logger = require('coztrail.core.logger')

local cache_dir = vim.fn.stdpath('cache') .. '/coztrail_fs'
vim.fn.mkdir(cache_dir, 'p')

local function sanitize_path(path)
  return path:gsub('[/:]', '|')
end

local function get_range(node)
  if not node or type(node.range) ~= 'function' then
    logger.error('Invalid node passed to get_range', 'fs')
    return nil, nil
  end

  local s, _, e, _ = node:range()
  return s and (s + 1) or nil, e and (e + 1) or nil
end

-- 修改 save_summary 函数
function M.save_summary(bufnr, node, text)
  if not node or type(text) ~= 'string' then
    logger.warn('Invalid parameters: node or text is nil or malformed', 'fs')
    return {
      success = false,
      error_code = 'INVALID_PARAMS',
      error_message = 'Invalid parameters: node or text is nil or malformed',
    }
  end

  local file = vim.api.nvim_buf_get_name(bufnr)
  if not file or file == '' then
    logger.warn('No file name found', 'fs')
    return false
  end

  local s, e = get_range(node)
  if not s or not e then
    logger.warn('Cannot determine range', 'fs')
    return false
  end

  local key = sanitize_path(file) .. ':' .. s .. ':' .. e .. '.txt'
  local path = cache_dir .. '/' .. key

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

-- 修改 get_summary 函数
function M.get_summary(bufnr, node)
  if not node then
    logger.warn('Invalid node passed to get_summary', 'fs')
    return {
      success = false,
      error_code = 'INVALID_PARAMS',
      error_message = 'Invalid node passed to get_summary',
    }
  end

  local file = vim.api.nvim_buf_get_name(bufnr)
  if not file or file == '' then
    return nil
  end

  local s, e = get_range(node)
  if not s or not e then
    return nil
  end

  local key = sanitize_path(file) .. ':' .. s .. ':' .. e .. '.txt'
  local path = cache_dir .. '/' .. key

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
