--[[
* template.lua
* 负责加载和渲染prompt模板
]]

local M = {}

-- 简单的模板渲染函数
local function render_template(template, data)
  local result = template
  
  -- 替换简单变量 {{VAR}}
  for key, value in pairs(data) do
    if type(value) == "string" then
      result = result:gsub("{{" .. key .. "}}", value)
    end
  end
  
  -- 处理条件块 {{#if VAR}}
  result = result:gsub("{{#if ([^}]+)}}(.-){{/if}}", function(var, content)
    if data[var] and #data[var] > 0 then
      return content
    else
      return ""
    end
  end)
  
  -- 处理循环块 {{#each VAR}}
  result = result:gsub("{{#each ([^}]+)}}(.-){{/each}}", function(var, content)
    if data[var] and #data[var] > 0 then
      local items = {}
      for _, item in ipairs(data[var]) do
        local item_content = content
        for k, v in pairs(item) do
          item_content = item_content:gsub("{{" .. k .. "}}", tostring(v))
        end
        table.insert(items, item_content)
      end
      return table.concat(items, "")
    else
      return ""
    end
  end)
  
  return result
end

-- 加载模板文件
function M.load_template(template_name)
  local source = debug.getinfo(1).source:sub(2)
  local base_path = source:match("(.*/)")
  if not base_path then
    base_path = source:match("(.*)/")
    if not base_path then
      base_path = ""
    else
      base_path = base_path .. "/"
    end
  end
  
  local template_path = base_path .. "templates/" .. template_name .. ".txt"
  local file = io.open(template_path, "r")
  if not file then
    error("Template file not found: " .. template_path)
  end
  
  local content = file:read("*all")
  file:close()
  return content
end

-- 渲染用户prompt
function M.render_user_prompt(func_name, func_text, structure, callee_summaries)
  local template = M.load_template("user_prompt")
  
  local data = {
    FUNCTION_NAME = func_name,
    FUNCTION_TEXT = func_text,
    FUNCTION_CALLS = structure.calls or {},
    GLOBAL_VARIABLES = structure.globals or {},
    CALLEE_SUMMARIES = callee_summaries or {}
  }
  
  return render_template(template, data)
end

-- 获取系统prompt
function M.get_system_prompt()
  return M.load_template("system_prompt")
end

return M