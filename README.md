# Mooncard

A small, offline card game built with Lua and LÖVE, inspired by Hearthstone.
Duel the Warden, a simple computer opponent, with four fantasy creatures.
Summon with mana, protect your hero with Guards, and reduce the opposing
hero from 20 health to zero. Both sides use the same shuffled 12-card deck.

## Run on Linux

Tested on Linux with LÖVE 11.5 (official portable runtime, X11).
Install LÖVE 11.5. On Fedora:

```sh
sudo dnf install love
```

For other distributions, install LÖVE through your package manager or use the
[official Linux download](https://love2d.org/).
Lua is bundled with LÖVE; no separate Lua installation is required.

From the project directory:

```sh
love .
```

Click a card in your hand to summon it. Click a ready friendly creature,
then an enemy creature or hero to attack. Enemy **Guards** must be attacked
first. New creatures wait until your next turn to attack.

Click **End turn** when finished. Mana refills and its maximum increases each
turn, up to six. You draw a card each turn; a full seven-card hand discards
extra draws. An empty deck causes increasing fatigue damage.

Right-click to cancel selection. Click **Play again** after a duel to restart.
Press **Escape** or close the window to quit.
