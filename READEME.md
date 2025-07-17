Editor integration for Piglet. Currently contains:

- piglet-mode, a major mode based on tree-sitter
- pdp, a Piglet Dev Protocol server implementation, for interactive eval

The package is called `piglet-nvim` for lack of a better name. 

- `piglet-mode` is too reductive, it's more than just the mode
- `piglet` is a misnomer, you're not installing the language
- We already called the repo that

## Requirements

- [websocket.nvim](https://github.com/samsze0/websocket.nvim/tree/main)
- lua-cbor (installed by luarocks)
