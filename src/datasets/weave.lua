local json = require('json')

local weave = {}

function weave.getBlock(height)
  local block = io.open("/block/" .. height)
  if not block then
    return nil, "Block Header not found!"
  end
  local headers = json.decode(
    block:read(
      block:seek('end')
    )
  )
  block:close()
  return headers
end

function weave.getTx(txId)
  local file = io.open('/tx/' .. txId)
  if not file then
    return nil, "File not found!"
  end
  local contents = json.decode(
    file:read(
      file:seek('end')
    )
  )
  file:close()
  return contents
end

function weave.getData(txId)
  local file = io.open('/data/' .. txId)
  if not file then
    return nil, "File not found!"
  end
  local contents = file:read(
    file:seek('end')
  )
  file:close()
  return contents
end

function weave.getJsonData(txId)
  local file = io.open('/data/' .. txId)
  if not file then
    return nil, "File not found!"
  end
  local contents = json.decode(
    file:read(
      file:seek('end')
    )
  )
  file:close()
  return contents
end


return weave