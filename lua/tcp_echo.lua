local uv = vim.uv or vim.loop
local server = uv.new_tcp()
server:bind("127.0.0.1", 8080)
server:listen(128, function(err)
  assert(not err, err)
  local client = uv.new_tcp()
  server:accept(client)
  print("Client connected")

  client:read_start(function(err, chunk)
    assert(not err, err)
    if chunk then
      print("Received from client:", chunk)
      client:write("Echo: " .. chunk)
    else
      print("Client disconnected")
      client:shutdown()
      client:close()
    end
  end)
end)

print("TCP server listening on 127.0.0.1:8080")

