-- [nfnl] Compiled from fnl/conjure-client-piglet/init.fnl by https://github.com/Olical/nfnl, do not edit.
local function setup()
  local function _1_()
    vim.bo.filetype = "piglet"
    return nil
  end
  vim.api.nvim_create_autocmd({"BufNewFile", "BufRead"}, {pattern = {"*.pig"}, callback = _1_, group = vim.api.nvim_create_augroup("piglet", {clear = true})})
  vim.g["conjure#filetype#piglet"] = "conjure-client-piglet.pdp"
  return nil
end
return {setup = setup}
