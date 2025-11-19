# AGENTS.md

Guidelines for agents working in this repository:

1. This plugin uses Lua for Neovim; keep code idiomatic and minimal.
2. Use `stylua` for formatting; follow default style (2 spaces, no tabs).
3. Prefer local functions and avoid global mutations.
4. Keep imports (`require`) at top of file in alphabetical order.
5. Use descriptive variable and function names in snake_case.
6. Avoid one-letter names except in tiny scopes.
7. Handle errors via `pcall` when interacting with user commands.
8. Keep modules small; one responsibility per file.
9. No tests currently exist; if adding them, use `busted`.
10. To run a single test: `busted path/to/test.lua -F`.
11. Linting: use `luacheck .` if adding lint setup.
12. Follow Neovim Lua APIs; avoid depending on external libraries.
13. Document public functions in the README or inline.
14. Maintain backwards‑compatible configuration whenever possible.
15. Organize plugin files under `lua/onmyterm/` if expanding.
16. Avoid side effects at module load time.
17. Prefer returning tables of functions over mutating state.
18. Keep functions pure unless interacting with Neovim APIs.
19. No Cursor or Copilot rules detected; none required.
20. When editing, keep changes minimal and consistent with existing style.