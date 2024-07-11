require('../libs/blueprints/apm')

Llama = Llama or nil

if Llama == nil then
  APM.install("@sam/Llama-Herder")
end

Handlers.append(
  "APM.UpdateClientResponse", 
  Handlers.utils.hasMatchingTag("Action", "APM.UpdateClientResponse"),
  function()
    Llama = require("@sam/Llama-Herder")
    print("📦 Loaded Llama Herder")
  end
)