//
//  RVCustomerProject.h
//  Rover
//
//  Created by Sean Rucker on 2014-08-08.
//  Copyright (c) 2014 Rover Labs Inc. All rights reserved.
//

#import "RVModelProject.h"
#import "RVCustomer.h"

@interface RVCustomer ()

+ (RVCustomer *)cachedCustomer;

@property (readonly, nonatomic) BOOL dirty;

@end