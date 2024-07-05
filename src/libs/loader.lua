GlobalVars = GlobalVars or nil

-- Load Var if already exist or use init value
function GetGlobalVar(varName, initValue)
  if GlobalVars[varName] then
    return GlobalVars[varName]
  end

  return initValue
end

-- Get Global Var or Load it if not exist
function GetGlobalVarOrLoad(varName, initValue)
  if GlobalVars[varName] then
    return GlobalVars[varName]
  end

  return require(varName)
end