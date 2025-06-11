-- astview_template.lua
local parsers = require("nvim-treesitter.parsers")
local ts_utils = require("nvim-treesitter.ts_utils")
local logger = require("coztrail.core.logger")

-- 参数由 shell 替换
local filename = "${FILENAME}"
local row = ${ROW}
local col = ${COL}
local up_n = ${UP}
local output_path = "${OUTFILE}"

logger.debug("Running AST viewer on file: " .. filename, "astview")

vim.cmd("edit " .. vim.fn.fnameescape(filename))
local bufnr = vim.api.nvim_get_current_buf()

-- 尝试获取 parser
local parser = parsers.get_parser(bufnr)
if not parser then
  local msg = "Failed to get parser for buffer: " .. filename
  logger.error(msg, "astview")
  vim.api.nvim_err_writeln(msg)
  return
end

local tree = parser:parse()[1]
if not tree then
  local msg = "Failed to parse tree for buffer: " .. filename
  logger.error(msg, "astview")
  vim.api.nvim_err_writeln(msg)
  return
end

local root = tree:root()

local node = vim.treesitter.get_node({
  bufnr = bufnr,
  pos = { row, col },
})

if not node then
  local msg = string.format("No node found at position (line: %d, col: %d)", row + 1, col + 1)
  logger.warn(msg, "astview")
  vim.api.nvim_err_writeln(msg)
  return
end

logger.info(string.format("Found node type: %s at (%d, %d)", node:type(), row + 1, col + 1), "astview")

-- 向上追溯 N 层
for i = 1, up_n do
  if node:parent() then
    node = node:parent()
  else
    logger.warn(string.format("Parent not found at depth %d, staying at current node", i), "astview")
    break
  end
end

-- 递归打印 AST 子树
local function write_node_tree(n, indent, lines)
  indent = indent or ""
  table.insert(lines, indent .. n:type())
  for child in n:iter_children() do
    write_node_tree(child, indent .. "  ", lines)
  end
end

local lines = {}
table.insert(lines, string.format("AST from node: '%s' at (%d, %d)", node:type(), row + 1, col + 1))
write_node_tree(node, "", lines)

-- 写入结果文件
vim.fn.writefile(lines, output_path)
logger.debug("AST output written to: " .. output_path, "astview")
