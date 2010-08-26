//
//  SixAxisStick.m
//  PS3_SixAxis
//
//  Created by Tobias Wetzel on 11.05.10.
//  Copyright 2010 Outcut. All rights reserved.
//

#import "SixAxisStick.h"


@implementation SixAxisStick

- (id) initWithFrame:(NSRect)frameRect {
	if(self = [super initWithFrame:frameRect]) {
		[self setWantsLayer:YES];
		
		CGColorRef blackColor = CGColorCreateGenericRGB(0.0, 0.0, 0.0, 0.7);
		CGColorRef whiteColor = CGColorCreateGenericRGB(1.0, 1.0, 1.0, 1.0);
		
		point = [CALayer layer];
		[point setAnchorPoint:CGPointMake(0, 0)];
		[point setBounds:CGRectMake(0, 0, 20, 20)];
		[point setShadowOpacity:.8f];
		[point setCornerRadius:10];
		[[self layer] setBackgroundColor:blackColor];
		[[self layer] addSublayer:point];
		
		[self setJoyStickX:128 Y:128 pressed:NO];
	}
	return self;
}

- (void) setJoyStickX:(NSInteger)x Y:(NSInteger)y pressed:(BOOL)isPressed {
	NSSize size = [self frame].size;
	float scale = size.width / (255 + 20);
	CGColorRef pointColor;
	if (isPressed) {
		pointColor = CGColorCreateGenericRGB(1.0, 0.0, 0.0, 1.0);
	} else {
		pointColor = CGColorCreateGenericRGB(0.0, 0.0, 1.0, 1.0);
	}
	[point setBackgroundColor:pointColor];
	[point setPosition:CGPointMake(x * scale - 10, size.height - (y * scale) - 10)];
}

@end
