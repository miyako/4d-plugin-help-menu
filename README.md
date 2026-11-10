![version](https://img.shields.io/badge/version-19%2B-5682DF)
![platform](https://img.shields.io/static/v1?label=platform&message=mac-intel%20|%20mac-arm%20|%20win-64&color=blue)
[![license](https://img.shields.io/github/license/miyako/4d-plugin-help-menu)](LICENSE)
![downloads](https://img.shields.io/github/downloads/miyako/4d-plugin-help-menu/total)
![deprecated](https://img.shields.io/badge/-deprecated-inactive)

Use [SET HELP MENU](https://blog.4d.com/create-a-help-menu-with-a-simple-collection/)

# 4d-plugin-help-menu

Forcefully disable the Help menu of the 4D application; use with caution! On macOS the plugin empties the AppKit Help menu and points `NSApp.helpMenu` at a menu that is not on the menu bar, which also removes the Spotlight help search field. On Windows it greys out the last menu of the MDI window's menu bar. Both commands work with a `Longint`.

| Command | Returns | Purpose |
|---|---|---|
| [HELP SET ENABLED](#help-set-enabled) | — | Disable (or, on Windows only, re-enable) the Help menu |
| [HELP Get enabled](#help-get-enabled) | `Longint` | Ask whether the Help menu is currently enabled |

**Platforms:** macOS (Apple silicon and Intel, 11.5 or later), Windows (64-bit). Requires 4D 19 or later.

[Releases](https://github.com/miyako/4d-plugin-help-menu/releases)

Maintainers: [manual source Bump and independent Build](.github/RELEASING.md),
including source authority, offline checks, and create-only publication recovery.
The [native ownership audit and synthetic regression](.github/tests/ownership/README.md)
document dormant helper fixes, bundled SDK contracts, and deferred boundaries.

---

## Requirements & platform notes

- **Deprecated.** 4D now has a built-in way to build the Help menu: [SET HELP MENU](https://blog.4d.com/create-a-help-menu-with-a-simple-collection/). Prefer it.
- **Disabling is one-way on macOS.** Enabling is not implemented on Mac: `HELP SET ENABLED(1)` does nothing there. Restart 4D to get the Help menu back.
- **Both commands always run in the 4D main process.** You can call them from any cooperative process, including a worker, but not from a preemptive process (the commands are not thread-safe).
- **Failure is silent.** Neither command raises a 4D error. If the plugin can't find the menu, nothing happens.
- **Timing matters, especially on Windows.** The menu bar may not exist yet, or may be replaced, during `On Startup`. Defer the call (the test database uses `CALL WORKER`, see the example below).

From [Apple's documentation of `NSApplication.helpMenu`](https://developer.apple.com/documentation/appkit/nsapplication/1428644-helpmenu): AppKit installs the Spotlight help items in a menu of its choosing, and specifying a menu that isn't on the menu bar suppresses them. The plugin does that, and also [removes all items](https://developer.apple.com/documentation/appkit/nsmenu/1518234-removeallitems?language=objc) of the Help menu.

---

## HELP SET ENABLED

### Syntax

```4d
HELP SET ENABLED ( enabled )
```

| Parameter | Type | Description |
|---|---|---|
| `enabled` | `Longint` | `0` to disable the Help menu, any other value to enable it (Windows only) |
| Result | — | none |

### Description

**On macOS**, `HELP SET ENABLED(0)` removes every item from the menu AppKit currently treats as the Help menu, then sets the application's Help menu to a new, empty menu with an empty title that is not on the menu bar. The original Help menu stays on the menu bar, but empty, and the Spotlight help search is gone. Any non-zero value does nothing: enabling is not implemented on Mac, so restart 4D to restore the menu.

**On Windows**, the command greys out (`0`) or re-enables (non-zero) the **last** top-level menu of the 4D MDI window's menu bar, and redraws the menu bar. The plugin assumes that the last menu is Help; if your menu bar ends with another menu, that one is affected instead. The MDI window is looked up once, when the plugin is loaded. When the plugin is unloaded (4D quits), it re-enables the menu.

If the window, the menu bar, or any menu is missing, the command does nothing. Since the review fixes in this version it returns early; before, it called the Windows menu API with an invalid position, which had no effect either.

### Example

From the test database's `CHECK` method:

```4d
SET MENU BAR:C67(1)

HELP SET ENABLED(1)
```

From the test database's `TEST` method, started from `On Startup` with `CALL WORKER:C1389(1; "TEST")`:

```4d
$enabled:=HELP Get enabled

HELP SET ENABLED(0)
```

Disable the menu only once:

```4d
If (HELP Get enabled=1)
	HELP SET ENABLED(0)
End if
```

---

## HELP Get enabled

### Syntax

```4d
HELP Get enabled → Longint
```

| Parameter | Type | Description |
|---|---|---|
| Result | `Longint` | `1` if the Help menu is enabled, `0` if it is disabled |

### Description

**On macOS**, the result is `0` when the application's Help menu has an empty title, which is the state [HELP SET ENABLED](#help-set-enabled)`(0)` leaves behind, and `1` otherwise, including when there is no Help menu at all.

**On Windows**, the result is `1` unless the menu item reports itself as disabled. When the MDI window or its menu bar can't be found, the result is `1`. The command looks the item up by command identifier, using the position of the last menu as the identifier, whereas [HELP SET ENABLED](#help-set-enabled) works by position. The result may therefore not reflect the state of the Help menu (inferred from the code, not tested in 4D).

### Example

```4d
var $enabled : Integer
$enabled:=HELP Get enabled
If ($enabled=0)
	ALERT("The Help menu is disabled.")
End if
```

---

## Error handling & troubleshooting

- **Nothing happens on Mac when enabling.** `HELP SET ENABLED(1)` is not implemented on macOS. Restart 4D.
- **The Help title is still on the Mac menu bar.** That is expected: the plugin empties the menu and detaches it from AppKit's help system, but does not remove the title.
- **The wrong menu is greyed out on Windows.** The plugin always targets the last menu of the menu bar. Make Help the last menu.
- **Nothing happens on Windows at startup.** The menu bar may not exist yet or may be rebuilt afterwards. Call the command later, for example from a worker (`CALL WORKER`) after `SET MENU BAR`.
- **HELP Get enabled disagrees with what you see on Windows.** See the note in [HELP Get enabled](#help-get-enabled): the state is read by identifier, not by position.
- **Not available in preemptive processes.** Both commands are declared not thread-safe; call them from a cooperative process.

---

## Quick reference

```4d
SET MENU BAR:C67(1)
If (HELP Get enabled=1)
	HELP SET ENABLED(0)  // Mac: permanent until 4D restarts
End if
HELP SET ENABLED(1)  // Windows only
```
