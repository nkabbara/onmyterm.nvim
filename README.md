# onmyterm.nvim

Plugin provides a simple workflow for managing multiple terminal instances in a floating window. It comes with sensible defaults and pre-configured keybindings.

_I initially started this project to learn neovim's API, but as I did so, it started becoming useful enough to where I found myself using it regularly. I'm open to feature requests._

With the exception to this readme, AI was used as I would have used google.

## Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
    "nkabbara/onmyterm.nvim"
}
```

## Usage

### Global Keymaps

The plugin works out of the box with the following global shortcuts. You can disable these by setting `vim.g.onmyterm_disable_bindings = true`.

| Key | Action | Description |
| :--- | :--- | :--- |
| `<leader>tt` | **Toggle Terminal** | Open or hide the floating terminal window. |
| `<leader>tn` | **New Terminal** | Directly open a new terminal instance. |
| `:OnMyTermToggle` | **Command** | Toggle the terminal via command mode. |

### Tab-Scoped Terminals

Each Vim tabpage gets its own isolated set of OnMyTerm terminals. Terminal indexes start over per tab, so terminal `1` in one tab is separate from terminal `1` in another tab.

New terminals start in the tab-local working directory from `:tcd`. When a Vim tab is closed, OnMyTerm prompts before killing that tab's running terminals. You can disable that prompt with:

```lua
vim.g.onmyterm_confirm_tab_close = false
```

#### Custom Configuration Example

If you disable the default bindings, you can set your own:

```lua
-- Disable default keymaps
vim.g.onmyterm_disable_bindings = true

-- Set your own keymaps
vim.keymap.set("n", "<C-t>", require("onmyterm").toggle_term, { desc = "Toggle Terminal" })
```

### Terminal Buffer Keymaps

Once inside the terminal window, the following buffer-local shortcuts are available to manage your sessions:

| Key | Action | Description |
| :--- | :--- | :--- |
| `n` | **Next Terminal** | Switch to the next terminal buffer in the list. |
| `p` | **Previous Terminal** | Switch to the previous terminal buffer in the list. |
| `C` | **Create New** | Create a new terminal instance and switch to it. |
| `D` | **Delete** | Close the current terminal instance (prompts for confirmation). |
| `t` | **Transparency** | Toggle the window transparency (ghost mode). |
| `q` | **Hide** | Hide the floating window (backgrounds the terminal). |

## Defaults

* **Window Size**: 80% width and 80% height.
* **Border**: "Double" when active, "Single" when inactive.
* **Transparency**: Opaque by default; toggles to 90% transparent.
