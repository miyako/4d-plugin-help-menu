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
    BOOL isHelpDisabled;

#if VERSIONWIN
    HWND mdiWindowRef;
#endif
    
    void enable()
    {
        if(Help::isHelpDisabled)
        {
#if VERSIONMAC
        //cocoa
        NSMenu *helpMenu = [NSApp helpMenu];
        if(helpMenu)
        {
            for(NSUInteger i = 0; i <[helpMenu numberOfItems]; ++i)
            {
                [helpMenu itemAtIndex:i].hidden = false;
            }
        }
#else
        HMENU mdiHelpRef = GetMenu(Help::mdiWindowRef);
        EnableMenuItem(mdiHelpRef, GetMenuItemCount(mdiHelpRef)-1, MF_BYPOSITION | MF_ENABLED);
        DrawMenuBar(Help::mdiWindowRef);
#endif
        Help::isHelpDisabled = false;
        }
    }
    
    void disable()
    {
        
#if VERSIONMAC
        //cocoa
           
        NSMenu *unusedMenu;
        unusedMenu = [[NSMenu alloc] initWithTitle:[[NSUUID UUID]UUIDString]];

        NSApplication *theApp;
        theApp = [NSApplication sharedApplication];
        theApp.helpMenu = unusedMenu;
                
        /*
         To suppress Spotlight help items altogether,
         specify a menu that doesn’t appear on the menu bar.
         https://developer.apple.com/documentation/appkit/nsapplication/1428644-helpmenu
         */
                
#else
        if(!Help::isHelpDisabled)
        {
            HMENU mdiHelpRef = GetMenu(Help::mdiWindowRef);
            EnableMenuItem(mdiHelpRef, GetMenuItemCount(mdiHelpRef)-1, MF_BYPOSITION | MF_DISABLED);
            DrawMenuBar(Help::mdiWindowRef);
        }
        
#endif
        Help::isHelpDisabled = true;
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
    
    Help::isHelpDisabled = false;
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
				HELP_Get_enabled(params);
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

    PA_ReturnLong(params, !Help::isHelpDisabled);
    
}

