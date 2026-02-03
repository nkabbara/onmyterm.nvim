vim.api.nvim_create_user_command("OnMyTermToggle", function()
    require("onmyterm").toggle_term()
end, {})

if not vim.g.onmyterm_disable_bindings then
    vim.keymap.set("n", "<leader>tt", function()
        require("onmyterm").toggle_term()
    end, { desc = "Toggle terminal" })

    vim.keymap.set("n", "<leader>tn", function()
        require("onmyterm").open_term()
        require("onmyterm").new_term()
    end, { desc = "New terminal" })
end
