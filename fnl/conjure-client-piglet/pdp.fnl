;;; pdp.fnl --- Piglet Dev Protocol, interactive programming over websocket

(local pdp-server (require :conjure-client-piglet.pdp-server))
(local {: autoload : define} (require :conjure.nfnl.module))
(local ts (autoload :conjure.tree-sitter))
(local config (autoload :conjure.config))
(local text (autoload :conjure.text))
(local log (autoload :conjure.log))
(local core (autoload :conjure.nfnl.core))
(local str (autoload :conjure.nfnl.string))

(local M (define :conjure.client.piglet.pdp
           {:buf-suffix :.pig
            :comment-node? ts.lisp-comment-node?
            :comment-prefix "; "
            :context-pattern "%(%s*module%s+(.-)[%s){]"
            :default-module-name :piglet.user}))

(fn M.form-node? [node]
  (ts.node-surrounded-by-form-pair-chars? node [["#(" ")"]]))

(config.merge {:client {:piglet {:pdp {}}}})

(when (config.get-in [:mapping :enable_defaults])
  (config.merge {:client {:piglet {:pdp {:mapping {}}}}}))

(local cfg (config.get-in-fn [:client :piglet :pdp]))

(fn with-repl-or-warn [f]
  (if (pdp-server.get-conn)
      (f)
      (log.append [(.. M.comment-prefix "No REPL running")])))

(fn eval-str-hdlr [msg]
  (let [result (core.get msg :result)]
    (vim.schedule (fn []
                    (log.append (text.split-lines result))))))

(fn M.eval-str [opts]
  "Client function, called by Conjure when evaluating a string."
  (log.dbg "eval-str: opts >> " (core.pr-str opts) "<<")
  (with-repl-or-warn (fn []
                       (pdp-server.send (let [msg {:op :eval
                                                   :code opts.code
                                                   :location nil
                                                   ;; opts.file-path
                                                   :module nil
                                                   ;;  opts.context
                                                   :package nil
                                                   :line nil
                                                   ;; (core.get-in opts [:range :start 1])
                                                   :start nil
                                                   ;; (-?> (core.get-in opts [:range :start 2]) (core.inc))
                                                   :var nil}]
                                          (pdp-server.register-handler msg
                                                                       eval-str-hdlr))))))

(fn M.eval-file [opts]
  "Client function, called by Conjure when evaluating a file from disk."
  (set opts.code (core.slurp opts.file-path))
  (when opts.code
    (M.eval-str opts)))

(fn M.doc-str [opts]
  "Client function, called by Conjure when looking up documentation."
  (core.assoc opts :code (.. ",doc " opts.code))
  (M.eval-str opts))

(fn M.def-str [opts]
  "TODO: try to implement it later"
  {})

(fn M.on-load []
  "init the pdp server listening"
  (pdp-server.start-server!)
  (log.append [(.. M.comment-prefix "PDP server is listening on Editor")
               (.. M.comment-prefix "run `pig pdp` to connect")]))

(fn M.on-exit []
  "close the pdp server"
  (pdp-server.stop-server!))

M
