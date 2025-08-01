local server = require'server_uv'.listen
{
  -- listen on port 8080
  port = 8080,
  -- the protocols field holds
  --   key: protocol name
  --   value: callback on new connection
  interface = "127.0.0.1",
  protocols = {
    -- this callback is called, whenever a new client connects.
    -- ws is a new websocket instance
    echo = function(ws)
      ws:on_message(function(ws,message)
          ws:send(message)
        end)

      -- this is optional
      ws:on_close(function()
          ws:close()
        end)
    end
  }
}
