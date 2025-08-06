-- [nfnl] Compiled from fnl/pdp.fnl by https://github.com/Olical/nfnl, do not edit.
local a = require("nfnl.core")
local nvim = require("conjure.aniseed.nvim")
local cbor = require("cbor")
local ws_server = require("server_uv")
local state = {connections = {}, server = nil, ["message-counter"] = 0, handlers = {}}
local function pdp__on_message(client, msg)
  local msg0 = cbor.decode(msg)
  local op = a.get(msg0, "op")
  local to = a.get(msg0, "to")
  local handler = a.get(state.handlers, to)
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
  state.connections = a.filter(_2_, state.connections)
  return print(string.format("[Piglet] PDP conn closed, %d active connections", a.count(state.connections)))
end
local function pdp__on_open(ws)
  table.insert(state.connections, ws)
  print(string.format("[Piglet] PDP conn opened, %d active connections", a.count(state.connections)))
  local function _3_(ws0, was_clean, code, reason)
    print(("code:" .. code))
    print(("reason:" .. reason))
    return pdp__on_close(ws0)
  end
  ws:on_close(_3_)
  local function _4_(ws0, err_msg)
    return print(("PDP server error: " .. err_msg))
  end
  ws:on_error(_4_)
  local function _5_(ws0, message, opcode)
    print(("opcode:" .. opcode))
    print(("message:" .. message))
    return ws0:send(message)
  end
  ws:on_message(_5_)
  return nil
end
local function pdp_start_server_21()
  if not state.server then
    state.server = ws_server.listen({port = 17017, default = pdp__on_open})
    return print("[Piglet] PDP server started on port: 17017")
  else
    return print("[Piglet] PDP server already running.")
  end
end
local function pdp_stop_server_21()
  if state.server then
    state.server.close()
  else
  end
  state.server = nil
  state.connections = {}
  return nil
end
local function pdp_msg(kvs)
  local function _9_(_8_)
    local k = _8_[1]
    local v = _8_[2]
    return v
  end
  return a.merge(kvs, a.filter(_9_, {location = nvim.fn.expand("%:p"), module = "default.module", package = "default.pkg"}))
end
return pdp_msg
