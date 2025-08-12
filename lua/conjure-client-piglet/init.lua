local function setup()
  vim.api.nvim_create_autocmd({ "BufNewFile", "BufRead" }, {
    -- 這裡的 pattern 是你想要識別的檔案類型
    pattern = { "*.pig" },
    callback = function()
      -- 將 filetype 設定為 `xyz`
      vim.bo.filetype = "piglet"
    end,
    -- 註冊一個群組可以避免每次重載設定時重複註冊
    group = vim.api.nvim_create_augroup("piglet", { clear = true }),
})
end

return {setup =setup}

