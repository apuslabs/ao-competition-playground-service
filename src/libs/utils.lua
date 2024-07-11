local Utils = {}

-- concat rest args with first arg
function Utils.concat(...)
  local sep = select(1, ...)
  local t = {}
  for i = 2, select("#", ...) do
    local v = select(i, ...)
    if v ~= nil then
      table.insert(t, v)
    end
  end
  return table.concat(t, sep)
end

return Utils