///////////////////////////////////////////////////////////////////////////////
// Name:        src/osx/notifmsg.cpp
// Purpose:     implementation of wxNotificationMessage for OSX
// Author:      Tobias Taschner
// Created:     2015-08-06
// Copyright:   (c) 2015 wxWidgets development team
// Licence:     wxWindows licence
///////////////////////////////////////////////////////////////////////////////

// ============================================================================
// declarations
// ============================================================================

// ----------------------------------------------------------------------------
// headers
// ----------------------------------------------------------------------------

// for compilers that support precompilation, includes "wx.h".
#include "wx/wxprec.h"

#import <UserNotifications/UserNotifications.h>

#include "wx/notifmsg.h"

#if wxUSE_NOTIFICATION_MESSAGE && defined(wxHAS_NATIVE_NOTIFICATION_MESSAGE)

#ifndef WX_PRECOMP
    #include "wx/string.h"
#endif // WX_PRECOMP

#include "wx/osx/private.h"
#include "wx/osx/private/available.h"
#include "wx/private/notifmsg.h"
#include "wx/timer.h"
#include "wx/platinfo.h"
#include "wx/artprov.h"
#include "wx/vector.h"
#include "wx/stockitem.h"

#include "wx/utils.h"
#include <map>

@interface wxUserNotificationHandler : NSObject<UNUserNotificationCenterDelegate>
@end

// ----------------------------------------------------------------------------
// wxUserNotificationMsgImpl
// ----------------------------------------------------------------------------

class wxUserNotificationMsgImpl : public wxNotificationMessageImpl
{
public:
    wxUserNotificationMsgImpl(wxNotificationMessageBase* notification) :
        wxNotificationMessageImpl(notification)
    {
        UseHandler();

        m_notif = [[UNMutableNotificationContent alloc] init];
        //m_notif.sound = [UNNotificationSound defaultSound];

        // Build Id to unqiuely idendify this notification
        m_id = wxString::Format("%d_%d", (int)wxGetProcessId(), ms_notifIdBase++);
        
        // Register the notification
        ms_activeNotifications[m_id] = this;
        
        wxCFStringRef cfId(m_id);
    }

    virtual ~wxUserNotificationMsgImpl()
    {
        ms_activeNotifications[m_id] = NULL;
        ReleaseHandler();
        [m_notif release];
    }

    virtual bool Show(int WXUNUSED(timeout)) wxOVERRIDE
    {
        NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
        NSLog(@"Bundle Identifier: %@", bundleIdentifier);

        if (bundleIdentifier == nil)
        {
            NSLog(@"Skipping UNUserNotificationCenter: bundleIdentifier is nil.");
            return false;
        }

        UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];

        [center requestAuthorizationWithOptions:(UNAuthorizationOptionAlert | UNAuthorizationOptionSound)
                              completionHandler:^(BOOL granted, NSError * _Nullable error)
        {
            if (granted)
            {
                NSLog(@"Разрешение получено");
            }
            else
            {
                 NSLog(@"Разрешение отклонено");
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSAlert *alert = [[NSAlert alloc] init];
                    [alert setMessageText:@"Notifications are disabled"];
                    [alert setInformativeText:@"Turn on notifications for the app in System Preferences."];
                    [alert addButtonWithTitle:@"Open Settings"];
                    [alert addButtonWithTitle:@"Cancel"];

                    if ([alert runModal] == NSAlertFirstButtonReturn) {
                        [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.notifications"]];
                    }
                });
            }
        }];

        if ( ms_handler && !m_action.empty() )
        {
            wxCFStringRef cfmsg(m_action);
            [ ms_handler openURLAfterClick:cfmsg.AsNSString() ];
        }

        UNTimeIntervalNotificationTrigger *trigger = [UNTimeIntervalNotificationTrigger triggerWithTimeInterval:1 repeats:NO];

        UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:@"PixelTakenNotification"
                                                                              content:m_notif
                                                                              trigger:trigger];

        [center addNotificationRequest:request withCompletionHandler:^(NSError * _Nullable error)
        {
            if (error)
            {
                NSLog(@"Error scheduling notification: %@", error);
            }
        }];

//        [nc deliverNotification:m_notif];
        return true;
    }
    
    virtual bool Close() wxOVERRIDE
    {
//        UNUserNotificationCenter* nc = [UNUserNotificationCenter currentNotificationCenter];
//        [nc removeDeliveredNotification:m_notif];
        
        return true;
    }
    
    virtual void SetTitle(const wxString& title) wxOVERRIDE
    {
        wxCFStringRef cftitle(title);
        m_notif.title = cftitle.AsNSString();
    }
    
    virtual void SetMessage(const wxString& message) wxOVERRIDE
    {
        wxCFStringRef cfmsg(message);
        m_notif.subtitle = cfmsg.AsNSString();
    }
    
    virtual void SetParent(wxWindow *WXUNUSED(parent)) wxOVERRIDE
    {
    }
    
    virtual void SetFlags(int WXUNUSED(flags)) wxOVERRIDE
    {
        // On OS X we do not add an icon based on the flags,
        // as this is primarily meant for custom icons
    }
    
    virtual void SetIcon(const wxIcon& icon) wxOVERRIDE
    {
//        m_notif.contentImage = icon.GetNSImage();
    }
    
    virtual bool AddAction(wxWindowID actionid, const wxString &label) wxOVERRIDE
    {
        wxCFStringRef cflabel(label);
        m_notif.userInfo = @{@"folderPath": cflabel.AsNSString()}; // Путь к папке;
#if 0
        if (m_actions.size() >= 1) // Currently only 1 actions are supported
            return false;
        
        wxString strLabel = label;
        if (strLabel.empty())
            strLabel = wxGetStockLabel(actionid, wxSTOCK_NOFLAGS);
        wxCFStringRef cflabel(strLabel);
        
        m_actions.push_back(actionid);
        
        if (m_actions.size() == 1)
//            m_notif.actionButtonTitle = cflabel.AsNSString();
#endif
        return true;
    }
    
//    void Activated(NSUserNotificationActivationType activationType)
//    {
//        switch (activationType)
//        {
//            case NSUserNotificationActivationTypeNone:
//            {
//                wxCommandEvent evt(wxEVT_NOTIFICATION_MESSAGE_DISMISSED);
//                ProcessNotificationEvent(evt);
//                break;
//            }
//            case NSUserNotificationActivationTypeContentsClicked:
//            {
//                wxCommandEvent evt(wxEVT_NOTIFICATION_MESSAGE_CLICK);
//                ProcessNotificationEvent(evt);
//                Close();
//                break;
//            }
//            case NSUserNotificationActivationTypeActionButtonClicked:
//            {
//                if (m_actions.empty())
//                {
//                    // Without actions the action button is handled as a message click
//                    wxCommandEvent evt(wxEVT_NOTIFICATION_MESSAGE_CLICK);
//                    ProcessNotificationEvent(evt);
//                }
//                else
//                {
//                    wxCommandEvent evt(wxEVT_NOTIFICATION_MESSAGE_ACTION);
//                    evt.SetId(m_actions[0]);
//                    ProcessNotificationEvent(evt);
//                }
//                Close();
//                break;
//            }

//            default:
//                break;
//        };
//    }
    
//    static void NotificationActivated(const wxString& notificationId, NSUserNotificationActivationType activationType)
//    {
//        wxUserNotificationMsgImpl* impl = ms_activeNotifications[notificationId];
//        if (impl)
//            impl->Activated(activationType);
//    }
    
    static void UseHandler()
    {
        if (!ms_handler)
        {
            @try
            {
                NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
                NSLog(@"Bundle Identifier: %@", bundleIdentifier);

                if (bundleIdentifier != nil)
                {
                    ms_handler = [wxUserNotificationHandler alloc];
                    [UNUserNotificationCenter currentNotificationCenter].delegate = ms_handler;
                }
                else
                {
                    NSLog(@"Skipping UNUserNotificationCenter: bundleIdentifier is nil.");
                }
            }
            @catch (NSException *exception)
            {
                NSLog(@"Exception caught: %@", exception);
            }
        }
    }
    
    static void ReleaseHandler()
    {
        
    }

private:
    UNMutableNotificationContent* m_notif;
    wxString m_id;
    wxString m_action;
    wxVector<wxWindowID> m_actions;
    
    static wxUserNotificationHandler* ms_handler;
    static std::map<wxString, wxUserNotificationMsgImpl*> ms_activeNotifications;
    static int ms_notifIdBase;
};

wxUserNotificationHandler* wxUserNotificationMsgImpl::ms_handler = nil;
std::map<wxString, wxUserNotificationMsgImpl*> wxUserNotificationMsgImpl::ms_activeNotifications;
int wxUserNotificationMsgImpl::ms_notifIdBase = 1000;

// ----------------------------------------------------------------------------
// wxUserNotificationHandler
// ----------------------------------------------------------------------------

@implementation wxUserNotificationHandler

// Delegate method to handle notification delivery
- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler
{
    // Show the notification even if the app is active
    completionHandler(UNNotificationPresentationOptionAlert + UNNotificationPresentationOptionSound);
}

// Delegate method to handle notification interaction
- (void)userNotificationCenter:(UNUserNotificationCenter *)center
didReceiveNotificationResponse:(UNNotificationResponse *)response
         withCompletionHandler:(void (^)(void))completionHandler
{
    NSLog(@"Notification clicked with identifier: %@", response.notification.request.identifier);

    NSDictionary *userInfo = response.notification.request.content.userInfo;
    NSString *folderPath = userInfo[@"folderPath"];
    if (folderPath) {
        NSString *expandedPath = [folderPath stringByExpandingTildeInPath];
        [[NSWorkspace sharedWorkspace] openFile:expandedPath];
    }

    completionHandler();
}

@end

// ============================================================================
// implementation
// ============================================================================


// ----------------------------------------------------------------------------
// wxNotificationMessage
// ----------------------------------------------------------------------------

void wxNotificationMessage::Init()
{
    m_impl = new wxUserNotificationMsgImpl(this);
}

#endif // wxUSE_NOTIFICATION_MESSAGE && defined(wxHAS_NATIVE_NOTIFICATION_MESSAGE)
