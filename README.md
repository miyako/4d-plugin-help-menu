![version](https://img.shields.io/badge/version-19%2B-5682DF)
![platform](https://img.shields.io/static/v1?label=platform&message=mac-intel%20|%20mac-arm%20|%20win-64&color=blue)
[![license](https://img.shields.io/github/license/miyako/4d-plugin-help-menu)](LICENSE)
![downloads](https://img.shields.io/github/downloads/miyako/4d-plugin-help-menu/total)
![deprecated](https://img.shields.io/badge/-deprecated-inactive)

Use [SET HELP MENU](https://blog.4d.com/create-a-help-menu-with-a-simple-collection/)

# 4d-plugin-help-menu
Forcefully disable the Help menu; use with caution!

On Mac: 

> AppKit installs Spotlight menu items on the menu of its choosing. To suppress Spotlight help items altogether, specify a menu that doesn’t appear on the menu bar.

https://developer.apple.com/documentation/appkit/nsapplication/1428644-helpmenu

Also [remove all items](https://developer.apple.com/documentation/appkit/nsmenu/1518234-removeallitems?language=objc) of the help menu.

Enabling is not implemented on Mac. you need to restart 4D.

On Windows:

Disable the Help menu of the MDI window.

You might need to defer the command on startup (see sample code) especially on Windows.
