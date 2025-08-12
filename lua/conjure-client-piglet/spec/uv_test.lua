-- open this file in Neovim and use command `:luafile %` to invoke it.
-- In other terminal, run the command `websocat ws://127.0.0.1:8080` to test it

local server = require("conjure-client-piglet.server_uv").listen
{
  -- listen on port 8080
  port = 8080,
  -- the protocols field holds
  --   key: protocol name
  --   value: callback on new connection
  
  default = function(ws)
    ws:on_message(function(ws,message)
        ws:send(message)
      end)
      -- this is optional
    ws:on_close(function()
        ws:close()
      end)
  end,
  interface = "127.0.0.1",
  protocols = {
  }
}
