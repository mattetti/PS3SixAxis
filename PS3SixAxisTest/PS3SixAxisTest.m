//
//  PS3SixAxisTest.m
//  PS3_SixAxis
//
//  Created by Tobias Wetzel on 04.05.10.
//  Copyright 2010 Outcut. All rights reserved.
//

#import "PS3SixAxisTest.h"


@implementation PS3SixAxisTest

@synthesize connectButton, disconnectButton, useBluetooth;
@synthesize led;

@synthesize selectButton, startButton, psButton;

@synthesize triangleButton, trianglePressure;
@synthesize circleButton, circlePressure;
@synthesize crossButton, crossPressure;
@synthesize squareButton, squarePressure;

@synthesize l1Button, l1Pressure;
@synthesize l2Button, l2Pressure;
@synthesize r1Button, r1Pressure;
@synthesize r2Button, r2Pressure;

@synthesize northButton, northPressure;
@synthesize eastButton, eastPressure;
@synthesize southButton, southPressure;
@synthesize westButton, westPressure;

@synthesize leftStick, rightStick;

-(void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	ps3SixAxis = [PS3SixAxis sixAixisControllerWithDelegate:self];
	[disconnectButton setEnabled:NO];
}

- (IBAction) doConnect:(id)sender {
	[ps3SixAxis connect:[useBluetooth state]];
}

- (IBAction) doDisconnect:(id)sender {
	[ps3SixAxis disconnect];
}

- (void) onDeviceConnected {
	[connectButton setEnabled:NO];
	[useBluetooth setEnabled:NO];
	[disconnectButton setEnabled:YES];
	[led setImage:[NSImage imageNamed:@"ledGreen"]];	
}

- (void) onDeviceDisconnected {
	[connectButton setEnabled:YES];
	[useBluetooth setEnabled:YES];
	[disconnectButton setEnabled:NO];
	[led setImage:[NSImage imageNamed:@"ledRed"]];
}

- (void) onDeviceConnectionError:(NSInteger)error {
	NSLog(@"%s %d", __PRETTY_FUNCTION__, error);
	switch (error) {
		case 0:
			NSLog(@"");
			break;
		default:
			break;
	}
}

- (void) onAxisX:(int)x Y:(int)y Z:(int)z {
	//NSLog(@"%s x:%d y:%d z:%d", __PRETTY_FUNCTION__, x, y, z);
}

- (void) onLeftStick:(NSPoint)axis pressed:(BOOL)isPressed {
	[leftStick setJoyStickX:(int)axis.x Y:(int)axis.y pressed:isPressed];
}

- (void) onRightStick:(NSPoint)axis pressed:(BOOL)isPressed {
	[rightStick setJoyStickX:(int)axis.x Y:(int)axis.y pressed:isPressed];
}

- (void) onTriangleButton:(BOOL)state {
	[triangleButton highlight:state];
}

- (void) onTriangleButtonWithPressure:(NSInteger)value {
	[trianglePressure setIntValue:value];
}

- (void) onCircleButton:(BOOL)state {
	[circleButton highlight:state];
}

- (void) onCircleButtonWithPressure:(NSInteger)value {
	[circlePressure setIntValue:value];
}

- (void) onCrossButton:(BOOL)state {
	[crossButton highlight:state];
}

- (void) onCrossButtonWithPressure:(NSInteger)value {
	[crossPressure setIntValue:value];
}

- (void) onSquareButton:(BOOL)state {
	[squareButton highlight:state];
}

- (void) onSquareButtonWithPressure:(NSInteger)value {
	[squarePressure setIntValue:value];
}

- (void) onL1Button:(BOOL)state {
	[l1Button highlight:state];
}

- (void) onL2Button:(BOOL)state {
	[l2Button highlight:state];
}

- (void) onR1Button:(BOOL)state {
	[r1Button highlight:state];
}

- (void) onR2Button:(BOOL)state {
	[r2Button highlight:state];
}

- (void) onL1ButtonWithPressure:(NSInteger)value {
	[l1Pressure setIntValue:value];
}

- (void) onL2ButtonWithPressure:(NSInteger)value {
	[l2Pressure setIntValue:value];
}

- (void) onR1ButtonWithPressure:(NSInteger)value {
	[r1Pressure setIntValue:value];
}

- (void) onR2ButtonWithPressure:(NSInteger)value {
	[r2Pressure setIntValue:value];
}

- (void) onSelectButton:(BOOL)state {
	[selectButton highlight:state];
}

- (void) onStartButton:(BOOL)state {
	[startButton highlight:state];
}

- (void) onPSButton:(BOOL)state {
	[psButton highlight:state];
}

- (void) onNorthButton:(BOOL)state {
	[northButton highlight:state];
}
- (void) onEastButton:(BOOL)state {
	[eastButton highlight:state];
}
- (void) onSouthButton:(BOOL)state {
	[southButton highlight:state];
}
- (void) onWestButton:(BOOL)state {
	[westButton highlight:state];
}

- (void) onNorthButtonWithPressure:(NSInteger)value {
	[northPressure setIntValue:value];
}
- (void) onEastButtonWithPressure:(NSInteger)value {
	[eastPressure setIntValue:value];
}
- (void) onSouthButtonWithPressure:(NSInteger)value {
	[southPressure setIntValue:value];
}
- (void) onWestButtonWithPressure:(NSInteger)value {
	[westPressure setIntValue:value];
}


-(void)applicationWillTerminate:(NSNotification *)aNotification {
	[ps3SixAxis disconnect];
}

@end
