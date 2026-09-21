# Mooncard

A small, offline card game built with Lua and LÖVE, inspired by Hearthstone.
Duel the Warden, a simple computer opponent, with eight fantasy creatures
and two targeted spells.
Summon with mana, protect your hero with Guards, and reduce the opposing
hero from 20 health to zero. Both sides use the same 20-card deck, shuffled
independently, with two copies of each card.

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

Hover over a card in your hand or a creature on the board for a larger preview
with its ability, stats, and current status.

Click a creature card in your hand to summon it. Click a ready friendly creature,
then an enemy creature or hero to attack. Enemy **Guards** must be attacked
first. Guards have a shield badge and a pointed frame. The blue gem is mana
cost, the sword is attack, and the heart is remaining health. Each creature
has its own emblem and color. New creatures wait until your next turn to attack.

Click a spell, then a highlighted creature to cast it. **Ember Bolt** costs
2 mana and deals 3 damage to an enemy creature, ignoring Guard. **Mending Light**
costs 1 mana and heals a wounded friendly creature for up to 3 health, capped
at its starting health. Neither spell targets heroes. Selecting or cancelling
a spell spends no mana; a successful cast consumes the card.

Click **End turn** when finished. Mana refills and its maximum increases each
turn, up to six. You draw a card each turn; a full seven-card hand discards
extra draws. An empty deck causes increasing fatigue damage.

Right-click to cancel selection. Click **Play again** after a duel to restart.
Press **Escape** or close the window to quit.
