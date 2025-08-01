local uv = vim.uv
local tools = require'websocket.tools'
local frame = require'websocket.frame'
local handshake = require'websocket.handshake'
local tinsert = table.insert
local tconcat = table.concat

local clients = {}
clients[true] = {}

local function async_send(sock, message, cb, err_cb)
  sock:write(message, function(err)
    if err then
      if err_cb then err_cb(err) end
    else
      if cb then cb() end
    end
  end)
end

local function message_io(sock, on_message, on_error)
  assert(sock and sock.read_start and sock.write, "sock must be a uv TCP handle")
  assert(on_message, "on_message callback required")
  assert(on_error, "on_error callback required")

  local frames = {}
  local first_opcode = nil
  local last = nil

  local function handle_data(data)
    if last then
      data = last .. data
      last = nil
    end

    while true do
      local decoded, fin, opcode, rest = frame.decode(data)
      if not decoded then
        break
      end

      if not first_opcode then
        first_opcode = opcode
      end

      tinsert(frames, decoded)
      data = rest or ""

      if fin then
        local full_message = tconcat(frames)
        on_message(full_message, first_opcode)
        frames = {}
        first_opcode = nil
      end
    end

    if #data > 0 then
      last = data
    end
  end

  local function on_read(err, chunk)
    if err then
      on_error(err, sock)
      sock:close()
      return
    end

    if chunk then
      handle_data(chunk)
    else
      -- EOF
      on_error("closed", sock)
    end
  end

  sock:read_start(on_read)

  return {
    stop = function()
      sock:read_stop()
    end,
    write = function(data)
      sock:write(data)
    end,
    is_active = function()
      return not sock:is_closing()
    end,
  }
end

local function client(sock, protocol)
  local self = {}
  self.state = 'OPEN'
  self.sock = sock

  local user_on_message = function() end
  local user_on_close = nil
  local user_on_error = nil

  local close_timer = nil

  local function on_close(was_clean, code, reason)
    if clients[protocol] then
      clients[protocol][self] = nil
    end
    if close_timer then
      close_timer:stop()
      close_timer:close()
      close_timer = nil
    end
    self.state = 'CLOSED'
    sock:read_stop()
    sock:shutdown()
    sock:close()
    if user_on_close then
      user_on_close(self, was_clean, code, reason or '')
    end
  end

  local function on_error(err)
    if self.state ~= 'CLOSED' then
      if err == 'closed' then
        on_close(false, 1006, '')
      elseif user_on_error then
        user_on_error(self, err)
      else
        print('WebSocket server error', err)
      end
    end
  end

  local function on_message(message, opcode)
    if opcode == frame.TEXT or opcode == frame.BINARY then
      user_on_message(self, message, opcode)
    elseif opcode == frame.CLOSE then
      if self.state ~= 'CLOSING' then
        self.state = 'CLOSING'
        local code, reason = frame.decode_close(message)
        local encoded = frame.encode(frame.encode_close(code), frame.CLOSE)
        async_send(sock, encoded, function()
          on_close(true, code or 1006, reason)
        end, on_error)
      else
        on_close(true, 1006, '')
      end
    end
  end

  self.send = function(_, message, opcode)
    local encoded = frame.encode(message, opcode or frame.TEXT)
    async_send(sock, encoded)
  end

  self.on_close = function(_, cb) user_on_close = cb end
  self.on_error = function(_, cb) user_on_error = cb end
  self.on_message = function(_, cb) user_on_message = cb end

  self.broadcast = function(_, ...)
    for c in pairs(clients[protocol]) do
      if c.state == 'OPEN' then
        c:send(...)
      end
    end
  end

  self.close = function(_, code, reason, timeout)
    if clients[protocol] then
      clients[protocol][self] = nil
    end
    if self.state == 'OPEN' then
      self.state = 'CLOSING'
      local encoded = frame.encode(frame.encode_close(code or 1000, reason or ''), frame.CLOSE)
      async_send(sock, encoded)
      close_timer = uv.new_timer()
      close_timer:start((timeout or 3) * 1000, 0, function()
        close_timer:stop()
        close_timer:close()
        close_timer = nil
        on_close(false, 1006, 'timeout')
      end)
    end
  end

  self.start = function()
    message_io(sock, on_message, on_error)
  end

  return self
end

local function listen(opts)
  assert(opts and (opts.protocols or opts.default), "Must provide protocols or default")

  local protocols = {}
  if opts.protocols then
    for protocol in pairs(opts.protocols) do
      clients[protocol] = {}
      tinsert(protocols, protocol)
    end
  end

  local server = uv.new_tcp()
  server:bind(opts.interface or "0.0.0.0", opts.port or 80)
  server:listen(128, function(err)
    if err then
      print("Listen error: ", err)
      return
    end
    local client_sock = uv.new_tcp()
    server:accept(client_sock)
    client_sock:read_start(function(err2, chunk)
      assert(not err2, err2)
      if not chunk then
        print("Client disconnected")
        client:shutdown()
        client_sock:close()
        return
      end

      local req_data = chunk
      print(req_data)
      local response, protocol = handshake.accept_upgrade(req_data, protocols)
      if not response then
        print("Handshake failed:\n" .. req_data)
        client_sock:close()
        return
      end

      print("res:" .. response)
      client_sock:write(response, function(write_err)
        if write_err then
          print("Handshake send error:", write_err)
          client_sock:close()
          return
        end
        local protocol_handler = nil
        local protocol_index = nil
        if protocol and opts.protocols and opts.protocols[protocol] then
          protocol_handler = opts.protocols[protocol]
          protocol_index = protocol
        elseif opts.default then
          protocol_handler = opts.default
          protocol_index = true
        else
          error("bad protocol")
          client_sock:close()
          return
        end

        local c = client(client_sock, protocol_index)
        clients[protocol_index][c] = true
        protocol_handler(c)
        c:start()
      end)
    end)
  end)

  print("server listening on ...")
  local self = {}
  self.close = function(keep_clients)
    if not keep_clients then
      for _, cl in pairs(clients) do
        for c in pairs(cl) do
          c:close()
        end
      end
    end
    server:close()
  end
  return self
end

return {
  listen = listen
}

