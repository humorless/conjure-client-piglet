(local a (require :conjure.nfnl.core))
(local cbor (require :org.conman.cbor))
(local frame (require :websocket.frame))
(local ws-server (require :server_uv))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; internal state

(local atom {;; List of active PDP connections.
             :connections {}
             ;; PDP websocket server, see `start-server!`
             :server nil
             ;; Incrementing value used to match replies to handlers.
             :message-counter 0
             ;; Association list from message number to handler function.
             :handlers {}})

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; websocket event handler

(fn str-rest [value]
  "similar to rest, but applies to string"
  "for removing the extra colon in keyword"
  (-> value
      a.seq
      a.rest
      table.concat))

(local tagged-items {:_id str-rest})

(fn pdp--on-message [ws msg]
  (let [msg (cbor.decode msg nil tagged-items)
        _ (a.pr msg)
        op (a.get msg :op)
        to (a.get msg :to)
        handler (and to (a.get atom.handlers to))]
    (when handler
      (handler msg))))

(fn pdp--on-close [ws]
  (set atom.connections (a.filter (fn [c] (not= c ws)) atom.connections))
  (print (string.format "[Piglet] PDP conn closed, %d active connections"
                        (a.count atom.connections))))

(fn pdp--on-open [ws]
  ;; `ws` is the return value of `client` fn
  (table.insert atom.connections ws)
  (print (string.format "[Piglet] PDP conn opened, %d active connections"
                        (a.count atom.connections)))
  ;; install callbacks
  (ws:on_close (fn [ws was_clean code reason]
                 ;; --> user_on_close in server_uv
                 (pdp--on-close ws)))
  (ws:on_error (fn [ws err_msg]
                 ;; --> user_on_error in server_uv
                 (print (.. "PDP server error: " err_msg))))
  (ws:on_message (fn [ws message opcode]
                   ;; --> user_on_message
                   ;; (print (.. "msg: " message))
                   (pdp--on-message ws message)))
  nil)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; service start/stop

(fn start-server! []
  (if (not atom.server)
      (do
        (set atom.server (ws-server.listen {:port 17017 :default pdp--on-open}))
        (print "[Piglet] PDP server started on port: 17017")
        atom.server)
      (print "[Piglet] PDP server already running.")))

(fn stop-server! []
  (when atom.server
    (atom.server.close))
  (set atom.server nil)
  (set atom.connections {}))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; message send/receive

(fn keyword [s]
  "keyword changes the string s => `:s` and register a `__tocbor` function"
  (let [t {:v (.. ":" s)}
        mt {:__tocbor (fn [self]
                        (cbor.TAG._id self.v))}]
    (setmetatable t mt)))

(fn update-keys [t f]
  "for every key in t, apply `(f key)`."
  (->> (a.seq t)
       (a.reduce (fn [acc v]
                   (a.assoc acc (f (a.first v)) (a.second v)))
                 {})))

(fn send [msg]
  (let [msg (update-keys msg keyword)
        payload (cbor.encode msg)]
    (a.map (fn [ws]
             (when (= ws.state :OPEN)
               (ws:send payload frame.BINARY))) atom.connections)))

(fn register-handler [msg handler]
  "register a handler, so when the msg return, it will call that handler"
  (let [index (+ atom.message-counter 1)
        msg (a.assoc msg :reply-to index)]
    (tset atom.handlers index handler)
    (set atom.message-counter index)
    msg))

;; msg-t is the message that after `(update-keys msg keyword)` processing
;;(local msg-t {(keyword "op") :eval (keyword "code") "(+ 1 1)"})

;; msg-u is the typical plain message.
;;(local msg-u {:op :eval :code "(+ 1 1)"})

;; tmp-hlr is the handler registered for message
;; (fn tmp-hlr [msg] (a.println "in registered handler:" msg))

;; testing command to verify send and pdp--on-message 
; (send (register-handler msg-u tmp-hlr))

;; testing command to verify cbor.encode/cbor.decode for tag 39
; (cbor.decode (cbor.encode (update-keys msg-u keyword)) nil tagged-items)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; CBOR utility functions

(fn cbor->hex-string [input]
  (let [output []]
    (for [i 1 (length input)]
      (let [byte (string.byte input i)
            hex-byte (string.format "%02x" byte)]
        (table.insert output hex-byte)))
    (table.concat output " ")))

;; (print (cbor->hex-string (cbor.encode msg-t)))

{: start-server! : stop-server! : send : register-handler}
