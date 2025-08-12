(fn setup []
  "let Neovim to recognize the filetype `Piglet`"
  (vim.api.nvim_create_autocmd [:BufNewFile :BufRead]
                               {:pattern [:*.pig]
                                :callback (fn [] (set vim.bo.filetype :piglet))
                                :group (vim.api.nvim_create_augroup :piglet
                                                                    {:clear true})})
  (set vim.g.conjure#filetype#piglet :conjure-client-piglet.pdp))

{: setup}
