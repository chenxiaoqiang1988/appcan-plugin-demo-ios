/**
 *
 *	@file   	: EUExDemoPlugin.m  in EUExDemoPlugin
 *
 *	@author 	: CeriNo
 *
 *	@date   	: Created on 16/3/25.
 *
 *	@copyright 	: 2016 The AppCan Open Source Project.
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU Lesser General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU Lesser General Public License for more details.
 *  You should have received a copy of the GNU Lesser General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

#define SHORT_ENABLE

#import "EUExDemoPlugin.h"
#import "JSON.h"
#import "uexDemoPluginViewController.h"
@interface EUExDemoPlugin()
@property (nonatomic,strong)UIView *aView;
@property (nonatomic,strong)uexDemoPluginViewController *aViewController;
@end

@implementation EUExDemoPlugin





#pragma mark - Global Event

static NSDictionary *AppLaunchOptions;

+ (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions{
    NSLog(@"app launched");
    //存储launchOptions
    AppLaunchOptions = launchOptions;
    return YES;
}

//第一个网页(root页面)加载完成时会触发此事件
//部分事件(比如application:didFinishLaunchingWithOptions:)触发时，第一个网页可能还没加载完成，因此无法当时回调给网页
//这些回调应该延迟至这个事件触发时再回调给root页面
+ (void)rootPageDidFinishLoading{
    NSString *jsStr = [NSString stringWithFormat:@"if(uexDemoPlugin.onAppLaunched){uexDemoPlugin.onAppLaunched('%@');}",[AppLaunchOptions ac_JSONFragment]];
    //在root页面执行JS脚本
    
    [AppCanRootWebViewEngine() evaluateScript:jsStr];
    AppLaunchOptions = nil;
    
}


#pragma mark - Life Cycle

- (instancetype)initWithWebViewEngine:(id<AppCanWebViewEngineObject>)engine
{
    self = [super initWithWebViewEngine:engine];
    if (self) {
        NSLog(@"插件实例被创建");
    }
    return self;
}

- (void)clean{
    [self dismissViewController];
    NSLog(@"网页即将被销毁");
}



#pragma mark - JavaScript API


#pragma mark hello world
- (void)helloWorld:(NSMutableArray *)inArguments{
    //打印 hello world!
    NSLog(@"hello world!");
    

}

#pragma mark 从JS端接收参数
- (void)sendValue:(NSMutableArray *)inArguments{
    //打印传入的参数个数
    NSLog(@"arguments count : %@",@(inArguments.count));
    //打印每个参数的描述，和参数所在的类的描述
    for (NSInteger i = 0; i < inArguments.count; i++) {
        id obj = inArguments[i];
        NSLog(@"value : %@ , class : %@ ",[obj description],[[obj class] description]);
    }
}

#pragma mark 从JS端接收JSON参数
- (void)sendJSONValue:(NSMutableArray *)inArguments{
    if([inArguments count] < 1){
        //当传入的参数为空时，直接返回，避免数组越界错误。
        return;
    }
    id json = [inArguments[0] JSONValue];
    NSLog(@"json : %@ class : %@",[json description],[[json class] description]);
}


#pragma mark 异步回调
- (void)doCallback:(NSMutableArray *)inArguments{
    NSDictionary *dict = @{
                           @"key":@"value"
                           };
    
    //构造参数数组
    //[dict ac_JSONFragment] 可以把NSString NSDictionary NSArray 转换成JSON字符串
    NSArray * args = ACArgsPack(dict.ac_JSONFragment);
    
    //执行网页中的uexDemoPlugin.cbDoCallback回调函数
    [self.webViewEngine callbackWithFunctionKeyPath:@"uexDemoPlugin.cbDoCallback" arguments:args completion:^(JSValue * _Nonnull returnValue) {
        if (returnValue) {
            NSLog(@"回调成功!");
        }
    }];
    

}


- (void)doCallbackWithFunction:(NSMutableArray *)inArguments{
    ACArgsUnpack(NSString *str,NSArray *array,ACJSFunctionRef *func) = inArguments;
    NSMutableArray *newArray = [array mutableCopy];
    if (str && newArray) {
        [newArray addObject:str];
    }
    [func executeWithArguments:ACArgsPack(newArray) completionHandler:^(JSValue * _Nullable returnValue) {
        if (returnValue) {
            NSLog(@"回调成功!");
        }
    }];
}



- (NSDictionary *)doSyncCallback:(NSMutableArray *)inArguments{
    return @{
             @"key1":@"value1",
             @"key2":@(NO),
             @"key3":@{
                     @"subKey":@"subValue"
                     }
             };

}


- (void)addView:(NSMutableArray *)inArguments{
    if (self.aView) {
        //如果已经添加了view 直接返回
        return;
    }
    ACArgsUnpack(NSDictionary *info) = inArguments;

    if(!info){
        return;
    }
    
    if (!info[@"isScrollable"]) {
        //如果参数信息不包含isScrollable这个键 直接返回
        return;
    }
    BOOL isScroll = [info[@"isScrollable"] boolValue];
    //新建一个view，并将其背景设置为红色
    UIView *view = [[UIView alloc]initWithFrame:CGRectMake(10, 400, 300, 200)];
    view.backgroundColor = [UIColor redColor];
    if (isScroll) {
        [[self.webViewEngine webScrollView] addSubview:view];
    }else{
        [[self.webViewEngine webView] addSubview:view];
    }
    //插件对象持有此view,方便对其进行移除操作
    self.aView = view;
}

- (void)removeView:(NSMutableArray *)inArguments{
    if (self.aView) {
        [self.aView removeFromSuperview];
        self.aView = nil;
    }
}

- (void)presentController:(NSMutableArray *)inArguments{
    if (self.aViewController) {
        return;
    }
    uexDemoPluginViewController *controller = [[uexDemoPluginViewController alloc]initWithEUExObj:self];
    [[self.webViewEngine viewController]presentViewController:controller animated:YES completion:nil];
    self.aViewController = controller;
}

- (void)dismissViewController{
    if (self.aViewController) {
        [self.aViewController dismissViewControllerAnimated:YES completion:^{
            //[self callbackJSONWithName:@"onControllerClose" object:nil];
            [self.webViewEngine callbackWithFunctionKeyPath:@"uexDemoPlugin.onControllerClose" arguments:nil];
            
            self.aViewController = nil;
        }];
    }
}

@end
