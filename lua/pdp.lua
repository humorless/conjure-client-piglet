-- [nfnl] Compiled from fnl/pdp.fnl by https://github.com/Olical/nfnl, do not edit.
local a = require("nfnl.core")
local nvim = require("conjure.aniseed.nvim")
local cbor = require("cbor")
local copas = require("copas")
local ws_server = require("websocket").server.copas
local pdp__connections = {}
local pdp__server = nil
local pdp__message_counter = 0
local pdp__handlers = {}
local function pdp__on_open(client)
  table.insert(pdp__connections, client)
  return print(string.format("[Piglet] PDP conn opened, %d active connections", a.count(pdp__connections)))
end
local function pdp__on_message(client, msg)
  local msg0 = cbor.decode(msg)
  local op = a.get(msg0, "op")
  local to = a.get(msg0, "to")
  local handler = a.get(pdp__handlers, to)
  if handler then
    return handler(msg0)
  else
    return nil
  end
end
local function pdp__on_close(client)
  local function _2_(c)
    return (c ~= client)
  end
  pdp__connections = a.filter(_2_, pdp__connections)
  return print(string.format("[Piglet] PDP conn closed, %d active connections", a.count(pdp__connections)))
end
local function echo_handler(client)
  while true do
    local message = client:receive()
    print(message)
    if message then
      client:send(message)
    else
      client:close()
    end
  end
  return nil
end
local function start_copas_loop()
  local timer = vim.loop.new_timer()
  local function _4_()
    copas.step(0.01)
    return nil
  end
  timer:start(0, 10, vim.schedule_wrap(_4_))
  return nil
end
local function pdp_start_server_21()
  if not pdp__server then
    local function _5_(s)
      return print(("error: " .. s))
    end
    pdp__server = ws_server.listen({port = 17017, on_error = _5_, default = echo_handler})
    start_copas_loop()
    return print("[Piglet] PDP server started on port: 17017")
  else
    return print("[Piglet] PDP server already running.")
  end
end
local function pdp_stop_server_21()
  if pdp__server then
    pdp__server.close()
  else
  end
  pdp__server = nil
  pdp__connections = {}
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
local function pdp_add_handler(msg, handler)
  local id = a.inc(pdp__message_counter)
  pdp__handlers[id] = handler
  return a.assoc(msg, "reply-to", id)
end
local function pdp_send(msg)
  local payload = cbor.encode(msg)
  for _, client in ipairs(pdp__connections) do
    if client.is_open then
      client.send(payload)
    else
    end
  end
  return nil
end
local function pdp__eval_handler(opts)
  local dest = a.get(opts, "destination", "minibuffer")
  local pretty_3f = a.get(opts, "pretty-print", false)
  local function _11_(msg)
    local result = a.get(msg, "result")
    if (dest == "minibuffer") then
      return print(("=> " .. result))
    elseif (dest == "buffer") then
      return nvim.command(("new | put ='" .. result .. "'"))
    elseif (dest == "repl") then
      return print("[Piglet] REPL output not implemented")
    elseif (dest == "insert") then
      return nvim.fn.append(nvim.fn.line("."), result)
    else
      local _ = dest
      return print(("=> " .. result))
    end
  end
  return _11_
end
local function pdp_op_eval(code_str, start, line, opts)
  local msg = pdp_msg({op = "eval", code = code_str, start = start, line = line})
  return pdp_send(pdp_add_handler(msg, pdp__eval_handler(opts)))
end
return pdp_op_eval
