local M = {}

local source = {}

source.new = function()
  return setmetatable({}, { __index = source })
end

function source:complete(callback)

  local handle = io.popen('python /home/jordan/brain/neurogenesis/neurogenesis.py get_nodes')
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
      data = { id = node_item.id}
    })
  end
  callback({items})
end

function source:get_trigger_characters()
  return {"@"}
end

function source:execute(completion_item, callback)
  -- replace completion item with [<cursor in insert>](id.md)
  vim.cmd [[lua print('Success')]]
  callback(completion_item)

end

function M.setup()
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
