//
//  RVVisitManager.m
//  Rover
//
//  Created by Sean Rucker on 2014-07-29.
//  Copyright (c) 2014 Rover Labs Inc. All rights reserved.
//

#import "Rover.h"
#import "RVVisitManager.h"

#import "RVCardProject.h"
#import "RVCustomerProject.h"
#import "RVLog.h"
#import "RVNetworkingManager.h"
#import "RVNotificationCenter.h"
#import "RVRegionManager.h"
#import "RVVisitProject.h"
#import "RVTouchpoint.h"

NSString *const kRVVisitManagerDidEnterTouchpointNotification = @"RVVisitManagerDidEnterTouchpointNotification";
NSString *const kRVVisitManagerDidEnterLocationNotification = @"RVVisitManagerDidEnterLocationNotification";
NSString *const kRVVisitManagerDidExitLocationNotification = @"RVVisitManagerDidExitLocationNotification";

@interface RVVisitManager ()

@property (strong, nonatomic) RVVisit *latestVisit;

@end

@implementation RVVisitManager

#pragma mark - Class Methods

+ (id)sharedManager {
    static RVVisitManager *sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedManager = [[self alloc] init];
    });
    
    return sharedManager;
}

#pragma mark - Initialization

- (id)init {
    self = [super init];
    if (self) {
        [[RVNotificationCenter defaultCenter] addObserver:self selector:@selector(regionManagerDidEnterRegion:) name:kRVRegionManagerDidEnterRegionNotification object:nil];
        
        [[RVNotificationCenter defaultCenter] addObserver:self selector:@selector(regionManagerDidExitRegion:) name:kRVRegionManagerDidExitRegionNotification object:nil];
    }
    return  self;
}

- (void)dealloc {
    [[RVNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Instance methods

- (RVVisit *)latestVisit
{
    if (_latestVisit) {
        return _latestVisit;
    }
    
    NSUserDefaults *standardDefault = [NSUserDefaults standardUserDefaults];
    _latestVisit = [NSKeyedUnarchiver unarchiveObjectWithData:[standardDefault objectForKey:@"_roverLatestVisit"]];
    return _latestVisit;
}


#pragma mark - Region Manager Notifications

- (void)regionManagerDidEnterRegion:(NSNotification *)note {
    CLBeaconRegion *beaconRegion = [note.userInfo objectForKey:@"beaconRegion"];
    if (self.latestVisit && [self.latestVisit isInRegion:beaconRegion] && /*self.latestVisit.isAlive*/ NO) {
        // Touchpoint check
        if (!self.latestVisit.currentTouchpoint || ![self.latestVisit.currentTouchpoint isInRegion:beaconRegion]) {
            RVTouchpoint *touchpoint = [self.latestVisit touchpointForRegion:beaconRegion];
            if (touchpoint) {
                self.latestVisit.currentTouchpoint = touchpoint;
                [[RVNotificationCenter defaultCenter] postNotificationName:kRVVisitManagerDidEnterTouchpointNotification object:self
                                                                  userInfo:@{ @"touchpoint": touchpoint,
                                                                              @"visit": self.latestVisit}];
                RVLog(kRoverDidEnterTouchpointNotification, nil);
            } else {
                NSLog(@"Invalid touchpoint");
            }
        }
        
        NSDate *now = [NSDate date];
        NSTimeInterval elapsed = [now timeIntervalSinceDate:self.latestVisit.enteredAt];
        
        // Reset the timer
        self.latestVisit.beaconLastDetectedAt = now;
        
        RVLog(kRoverAlreadyVisitingNotification, @{ @"elapsed": [NSNumber numberWithDouble:elapsed],
                                                    @"keepAlive": [NSNumber numberWithDouble:self.latestVisit.keepAlive] });
        return;
    }

    RVCustomer *customer = [Rover shared].customer;
    if (customer.dirty) {
        [customer save:^{
            [self createVisitWithUUID:beaconRegion.proximityUUID major:beaconRegion.major minor:beaconRegion.minor];
        } failure:nil];
    } else {
        [self createVisitWithUUID:beaconRegion.proximityUUID major:beaconRegion.major minor:beaconRegion.minor];
    }
}

- (void)regionManagerDidExitRegion:(NSNotification *)note {
    CLBeaconRegion *beaconRegion = [note.userInfo objectForKey:@"beaconRegion"];
    
    if (self.latestVisit && [self.latestVisit isInRegion:beaconRegion]) {
        [self updateVisitExitTime];
    }
}

#pragma mark - Networking

- (void)createVisitWithUUID:(NSUUID *)UUID major:(NSNumber *)major minor:(NSNumber *)minor {
    RVLog(kRoverWillPostVisitNotification, nil);
    
    self.latestVisit = [RVVisit new];
    self.latestVisit.UUID = UUID;
    self.latestVisit.major = major;
    self.latestVisit.customerID = [Rover shared].customer.customerID;
    self.latestVisit.enteredAt = [NSDate date];
    
    [self.latestVisit save:^{
        [[RVNotificationCenter defaultCenter] postNotificationName:kRVVisitManagerDidEnterLocationNotification object:self userInfo:@{ @"visit": self.latestVisit }];
        RVLog(kRoverDidPostVisitNotification, nil);
        
        NSLog(@"touchpoints: %@", self.latestVisit.touchpoints); //DELETE
        // Touchpoint
        RVTouchpoint *touchpoint = [self.latestVisit touchpointForMinor:minor];
        if (touchpoint) {
            self.latestVisit.currentTouchpoint = touchpoint;
            [[RVNotificationCenter defaultCenter] postNotificationName:kRVVisitManagerDidEnterTouchpointNotification object:self
                                                              userInfo:@{ @"touchpoint": touchpoint,
                                                                          @"visit": self.latestVisit }];
            RVLog(kRoverDidEnterTouchpointNotification, nil);
        } else {
            NSLog(@"Invalid touchpoint");
        }
        
    } failure:^(NSString *reason) {
        RVLog(kRoverPostVisitFailedNotification, nil);
    }];
}

- (void)updateVisitExitTime {
    if (!self.latestVisit) return;
    
    RVLog(kRoverWillUpdateExitTimeNotification, nil);
    
    self.latestVisit.exitedAt = [NSDate date];
    [self.latestVisit save:^{
        RVLog(kRoverDidUpdateExitTimeNotification, nil);
    } failure:^(NSString *reason) {
        RVLog(kRoverUpdateExitTimeFailedNotification, nil);
    }];
}

@end