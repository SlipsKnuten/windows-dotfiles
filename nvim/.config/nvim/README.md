# 💤 LazyVim

My [LazyVim](https://github.com/LazyVim/LazyVim) config. See the [documentation](https://lazyvim.github.io/installation) for the basics.

## Navigation cheatsheet

How to read the keys: `Ctrl+d` means hold Ctrl and press d. `Space h` means press Space, then h (Space is the leader key). `] f` means press `]`, then `f`. `Shift+J` is a capital J. A plain letter is just that key.

With kanata running (see the repo's root README), hold `s` for Ctrl and hold `d` for Shift, e.g. `Ctrl+d` = hold `s`, press `d`.

These are mostly the habits of ThePrimeagen, TJ DeVries and folke (the LazyVim author).

### Up and down

| Keys | What it does |
| --- | --- |
| a number, then `j` / `k` | Move that many lines down/up. Read the number off the gutter, which shows each line's distance from the cursor (e.g. `1` `2` `j`) |
| `Ctrl+d` / `Ctrl+u` | Half a page down/up, with the cursor kept in the middle of the screen |
| `}` / `{` | Next/previous blank line (jumps a whole block of code at a time) |
| `Shift+H` / `Shift+M` / `Shift+L` | Top/middle/bottom of the visible screen |
| `g g` / `Shift+G` | Start/end of the file |
| `z z` | Scroll so the cursor line is in the middle of the screen |
| `] f` / `[ f` | Next/previous function |
| `] c` / `[ c` | Next/previous class |
| `] ]` / `[ [` | Next/previous use of the word under the cursor |
| `] d` / `[ d` | Next/previous error or warning |
| `n` / `Shift+N` | Next/previous search match (centred) |
| `Alt+j` / `Alt+k` | 5 lines down/up |

### Sideways

| Keys | What it does |
| --- | --- |
| `f` + a letter | Jump onto the next occurrence of that letter on the line |
| `t` + a letter | Jump to just before it (handy with `d` / `c`, e.g. `d` `t` `)` deletes up to the bracket) |
| `Shift+F` / `Shift+T` + a letter | The same, backwards |
| `;` / `,` | Repeat the last `f`/`t` forward/backward |
| `w` / `b` / `e` | Next word / back a word / end of word (stops at punctuation) |
| `Shift+W` / `Shift+B` / `Shift+E` | The same, but a "word" is anything between spaces (much bigger steps) |
| `0` / `^` / `$` | Very start of the line / first non-blank character / end of the line |
| `Alt+h` / `Alt+l` | First non-blank character / end of the line |
| `%` | Jump to the matching bracket |

### Anywhere on the screen (flash)

| Keys | What it does |
| --- | --- |
| `s` + 2 letters | Labels appear on every match on screen. Press the label to jump there |
| `Shift+S` | Select a whole code block (function, if-statement, argument…) with labels |

### Files and buffers

| Keys | What it does |
| --- | --- |
| `Space Shift+H` | Pin the current file to Harpoon |
| `Space h` | Show and edit the pinned file list |
| `Space 1` … `Space 9` | Jump to pinned file 1–9 |
| `Space Space` | Find a file by name |
| `Alt+1` … `Alt+9` | Go to buffer tab 1–9 |
| `-` | File browser for the current folder (Oil) |

### Custom keys in this config

| Keys | What it does |
| --- | --- |
| `q` | Jump inside the next bracket or quote and start typing |
| `Alt+i` / `Alt+o` | Back/forward through go-to-definition/reference jumps |
| `Alt+r` | Reopen the last picker (e.g. the reference list) |
| `Ctrl+n` | Multicursor: select the word under the cursor, press again for the next match |
| `Shift+J` / `Shift+K` (in visual mode) | Move the selected lines down/up |
| `j` `j` | Leave insert/visual mode |

### Practicing

- Pick one new motion a week and use it on purpose until it's automatic.
- When you catch yourself pressing `Alt+j` several times in a row, look at the gutter and use a number + `j` instead.
- `:Tutor` is the built-in interactive tutorial.
- ThePrimeagen's [vim-be-good](https://github.com/ThePrimeagen/vim-be-good) is a game for drilling these motions.
