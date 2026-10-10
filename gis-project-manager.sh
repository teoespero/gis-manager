#!/usr/bin/env bash
# GIS Project Manager
# Author: Teo Espero
# Revision history:
# 1.7 | 2026-10-10 | Correct Unicode padding and clip every boxed row.
# 1.6 | 2026-10-10 | Explorer-style folder selection with arrow keys.
# 1.5 | 2026-10-10 | Unicode box-drawing interface.
# 1.4 | 2026-10-10 | Browse first and create directly in the selected folder.
# 1.3 | 2026-10-10 | YYYY-MMDD-name-Version 001 folder naming.
# 1.2 | 2026-10-10 | Multiline project descriptions saved as text.
# 1.1 | 2026-10-10 | Folder browser and numbered project iterations.
# 1.0 | 2026-10-10 | IDE-style terminal interface and project folder creation.
# Usage: bash gis-project-manager.sh [parent-directory]
# Requires Bash and mkdir. No GIS software or additional packages needed.

set -u
BASE=${1:-"$PWD"}
if [[ ! -d "$BASE" ]]; then
    printf 'Parent directory does not exist: %s\n' "$BASE" >&2
    exit 1
fi
BASE=$(cd -- "$BASE" && pwd -P) || exit 1
if [[ ! -t 0 || ! -t 1 ]]; then
    printf 'Run this app in an interactive terminal.\n' >&2
    exit 1
fi

CYAN=$'\033[36m'; BLUE=$'\033[44m'; GREEN=$'\033[32m'
YELLOW=$'\033[33m'; RESET=$'\033[0m'; BOLD=$'\033[1m'
STATUS='Ready. Enter a project name to begin.'
PROJECT='(no project selected)'
WIDTH=78
BROWSER_CREATE=0

# Use an alternate screen so the previous terminal contents return on exit.
cleanup() { printf '\033[0m\033[?25h\033[?1049l'; }
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM HUP
printf '\033[?1049h'

border() {
    local i left='├' right='┤'
    case "${1:-middle}" in
        top) left='┌'; right='┐' ;;
        bottom) left='└'; right='┘' ;;
    esac
    printf '%s%s' "$CYAN" "$left"
    for ((i=0; i<WIDTH-2; i++)); do printf '─'; done
    printf '%s%s\n' "$right" "$RESET"
}
# Count terminal cells rather than the byte length used by printf padding.
# Covers box characters, combining accents, and common wide Unicode text.
cell_width() {
    local code
    printf -v code '%d' "'$1"
    CELL_WIDTH=1
    if ((code<32 || (code>=127 && code<160))); then
        CELL_WIDTH=0
    elif (( (code>=0x300 && code<=0x36f) || (code>=0x1ab0 && code<=0x1aff) ||
            (code>=0x1dc0 && code<=0x1dff) || (code>=0xfe00 && code<=0xfe0f) ||
            (code>=0xfe20 && code<=0xfe2f) )); then
        CELL_WIDTH=0
    elif (( (code>=0x1100 && code<=0x115f) || (code>=0x2e80 && code<=0xa4cf) ||
            (code>=0xac00 && code<=0xd7a3) || (code>=0xf900 && code<=0xfaff) ||
            (code>=0xfe10 && code<=0xfe19) || (code>=0xfe30 && code<=0xfe6f) ||
            (code>=0xff01 && code<=0xff60) || (code>=0xffe0 && code<=0xffe6) ||
            (code>=0x1f300 && code<=0x1faff) || (code>=0x20000 && code<=0x3fffd) )); then
        CELL_WIDTH=2
    fi
}
row() {
    local value=$1 style=${2:-} clipped='' char i used=0 limit=$((WIDTH-4))
    for ((i=0; i<${#value}; i++)); do
        char=${value:i:1}
        cell_width "$char"
        # Drop control characters; color codes are supplied separately.
        if [[ $char =~ [[:cntrl:]] ]]; then continue; fi
        ((used+CELL_WIDTH>limit)) && break
        clipped+=$char
        used=$((used+CELL_WIDTH))
    done
    printf '%s│%s%s %s%*s %s%s│%s\n' "$CYAN" "$RESET" "$style" \
        "$clipped" "$((limit-used))" '' "$RESET" "$CYAN" "$RESET"
}

draw() {
    local cols
    cols=$(tput cols 2>/dev/null) || cols=80
    [[ $cols =~ ^[0-9]+$ ]] || cols=80
    WIDTH=$((cols > 101 ? 100 : cols-1))
    ((WIDTH < 6)) && WIDTH=6
    printf '\033[H\033[2J'
    border top
    row 'GIS PROJECT MANAGER | v1.7' "$BLUE$BOLD"
    border
    row 'WORKSPACE                         Author: Teo Espero'
    row "Parent: $BASE"
    border
    row 'EXPLORER / FOLDER PREVIEW'
    row "$PROJECT"
    row '    ├── 01_Raw_Data    - Original downloads and source data'
    row '    ├── 02_Processed   - Cleaned, clipped, and converted data'
    row '    ├── 03_Outputs     - Final maps, reports, and exports'
    row '    └── Project_Description.txt - Project notes'
    border
    row 'CONSOLE'
    row "$STATUS"
    border
    row '[N] New project   [P] Browse folders   [Q] Quit'
    border bottom
    printf '\n'
}
ask() {
    printf '%s%s%s' "$GREEN" "$1" "$RESET"
    IFS= read -r REPLY || exit 0
}

choose_folder() {
    BROWSER_CREATE=0
    local current=$BASE entry key extra selected=0 offset=0 total i label cols rows page_size
    local -a folders=()
    while :; do
        folders=()
        for entry in "$current"/* "$current"/.[!.]* "$current"/..?*; do
            [[ -d $entry && -r $entry && -x $entry ]] && folders+=("$entry")
        done
        total=${#folders[@]}
        ((selected >= total)) && selected=$((total-1))
        ((selected < 0)) && selected=0
        cols=$(tput cols 2>/dev/null) || cols=80
        rows=$(tput lines 2>/dev/null) || rows=24
        [[ $cols =~ ^[0-9]+$ ]] || cols=80
        [[ $rows =~ ^[0-9]+$ ]] || rows=24
        WIDTH=$((cols > 101 ? 100 : cols-1))
        ((WIDTH<6)) && WIDTH=6
        page_size=$((rows-13))
        ((page_size<3)) && page_size=3
        offset=$((selected/page_size*page_size))
        printf '\033[H\033[2J\033[?25l'
        border top
        row 'GIS PROJECT MANAGER | FOLDER EXPLORER | v1.7'
        border
        row "Location: $current"
        border
        row '     NAME                                      TYPE'
        for ((i=offset; i<total && i<offset+page_size; i++)); do
            label=${folders[i]##*/}
            # Escape unusual filenames so they cannot control the terminal.
            printf -v label '%q' "$label"
            if ((i==selected)); then
                row "> [DIR] $label" $'\033[7m'
            else
                row "  [DIR] $label"
            fi
        done
        ((total==0)) && row '(No accessible subfolders)'
        border
        row 'Up/Down: select | Enter/Right: open | Left/Backspace: up'
        row '[A] Create project here  [S] Select current folder'
        row '[H] Home  [T] Type path  [C] Cancel'
        row "Folders: $total | Page $((offset/page_size+1))"
        border bottom
        printf '%sNavigate to the save folder, then press A.%s' "$GREEN" "$RESET"
        IFS= read -rsn1 key || exit 0
        if [[ $key == $'\033' ]]; then
            extra=''
            IFS= read -rsn1 -t 0.15 extra || true
            if [[ $extra == '[' || $extra == 'O' ]]; then
                IFS= read -rsn1 -t 0.15 extra || true
                case "$extra" in
                    A) key='UP' ;; B) key='DOWN' ;;
                    C) key='OPEN' ;; D) key='PARENT' ;;
                    *) key='' ;;
                esac
            else
                key='c'
            fi
        elif [[ -z $key ]]; then
            key='OPEN'
        elif [[ $key == $'\177' || $key == $'\b' ]]; then
            key='PARENT'
        fi
        case "$key" in
            UP) ((selected>0)) && selected=$((selected-1)) ;;
            DOWN) ((selected+1<total)) && selected=$((selected+1)) ;;
            OPEN)
                if ((total)); then
                    current=$(cd -- "${folders[selected]}" && pwd -P) || return 1
                    selected=0
                fi ;;
            PARENT) current=$(cd -- "$current/.." && pwd -P) || return 1; selected=0 ;;
            a|A) BASE=$current; BROWSER_CREATE=1; STATUS='Create a project in this folder.'; printf '\033[?25h'; return 0 ;;
            s|S) BASE=$current; STATUS='Save location selected.'; printf '\033[?25h'; return 0 ;;
            c|C|q|Q) STATUS='Folder selection canceled.'; printf '\033[?25h'; return 1 ;;
            h|H) current=$HOME; selected=0 ;;
            t|T)
                printf '\033[?25h\n'
                ask 'Directory path: '
                entry=$REPLY
                [[ $entry == '~' ]] && entry=$HOME
                [[ $entry == '~/'* ]] && entry="$HOME/${entry:2}"
                [[ $entry != /* ]] && entry="$current/$entry"
                if [[ -d $entry && -r $entry && -x $entry ]]; then
                    current=$(cd -- "$entry" && pwd -P) || return 1
                    selected=0
                else
                    printf 'That folder is unavailable.\n'
                    ask 'Press Enter to continue: '
                fi ;;
        esac
    done
}

new_project() {
    local name target answer error entry suffix max=0 version found=0 line stamp folder prefix
    local -a description=()
    draw
    printf 'Create project in: %s\n\n' "$BASE"
    ask 'Project name (blank cancels): '
    name=$REPLY
    # Trim surrounding whitespace; retain spaces inside the project name.
    name="${name#"${name%%[![:space:]]*}"}"
    name="${name%"${name##*[![:space:]]}"}"
    [[ -z $name ]] && return
    if [[ $name == */* || $name == *\\* || $name =~ [[:cntrl:]] || $name == '.' || $name == '..' ]]; then
        STATUS='Invalid name: do not use slashes, control characters, . or ..'
        return
    fi
    if [[ -e "$BASE/$name Project" || -L "$BASE/$name Project" ]]; then
        found=1
        max=1
    fi
    # Recognize numbered iterations even if the original was moved or deleted.
    for entry in "$BASE/$name Project v"*; do
        [[ -e $entry || -L $entry ]] || continue
        suffix=${entry#"$BASE/$name Project v"}
        if [[ $suffix =~ ^[1-9][0-9]{0,8}$ ]]; then
            found=1
            version=$((10#$suffix))
            ((version>max)) && max=$version
        fi
    done
    # Match the exact project name across dates; quoted glob text is literal.
    for entry in "$BASE"/????-????-"$name"-Version\ *; do
        [[ -e $entry || -L $entry ]] || continue
        folder=${entry##*/}
        prefix=${folder:0:10}
        [[ $prefix =~ ^[0-9]{4}-[0-9]{4}-$ ]] || continue
        suffix=${folder#"$prefix$name-Version "}
        if [[ $suffix =~ ^[0-9]{3}$ ]]; then
            found=1
            version=$((10#$suffix))
            ((version>max)) && max=$version
        fi
    done
    if ((found)); then
        draw
        printf 'A project named "%s" already exists in this location.\n' "$name"
        ask 'Is this another iteration of the project? [y/N]: '
        case "$REPLY" in
            y|Y|yes|YES)
                : ;;
            *) STATUS='Creation canceled. Choose another project name.'; return ;;
        esac
    fi
    if ((max>=999)); then
        STATUS='Version limit reached (999). Choose another name or location.'
        return
    fi
    version=$((max+1))
    stamp=$(date '+%Y-%m%d') || { STATUS='Could not read the current date.'; return; }
    printf -v folder '%s-%s-Version %03d' "$stamp" "$name" "$version"
    target="$BASE/$folder"
    PROJECT="$folder/"
    draw
    printf 'Full destination: %s\n\n' "$target"
    ask 'Create this project? [Y/n]: '
    answer=$REPLY
    case "$answer" in ''|y|Y|yes|YES) ;; *) STATUS='Creation canceled.'; return ;; esac
    printf '\nEnter a project description (multiple lines allowed).\n'
    printf 'Type a single period (.) on its own line to finish.\n'
    printf 'Enter . immediately to leave the description blank.\n\n'
    while :; do
        ask '> '
        line=$REPLY
        [[ $line == '.' ]] && break
        description+=("$line")
    done
    # Create the project exclusively; never merge into an existing folder.
    if ! error=$(mkdir -- "$target" 2>&1); then
        STATUS="Could not create project: $error"
        return
    fi
    if error=$(mkdir -- "$target/01_Raw_Data" "$target/02_Processed" "$target/03_Outputs" 2>&1); then
        if (
            # Exclusive write protects a file created by another process.
            set -o noclobber
            {
                printf 'Project: %s\n' "${target##*/}"
                printf 'Author: Teo Espero\n'
                printf 'Created: %s\n\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')"
                printf 'Description:\n'
                if ((${#description[@]})); then
                    printf '%s\n' "${description[@]}"
                else
                    printf '(No description provided.)\n'
                fi
            } > "$target/Project_Description.txt"
        ); then
            STATUS="Created: ${target##*/} (folders and description saved)."
        else
            STATUS='Folders created, but the description could not be saved.'
        fi
    else
        STATUS="Incomplete project: $error"
    fi
    draw
    printf '\n%s\n%s\n' "$STATUS" "Full path: $target"
    ask 'Press Enter to return to the menu: '
}

# Start with navigation. Project creation uses the folder currently selected.
if choose_folder && ((BROWSER_CREATE)); then
    new_project
fi
while :; do
    draw
    ask 'Command [N/P/Q]: '
    case "$REPLY" in
        n|N|'') new_project ;;
        p|P)
            if choose_folder; then
                PROJECT='(no project selected)'
                ((BROWSER_CREATE)) && new_project
            fi ;;
        q|Q) exit 0 ;;
        *) STATUS='Choose N, P, or Q.' ;;
    esac
done
