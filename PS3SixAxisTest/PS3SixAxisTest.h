//
//  PS3SixAxisTest.h
//  PS3SixAxis
//
//  Created by Tobias Wetzel on 04.05.10.
//  Copyright 2010 Outcut. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <PS3SixAxis.h>
#import <SixAxisStick.h>

@interface PS3SixAxisTest : NSObject <NSApplicationDelegate, PS3SixAxisDelegate> {
	PS3SixAxis *ps3SixAxis;
	NSButton *connectButton;
	NSButton *disconnectButton;
	NSButton *useBluetooth;
	NSImageView *led;
	
	NSButton *selectButton;
	NSButton *startButton;
	NSButton *psButton;
	
	NSButton *triangleButton;
	NSLevelIndicator *trianglePressure;
	NSButton *circleButton;
	NSLevelIndicator *circlePressure;
	NSButton *crossButton;
	NSLevelIndicator *crossPressure;
	NSButton *squareButton;
	NSLevelIndicator *squarePressure;
	
	NSButton *l1Button;
	NSLevelIndicator *l1Pressure;
	NSButton *l2Button;
	NSLevelIndicator *l2Pressure;
	NSButton *r1Button;
	NSLevelIndicator *r1Pressure;
	NSButton *r2Button;
	NSLevelIndicator *r2Pressure;
	
	NSButton *northButton;
	NSLevelIndicator *northPressure;
	NSButton *eastButton;
	NSLevelIndicator *eastPressure;
	NSButton *southButton;
	NSLevelIndicator *southPressure;
	NSButton *westButton;
	NSLevelIndicator *westPressure;
	
	SixAxisStick *leftStick;
	SixAxisStick *rightStick;
}

@property (assign) IBOutlet NSButton *connectButton;
@property (assign) IBOutlet NSButton *disconnectButton;
@property (assign) IBOutlet NSButton *useBluetooth;
@property (assign) IBOutlet NSImageView *led;

@property (assign) IBOutlet NSButton *selectButton;
@property (assign) IBOutlet NSButton *startButton;
@property (assign) IBOutlet NSButton *psButton;

@property (assign) IBOutlet NSButton *triangleButton;
@property (assign) IBOutlet NSLevelIndicator *trianglePressure;
@property (assign) IBOutlet NSButton *circleButton;
@property (assign) IBOutlet NSLevelIndicator *circlePressure;
@property (assign) IBOutlet NSButton *squareButton;
@property (assign) IBOutlet NSLevelIndicator *squarePressure;
@property (assign) IBOutlet NSButton *crossButton;
@property (assign) IBOutlet NSLevelIndicator *crossPressure;

@property (assign) IBOutlet NSButton *l1Button;
@property (assign) IBOutlet NSLevelIndicator *l1Pressure;
@property (assign) IBOutlet NSButton *l2Button;
@property (assign) IBOutlet NSLevelIndicator *l2Pressure;
@property (assign) IBOutlet NSButton *r1Button;
@property (assign) IBOutlet NSLevelIndicator *r1Pressure;
@property (assign) IBOutlet NSButton *r2Button;
@property (assign) IBOutlet NSLevelIndicator *r2Pressure;

@property (assign) IBOutlet NSButton *northButton;
@property (assign) IBOutlet NSLevelIndicator *northPressure;
@property (assign) IBOutlet NSButton *eastButton;
@property (assign) IBOutlet NSLevelIndicator *eastPressure;
@property (assign) IBOutlet NSButton *southButton;
@property (assign) IBOutlet NSLevelIndicator *southPressure;
@property (assign) IBOutlet NSButton *westButton;
@property (assign) IBOutlet NSLevelIndicator *westPressure;

@property (assign) IBOutlet SixAxisStick *leftStick;
@property (assign) IBOutlet SixAxisStick *rightStick;

- (IBAction) doConnect:(id)sender;
- (IBAction) doDisconnect:(id)sender;
@end
