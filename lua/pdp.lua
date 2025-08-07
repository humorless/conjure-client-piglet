-- [nfnl] Compiled from fnl/pdp.fnl by https://github.com/Olical/nfnl, do not edit.
local a = require("nfnl.core")
local nvim = require("conjure.aniseed.nvim")
local cbor = require("cbor")
local frame = require("websocket.frame")
local ws_server = require("server_uv")
local atom = {connections = {}, server = nil, ["message-counter"] = 0, handlers = {}}
local function pdp__on_message(ws, msg)
  local msg0 = cbor.decode(msg)
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
    print(("opcode: " .. opcode))
    print(("msg: " .. message))
    return pdp__on_message(ws0, message)
  end
  ws:on_message(_5_)
  return nil
end
local function pdp_start_server_21()
  if not atom.server then
    atom.server = ws_server.listen({port = 17017, default = pdp__on_open})
    return print("[Piglet] PDP server started on port: 17017")
  else
    return print("[Piglet] PDP server already running.")
  end
end
local function pdp_stop_server_21()
  if atom.server then
    atom.server.close()
  else
  end
  atom.server = nil
  atom.connections = {}
  return nil
end
local msg_t = {op = "eval", code = "(+ 1 1)"}
local function pdp_send(msg)
  local payload = cbor.encode(msg)
  local function _8_(ws)
    if (ws.state == "OPEN") then
      return ws:send(payload, frame.BINARY)
    else
      return nil
    end
  end
  return a.map(_8_, atom.connections)
end
return pdp_send
