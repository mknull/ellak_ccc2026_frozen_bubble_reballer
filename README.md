# Frozen Bubble tools

Bash commands for CachyOS/Arch Linux and Debian/Ubuntu: install Frozen Bubble
and discover its ball assets, replace one normal ball and its miniature with a
tinted image, and launch the game with a webcam snapshot as a ball.

Platform scripts live in `archlinux/` and `debian/`.

## Setup

Arch / CachyOS:

```bash
sudo pacman -Syu --needed python-pillow
bash archlinux/install-frozen-bubble.sh
```

The setup command updates the system and installs Pillow. Run the installer as
your normal user: it skips installation if `pacman -Q frozen-bubble` succeeds.
Otherwise it installs from your configured repositories, or uses an existing
`paru`/`yay` helper if the package is unavailable there. Helper prompts remain
enabled. Repository/AUR availability is checked on your machine; the script does
not install a helper or silently refresh package databases.

Debian / Ubuntu:

```bash
sudo apt-get install python3-pil
bash debian/install-frozen-bubble.sh
```

The Debian installer installs `frozen-bubble` and `frozen-bubble-data` via apt
if they are missing, prompting for sudo when needed.

Both installers print ball GIF paths, including colourblind variants; miniature
PNGs are not part of this listing.
The replacement commands use Python 3 and Pillow internally (Pillow 9.1 or newer).

## Replace a ball

Close Frozen Bubble, then run:

```bash
# Arch / CachyOS
sudo bash archlinux/replace-frozen-bubble.sh /path/to/avatar.png red
# Debian / Ubuntu
sudo bash debian/replace-frozen-bubble.sh /path/to/avatar.png red
```

Each command replaces one pair.
The tint comes from the selected original ball, not directly from the supplied
color. Existing `.original` backups are used for color sampling on later runs.

The input must be a still image. It is converted to grayscale, tinted, fitted to
each original asset's dimensions without stretching, and padded with transparency.
An opaque image keeps its background; the script does not remove backgrounds.
Restart the game to load the changes. Package upgrades may overwrite replacements.

## Launch with a webcam snapshot

Debian / Ubuntu:

```bash
bash debian/launch-frozen-bubble.sh red
```

Declares the color first, snapshots the webcam with fswebcam at 1280x720 (saved
to `/tmp/frozen-bubble-ball.jpg`), replaces the matching ball with the tinted
snapshot, then launches the game. The replacement step prompts for sudo if the
asset directory is not writable. Requires `fswebcam`
(`sudo apt-get install fswebcam`). The game starts only if the snapshot and
replacement succeed.

## Help

```bash
bash archlinux/install-frozen-bubble.sh --help
bash archlinux/replace-frozen-bubble.sh --help
bash debian/replace-frozen-bubble.sh --help
bash debian/launch-frozen-bubble.sh --help
```

## Restore originals

Backups are created once alongside each modified asset as `FILE.original`.
For example, to restore slot 3 (adjust the directory to the discovered location):

```bash
assets=$(dirname "$(bash debian/install-frozen-bubble.sh | head -n 1)")
sudo cp -- "$assets/bubble-3.gif.original" "$assets/bubble-3.gif"
sudo cp -- "$assets/bubble-3-mini.png.original" "$assets/bubble-3-mini.png"
```
