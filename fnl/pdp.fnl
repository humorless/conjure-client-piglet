;;; pdp.fnl --- Piglet Dev Protocol, interactive programming over websocket

(local a (require :nfnl.core))
(local nvim (require :conjure.aniseed.nvim))
(local cbor (require :cbor))
(local ws-server (require :server_uv))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Internals

;; List of active PDP connections.
(var pdp--connections {})

;; PDP websocket server, see `pdp-start-server!`
(var pdp--server nil)

;; Incrementing value used to match replies to handlers.
(var pdp--message-counter 0)

;; Association list from message number to handler function.
(var pdp--handlers {})

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; event handler

(fn pdp--on-open [client]
  (table.insert pdp--connections client)
  (print (string.format "[Piglet] PDP conn opened, %d active connections"
                        (a.count pdp--connections))))

(fn pdp--on-message [client msg]
  (let [msg (cbor.decode msg)
        op (a.get msg :op)
        to (a.get msg :to)
        handler (a.get pdp--handlers to)]
    (when handler
      (handler msg))))

(fn pdp--on-close [client]
  (set pdp--connections (a.filter (fn [c] (not= c client)) pdp--connections))
  (print (string.format "[Piglet] PDP conn closed, %d active connections"
                        (a.count pdp--connections))))

(fn echo-handler [ws]
  (ws:on_message (fn [ws message] (ws:send message)))
  (ws:on_close (fn [] (ws:close)))
  nil)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; service start/stop

(fn pdp-start-server! []
  (if (not pdp--server)
      (do
        (set pdp--server
             (ws-server.listen {:port 17017
                                :on_error (fn [s] (print (.. "error: " s)))
                                :default echo-handler}))
        (print "[Piglet] PDP server started on port: 17017"))
      (print "[Piglet] PDP server already running.")))

(fn pdp-stop-server! []
  (when pdp--server
    (pdp--server.close))
  (set pdp--server nil)
  (set pdp--connections {}))

(fn pdp-msg [kvs]
  (a.merge kvs (a.filter (fn [[k v]] v)
                         {:location (nvim.fn.expand "%:p")
                          :module :default.module
                          ;; placeholder
                          :package :default.pkg})))

;; optional

(fn pdp-add-handler [msg handler]
  (let [id (a.inc pdp--message-counter)]
    (tset pdp--handlers id handler)
    (a.assoc msg :reply-to id)))

(fn pdp-send [msg]
  (let [payload (cbor.encode msg)]
    (each [_ client (ipairs pdp--connections)]
      (when client.is_open
        (client.send payload)))))

(fn pdp--eval-handler [opts]
  (let [dest (a.get opts :destination :minibuffer)
        pretty? (a.get opts :pretty-print false)]
    (fn [msg]
      (let [result (a.get msg :result)]
        (match dest
          :minibuffer (print (.. "=> " result))
          :buffer (do
                    ;; Replace with actual buffer API
                    (nvim.command (.. "new | put ='" result "'")))
          :repl (print "[Piglet] REPL output not implemented")
          :insert (do
                    (nvim.fn.append (nvim.fn.line ".") result))
          _ (print (.. "=> " result)))))))

(fn pdp-op-eval [code-str start line opts]
  (let [msg (pdp-msg {:op :eval :code code-str : start : line})]
    (pdp-send (pdp-add-handler msg (pdp--eval-handler opts)))))
