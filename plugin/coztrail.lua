-- 防止重复加载
if vim.g.loaded_coztrail == 1 then
  return
end
vim.g.loaded_coztrail = 1

-- 检查用户是否已经设置了配置
if vim.g.coztrail_setup_done ~= 1 then
  -- 用户没有自定义配置，使用默认配置初始化
  require('coztrail').setup({})
end

-- 直接注册命令，而不是加载整个命令模块
vim.api.nvim_create_user_command("CozTrail", function(opts)
  -- 惰性加载命令处理模块
  require('coztrail.core.command').execute_command(opts)
end, {
  nargs = "*",
  desc = "代码分析工具",
  complete = function(ArgLead, CmdLine, CursorPos)
    -- 惰性加载补全模块
    return require('coztrail.core.command').command_complete(ArgLead, CmdLine, CursorPos)
  end
})