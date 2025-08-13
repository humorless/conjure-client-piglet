Neovim Editor integration for Piglet, currently contains: 

- [Conjure](https://github.com/Olical/conjure) Piglet client
- pdp, a Piglet Dev Protocol server implementation, for interactive eval
- setup Neovim Piglet filetype.
- register Piglet into Conjure.

## Setup

1. Prepare the required luarocks dependencies. (See next section)
2. Config `init.vim` with following content and then `:PlugInstall`  

```
" install with vim-plug
call plug#begin(stdpath('data') . '/plugged')
...
Plug 'humorless/conjure-client-piglet'
...
call plug#end()


" register piglet filetype into Neovim/Conjure
" and register conjure-client-piglet for piglet filetype
lua require("conjure-client-piglet").setup()
```

## Requirements

```
 luarocks install org.conman.cbor
 luarocks install lua-websockets 
```

### Install/configure luarocks with Neovim

> If we install lua-cbor using Luarocks, can we use it in Lua scripts inside Neovim? 

The answer is **not** by default — some adjustments are needed.

This is because our Luarocks was also installed via Homebrew, and the default Lua interpreter used by Luarocks differs from the one Neovim uses by default. Additionally, Neovim's package path likely won’t include Luarocks' installation paths.

### Solution A:

Use [rocks.nvim](https://github.com/nvim-neorocks/rocks.nvim) or [luarocks.nvim](https://github.com/vhyrro/luarocks.nvim) to manage it. 

### Solution B:

1. **Reinstall Luarocks**

  Download the source tarball, recompile, and install it so that it links explicitly to the same Lua interpreter used by Neovim — namely, **LuaJIT**.

2. **Configure Neovim’s internal** `package.path` **and** `package.cpath`

  This ensures that Neovim can locate the modules and shared libraries installed via Luarocks.

#### Reinstall Luarocks — Step-by-step:

```
$ brew install luajit
$ wget https://luarocks.org/releases/luarocks-3.12.0.tar.gz
$ tar zxvf luarocks-3.12.0.tar.gz && cd luarocks-3.12.0
$ mkdir ~/.luarocks-luajit
$ ./configure \
  --with-lua=$(brew --prefix luajit) \
  --with-lua-include=$(brew --prefix luajit)/include/luajit-2.1 \
  --lua-suffix=jit \
  --prefix=$HOME/.luarocks-luajit
$ make && make install
```

Note: The version of Luarocks is important. LuaJIT has a limit of 65536 constants in a single function. If you don’t use a compatible version of Luarocks, you may encounter the error:

> Error: main function has more than 65536 constants

(See [related references](https://support.konghq.com/support/s/article/LuaRocks-Error-main-function-has-more-than-65536-constants) for more.)

#### Configure Neovim with Luarocks Modules

1. Under your Neovim `lua/` directory, create a file named `luarocks.lua`.

2. Paste the following content into it, and replace the `$username` variable.

  ```
local function add_luarocks_paths()
  local luarocks_path = "/Users/$username/.luarocks-luajit/share/lua/5.1/?.lua;/Users/$username/.luarocks-luajit/share/lua/5.1/?/init.lua"
  local luarocks_cpath = "/Users/$username/.luarocks-luajit/lib/lua/5.1/?.so"
  package.path = package.path .. ";" .. luarocks_path
  package.cpath = package.cpath .. ";" .. luarocks_cpath
end
return { add_luarocks_paths = add_luarocks_paths }
  ```
3. In your `init.vim`, add the following line:

```
lua require("luarocks").add_luarocks_paths()
```

## Dev

Swith on debugging: add the following lines to `init.vim`:

```
let g:conjure#debug = v:true
```

## Reusable Part: Lua websockets for Neovim

`conjure-client-piglet/server_uv.lua` is adapted from `server_ev.lua` in [lua-websockets](https://github.com/lipp/lua-websockets).  
I removed its original dependency on LuaSocket and replaced it with a dependency on `vim.uv`’s TCP socket.

While developing this part, I spent some time searching but couldn’t find a Lua WebSocket implementation suitable for Neovim, so I modified one myself.

