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
  local buffer = ""
  local function read_cb(err, chunk)
    if err then
      on_error(err)
    elseif chunk then
      buffer = buffer .. chunk
      while true do
        local msg, opcode, rest = frame.decode(buffer)
        if not msg then break end
        buffer = rest
        on_message(msg, opcode)
      end
    else
      on_error("closed")
    end
  end
  sock:read_start(read_cb)
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
      
      if err2 or not chunk then
        print("Handshake read error", err2)
        client_sock:close()
        return
      end

      local req_data = chunk
      local response, protocol = handshake.accept_upgrade(req_data, protocols)
      if not response then
        print("Handshake failed:\n" .. req_data)
        client_sock:close()
        return
      end

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

