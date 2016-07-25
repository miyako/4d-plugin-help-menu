# 4d-plugin-help-menu
Forcefully disable the Help menu; use with caution!

##Platform

| carbon | cocoa | win32 | win64 |
|:------:|:-----:|:---------:|:---------:|
|🆗|🆗|🆗|🆗|

Commands
---

```c
// --- Help Menu
HELP_SET_ENABLED
HELP_Get_enabled
```

Examples
---

```
HELP SET ENABLED (False)
$enabled:=HELP Get enabled 
TRACE
HELP SET ENABLED (True)
$enabled:=HELP Get enabled 
```

About
---
Cocoa code is used for v14 and 64 bits. Carbon code for older 4D.
