-- [nfnl] Compiled from fnl/conjure-client-piglet/pdp.fnl by https://github.com/Olical/nfnl, do not edit.
local pdp_server = require("conjure-client-piglet.pdp-server")
local _local_1_ = require("conjure.nfnl.module")
local autoload = _local_1_["autoload"]
local define = _local_1_["define"]
local ts = autoload("conjure.tree-sitter")
local config = autoload("conjure.config")
local text = autoload("conjure.text")
local log = autoload("conjure.log")
local core = autoload("conjure.nfnl.core")
local str = autoload("conjure.nfnl.string")
local M = define("conjure.client.piglet.pdp", {["buf-suffix"] = ".pig", ["comment-node?"] = ts["lisp-comment-node?"], ["comment-prefix"] = "; ", ["context-pattern"] = "%(%s*module%s+(.-)[%s){]", ["default-module-name"] = "piglet.user"})
M["form-node?"] = function(node)
  return ts["node-surrounded-by-form-pair-chars?"](node, {{"#(", ")"}})
end
config.merge({client = {piglet = {pdp = {}}}})
if config["get-in"]({"mapping", "enable_defaults"}) then
  config.merge({client = {piglet = {pdp = {mapping = {}}}}})
else
end
local cfg = config["get-in-fn"]({"client", "piglet", "pdp"})
local function with_repl_or_warn(f)
  if pdp_server["get-conn"]() then
    return f()
  else
    return log.append({(M["comment-prefix"] .. "No REPL running")})
  end
end
local function eval_str_hdlr(msg)
  local result = core.get(msg, "result")
  local function _4_()
    return log.append(text["split-lines"](result))
  end
  return vim.schedule(_4_)
end
M["eval-str"] = function(opts)
  log.dbg("eval-str: opts >> ", core["pr-str"](opts), "<<")
  local function _5_()
    local function _6_()
      local msg = {op = "eval", code = opts.code, location = nil, module = nil, package = nil, line = nil, start = nil, var = nil}
      return pdp_server["register-handler"](msg, eval_str_hdlr)
    end
    return pdp_server.send(_6_())
  end
  return with_repl_or_warn(_5_)
end
M["eval-file"] = function(opts)
  opts.code = core.slurp(opts["file-path"])
  if opts.code then
    return M["eval-str"](opts)
  else
    return nil
  end
end
M["doc-str"] = function(opts)
  core.assoc(opts, "code", (",doc " .. opts.code))
  return M["eval-str"](opts)
end
M["def-str"] = function(opts)
  return {}
end
M["on-load"] = function()
  pdp_server["start-server!"]()
  return log.append({(M["comment-prefix"] .. "PDP server is listening on Editor"), (M["comment-prefix"] .. "run `pig pdp` to connect")})
end
M["on-exit"] = function()
  return pdp_server["stop-server!"]()
end
return M
