# Frozen Bubble tools

Two Bash commands for CachyOS/Arch Linux: install Frozen Bubble and discover its
ball assets, then replace one normal ball and its miniature with a tinted image.

## Setup

```bash
sudo pacman -Syu --needed python-pillow
./install-frozen-bubble.sh
```

The setup command updates the system and installs Pillow. Run the installer as
your normal user: it skips installation if `pacman -Q frozen-bubble` succeeds.
Otherwise it installs from your configured repositories, or uses an existing
`paru`/`yay` helper if the package is unavailable there. Helper prompts remain
enabled. Repository/AUR availability is checked on your machine; the script does
not install a helper or silently refresh package databases. It prints ball GIF paths, including
colourblind variants; miniature PNGs are not part of this listing.
The replacement command uses Python 3 and Pillow internally (Pillow 9.1 or newer).

## Replace a ball

Close Frozen Bubble, then run:

```bash
sudo ./replace-frozen-bubble.sh /path/to/avatar.png red
```

Each command replaces one pair.
The tint comes from the selected original ball, not directly from the supplied
color. Existing `.original` backups are used for color sampling on later runs.

The input must be a still image. It is converted to grayscale, tinted, fitted to
each original asset's dimensions without stretching, and padded with transparency.
An opaque image keeps its background; the script does not remove backgrounds.
Restart the game to load the changes. Package upgrades may overwrite replacements.

## Help

```bash
./install-frozen-bubble.sh --help
./replace-frozen-bubble.sh --help
```

Replacement help works without Pillow installed and shows the script name,
arguments, examples, dependencies, color selection, and backup behavior.

## Restore originals

Backups are created once alongside each modified asset as `FILE.original`.
For example, to restore slot 3 (adjust the directory to the discovered location):

```bash
assets=$(dirname "$(./install-frozen-bubble.sh | head -n 1)")
sudo cp -- "$assets/bubble-3.gif.original" "$assets/bubble-3.gif"
sudo cp -- "$assets/bubble-3-mini.png.original" "$assets/bubble-3-mini.png"
```
