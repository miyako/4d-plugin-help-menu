#import <Foundation/Foundation.h>

// Only the entry translation unit sees this header: no AppKit is linked.
@interface AuditMenu : NSObject
@property(copy) NSString *title;
- (id)initWithTitle:(NSString *)title;
- (void)removeAllItems;
@end
@interface AuditApplication : NSObject
@property(retain) AuditMenu *helpMenu;
+ (AuditApplication *)sharedApplication;
@end
extern AuditApplication *auditApp;
#define NSMenu AuditMenu
#define NSApplication AuditApplication
#define NSApp auditApp
