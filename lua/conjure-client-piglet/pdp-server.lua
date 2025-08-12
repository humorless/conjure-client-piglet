-- [nfnl] Compiled from fnl/conjure-client-piglet/pdp-server.fnl by https://github.com/Olical/nfnl, do not edit.
local a = require("conjure.nfnl.core")
local cbor = require("org.conman.cbor")
local frame = require("websocket.frame")
local ws_server = require("conjure-client-piglet.server_uv")
local atom = {connections = {}, server = nil, ["message-counter"] = 0, handlers = {}}
local function str_rest(value)
  return table.concat(a.rest(a.seq(value)))
end
local tagged_items = {_id = str_rest}
local function pdp__on_message(ws, msg)
  local msg0 = cbor.decode(msg, nil, tagged_items)
  local _ = a.pr(msg0)
  local op = a.get(msg0, "op")
  local to = a.get(msg0, "to")
  local handler = (to and a.get(atom.handlers, to))
  if handler then
    return handler(msg0)
  else
    return nil
  end
end
local function pdp__on_close(ws)
  local function _2_(c)
    return (c ~= ws)
  end
  atom.connections = a.filter(_2_, atom.connections)
  return print(string.format("[Piglet] PDP conn closed, %d active connections", a.count(atom.connections)))
end
local function pdp__on_open(ws)
  table.insert(atom.connections, ws)
  print(string.format("[Piglet] PDP conn opened, %d active connections", a.count(atom.connections)))
  local function _3_(ws0, was_clean, code, reason)
    return pdp__on_close(ws0)
  end
  ws:on_close(_3_)
  local function _4_(ws0, err_msg)
    return print(("PDP server error: " .. err_msg))
  end
  ws:on_error(_4_)
  local function _5_(ws0, message, opcode)
    return pdp__on_message(ws0, message)
  end
  ws:on_message(_5_)
  return nil
end
local function start_server_21()
  if not atom.server then
    atom.server = ws_server.listen({port = 17017, default = pdp__on_open})
    print("[Piglet] PDP server started on port: 17017")
    return atom.server
  else
    return print("[Piglet] PDP server already running.")
  end
end
local function stop_server_21()
  if atom.server then
    atom.server.close()
  else
  end
  atom.server = nil
  atom.connections = {}
  return nil
end
local function keyword(s)
  local t = {v = (":" .. s)}
  local mt
  local function _8_(self)
    return cbor.TAG._id(self.v)
  end
  mt = {__tocbor = _8_}
  return setmetatable(t, mt)
end
local function update_keys(t, f)
  local function _9_(acc, v)
    return a.assoc(acc, f(a.first(v)), a.second(v))
  end
  return a.reduce(_9_, {}, a.seq(t))
end
local function send(msg)
  local msg0 = update_keys(msg, keyword)
  local payload = cbor.encode(msg0)
  local function _10_(ws)
    if (ws.state == "OPEN") then
      return ws:send(payload, frame.BINARY)
    else
      return nil
    end
  end
  return a.map(_10_, atom.connections)
end
local function register_handler(msg, handler)
  local index = (atom["message-counter"] + 1)
  local msg0 = a.assoc(msg, "reply-to", index)
  atom.handlers[index] = handler
  atom["message-counter"] = index
  return msg0
end
local function cbor__3ehex_string(input)
  local output = {}
  for i = 1, #input do
    local byte = string.byte(input, i)
    local hex_byte = string.format("%02x", byte)
    table.insert(output, hex_byte)
  end
  return table.concat(output, " ")
end
return {["start-server!"] = start_server_21, ["stop-server!"] = stop_server_21, send = send, ["register-handler"] = register_handler}
