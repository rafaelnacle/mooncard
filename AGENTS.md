# Project instructions

Mooncard is a small, offline Lua + LÖVE card game, targeting Linux first.
Implement only the requested milestone. Keep changes small and understandable.

## Code and architecture

- Start with `main.lua` and `conf.lua`; avoid speculative abstractions and empty directories.
- Use LuaJIT-compatible Lua, four-space indentation, `snake_case` names, local variables, and small functions. Keep LÖVE callback names as required by its API.
- Use LÖVE alone initially. Explain the need for any additional dependency before adding it.
- When gameplay arrives, keep pure Lua rules separate from drawing and input. Human input and AI must use the same rule validation.
- Use original or appropriately licensed assets. The initial window uses the built-in font only.

## Verification

- Run `love .` from the repository root for visual changes. Check appearance, responsiveness, Escape, the window close button, and relaunching.
- Add meaningful automated tests when gameplay rules exist; do not introduce a window-testing framework for the bootstrap.
- Report checks performed and anything unverified. Never describe an unrun check as passing.
- Review `git diff --check`, the staged diff, and repository status before committing.

## Documentation

- Keep `README.md` limited to what the project is and how to install prerequisites and run it, including controls and the tested runtime version.
- Keep development instructions here and milestone planning in `docs/plan.md`.
- Update documented commands when behavior changes.

## Git and ownership

- Use `main` as the base branch. Use short-lived `feat/...`, `fix/...`, or `chore/...` branches for coherent tasks.
- Use Conventional Commit messages such as `feat: add initial game window`.
- Local branches and commits are authorized. Stage specific files and inspect the staged diff.
- Leave completed feature branches for the user's review; merge only when requested.
- Never push, publish, configure remotes, or automate publication. The user handles all pushes.
- Preserve unrelated user changes. Never discard user work, rewrite history, or change Git identity without explicit authorization.

## Secrets and generated files

- Never commit credentials, tokens, private keys, real `.env` files, sensitive logs, or machine-specific private configuration.
- Use dummy values in examples. Review actual staged contents; ignore rules alone do not prevent leaks.
- Keep caches, generated packages, and runtime artifacts out of Git.
- This milestone requires no accounts, API keys, network services, or external AI service.
