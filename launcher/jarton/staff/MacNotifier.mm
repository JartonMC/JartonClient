// SPDX-License-Identifier: GPL-3.0-only
#include "jarton/staff/MacNotifier.h"

#import <Foundation/Foundation.h>
#import <UserNotifications/UserNotifications.h>

// Without a delegate, macOS suppresses banners while the app is frontmost —
// exactly when a staffer is most likely to be staring at the launcher.
@interface JartonNotifDelegate : NSObject <UNUserNotificationCenterDelegate>
@end

@implementation JartonNotifDelegate
- (void)userNotificationCenter:(UNUserNotificationCenter*)center
       willPresentNotification:(UNNotification*)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler
{
    completionHandler(UNNotificationPresentationOptionBanner | UNNotificationPresentationOptionSound);
}
@end

namespace Jarton::Mac {

static bool haveBundle()
{
    return [NSBundle mainBundle].bundleIdentifier != nil;
}

void requestNotificationPermission()
{
    if (!haveBundle()) {
        return;
    }
    @autoreleasepool {
        static JartonNotifDelegate* delegate = [[JartonNotifDelegate alloc] init];  // lives for the process
        UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
        center.delegate = delegate;
        [center requestAuthorizationWithOptions:(UNAuthorizationOptionAlert | UNAuthorizationOptionSound)
                              completionHandler:^(BOOL, NSError*) {
                              }];
    }
}

void postNotification(const QString& title, const QString& body)
{
    if (!haveBundle()) {
        return;
    }
    @autoreleasepool {
        UNMutableNotificationContent* content = [[[UNMutableNotificationContent alloc] init] autorelease];
        content.title = title.toNSString();
        content.body = body.toNSString();
        content.sound = [UNNotificationSound defaultSound];
        NSString* ident = [NSString stringWithFormat:@"jarton-staff-%llu", (unsigned long long)([[NSDate date] timeIntervalSince1970] * 1000)];
        UNNotificationRequest* req = [UNNotificationRequest requestWithIdentifier:ident content:content trigger:nil];
        [[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:req
                                                               withCompletionHandler:^(NSError*) {
                                                               }];
    }
}

}  // namespace Jarton::Mac
