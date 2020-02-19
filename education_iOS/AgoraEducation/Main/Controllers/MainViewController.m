//
//  MainViewController.m
//  AgoraSmallClass
//
//  Created by yangmoumou on 2019/5/9.
//  Copyright © 2019 Agora. All rights reserved.
//

#import "MainViewController.h"
#import "EEClassRoomTypeView.h"
#import "SettingViewController.h"
#import "GenerateSignalBody.h"
#import "EyeCareModeUtil.h"

#import "MinEducationManager.h"
#import "BigEducationManager.h"

#import "OneToOneViewController.h"
#import "MCViewController.h"
#import "BCViewController.h"

#import "NSString+MD5.h"
#import "KeyCenter.h"

#import "HttpManager.h"
#import "ConfigModel.h"
#import "EnterRoomAllModel.h"
#import "UIView+Toast.h"
#import "AppUpdateManager.h"

@interface MainViewController ()<EEClassRoomTypeDelegate, SignalDelegate, UITextFieldDelegate>
@property (weak, nonatomic) IBOutlet UIView *baseView;
@property (weak, nonatomic) IBOutlet UITextField *userNameTextFiled;
@property (weak, nonatomic) IBOutlet UITextField *passwordTextFiled;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *textViewBottomCon;
@property (weak, nonatomic) IBOutlet UIButton *joinButton;

@property (nonatomic, strong) UIActivityIndicatorView * activityIndicator;

@property (nonatomic, strong) ConfigInfoModel *configInfoModel;
@property (nonatomic, strong) EnterRoomInfoModel *enterRoomInfoModel;

@end

@implementation MainViewController

#pragma mark LifeCycle
- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setupView];
    [self setupConfigWithSuccessBolck:nil];
    [self addTouchedRecognizer];
    [self addNotification];
}

- (void)setupConfigWithSuccessBolck:(void (^)(void))successBlock {
    
    WEAK(self);
    [self.activityIndicator startAnimating];
    [self.joinButton setEnabled:NO];
    
    [HttpManager getAppConfigWithSuccess:^(id responseObj) {
        
        [weakself.activityIndicator stopAnimating];
        [weakself.joinButton setEnabled:YES];
        
        ConfigModel *model = [ConfigModel yy_modelWithDictionary:responseObj];
        if(model.code == 0 && model.data != nil){
            
            [AppUpdateManager.shareManager checkAppUpdateWithModel:model];
            
            weakself.configInfoModel = model.data.config;
            [KeyCenter setAgoraAppid:weakself.configInfoModel.appId];
            
            if(successBlock != nil){
                successBlock();
            }
        } else {
            [weakself showToast:model.msg];
        }
        
    } failure:^(NSError *error) {
        
        [weakself.activityIndicator stopAnimating];
        [weakself.joinButton setEnabled:YES];
        
        [weakself showToast:NSLocalizedString(@"RequestFailedText", nil)];
        NSLog(@"HTTP GET CONFIG ERROR:%@", error.description);
    }];
}

- (void)showToast:(NSString *)title {
    if(title == nil || title.length == 0){
        title = NSLocalizedString(@"RequestFailedText", nil);
    }
    [self.view makeToast:title];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBarHidden = YES;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    if ([[EyeCareModeUtil sharedUtil] queryEyeCareModeStatus]) {
        [[EyeCareModeUtil sharedUtil] switchEyeCareMode:YES];
    }
}

- (BOOL)prefersStatusBarHidden {
    return NO;
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
    return UIInterfaceOrientationPortrait;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark Private Function
- (void)setupView {
    self.activityIndicator = [[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:(UIActivityIndicatorViewStyleWhiteLarge)];
    [self.view addSubview:self.activityIndicator];
    self.activityIndicator.frame= CGRectMake((kScreenWidth -100)/2, (kScreenHeight - 100)/2, 100, 100);
    self.activityIndicator.color = [UIColor grayColor];
    self.activityIndicator.backgroundColor = [UIColor whiteColor];
    self.activityIndicator.hidesWhenStopped = YES;
    
    self.joinButton.layer.cornerRadius = 20;
    
    self.userNameTextFiled.delegate = self;
    self.passwordTextFiled.delegate = self;
}

- (void)addTouchedRecognizer {
    UITapGestureRecognizer *touchedControl = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(touchedBegan:)];
    [self.baseView addGestureRecognizer:touchedControl];
}
- (void)touchedBegan:(UIGestureRecognizer *)recognizer {
    [self.userNameTextFiled resignFirstResponder];
    [self.passwordTextFiled resignFirstResponder];
}

- (void)addNotification {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardDidShow:) name:UIKeyboardDidShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHidden:) name:UIKeyboardWillHideNotification object:nil];
}

- (void)keyboardDidShow:(NSNotification *)notification {
    CGRect frame = [[[notification userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    float bottom = frame.size.height;
    self.textViewBottomCon.constant = bottom;
}

- (void)keyboardWillHidden:(NSNotification *)notification {
    self.textViewBottomCon.constant = 261;
}

- (BOOL)checkUserNameText:(NSString *)text {
    
    int strlength = 0;
    char *p = (char *)[text cStringUsingEncoding:NSUnicodeStringEncoding];
    for (int i=0; i < [text lengthOfBytesUsingEncoding:NSUnicodeStringEncoding]; i++) {
        if (*p) {
            p++;
            strlength++;
        }
        else {
            p++;
        }
    }
    
    if(strlength <= 20){
        return YES;
    } else {
       return NO;
    }
}

#pragma mark Click Event
- (IBAction)joinRoom:(UIButton *)sender {

    if (self.userNameTextFiled.text.length == 0 || self.passwordTextFiled.text.length == 0 || ![self checkUserNameText:self.userNameTextFiled.text]) {
        
        [AlertViewUtil showAlertWithController:self title:NSLocalizedString(@"UserNameVerifyText", nil)];
        return;
    }
    
    WEAK(self);
    if([KeyCenter agoraAppid].length == 0){
        [self setupConfigWithSuccessBolck:^{
            [weakself enterRoom];
        }];
    } else {
        [self enterRoom];
    }
}

- (void)enterRoom {
    
    [self.activityIndicator startAnimating];
    [self.joinButton setEnabled:YES];
    
    NSString *url = [NSString stringWithFormat:HTTP_POST_ENTER_ROOM, [KeyCenter agoraAppid]];
    
    NSDictionary *headers = @{
        @"Authorization" : self.configInfoModel.authorization,
    };
    
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    params[@"userName"] = self.userNameTextFiled.text;
    params[@"password"] = self.passwordTextFiled.text;
    params[@"role"] = @(2);
    params[@"uuid"] = [UIDevice currentDevice].identifierForVendor.UUIDString;
    
    WEAK(self);
    [HttpManager post:url params:params headers:headers success:^(id responseObj) {
        
        EnterRoomAllModel *model = [EnterRoomAllModel yy_modelWithDictionary:responseObj];
        if(model.code == 0){
            
            weakself.enterRoomInfoModel = model.data;
            [KeyCenter setWhiteBoardId:weakself.enterRoomInfoModel.room.boardId];
            [KeyCenter setWhiteBoardToken:weakself.enterRoomInfoModel.room.boardToken];
            [KeyCenter setAgoraRTMToken:weakself.enterRoomInfoModel.user.rtmToken];
            [KeyCenter setAgoraRTCToken:weakself.enterRoomInfoModel.user.rtcToken];
            
            if (weakself.enterRoomInfoModel.room.type == 0) {
                [weakself join1V1RoomWithIdentifier:@"oneToOneRoom"];
            } else if (weakself.enterRoomInfoModel.room.type == 1){
                [weakself joinMinRoomWithIdentifier:@"mcRoom"];
            } else if (weakself.enterRoomInfoModel.room.type == 2){
                [weakself joinBigRoomWithIdentifier:@"bcroom"];
            } else {
                [weakself showToast:NSLocalizedString(@"RoomTypeVerifyText", nil)];
            }
            
        } else {
            
            [weakself.activityIndicator stopAnimating];
            [weakself.joinButton setEnabled:YES];
            [weakself showToast:model.msg];
        }
        
    } failure:^(NSError *error) {
        
        [weakself.activityIndicator stopAnimating];
        [weakself.joinButton setEnabled:YES];
        
        [weakself showToast:NSLocalizedString(@"RequestFailedText", nil)];
        NSLog(@"HTTP GET CONFIG ERROR:%@", error.description);
    }];
}

- (IBAction)settingAction:(UIButton *)sender {
    SettingViewController *settingVC = [[SettingViewController alloc] init];
    [self.navigationController pushViewController:settingVC animated:YES];
}

- (void)join1V1RoomWithIdentifier:(NSString*)identifier {
    
    NSInteger maxCount = self.configInfoModel.oneToOneStudentLimit.integerValue;
    NSString *channelName = self.enterRoomInfoModel.room.channelName;
    NSString *uid = @(self.enterRoomInfoModel.user.uid).stringValue;
    
    WEAK(self);
    SignalModel *model = [SignalModel new];
    model.appId = [KeyCenter agoraAppid];
    model.token = [KeyCenter agoraRTMToken];
    model.uid = uid;
    OneToOneEducationManager *educationManager = [OneToOneEducationManager new];
    [educationManager initSignalWithModel:model dataSourceDelegate:nil completeSuccessBlock:^{
        
        [educationManager queryOnlineStudentCountWithChannelName:channelName maxCount:maxCount excludeUids:@[uid] completeSuccessBlock:^(NSInteger count) {
            
            [weakself.activityIndicator stopAnimating];
            [weakself.joinButton setEnabled:YES];
            
            if (count < maxCount) {
                VCParamsModel *paramsModel = [weakself generateVCParamsModel];
                UIStoryboard *story = [UIStoryboard storyboardWithName:@"Room" bundle:[NSBundle mainBundle]];
                OneToOneViewController *vc = [story instantiateViewControllerWithIdentifier:identifier];
                vc.modalPresentationStyle = UIModalPresentationFullScreen;
                vc.educationManager = educationManager;
                vc.paramsModel = paramsModel;
                [weakself presentViewController:vc animated:YES completion:nil];
                
            } else {
                [AlertViewUtil showAlertWithController:self title:NSLocalizedString(@"RoomCountVerifyText", nil)];
            }
            
        } completeFailBlock:^{
            [weakself showToast:NSLocalizedString(@"QueryOnlineErrorText", nil)];
            
            [weakself.activityIndicator stopAnimating];
            [weakself.joinButton setEnabled:YES];
        }];
        
    } completeFailBlock:^{
        
        [weakself showToast:NSLocalizedString(@"InitSignalErrorText", nil)];
        
        [weakself.activityIndicator stopAnimating];
        [weakself.joinButton setEnabled:YES];
    }];
}

- (void)joinMinRoomWithIdentifier:(NSString*)identifier {
    
    NSInteger maxCount = self.configInfoModel.smallClassStudentLimit.integerValue;
    NSString *channelName = self.enterRoomInfoModel.room.channelName;
    NSString *uid = [NSNumber numberWithInteger:self.enterRoomInfoModel.user.uid].stringValue;
    
    WEAK(self);
    SignalModel *model = [SignalModel new];
    model.appId = [KeyCenter agoraAppid];
    model.token = [KeyCenter agoraRTMToken];
    model.uid = uid;
    MinEducationManager *educationManager = [MinEducationManager new];
    [educationManager initSignalWithModel:model dataSourceDelegate:nil completeSuccessBlock:^{
        
        [educationManager queryOnlineStudentCountWithChannelName:channelName maxCount:maxCount excludeUids:@[uid] completeSuccessBlock:^(NSInteger count) {
            
            [weakself.activityIndicator stopAnimating];
            [weakself.joinButton setEnabled:YES];
            
            if (count < maxCount) {
                VCParamsModel *paramsModel = [weakself generateVCParamsModel];
                UIStoryboard *story = [UIStoryboard storyboardWithName:@"Room" bundle:[NSBundle mainBundle]];
                MCViewController *vc = [story instantiateViewControllerWithIdentifier:identifier];
                vc.modalPresentationStyle = UIModalPresentationFullScreen;
                vc.educationManager = educationManager;
                vc.paramsModel = paramsModel;
                [weakself presentViewController:vc animated:YES completion:nil];
                
            } else {
                [AlertViewUtil showAlertWithController:self title:NSLocalizedString(@"RoomCountVerifyText", nil)];
            }
            
        } completeFailBlock:^{
            [weakself showToast:NSLocalizedString(@"QueryOnlineErrorText", nil)];
            
            [weakself.activityIndicator stopAnimating];
            [weakself.joinButton setEnabled:YES];
        }];
        
    } completeFailBlock:^{
        
        [weakself showToast:NSLocalizedString(@"InitSignalErrorText", nil)];
        
        [weakself.activityIndicator stopAnimating];
        [weakself.joinButton setEnabled:YES];
    }];
}

- (void)joinBigRoomWithIdentifier:(NSString*)identifier {
    
    NSInteger maxCount = self.configInfoModel.largeClassStudentLimit.integerValue;
    NSString *channelName = self.enterRoomInfoModel.room.channelName;
    NSString *uid = [NSNumber numberWithInteger:self.enterRoomInfoModel.user.uid].stringValue;
    
    WEAK(self);
    SignalModel *model = [SignalModel new];
    model.appId = [KeyCenter agoraAppid];
    model.token = [KeyCenter agoraRTMToken];
    model.uid = uid;
    BigEducationManager *educationManager = [BigEducationManager new];
    
    [educationManager initSignalWithModel:model dataSourceDelegate:nil completeSuccessBlock:^{
        
        [educationManager queryOnlineStudentCountWithChannelName:channelName maxCount:maxCount excludeUids:@[uid] completeSuccessBlock:^(NSInteger count) {
            
            [weakself.activityIndicator stopAnimating];
            [weakself.joinButton setEnabled:YES];
            
            if (count < maxCount) {
                VCParamsModel *paramsModel = [weakself generateVCParamsModel];
                UIStoryboard *story = [UIStoryboard storyboardWithName:@"Room" bundle:[NSBundle mainBundle]];
                BCViewController *vc = [story instantiateViewControllerWithIdentifier:identifier];
                vc.modalPresentationStyle = UIModalPresentationFullScreen;
                vc.educationManager = educationManager;
                vc.paramsModel = paramsModel;vc.paramsModel = paramsModel;
                [weakself presentViewController:vc animated:YES completion:nil];
                
            } else {
                [AlertViewUtil showAlertWithController:self title:NSLocalizedString(@"RoomCountVerifyText", nil)];
            }
            
        } completeFailBlock:^{
            [weakself showToast:NSLocalizedString(@"QueryOnlineErrorText", nil)];

            [weakself.activityIndicator stopAnimating];
            [weakself.joinButton setEnabled:YES];
        }];
        
    } completeFailBlock:^{
        
        [weakself showToast:NSLocalizedString(@"InitSignalErrorText", nil)];

        [weakself.activityIndicator stopAnimating];
        [weakself.joinButton setEnabled:YES];
    }];
}

- (VCParamsModel*)generateVCParamsModel {
    
    NSString *className = self.enterRoomInfoModel.room.roomName;
    NSString *userName = self.userNameTextFiled.text;
    
    NSString *channelName = self.enterRoomInfoModel.room.channelName;
    NSString *uid = [NSNumber numberWithInteger:self.enterRoomInfoModel.user.uid].stringValue;
    NSString *userToken = self.enterRoomInfoModel.user.userToken;
    NSString *roomid = @(self.enterRoomInfoModel.room.roomId).stringValue;
    
    VCParamsModel *paramsModel = [VCParamsModel new];
    paramsModel.className = className;
    paramsModel.userName = userName;
    paramsModel.channelName = channelName;
    paramsModel.uid = uid;
    paramsModel.userToken = userToken;
    paramsModel.roomId = roomid;
    
    return paramsModel;
}

#pragma mark UITextFieldDelegate
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

@end
