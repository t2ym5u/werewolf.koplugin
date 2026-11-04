# Changelog

## [1.1.1] - 2026-11-04

### Changed
- Uses less memory: the game loads when you open it, not when KOReader
  starts, so it no longer takes memory or startup time while unplayed.

## [1.1.0] - 2026-11-03

### Added
- Medieval, Space station and Pirate ship themes: 9 narration variants for
  every night and day step (was 2 to 5), in French and English — 207
  narration lines per theme and language instead of 76.

### Changed
- No narration line repeats within a game while another is left: once a
  theme's own lines for a step have all been read, the classic village's
  lines for that step are used before any repeat.
- The lines already heard are remembered from one game to the next (one
  memory per theme and language): a new game starts with the lines the
  table hasn't heard yet.

## [1.0.2] - 2026-11-02

### Changed
- Picks up game-common 1.10.0: the shared Tools → Games menu also lists
  the games' new "· multiplayer" entries under Party & quiz.

## [1.0.1] - 2026-11-02

### Changed
- Listed under **Tools → Games**, grouped by category, instead of its own
  entry in the Tools menu (game-common 1.9.1).

## [1.0.0] - 2026-10-30

### Added
- First release: a game master for the classic werewolf party game, 6 to 18
  players. Player names (remembered), suggested role composition per player
  count, editable with − / +.
- 22 roles: villager, werewolf, big bad wolf, accursed wolf-father, white
  werewolf, seer, witch, hunter, cupid and the lovers, guard, little girl,
  elder, village idiot, fox, raven, bear tamer, knight with the rusty sword,
  scapegoat, the two sisters, wild child, thief and pied piper; optional mayor
  election.
- Pass-the-reader role distribution with a neutral hand-over screen; night
  steps for each waking role with a narration to read aloud; dawn
  announcements, hunter's shot, debate timer and vote; win detection (village,
  werewolves, lovers, white werewolf, pied piper) and a full game log at the end.
- French and English content (narration variants, flavour lines, role cards)
  with five themes: Classic village, Famous village (famous aliases for every
  player), Medieval, Space station and Pirate ship.
- The game is saved after every step and resumes where it was left, never on
  a secret screen.
