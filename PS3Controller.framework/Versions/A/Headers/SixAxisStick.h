//
//  SixAxisStick.h
//  PS3_SixAxis
//
//  Created by Tobias Wetzel on 11.05.10.
//  Copyright 2010 Outcut. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>


@interface SixAxisStick : NSView {
	CALayer *point;
}
- (void) setJoyStickX:(NSInteger)x Y:(NSInteger)y pressed:(BOOL)isPressed;
@end
