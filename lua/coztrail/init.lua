local M = {}

-- 默认配置
local default_config = {
  log_level = 'INFO',
  log_to_file = true,
  log_to_console = true,
  -- 其他默认配置项
}

-- 用户配置
M.config = {}

-- 移除对 command.setup() 的调用
function M.setup(opts)
  -- 合并用户配置和默认配置
  opts = opts or {}
  M.config = vim.tbl_deep_extend('force', default_config, opts)

  -- 标记已经初始化
  vim.g.coztrail_setup_done = 1

  -- 初始化日志模块
  local logger = require('coztrail.core.logger')

  -- 使用合并后的配置
  logger.set_level(M.config.log_level)
  logger.set_file_enabled(M.config.log_to_file)
  logger.set_console_enabled(M.config.log_to_console)

  -- 记录插件启动日志
  logger.info('Coztrail plugin initialized', 'init')
  logger.debug('Configuration: ' .. vim.inspect(M.config), 'init')

  -- 移除这一行，避免重复注册命令
  -- require('coztrail.core.command').setup()

  -- 其他初始化逻辑

  logger.info('Coztrail setup completed', 'init')
end

return M
