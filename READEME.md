Editor integration for Piglet. Currently contains:

- pdp, a Piglet Dev Protocol server implementation, for interactive eval

The package is called `piglet-nvim` for lack of a better name. 

- `piglet-mode` is too reductive, it's more than just the mode
- `piglet` is a misnomer, you're not installing the language
- We already called the repo that

## Requirements

```
 luarocks install ${lib_name}
```

- lua-cbor
- lua-websockets

## Dev Requirement

-  websocat ;; command line websocket
