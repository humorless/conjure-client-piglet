;;; pdp.fnl --- Piglet Dev Protocol, interactive programming over websocket

(local a (require :nfnl.core))
(local nvim (require :conjure.aniseed.nvim))
(local cbor (require :cbor))
(local ws-server (require :server_uv))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Internals
(local state {;; List of active PDP connections.
              :connections {}
              ;; PDP websocket server, see `pdp-start-server!`
              :server nil
              ;; Incrementing value used to match replies to handlers.
              :message-counter 0
              ;; Association list from message number to handler function.
              :handlers {}})

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; event handler

(fn pdp--on-message [client msg]
  (let [msg (cbor.decode msg)
        op (a.get msg :op)
        to (a.get msg :to)
        handler (a.get state.handlers to)]
    (when handler
      (handler msg))))

(fn pdp--on-close [ws]
  (set state.connections (a.filter (fn [c] (not= c ws)) state.connections))
  (print (string.format "[Piglet] PDP conn closed, %d active connections"
                        (a.count state.connections))))

(fn pdp--on-open [ws]
  ;; `ws` is the return value of `client` fn
  (table.insert state.connections ws)
  (print (string.format "[Piglet] PDP conn opened, %d active connections"
                        (a.count state.connections)))
  ;; install callbacks
  (ws:on_close (fn [ws was_clean code reason]
                 ;; --> user_on_close in server_uv
                 (print (.. "code:" code))
                 (print (.. "reason:" reason))
                 (pdp--on-close ws)))
  (ws:on_error (fn [ws err_msg]
                 ;; --> user_on_error in server_uv
                 (print (.. "PDP server error: " err_msg))))
  (ws:on_message (fn [ws message opcode]
                   ;; --> user_on_message
                   (print (.. "opcode:" opcode))
                   (print (.. "message:" message))
                   (ws:send message)))
  nil)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; service start/stop

(fn pdp-start-server! []
  (if (not state.server)
      (do
        (set state.server
             (ws-server.listen {:port 17017 :default pdp--on-open}))
        (print "[Piglet] PDP server started on port: 17017"))
      (print "[Piglet] PDP server already running.")))

(fn pdp-stop-server! []
  (when state.server
    (state.server.close))
  (set state.server nil)
  (set state.connections {}))

(fn pdp-msg [kvs]
  (a.merge kvs (a.filter (fn [[k v]] v)
                         {:location (nvim.fn.expand "%:p")
                          :module :default.module
                          ;; placeholder
                          :package :default.pkg})))
