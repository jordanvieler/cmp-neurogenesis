local M = {}

local source = {}
local trigger_char
local brain_path

source.new = function()
  return setmetatable({}, { __index = source })
end

function source:complete(request, callback)

  local cursor_before_line = request.context.cursor_before_line
  -- getting request offset for computing input string and prefix string
  local offset_idx = request.offset - 1
  -- line[@,end]
  local input = string.sub(cursor_before_line, offset_idx)
  -- line [start,@)
  local prefix = string.sub(cursor_before_line, 1, offset_idx)
  local current_line = request.context.cursor.row - 1
  local current_char = request.context.cursor.col - 1

  if vim.startswith(input, trigger_char) and (prefix == trigger_char or vim.endswith(prefix, ' '..trigger_char)) then
    local handle = io.popen('python '..brain_path..'/neurogenesis/neurogenesis.py get_nodes')
    if handle == nil then
      return
    end
    local content = handle:read('*all')
    local status_ok, parsed = pcall(vim.json.decode, content)
    if not status_ok then
      return
    end

    local items = {}
    for _, node_item in ipairs(parsed) do
      table.insert(items, {
        label = node_item.title,
        documentation = { kind = "markdown", value = node_item.id},
        -- data payload with completion item
        -- add range where we remove the at and replace with [<cursor>](id.md)
        textEdit = {
          newText = '[$0]('..node_item.id..'.md)',
          range = {
            start = {
              line = current_line,
              character = current_char - #input --start completion right before trigger_char
            },
            -- weird way to say table key 'end' because end is a keyword in lua
            ['end'] = {
              line = current_line,
              character = current_char
            }
          }
        },
        kind = 15, --set completion type to snippet
        insertTextFormat = 2 --set insert text to snippet format
      })
    end
    vim.notify(vim.inspect(items))
    callback({items=items, isIncomplete=false})
  else
    -- if topcheck fails. Don't get and return any nodes for completion
    callback({isIncomplete=false})
  end

end

function source:get_trigger_characters()
  return {trigger_char}
end

function source:is_available()
  -- brain = '/home/jordan/brain'
  -- current = '/home/jordan/brain/markdown.md'
  -- is brain_path in current. is everything after brain /*.md
  -- split prefix_path = /home/jordan/brain
  -- suffix path = /markdown.md
  -- prefix_path == brain
  -- suffix path == pattern /*.md
  -- and filetype is markdown
  local current_path = vim.fn.expand('%:p') --expand % register to the absolute path
  local split_idx = #brain_path
  local prefix = string.sub(current_path, 1, split_idx)
  -- might want to pattern match the suffix to a particular dir in the brain
  -- local suffix = string.sub(current_path, split_idx+1) 

  return vim.bo.filetype == 'markdown' and prefix == brain_path
end

function source:execute(completion_item, callback)
  -- replace completion item with [<cursor in insert>](id.md)
  callback(completion_item)
end

function M.setup(opts)
  trigger_char = opts.trigger_char
  brain_path = opts.brain_path
  local status_ok, cmp = pcall(require, 'cmp')
  if not status_ok then
    vim.notify('failed to load cmp!')
    return
  end
  if cmp==nil then
    return
  end
  cmp.register_source('neurogenesis', source.new())
end

return M
