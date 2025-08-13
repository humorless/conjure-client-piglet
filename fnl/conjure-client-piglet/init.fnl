(fn setup []
  "let Neovim/Conjure recognize the filetype `Piglet`"
  ;; register piglet filetype into Neovim
  (vim.api.nvim_create_autocmd [:BufNewFile :BufRead]
                               {:pattern [:*.pig]
                                :callback (fn [] (set vim.bo.filetype :piglet))
                                :group (vim.api.nvim_create_augroup :piglet
                                                                    {:clear true})})
  ;; register piglet filetype into Conjure
  (set vim.g.conjure#filetypes [:clojure
                                :fennel
                                :janet
                                :hy
                                :julia
                                :racket
                                :scheme
                                :lua
                                :lisp
                                :python
                                :rust
                                :sql
                                :php
                                :r
                                :piglet])
  ;; register conjure-client-piglet for piglet 
  (set vim.g.conjure#filetype#piglet :conjure-client-piglet.pdp))

{: setup}
