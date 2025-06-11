--[[
* command.lua
* 负责注册Neovim命令，提供用户界面入口
* 该模块提供CozTrail命令及其子命令的实现
]]

local M = {}

-- 命令补全函数
function M.command_complete(ArgLead, CmdLine, CursorPos)
  local subcommands = {"analyze", "setup", "clear", "config", "help"}
  local matches = {}
  
  for _, cmd in ipairs(subcommands) do
    if cmd:find(ArgLead, 1, true) == 1 then
      table.insert(matches, cmd)
    end
  end
  
  return matches
end

-- 命令执行函数
function M.execute_command(opts)
  local args = opts.fargs
  local subcmd = args[1] or "analyze" -- 默认子命令
  
  -- 惰性加载处理函数
  if subcmd == "analyze" then
    -- 只有在需要时才加载 orchestrator 模块
    require("coztrail.core.orchestrator").run()
  elseif subcmd == "setup" then
    -- 只有在需要时才加载 init 模块
    table.remove(args, 1) -- 移除子命令
    require('coztrail').setup(args[1] or {})
    vim.notify("CozTrail: 配置已更新", vim.log.levels.INFO)
  elseif subcmd == "clear" then
    -- 只有在需要时才加载 db 模块
    local db = require("coztrail.storage.db")
    if db.clear_cache then
      db.clear_cache()
      vim.notify("CozTrail: 缓存已清除", vim.log.levels.INFO)
    else
      vim.notify("CozTrail: 清除缓存功能未实现", vim.log.levels.WARN)
    end
  elseif subcmd == "config" then
    -- 只有在需要时才加载 init 模块
    local config_module = require("coztrail")
    vim.notify("当前配置:\n" .. vim.inspect(config_module.config), vim.log.levels.INFO)
  elseif subcmd == "help" then
    -- 帮助信息不需要加载任何模块
    print("CozTrail 命令帮助:")
    print("  :CozTrail analyze - 分析当前光标所在函数 (默认)")
    print("  :CozTrail setup   - 重新设置插件配置")
    print("  :CozTrail clear   - 清除函数分析缓存")
    print("  :CozTrail config  - 显示当前配置")
    print("  :CozTrail help    - 显示此帮助信息")
  else
    -- 未知子命令
    vim.notify("未知的子命令: " .. subcmd .. "\n使用 :CozTrail help 查看可用命令", vim.log.levels.ERROR)
  end
end

-- 导出模块
return M