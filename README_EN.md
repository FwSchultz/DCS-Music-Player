<div align="center">

  <img src="https://github.com/FwSchultz/assets/blob/main/bots/FwS-Bots/Bot.png" alt="Fw.Schultz Logo" width="200" height="auto" />

  <h1>DCS Music Player</h1>

  <p>A compact in-game music player for DCS World – listen to and control your own music without leaving the game.</p>

<p>
  <a href="README.md">Deutsch</a>
  <span> · </span>
  <strong>English</strong>
</p>

<p>
  <a href="https://github.com/FwSchultz/DCS-Music-Player/releases">
    <img src="https://img.shields.io/badge/version-v0.5.0-blue" alt="version" />
  </a>
  <a href="https://github.com/FwSchultz/DCS-Music-Player/commits/main">
    <img src="https://img.shields.io/github/last-commit/FwSchultz/DCS-Music-Player" alt="last update" />
  </a>
  <a href="https://github.com/FwSchultz/DCS-Music-Player/stargazers">
    <img src="https://img.shields.io/github/stars/FwSchultz/DCS-Music-Player" alt="stars" />
  </a>
  <a href="https://github.com/FwSchultz/DCS-Music-Player/issues">
    <img src="https://img.shields.io/github/issues/FwSchultz/DCS-Music-Player" alt="open issues" />
  </a>
  <img src="https://img.shields.io/badge/DCS%20World-2.9+-4b9cd3" alt="DCS World 2.9+" />
  <img src="https://img.shields.io/badge/Lua-DCS%20GUI-2c2d72" alt="Lua" />
</p>

<h4>
  <a href="#installation">Installation</a>
  <span> · </span>
  <a href="https://github.com/FwSchultz/DCS-Music-Player/issues">Report a bug</a>
  <span> · </span>
  <a href="https://github.com/FwSchultz/DCS-Music-Player/issues">Request a feature</a>
</h4>
</div>

<br />

<p align="center">
  <img src="docs/images/dcs-music-player-banner.png" alt="DCS Music Player Banner" width="1000" />
</p>

# Table of Contents

- [About the Project](#about-the-project)
- [Features](#features)
- [Screenshots](#screenshots)
- [Technology](#technology)
- [Project Structure](#project-structure)
- [Requirements](#requirements)
- [Installation](#installation)
- [Music and Playlists](#music-and-playlists)
- [Controls](#controls)
- [Automatic Track Progression](#automatic-track-progression)
- [Transparency](#transparency)
- [Configuration](#configuration)
- [Log File and Troubleshooting](#log-file-and-troubleshooting)
- [Updating](#updating)
- [Hotkeys](#hotkeys)
- [Notes and Known Limitations](#notes-and-known-limitations)
- [Credits](#credits)
- [License](#license)

---

## About the Project

**DCS Music Player** is a lightweight music player that runs directly inside the **DCS World** user interface. This allows you to control your own music while flying without leaving DCS or bringing another application to the foreground.

The project was inspired by the original **DCS-Walkman by Bailey** and was then rebuilt and expanded with its own implementation. Improvements include a new compact interface, multiple playlists, automatic track progression, shuffle, saved volume and configurable hover transparency.

The player is installed exclusively in the DCS **Saved Games** directory. Files in the actual DCS installation are not modified.

---

## Features

- Compact in-game music player
- Runs directly inside DCS World
- Support for **OGG** and **WAV**
- Multiple playlists via subfolders
- Automatic progression to the next track
- Previous / Play / Stop / Next controls
- Shuffle function
- Playlist selection directly in the player
- In-game volume slider
- Selected volume is saved
- Current track shown in the title bar
- Scrolling title for long filenames
- Freely movable player window
- Compact **328 px layout**
- Automatic hover transparency
- Configurable inactive and hover opacity
- Music can be added without rebuilding or reinstalling the player
- No external application required
- Installed in `Saved Games`, making it update-friendly
- Dedicated log file for troubleshooting

---

## Screenshots

### In the DCS Main Menu

<p align="center">
  <img src="docs/images/dcs-music-player-ingame.png" alt="DCS Music Player in the DCS main menu" width="1000" />
</p>

### Compact Player View

<p align="center">
  <img src="docs/images/dcs-music-player-player.png" alt="DCS Music Player compact view" width="500" />
</p>

---

## Technology

- **Language:** Lua
- **Environment:** DCS GUI / Saved Games hook
- **DCS version:** DCS World 2.9+
- **Audio:** OGG and WAV
- **Installation:** Saved Games only
- **Additional software:** not required
- **Configuration:** automatically generated `config.lua`
- **Platform:** Windows / DCS World

---

## Project Structure

```text
DCS-Music-Player/
├── Config/
│   └── DCS-Music-Player/
│       └── Music/
│           ├── Metal/
│           ├── Rock/
│           ├── Soundtracks/
│           ├── Top Gun/
│           └── Vietnam/
├── Scripts/
│   ├── DCS-Music-Player/
│   │   └── PlayerWindow.dlg
│   └── Hooks/
│       └── dcs-music-player-hook.lua
├── docs/
│   └── images/
├── .gitignore
└── README.md
```

The included playlist folders contain placeholders only. **No music files are distributed with this repository.**

---

## Requirements

- **DCS World 2.9 or newer** installed
- Access to your DCS `Saved Games` directory
- Your own music files in `.ogg` or `.wav` format

The player does not require an additional EXE, a separate music player or a background service.

---

## Installation

### 1. Download DCS Music Player

Download the latest version from the GitHub Releases page and extract the ZIP archive.

### 2. Copy the Files

Copy the included `Config` and `Scripts` folders into your DCS `Saved Games` directory.

Example for DCS:

```text
C:\Users\YOURNAME\Saved Games\DCS\
```

Depending on your installation, the folder may also be named for example:

```text
C:\Users\YOURNAME\Saved Games\DCS.openbeta\
```

Afterwards, these files in particular should exist:

```text
Saved Games\DCS\Scripts\Hooks\dcs-music-player-hook.lua
Saved Games\DCS\Scripts\DCS-Music-Player\PlayerWindow.dlg
```

### 3. Start DCS

Start DCS World. The Music Player should load automatically.

On first launch, the player creates its configuration automatically:

```text
Saved Games\DCS\Config\DCS-Music-Player\config.lua
```

---

## Music and Playlists

Your music is stored here:

```text
Saved Games\DCS\Config\DCS-Music-Player\Music\
```

Supported formats:

```text
.ogg
.wav
```

Music can be placed directly inside the `Music` folder. To create multiple playlists, use subfolders.

Example:

```text
Music\
├── Rock\
│   ├── song1.ogg
│   └── song2.ogg
├── Metal\
│   ├── song1.ogg
│   └── song2.ogg
├── Soundtracks\
│   └── song1.ogg
└── Vietnam\
    └── song1.ogg
```

Each direct subfolder is automatically detected as a separate playlist. Empty playlist folders are ignored.

> **Important:** Music files do not belong in the GitHub repository. The `.gitignore` blocks common audio formats as a precaution.

---

## Controls

| Symbol | Function |
|---|---|
| `◄◄` | Previous track |
| `►` | Play current track |
| `■` | Stop playback |
| `►►` | Next track |
| `⇄` | Shuffle |
| `≡` | Playlist menu |

The slider below the buttons controls music volume.

### Selecting a Playlist

Click `≡` to open the playlist selector. After a playlist is selected, the menu closes automatically.

Music folders are scanned when DCS starts.

---

## Automatic Track Progression

DCS Music Player reads the duration of supported OGG and WAV files. When a track finishes, the next track in the current playlist starts automatically.

This allows playlists to continue playing without manual input.

---

## Transparency

The player is designed to stay out of the way while flying.

By default:

```text
Mouse outside the player: 25% opacity
Mouse over the player:    100% opacity
```

These values can be changed in the automatically generated configuration file:

```text
Saved Games\DCS\Config\DCS-Music-Player\config.lua
```

Default:

```lua
inactiveOpacity = 0.25,
hoverOpacity = 1.00,
```

Other examples:

```lua
inactiveOpacity = 0.40,
hoverOpacity = 1.00,
```

or:

```lua
inactiveOpacity = 0.20,
hoverOpacity = 0.85,
```

The supported range is approximately:

```text
0.05 = 5%
1.00 = 100%
```

---

## Configuration

The configuration file is created automatically:

```text
Saved Games\DCS\Config\DCS-Music-Player\config.lua
```

It stores settings including:

- Volume
- Window position
- Window size
- Selected playlist
- Inactive opacity
- Hover opacity
- Auto-next settings
- Hotkey bindings

Most users should not need to edit this file manually.

---

## Log File and Troubleshooting

The player writes its own log file:

```text
Saved Games\DCS\Logs\DCS-Music-Player.log
```

If you encounter a problem, provide this file together with a short description of the issue.

Bugs and feature requests can be submitted through GitHub Issues:

https://github.com/FwSchultz/DCS-Music-Player/issues

---

## Updating

When updating, normally only these files need to be replaced:

```text
Saved Games\DCS\Scripts\Hooks\dcs-music-player-hook.lua
Saved Games\DCS\Scripts\DCS-Music-Player\PlayerWindow.dlg
```

Your own music and existing `config.lua` can remain untouched.

Before a major version upgrade, backing up the configuration file is still recommended.

---

## Hotkeys

The current version already includes configurable hotkeys. The default bindings are:

| Action | Hotkey |
|---|---|
| Show / hide player | `Ctrl + Shift + 8` |
| Stop | `Ctrl + Shift + 1` |
| Previous track | `Ctrl + Shift + 2` |
| Play | `Ctrl + Shift + 3` |
| Next track | `Ctrl + Shift + 4` |
| Shuffle | `Ctrl + Shift + 5` |
| Volume down | `Ctrl + Shift + 6` |
| Volume up | `Ctrl + Shift + 7` |
| Rescan music | `Ctrl + Shift + 9` |
| Previous playlist | `Ctrl + Shift + 0` |
| Next playlist | `Ctrl + Shift + -` |

The values are stored in `config.lua`.

---

## Notes and Known Limitations

- The player runs inside the DCS GUI environment.
- OGG and WAV are currently supported.
- The project is designed primarily for flatscreen use; VR compatibility may vary.
- If the original DCS-Walkman or another music-player hook is installed, its hook should be disabled to avoid conflicts.
- **Integrity Check Safe is currently not claimed** until the player has been tested on an IC-protected multiplayer server.

---

## Credits

Special thanks to **Bailey**, the developer of the original **DCS-Walkman**. His project was the inspiration and starting point for this community music player.

Original DCS-Walkman by Bailey:

https://files.digitalcombatsimulator.com/en/files/3322875/

DCS Music Player was independently rebuilt and expanded with a new interface, playlist management, automatic track progression, scrolling track titles, configurable hover transparency and other improvements.

Thank you Bailey for the original idea and for contributing to the DCS community.

---

## License

No license file has currently been defined for this repository. Until a license is added, the standard copyright terms of the repository owner apply.
