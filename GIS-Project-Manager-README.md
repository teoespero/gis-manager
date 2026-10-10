# GIS Project Manager

**Author:** Teo Espero  
**Script:** `gis-project-manager.sh`  
**Current version:** 1.7  
**Updated:** October 10, 2026

## What it does

GIS Project Manager is a Bash terminal app that creates a folder structure for a GIS project. Browse to the location where you want to save your work, enter a project name, and add a description. The app creates the project folder, three subfolders, and a description text file.

The interface uses Unicode box characters, colored panels, and a highlighted folder selection. It runs inside a terminal and lets you browse using the arrow keys.

It sets up folders only. It does not download data, process GIS files, or create QGIS or ArcGIS project files. You place your data and project files in the folders afterward.

## Folder structure

For a project called **Forest Canopy**, created on October 10, 2026, the first project folder is:

`2026-1010-Forest Canopy-Version 001`

| Location inside the project folder | Purpose |
| --- | --- |
| `01_Raw_Data/` | Original downloads and source data, such as LAZ files, DEMs, imagery, and shapefiles. |
| `02_Processed/` | Data after clipping, cleaning, reprojecting, converting, or other processing. |
| `03_Outputs/` | Finished maps, reports, exported images, and other final results. |
| `Project_Description.txt` | Project name, author, creation timestamp, and your description. |

Each iteration gets its own empty subfolders and description file. Earlier files are not copied into a new iteration.

## Requirements

- Bash in an interactive terminal.
- Standard commands: `mkdir` and `date`.
- `tput` for detecting terminal size. If it is unavailable, the app uses an 80-column, 24-row fallback for the browser.
- A terminal and locale that support UTF-8, Unicode box characters, and ANSI escape sequences.
- Permission to create folders and files in the selected location.

No Python, GIS software, or graphical file chooser is required. The script does not install packages. A normal terminal window of at least 80 columns and 24 rows is recommended so the controls are easy to read.

## How to run it

Open a terminal in the folder containing the script and run:

```bash
bash gis-project-manager.sh
```

The browser starts in the terminal's current working directory. You can also supply an existing starting folder:

```bash
bash gis-project-manager.sh "$HOME/Documents/agsrt"
```

To run the script while your terminal is in another directory, provide its path:

```bash
bash "$HOME/Documents/bash-shell-scripts/gis-project-manager.sh" "$HOME/Documents"
```

Adjust the paths to match where you saved the script. The supplied starting folder must already exist.

## Creating a project

1. Start the app. The folder explorer appears first.
2. Use Up and Down to highlight a folder. Press Enter or Right to open it.
3. Continue browsing until the displayed location is where you want the new project saved.
4. Press **A** to create a project in that location.
5. Enter the project name. Spaces inside the name are allowed. A blank name cancels creation.
6. If a matching project exists in this location, answer whether this is another iteration. Enter **Y** to continue or **N** to cancel.
7. Review the full destination. Press Enter or enter **Y** to confirm; enter **N** to cancel.
8. Enter the description. Multiple lines and blank lines are allowed. Type a single period (`.`) on its own line to finish.
9. The app creates the folder structure and description file, then displays the result and full project path.
10. Press Enter to return to the main menu.

Once a save folder is selected, **N** on the main menu creates another project there. Use **P** to browse to another location.

## Folder explorer controls

Browser commands respond to a single key; you do not need to press Enter after letter commands.

| Key | Action |
| --- | --- |
| Up / Down | Move the highlighted selection. The list changes pages as you move beyond the visible entries. |
| Enter / Right | Open the highlighted folder. |
| Backspace / Left | Go to the parent folder. |
| A | Create a project in the folder currently being viewed. |
| S | Select the current folder and return to the main menu. |
| H | Browse your Home folder. |
| T | Type an existing directory path. Relative paths are resolved from the folder being viewed; `~` and `~/` are supported. |
| C / Q / Escape | Cancel browsing and return to the main menu. |

The browser lists accessible folders, including hidden folders. It does not list regular files or create new parent folders. The highlighted entry is the folder that Enter opens; **A creates in the displayed current location**, not inside the highlighted entry. Open the entry first if you want to create there.

## Main menu controls

Enter the letter and press Enter.

| Command | Action |
| --- | --- |
| N, or a blank command | Create a new project in the selected location. |
| P | Open the folder browser. |
| Q | Exit the app. |

Pressing Ctrl+C also exits. Canceling the browser does not exit the whole app.

## Project naming and versions

The folder name follows:

```text
YYYY-MMDD-<project name>-Version NNN
```

| Part | Meaning | Example |
| --- | --- | --- |
| `YYYY` | Four-digit year | `2026` |
| `MMDD` | Two-digit month followed by two-digit day | `1010` |
| `<project name>` | The name entered by the user | `Forest Canopy` |
| `NNN` | Three-digit version | `001` |

The date comes from the computer's local date when creating the project. A new name starts at `001`. For an existing name, the app finds the highest recognized version in the selected parent folder and adds one. It checks matching names across date prefixes, so a project created on a later day continues the numbering.

For example, if versions `001`, `002`, and `009` exist, the next iteration is `010`. It does not fill gaps. At version `999`, creation stops and asks you to use another name or location.

The app also recognizes the earlier naming formats, `<name> Project` and `<name> Project v<number>`, when choosing the next version. It leaves those folders unchanged.

Checks are limited to the selected parent folder, not its descendants or other save locations. Names are matched exactly and case-sensitively by the script. Version numbers are based on folders currently present; there is no separate version database.

## Description file

The description is entered line by line and saved in the root of the new project folder. A single period on its own line ends entry and is not saved. If you finish immediately, the file says `(No description provided.)`.

Example file contents:

```text
Project: 2026-1010-Forest Canopy-Version 001
Author: Teo Espero
Created: 2026-10-10 12:00:00 PDT

Description:
Estimate forest canopy height from LiDAR data.
Compare the terrain model with the surface model.
```

The author field is currently fixed as Teo Espero. The timestamp uses the computer's configured time zone. Each iteration has its own description file.

## How the code works

### Startup and selected location

```bash
BASE=${1:-"$PWD"}
BASE=$(cd -- "$BASE" && pwd -P) || exit 1
```

`BASE` holds the parent directory where projects will be created. The first command-line argument sets the starting location; otherwise, the app uses the current working directory. `pwd -P` resolves the location to an absolute physical path.

The script checks that the starting directory exists and that input and output are connected to a terminal. It then opens the browser before offering project creation.

### Browsing folders

`choose_folder()` collects accessible subdirectories into a Bash array. It tracks the current location, highlighted array index, and visible page. Enter changes the current location to the highlighted folder; Left or Backspace changes it to the parent directory.

```bash
IFS= read -rsn1 key || exit 0
```

This reads one key without echoing it. Arrow keys send escape sequences, which the function translates into selection or navigation actions. **A** stores the current directory in `BASE` and signals that project creation should start. **S** stores it and returns to the main menu.

### Checking the name and choosing a version

`new_project()` trims whitespace from the beginning and end of the name while keeping spaces inside it. It rejects slashes, backslashes, control characters, and the names `.` and `..`.

It checks recognized project names in `BASE`, tracks the highest version, and asks whether the new folder is another iteration when a match exists.

```bash
version=$((max+1))
stamp=$(date '+%Y-%m%d')
printf -v folder '%s-%s-Version %03d' "$stamp" "$name" "$version"
```

`%03d` pads the version number to three digits. For example, `3` becomes `003`. The new folder name combines this number with the date and project name.

### Creating folders and writing notes

```bash
mkdir -- "$target"
mkdir -- "$target/01_Raw_Data" "$target/02_Processed" "$target/03_Outputs"
```

The project root is created without `mkdir -p`, so creation fails if that destination already exists. Quoted paths preserve spaces; `--` marks the end of command options.

The description lines are held in a Bash array and written with `printf`, preserving blank lines. The file is written inside a subshell with `noclobber` enabled, so an existing description file cannot be silently overwritten.

If creation fails partway through, the app reports the problem. It does not automatically remove a partially created project folder.

### Drawing the interface and fixing padding

`border()` draws the corners, horizontal rules, and panel separators. `row()` draws each content row and adds the remaining spaces before the right border.

`cell_width()` estimates how many terminal cells a character occupies. Ordinary characters and box characters count as one cell, supported combining marks as zero, and common wide characters as two. This avoids the byte-based padding problem with Unicode text.

All boxed content uses the same row function, including colored headers and highlighted selections. Long text is clipped to the available width. The width is capped at 100 columns and normally leaves one terminal column unused to reduce wrapping.

The width calculation covers common text, but complex emoji sequences or terminal-specific character widths may still display differently. Clipping affects the display only; the full folder name and description remain stored.

### Restoring the terminal

The app uses an alternate terminal screen. Exit traps reset colors, show the cursor, and return to the previous terminal screen when the app exits normally or receives a handled interrupt.

## Troubleshooting

| Problem | What to check |
| --- | --- |
| Starting directory does not exist | Supply an existing folder or run without a starting path. |
| App says to use an interactive terminal | Run directly in a terminal rather than through redirected input or output. |
| Box characters appear incorrectly | Use a UTF-8 locale and a terminal font that includes box characters. |
| Controls or paths are clipped | Enlarge the terminal. Long paths are clipped in panels; the destination is also printed during confirmation. |
| Cannot create the project | Check write permission, available space, and whether the destination already exists. |
| Description could not be saved | Check permissions and available space. The project folders may already have been created. |
| Expected version is not found | Check that you selected the same parent folder and entered the same project name. |

## Revision history

| Version | Date | Change |
| --- | --- | --- |
| 1.0 | 2026-10-10 | Initial terminal interface and project folder creation. |
| 1.1 | 2026-10-10 | Folder browser and numbered iterations. |
| 1.2 | 2026-10-10 | Multiline descriptions saved as text. |
| 1.3 | 2026-10-10 | Date-prefixed names and three-digit versions. |
| 1.4 | 2026-10-10 | Browse first and create in the selected location. |
| 1.5 | 2026-10-10 | Unicode box interface. |
| 1.6 | 2026-10-10 | Explorer-style arrow-key navigation and highlighted selection. |
| 1.7 | 2026-10-10 | Display-width padding and consistent clipping for boxed rows. |
