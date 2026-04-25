#Requires AutoHotkey v2.0
#SingleInstance Force

; ============================================================================
; disable-winkey.ahk — free up the Windows key
;
; Goal: behave like Linux Super — Win does nothing on its own, and every
; Win+<key> combo Windows tries to claim is intercepted and discarded.
; The key remains available as a free modifier you can bind later.
;
; What this blocks:
;   - Win tapped alone           (no Start menu)
;   - Win + a-z                  (with/without Shift/Ctrl/Alt)
;   - Win + 0-9
;   - Win + F1-F12
;   - Win + Tab/Space/Enter/Esc/Backspace/Delete
;   - Win + Arrows
;   - Win + Home/End/PgUp/PgDn/Insert/PrintScreen/Pause
;   - Win + symbols  . , ; ' / \ [ ] - = `
;
; What CANNOT be blocked (Windows kernel reserves these):
;   - Win + L          (lock screen)
;   - Ctrl + Alt + Del (security desktop)
;   - Ctrl + Shift + Esc (Task Manager)
; ============================================================================

; --- Stop Win-tap from opening the Start menu --------------------------------
; (Win+<combo> hotkeys below are matched first, so Win still works as a modifier.)
LWin::return
RWin::return

; --- Helper: a no-op callback used by every blocked hotkey -------------------
NoOp(*) {
}

; --- Bulk-block Win + letters/digits/function keys ---------------------------
; The leading `*` means "any other modifier" — so Win+Shift+E, Win+Ctrl+E, etc.
; are all blocked by the same hotkey.
loop 26
    Hotkey "*#" Chr(96 + A_Index), NoOp        ; Win + a..z

loop 10
    Hotkey "*#" (A_Index - 1), NoOp            ; Win + 0..9

loop 12
    Hotkey "*#F" A_Index, NoOp                 ; Win + F1..F12

; --- Block Win + named keys --------------------------------------------------
namedKeys := [
    "Up", "Down", "Left", "Right",
    "Tab", "Space", "Enter", "Escape",
    "BackSpace", "Delete", "Insert",
    "Home", "End", "PgUp", "PgDn",
    "PrintScreen", "Pause", "AppsKey"
]
for key in namedKeys
    Hotkey "*#" key, NoOp

; --- Block Win + symbols -----------------------------------------------------
; (backtick is escaped as `` because ` is AHK's escape character)
symbols := [".", ",", ";", "'", "/", "\", "[", "]", "-", "=", "``"]
for sym in symbols
    Hotkey "*#" sym, NoOp

; ============================================================================
; ADD YOUR OWN BINDINGS BELOW
; ----------------------------------------------------------------------------
; Examples — uncomment to use:
;
; #j::Send "{Down 5}"            ; Win+J  -> jump 5 lines down (like nvim Alt+j)
; #k::Send "{Up 5}"              ; Win+K  -> jump 5 lines up
; #t::Run "wt.exe"               ; Win+T  -> open Windows Terminal
; #b::Run "msedge.exe"           ; Win+B  -> open browser
;
; Note: any custom binding here will OVERRIDE the bulk-block above for that
; specific combo, because more-specific hotkeys win.
; ============================================================================
