# Mooncard development plan

## Direction

Build an original, small Hearthstone-inspired card game with Lua + LÖVE,
targeting Linux first and eventually a simple computer opponent. Keep it
offline, with no accounts, backend, networking, or external AI service.

## Milestone 1: repository and window

- Establish `AGENTS.md`, a minimal `.editorconfig` and `.gitignore`, and a README limited to the project description and installation/run instructions.
- Use `conf.lua` for a fixed 1280 × 720 window titled Mooncard with VSync enabled.
- Use `main.lua` for a dark background, centered Mooncard title, and “Press Escape to quit.” Built-in fonts only; no extra libraries or assets.
- Exit cleanly through Escape and the window close button. Run with `love .`.
- Keep LuaJIT-compatible code small, with local variables, four-space indentation, and snake_case names.
- Record the tested LÖVE version. Verify visual appearance, responsiveness, both exit paths, and relaunching without repository artifacts.
- No automated window-testing framework or CI for this milestone.

## Local versioning

Initialize `main` without deleting existing Git metadata. Commit conventions as
`chore: initialize project conventions`. Create `feat/window-bootstrap` and
commit the verified window as `feat: add initial game window`.

Use short-lived feat/fix/chore branches and Conventional Commits. Inspect staged
contents for accidental files and secrets. Preserve user work and Git identity.
Leave feature branches for review and merge only on request. The user alone
pushes; agents must not configure remotes or publish.

## Later milestones (not part of the bootstrap)

1. Card interaction: placeholder cards, hand and board, hover and click selection.
2. Rules: decks, drawing, mana, turns, units, attacks, and victory conditions. Plan exact rules first; keep them in pure Lua and test independently of LÖVE.
3. Computer opponent: choose legal plays and attacks with simple heuristics, then end its turn. Use the same validation as human input.
4. Playable loop: restart, clear feedback, and modest visual polish.
