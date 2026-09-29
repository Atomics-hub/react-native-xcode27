// Lets an app written for the app-based life cycle launch when it is built with the iOS 27 SDK.
//
// Apps built with the iOS 27 SDK must adopt the UIScene life cycle or UIKit stops them at launch with
// "UIScene life cycle is required for apps built with this SDK". React Native adopts it from 0.88.
// Earlier templates, and Expo SDK 56 and earlier, create their window in
// application:didFinishLaunchingWithOptions: and never declare a scene.
//
// This file adopts the scene life cycle for such an app without touching its code. When UIKit assigns
// the app delegate, the delegate's class gets the scene-configuration method UIKit asks for. The scene
// delegate below then puts the window the app already created into the scene, and hands the events
// UIKit now sends to the scene back to the app delegate methods that used to receive them. Apps that
// already declare scenes, and builds made with an SDK older than iOS 27, are left alone.

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#if defined(__IPHONE_27_0) && __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_27_0

// Calling the app delegate methods that the scene methods replaced is the point of this file.
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

typedef void (^RNXcode27Resolve)(id result);
typedef void (^RNXcode27Reject)(NSString *code, NSString *message, NSError *error);

// The link that launched the app. Under the scene life cycle it arrives with the scene's connection
// options instead of in the launch options React Native reads its initial URL from.
static NSURL *RNXcode27LaunchURL = nil;

static id<UIApplicationDelegate> RNXcode27AppDelegate(void)
{
  return UIApplication.sharedApplication.delegate;
}

@interface RNXcode27SceneDelegate : UIResponder <UIWindowSceneDelegate>
@property (nonatomic, strong, nullable) UIWindow *window;
@property (nonatomic) BOOL becameActive;
@end

@implementation RNXcode27SceneDelegate

- (void)scene:(UIScene *)scene
    willConnectToSession:(UISceneSession *)session
                 options:(UISceneConnectionOptions *)connectionOptions
{
  if (![scene isKindOfClass:UIWindowScene.class]) {
    return;
  }
  UIWindowScene *windowScene = (UIWindowScene *)scene;
  id<UIApplicationDelegate> delegate = RNXcode27AppDelegate();

  UIWindow *window = [delegate respondsToSelector:@selector(window)] ? delegate.window : nil;
  if (window == nil) {
    window = [[UIWindow alloc] initWithWindowScene:windowScene];
    if ([delegate respondsToSelector:@selector(setWindow:)]) {
      delegate.window = window;
    }
  } else {
    window.windowScene = windowScene;
  }
  self.window = window;
  [window makeKeyAndVisible];

  NSUserActivity *activity = connectionOptions.userActivities.anyObject;
  NSURL *URL = connectionOptions.URLContexts.anyObject.URL;
  if (URL != nil) {
    RNXcode27LaunchURL = URL;
  } else if ([activity.activityType isEqualToString:NSUserActivityTypeBrowsingWeb] && activity.webpageURL != nil) {
    RNXcode27LaunchURL = activity.webpageURL;
  }

  // Under the app-based life cycle UIKit also calls these app delegate methods after a launch by link,
  // user activity or quick action.
  if (connectionOptions.URLContexts.count > 0) {
    [self scene:scene openURLContexts:connectionOptions.URLContexts];
  }
  if (activity != nil) {
    [self scene:scene continueUserActivity:activity];
  }
  if (connectionOptions.shortcutItem != nil) {
    [self windowScene:windowScene
        performActionForShortcutItem:connectionOptions.shortcutItem
                   completionHandler:^(BOOL succeeded){
                   }];
  }
}

- (void)scene:(UIScene *)scene openURLContexts:(NSSet<UIOpenURLContext *> *)URLContexts
{
  id<UIApplicationDelegate> delegate = RNXcode27AppDelegate();
  if (![delegate respondsToSelector:@selector(application:openURL:options:)]) {
    return;
  }
  for (UIOpenURLContext *context in URLContexts) {
    NSMutableDictionary<UIApplicationOpenURLOptionsKey, id> *options = [NSMutableDictionary dictionary];
    if (context.options.sourceApplication != nil) {
      options[UIApplicationOpenURLOptionsSourceApplicationKey] = context.options.sourceApplication;
    }
    if (context.options.annotation != nil) {
      options[UIApplicationOpenURLOptionsAnnotationKey] = context.options.annotation;
    }
    options[UIApplicationOpenURLOptionsOpenInPlaceKey] = @(context.options.openInPlace);
    [delegate application:UIApplication.sharedApplication openURL:context.URL options:options];
  }
}

- (void)scene:(UIScene *)scene continueUserActivity:(NSUserActivity *)userActivity
{
  id<UIApplicationDelegate> delegate = RNXcode27AppDelegate();
  if ([delegate respondsToSelector:@selector(application:continueUserActivity:restorationHandler:)]) {
    [delegate application:UIApplication.sharedApplication
        continueUserActivity:userActivity
          restorationHandler:^(NSArray<id<UIUserActivityRestoring>> *restorableObjects){
          }];
  }
}

- (void)windowScene:(UIWindowScene *)windowScene
    performActionForShortcutItem:(UIApplicationShortcutItem *)shortcutItem
               completionHandler:(void (^)(BOOL))completionHandler
{
  id<UIApplicationDelegate> delegate = RNXcode27AppDelegate();
  if ([delegate respondsToSelector:@selector(application:performActionForShortcutItem:completionHandler:)]) {
    [delegate application:UIApplication.sharedApplication
        performActionForShortcutItem:shortcutItem
                   completionHandler:completionHandler];
  } else {
    completionHandler(NO);
  }
}

// With scenes, UIKit stops calling these app delegate methods and calls the scene's instead. The app
// still gets the UIApplication notifications. A scene also reports entering the foreground when it
// first connects, which the app-based life cycle never did, so that first one is not passed on.

- (void)sceneWillEnterForeground:(UIScene *)scene
{
  id<UIApplicationDelegate> delegate = RNXcode27AppDelegate();
  if (self.becameActive && [delegate respondsToSelector:@selector(applicationWillEnterForeground:)]) {
    [delegate applicationWillEnterForeground:UIApplication.sharedApplication];
  }
}

- (void)sceneDidBecomeActive:(UIScene *)scene
{
  self.becameActive = YES;
  id<UIApplicationDelegate> delegate = RNXcode27AppDelegate();
  if ([delegate respondsToSelector:@selector(applicationDidBecomeActive:)]) {
    [delegate applicationDidBecomeActive:UIApplication.sharedApplication];
  }
}

- (void)sceneWillResignActive:(UIScene *)scene
{
  id<UIApplicationDelegate> delegate = RNXcode27AppDelegate();
  if ([delegate respondsToSelector:@selector(applicationWillResignActive:)]) {
    [delegate applicationWillResignActive:UIApplication.sharedApplication];
  }
}

- (void)sceneDidEnterBackground:(UIScene *)scene
{
  id<UIApplicationDelegate> delegate = RNXcode27AppDelegate();
  if ([delegate respondsToSelector:@selector(applicationDidEnterBackground:)]) {
    [delegate applicationDidEnterBackground:UIApplication.sharedApplication];
  }
}

@end

static UISceneConfiguration *RNXcode27Configuration(
    id delegate,
    SEL command,
    UIApplication *application,
    UISceneSession *session,
    UISceneConnectionOptions *options)
{
  UISceneConfiguration *configuration = [[UISceneConfiguration alloc] initWithName:@"Default Configuration"
                                                                        sessionRole:session.role];
  configuration.delegateClass = RNXcode27SceneDelegate.class;
  return configuration;
}

// React Native's Linking.getInitialURL reads the launch options, which no longer carry the link that
// launched the app. When they have none, answer with the link the scene was connected with.
static void RNXcode27AnswerInitialURL(void)
{
  Class linkingManager = NSClassFromString(@"RCTLinkingManager");
  SEL selector = NSSelectorFromString(@"getInitialURL:reject:");
  Method method = linkingManager != Nil ? class_getInstanceMethod(linkingManager, selector) : NULL;
  if (method == NULL) {
    return;
  }
  typedef void (*GetInitialURL)(id, SEL, RNXcode27Resolve, RNXcode27Reject);
  GetInitialURL original = (GetInitialURL)method_getImplementation(method);
  method_setImplementation(method, imp_implementationWithBlock(^(id manager, RNXcode27Resolve resolve, RNXcode27Reject reject) {
    original(manager, selector, ^(id result) {
      BOOL missing = result == nil || result == (id)kCFNull;
      resolve(missing && RNXcode27LaunchURL != nil ? RNXcode27LaunchURL.absoluteString : result);
    }, reject);
  }));
}

static IMP RNXcode27OriginalSetDelegate = NULL;

static void RNXcode27SetDelegate(UIApplication *application, SEL command, id<UIApplicationDelegate> delegate)
{
  SEL configurationSelector = @selector(application:configurationForConnectingSceneSession:options:);
  BOOL declaresScenes = [NSBundle.mainBundle objectForInfoDictionaryKey:@"UIApplicationSceneManifest"] != nil;
  if (delegate != nil && !declaresScenes && !class_respondsToSelector(object_getClass(delegate), configurationSelector)) {
    class_addMethod(object_getClass(delegate), configurationSelector, (IMP)RNXcode27Configuration, "@@:@@@");
    RNXcode27AnswerInitialURL();
  }
  ((void (*)(id, SEL, id))RNXcode27OriginalSetDelegate)(application, command, delegate);
}

@interface RNXcode27 : NSObject
@end

@implementation RNXcode27

+ (void)load
{
  Method method = class_getInstanceMethod(UIApplication.class, @selector(setDelegate:));
  RNXcode27OriginalSetDelegate = method_setImplementation(method, (IMP)RNXcode27SetDelegate);
}

@end

#endif
