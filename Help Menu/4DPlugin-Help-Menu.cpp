/* --------------------------------------------------------------------------------
 #
 #  4DPlugin-Help-Menu.cpp
 #	source generated by 4D Plugin Wizard
 #	Project : Help Menu
 #	author : miyako
 #	2022/10/11
 #
 # --------------------------------------------------------------------------------*/

#include "4DPlugin-Help-Menu.h"

#pragma mark -

namespace Help
{
#if VERSIONWIN

HWND mdiWindowRef;

bool isEnabled() {
    
    HMENU mdiHelpRef = GetMenu(Help::mdiWindowRef);
    UINT uId = GetMenuItemCount(mdiHelpRef) - 1;
    
    MENUITEMINFO mii = { 0 };
    mii.cbSize = sizeof(mii);
    mii.fMask = MIIM_STATE;
    GetMenuItemInfo(mdiHelpRef, uId, FALSE, &mii);
    return !(mii.fState & MFS_DISABLED);
}
#else

bool isEnabled() {
    
    NSMenu *helpMenu = [NSApp helpMenu];
    
    if(helpMenu)
    {
        return ![[helpMenu title]isEqualToString:@""];
    }
    
    return true;
}
#endif

void enable()
{
    
#if VERSIONMAC

    //not implemented
    
#else
    HMENU mdiHelpRef = GetMenu(Help::mdiWindowRef);
    UINT uId = GetMenuItemCount(mdiHelpRef) - 1;
    
    EnableMenuItem(mdiHelpRef, uId, MF_BYPOSITION | MF_ENABLED);
    DrawMenuBar(Help::mdiWindowRef);
#endif
}

void disable()
{
    
#if VERSIONMAC
    
    NSMenu *unusedMenu = [[NSMenu alloc] initWithTitle:@""];
    
    NSApplication *theApp = [NSApplication sharedApplication];
    
    [theApp.helpMenu removeAllItems];
    
    theApp.helpMenu = unusedMenu;
    [unusedMenu release];
    
    /*
     To suppress Spotlight help items altogether,
     specify a menu that doesn’t appear on the menu bar.
     https://developer.apple.com/documentation/appkit/nsapplication/1428644-helpmenu
     */
        
#else
    HMENU mdiHelpRef = GetMenu(Help::mdiWindowRef);
    UINT uId = GetMenuItemCount(mdiHelpRef) - 1;
    
    EnableMenuItem(mdiHelpRef, uId, MF_BYPOSITION | MF_GRAYED);
    DrawMenuBar(Help::mdiWindowRef);
#endif
}
}

#if VERSIONWIN

static HWND getMDI() {
    
    PA_ulong32 version = PA_Get4DVersion();
    
    if (version >= 16)
        return (HWND)PA_GetMainWindowHWND();
    
    // Altura MAc2Win does not allow multiple instances of the same app
    // we can assume that the window class is the folder name of the application
    
    HWND mdi = NULL;
    wchar_t path[_MAX_PATH] = { 0 };
    wchar_t * applicationPath = wcscpy(path, (const wchar_t *)PA_GetApplicationFullPath().fString);
    
    //remove file name (4D.exe)
    PathRemoveFileSpec(path);
    //check instance as well, to be sure
    HINSTANCE h = (HINSTANCE)PA_Get4DHInstance();
    
    do {
        mdi = FindWindowEx(NULL, mdi, (LPCTSTR)path, NULL);
        if (mdi)
        {
            if (h == (HINSTANCE)GetWindowLongPtr(mdi, GWLP_HINSTANCE))
            {
                break;
            }
        }
    } while (mdi);
    
    return mdi;
}

#endif

void OnStartup(){
    
#if VERSIONWIN
    Help::mdiWindowRef = getMDI();
#endif
    
}

void OnExit(){
    
    Help::enable();
    
}

void PluginMain(PA_long32 selector, PA_PluginParameters params) {
    
    try
    {
        switch(selector)
        {
                
            case kInitPlugin :
            case kServerInitPlugin :
                OnStartup();
                break;
                
            case kDeinitPlugin :
            case kServerDeinitPlugin :
                OnExit();
                break;
                
                // --- Help Menu
                
            case 1 :
                PA_RunInMainProcess((PA_RunInMainProcessProcPtr)HELP_SET_ENABLED, params);
                break;
            case 2 :
                PA_RunInMainProcess((PA_RunInMainProcessProcPtr)HELP_Get_enabled, params);
                break;
                
        }
        
    }
    catch(...)
    {
        
    }
}

#pragma mark -

void HELP_SET_ENABLED(PA_PluginParameters params) {
    
    if(PA_GetLongParameter(params, 1))
    {
        Help::enable();
    }else
    {
        Help::disable();
    }
}

void HELP_Get_enabled(PA_PluginParameters params) {
    
    PA_ReturnLong(params, Help::isEnabled());
    
}
