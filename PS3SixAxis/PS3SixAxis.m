//
//  PS3SixAxis.m
//  PS3_SixAxis
//
//  Created by Tobias Wetzel on 04.05.10.
//  Copyright 2010 Outcut. All rights reserved.
//

#import "PS3SixAxis.h"
#import <IOKit/hid/IOHIDLib.h>
#import <Cocoa/Cocoa.h>
#import <IOBluetooth/objc/IOBluetoothHostController.h>

//#import "sixaxis.h"

#pragma mark -
#pragma mark conditional macro's

#define DO_BLUETOOTH 1
#define DO_SET_MASTER (DO_BLUETOOTH && 1)

//#define TRACE 1

#pragma mark -
#pragma mark static globals

enum Button {
	kButtonsRelease = 0,
	kTriangleButton = 16,
	kCircleButton = 32,
	kTriangleAndCircleButton = 48,
	kCrossButton = 64,
	kTriangleAndCrossButton = 80,
	kCircleAndCrossButton = 96,
	kTriangleAndCircleAndCrossButton = 112,
	kSquareButton = 128,
	kTriangleAndSquareButton = 144,
	kCircleAndSquareButton = 160,
	kTriangleAndSquareAndCircleButton = 176,
	kCrossAndSquareButton = 192,
	kCrossAndSquareAndTriangleButton = 208,
	kCircleAndCrossAndSquareButton = 224,
	kCircleAndCrossAndSquareAndTriangleButton = 240,
	
	
	kL2 = 1,
	kR2 = 2,
	kL2R2 = 3,
	kL1 = 4,
	kL1L2 = 5,
	kL1R2 = 6,
	kL1L2R2 = 7,
	kR1 = 8,
	kR1L2 = 9,
	kR1R2 = 10,
	kR1R2L2 = 11,
	kL1R1 = 12,
	kL1L2R1 = 13,
	kL1R1R2 = 14,
	kL1L2R1R2 = 15
} ButtonTags;

enum DirectionButton {
	kSelectButton = 1,
	kStartButton = 8,
	kSelectAndStartButton = 9,
	kDirectionButtonsRelease = 0,
	kLeftStickButton = 2,
	kRightStickButton = 4,
	kLeftAndRightStickButton = 6,
	kNorthButton = 16,
	kEastButton = 32,
	kNorthEastButton = 48,
	kSouthButton = 64,
	kEastSouthButton = 96,
	kWestButton = 128,
	kWestNorthButton = 144,
	kWestSouthButton = 192
} DirectionButtonTags;

#pragma mark -
#pragma mark static functions

@interface PS3SixAxis (Private)
BOOL isConnected;
BOOL doBluetooth;
IOHIDManagerRef hidManagerRef;
IOHIDDeviceRef gIOHIDDeviceRef = NULL;

BluetoothDeviceAddress gMasterBluetoothAddress;
Boolean gMasterBluetoothAddressValid = FALSE;

BOOL isUseBuffered = YES;

BOOL isLeftStickDown, preIsLeftStickDown;
BOOL isRightStickDown, preIsRightStickDown;
BOOL isTriangleButtonDown, preIsTriangleButtonDown;
BOOL isCircleButtonDown, preIsCircleButtonDown;
BOOL isCrossButtonDown, preIsCrossButtonDown;
BOOL isSquareButtonDown, preIsSquareButtonDown;
BOOL isL1ButtonDown, preIsL1ButtonDown;
BOOL isL2ButtonDown, preIsL2ButtonDown;
BOOL isR1ButtonDown, preIsR1ButtonDown;
BOOL isR2ButtonDown, preIsR2ButtonDown;

BOOL isNorthButtonDown, preIsNorthButtonDown;
BOOL isEastButtonDown, preIsEastButtonDown;
BOOL isSouthButtonDown, preIsSouthButtonDown;
BOOL isWestButtonDown, preIsWestButtonDown;

BOOL isSelectButtonDown, preIsSelectButtonDown;
BOOL isStartButtonDown, preIsStartButtonDown;
BOOL isPSButtonDown, preIsPSButtonDown;

int preLeftStickX, preLeftStickY;
int preRightStickX, preRightStickY;

unsigned int mx, my, mz;

PS3SixAxis *target = NULL;

- (void) parse:(uint8_t*)data l:(CFIndex)length;
- (void) parseUnBuffered:(uint8_t*)data l:(CFIndex)length;
- (void) sendDeviceConnected;
- (void) sendDeviceDisconnected;
- (void) sendDeviceConnectionError:(NSInteger)error;
@end

@implementation PS3SixAxis (Private)

// ask a IOHIDDevice for a feature report
static IOReturn Get_DeviceFeatureReport(IOHIDDeviceRef inIOHIDDeviceRef, CFIndex inReportID, void* inReportBuffer, CFIndex* ioReportSize) {
	IOReturn result = paramErr;
	if (inIOHIDDeviceRef && ioReportSize && inReportBuffer) {
		result = IOHIDDeviceGetReport(inIOHIDDeviceRef, kIOHIDReportTypeFeature, inReportID, inReportBuffer, ioReportSize);
		if (noErr != result) {
			printf("%s, IOHIDDeviceGetReport error: %ld (0x%08lX ).\n", __PRETTY_FUNCTION__, (long int) result, (long int) result);
		}
	}
	return result;
}

// send a IOHIDDevice a feature report
static IOReturn Set_DeviceFeatureReport(IOHIDDeviceRef inIOHIDDeviceRef, CFIndex inReportID, void* inReportBuffer, CFIndex inReportSize) {
	IOReturn result = paramErr;
	if (inIOHIDDeviceRef && inReportSize && inReportBuffer) {
		result = IOHIDDeviceSetReport(inIOHIDDeviceRef, kIOHIDReportTypeFeature, inReportID, inReportBuffer, inReportSize);
		if (noErr != result) {
			printf("%s, IOHIDDeviceSetReport error: %ld (0x%08lX ).\n", __PRETTY_FUNCTION__, (long int) result, (long int) result);
		}
	}
	return result;
}

// ask a PS3 IOHIDDevice for the bluetooth address of its master
static IOReturn PS3_GetMasterBluetoothAddress(IOHIDDeviceRef inIOHIDDeviceRef, BluetoothDeviceAddress*ioBluetoothDeviceAddress) {
	IOReturn result = noErr;
	CFIndex reportID = 0xF5;
	uint8_t report[8];
	CFIndex reportSize = sizeof(report);
	result = IOHIDDeviceGetReport(inIOHIDDeviceRef, kIOHIDReportTypeFeature, reportID, report, &reportSize);
	if (noErr == result) {
		if (ioBluetoothDeviceAddress) {
			memcpy(ioBluetoothDeviceAddress, &report[2], sizeof(*ioBluetoothDeviceAddress));
		}
	} else{
		printf("%s, IOHIDDeviceGetReport error: %ld (0x%08lX ).\n", __PRETTY_FUNCTION__, (long int) result, (long int) result);
	}
	return result;
}

// tell a PS3 IOHIDDevice what bluetooth address to use as its master
static IOReturn PS3_SetMasterBluetoothAddress(IOHIDDeviceRef inIOHIDDeviceRef, BluetoothDeviceAddress inBluetoothDeviceAddress) {
	IOReturn result = paramErr;
	if (inIOHIDDeviceRef) {
		CFIndex reportID = 0xF5;
		uint8_t report[8];		
		report[0] = 0x01; report[1] = 0x00;
		memcpy(&report[2], &inBluetoothDeviceAddress, sizeof(inBluetoothDeviceAddress));
		
		CFIndex reportSize = sizeof(report);
		result = IOHIDDeviceSetReport(inIOHIDDeviceRef, kIOHIDReportTypeFeature, reportID, report, reportSize);
		if (noErr != result) {
			[target sendDeviceConnectionError:101];
			printf("%s, IOHIDDeviceSetReport error: %ld (0x%08lX ).\n", __PRETTY_FUNCTION__, (long int) result, (long int) result);
		}
	}
	return(result);
}

// ask a PS3 IOHIDDevice for its bluetooth address
static IOReturn PS3_GetDeviceBluetoothAddress(IOHIDDeviceRef inIOHIDDeviceRef, BluetoothDeviceAddress*ioBluetoothDeviceAddress) {
	IOReturn result = noErr;
	CFIndex reportID = 0xF2;
	uint8_t report[17];
	CFIndex reportSize = sizeof(report);
	result = IOHIDDeviceGetReport(inIOHIDDeviceRef, kIOHIDReportTypeFeature, reportID, report, &reportSize);
	if (noErr == result) {
		if (ioBluetoothDeviceAddress) {
			memcpy(ioBluetoothDeviceAddress, &report[4], sizeof(*ioBluetoothDeviceAddress));
		}
	} else{
		[target sendDeviceConnectionError:102];
	}
	return result;
}

// tell a PS3 IOHIDDevice to start sending input reports
static IOReturn PS3_StartInputReports(IOHIDDeviceRef inIOHIDDeviceRef) {
	uint8_t buffer[5] = {0x42, 0x03, 0x00, 0x00};
	return(Set_DeviceFeatureReport(inIOHIDDeviceRef, 0xF4, buffer, sizeof(buffer)));
}

// this will be called when an input report is received
static void Handle_IOHIDDeviceIOHIDReportCallback(void* inContext, IOReturn inResult, void* inSender, IOHIDReportType inType, uint32_t inReportID, uint8_t* inReport, CFIndex inReportLength) {
	if(isUseBuffered) {
		[target parse:inReport l:inReportLength];
	} else {
		[target parseUnBuffered:inReport l:inReportLength];
	}

#ifdef TRACE	
	unsigned char ReportType;     //Report Type 01
    unsigned char Reserved1;      // Unknown
    unsigned char ButtonState;    // Main buttons
    unsigned char PSButtonState;  // PS button
    unsigned char Reserved2;      // Unknown
    unsigned char LeftStickX;     // left Joystick X axis 0 - 255, 128 is mid
    unsigned char LeftStickY;     // left Joystick Y axis 0 - 255, 128 is mid
    unsigned char RightStickX;    // right Joystick X axis 0 - 255, 128 is mid
    unsigned char RightStickY;    // right Joystick Y axis 0 - 255, 128 is mid
    unsigned char Reserved3[4];   // Unknown
    unsigned char PressureUp;     // digital Pad Up button Pressure 0 - 255
    unsigned char PressureRight;  // digital Pad Right button Pressure 0 - 255
    unsigned char PressureDown;   // digital Pad Down button Pressure 0 - 255
    unsigned char PressureLeft;   // digital Pad Left button Pressure 0 - 255
    unsigned char PressureL2;     // digital Pad L2 button Pressure 0 - 255
    unsigned char PressureR2;     // digital Pad R2 button Pressure 0 - 255
    unsigned char PressureL1;     // digital Pad L1 button Pressure 0 - 255
    unsigned char PressureR1;     // digital Pad R1 button Pressure 0 - 255
    unsigned char PressureTriangle;   // digital Pad Triangle button Pressure 0 - 255
    unsigned char PressureCircle;     // digital Pad Circle button Pressure 0 - 255
    unsigned char PressureCross;      // digital Pad Cross button Pressure 0 - 255
    unsigned char PressureSquare;     // digital Pad Square button Pressure 0 - 255
    unsigned char Reserved4[3];   // Unknown
    unsigned char Charge;         // charging status ? 02 = charge, 03 = normal
    unsigned char Power;          // Battery status ?
    unsigned char Connection;     // Connection Type ?
    unsigned char Reserved5[9];   // Unknown
    unsigned int AccelX;          // X axis accelerometer Big Endian 0 - 1023
    unsigned int AccelY;          // Y axis accelerometer Big Endian 0 - 1023
    unsigned int AccelZ;          // Z axis accelerometer Big Endian 0 - 1023
    unsigned int GyroZ; 

	// Copy bytes to their respective variables (incase they are not aligned correctly)
	memcpy( &ReportType, &inReport[1], sizeof( unsigned char ) );
	memcpy( &Reserved1, &inReport[2], sizeof( unsigned char ) );
	memcpy( &ButtonState, &inReport[3], sizeof( unsigned char ) );
	memcpy( &PSButtonState, &inReport[4], sizeof( unsigned char ) );
	memcpy( &Reserved2, &inReport[5], sizeof( unsigned char ) );
	memcpy( &LeftStickX, &inReport[6], sizeof( unsigned char ) );
	memcpy( &LeftStickY, &inReport[7], sizeof( unsigned char ) );
	memcpy( &RightStickX, &inReport[8], sizeof( unsigned char ) );
	memcpy( &RightStickY, &inReport[9], sizeof( unsigned char ) );
	memcpy( &Reserved3, &inReport[10], sizeof( unsigned char ) );
	
	memcpy( &PressureUp, &inReport[14], sizeof( unsigned char ) );
	memcpy( &PressureRight, &inReport[15], sizeof( unsigned char ) );
	memcpy( &PressureDown, &inReport[16], sizeof( unsigned char ) );
	memcpy( &PressureLeft, &inReport[17], sizeof( unsigned char ) );
	memcpy( &PressureL2, &inReport[18], sizeof( unsigned char ) );
	memcpy( &PressureR2, &inReport[19], sizeof( unsigned char ) );
	memcpy( &PressureL1, &inReport[20], sizeof( unsigned char ) );
	memcpy( &PressureR1, &inReport[21], sizeof( unsigned char ) );
	
	memcpy( &PressureTriangle, &inReport[22], sizeof( unsigned char ) );
	memcpy( &PressureCircle, &inReport[23], sizeof( unsigned char ) );
	memcpy( &PressureCross, &inReport[24], sizeof( unsigned char ) );
	memcpy( &PressureSquare, &inReport[25], sizeof( unsigned char ) );
	
	memcpy( &Reserved4, &inReport[30], sizeof( unsigned char ) );
	memcpy( &Charge, &inReport[31], sizeof( unsigned char ) );
	memcpy( &Power, &inReport[32], sizeof( unsigned char ) );
	memcpy( &Connection, &inReport[33], sizeof( unsigned char ) );
	memcpy( &Reserved5, &inReport[34], sizeof( unsigned char ) );
	memcpy( &AccelX, &inReport[43], sizeof( unsigned int ) );
	memcpy( &AccelY, &inReport[44], sizeof( unsigned int ) );
	memcpy( &AccelZ, &inReport[45], sizeof( unsigned int ) );
	memcpy( &GyroZ, &inReport[46], sizeof( unsigned int ) );
#endif	
}

static Boolean IOHIDDevice_GetLongProperty_( IOHIDDeviceRef inIOHIDDeviceRef, CFStringRef inKey, long * outValue ) {
	Boolean result = FALSE;
	if (inIOHIDDeviceRef) {
		assert( IOHIDDeviceGetTypeID() == CFGetTypeID( inIOHIDDeviceRef ) );
		CFTypeRef tCFTypeRef = IOHIDDeviceGetProperty( inIOHIDDeviceRef, inKey );
		if ( tCFTypeRef ) {
			// if this is a number
			if ( CFNumberGetTypeID() == CFGetTypeID( tCFTypeRef ) ) {
				// get it's value
				result = CFNumberGetValue( ( CFNumberRef ) tCFTypeRef, kCFNumberSInt32Type, outValue );
			}
		}
	}
	return result;
}

long IOHIDDevice_GetVendorID_( IOHIDDeviceRef inIOHIDDeviceRef ) {
	long result = 0;
	( void ) IOHIDDevice_GetLongProperty_( inIOHIDDeviceRef, CFSTR( kIOHIDVendorIDKey ), &result );
	return result;
}

long IOHIDDevice_GetProductID_( IOHIDDeviceRef inIOHIDDeviceRef ) {
	long result = 0;
	( void ) IOHIDDevice_GetLongProperty_( inIOHIDDeviceRef, CFSTR( kIOHIDProductIDKey ), &result );
	return result;
}

// this will be called when the HID Manager matches a new (hot plugged) HID device
static void Handle_DeviceMatchingCallback(void* inContext, IOReturn inResult, void* inSender, IOHIDDeviceRef inIOHIDDeviceRef) {

	IOReturn ioReturn = noErr;
	
	// Device VendorID/ProductID:   0x054C/0x0268   (Sony Corporation)
	long vendorID = IOHIDDevice_GetVendorID_(inIOHIDDeviceRef);
	long productID = IOHIDDevice_GetProductID_(inIOHIDDeviceRef);

	// Sony PlayStation(R)3 Controller
	if ((0x054C != vendorID) || (0x0268 != productID)) {
		return;
	}
	gIOHIDDeviceRef = inIOHIDDeviceRef;
	
	if (doBluetooth) {
#if DO_BLUETOOTH
		Boolean devicesMasterBluetoothAddressValid = FALSE;
		Boolean masterBluetoothAddressesMatch = TRUE;
		
		BluetoothDeviceAddress tBtDeviceAddr;
		ioReturn = PS3_GetMasterBluetoothAddress(inIOHIDDeviceRef, &tBtDeviceAddr);
		
		if (noErr == ioReturn) {
			devicesMasterBluetoothAddressValid = TRUE;
			//printf("<%02hX-%02hX-%02hX-%02hX-%02hX-%02hX>\n", tBtDeviceAddr.data[0], tBtDeviceAddr.data[1],tBtDeviceAddr.data[2], tBtDeviceAddr.data[3], tBtDeviceAddr.data[4],tBtDeviceAddr.data[5]);
			masterBluetoothAddressesMatch = TRUE;
			int idx;
			for (idx = 0; idx < 6; idx++) {
				if (tBtDeviceAddr.data[idx] != gMasterBluetoothAddress.data[idx]) {
					masterBluetoothAddressesMatch = FALSE;
					break;
				}
			}
			
			if (!masterBluetoothAddressesMatch) {
				[target sendDeviceConnectionError:103];
			}
		} else {
			[target sendDeviceConnectionError:104];
			//printf("%s, PS3_GetMasterBluetoothAddress error: %ld (0x%08lX ).\n", __PRETTY_FUNCTION__, (long int) ioReturn, (long int) ioReturn);
		}
		{
			//printf("	Getting devices current Bluetooth address\n");
			BluetoothDeviceAddress tBtDeviceAddr;
			IOReturn ioReturn = PS3_GetDeviceBluetoothAddress(inIOHIDDeviceRef, &tBtDeviceAddr);
			
			if (noErr == ioReturn) {
				//printf("<%02hX-%02hX-%02hX-%02hX-%02hX-%02hX>\n",tBtDeviceAddr.data[0], tBtDeviceAddr.data[1], tBtDeviceAddr.data[2], tBtDeviceAddr.data[3],tBtDeviceAddr.data[4],tBtDeviceAddr.data[5]);
			}
		}
#endif //  DO_BLUETOOTH
		
#if (DO_BLUETOOTH && DO_SET_MASTER)
		do {
			if (!gMasterBluetoothAddressValid) {
				//printf("	NO BLUETOOTH!\n");
				[target sendDeviceConnectionError:105];
				break;
			}
			
			if (devicesMasterBluetoothAddressValid && !masterBluetoothAddressesMatch) {
				//printf("	Setting devices master Bluetooth address\n");
				ioReturn = PS3_SetMasterBluetoothAddress(inIOHIDDeviceRef, gMasterBluetoothAddress);
				
				if (noErr == ioReturn) {
					//printf("	Getting devices current master Bluetooth address\n");
					BluetoothDeviceAddress tBtDeviceAddr;
					IOReturn ioReturn = PS3_GetMasterBluetoothAddress(inIOHIDDeviceRef, &tBtDeviceAddr);
					
					if (noErr == ioReturn) {
						//printf("<%02hX-%02hX-%02hX-%02hX-%02hX-%02hX>\n",tBtDeviceAddr.data[0],tBtDeviceAddr.data[1], tBtDeviceAddr.data[2], tBtDeviceAddr.data[3],tBtDeviceAddr.data[4],tBtDeviceAddr.data[5]);
						masterBluetoothAddressesMatch = TRUE;
						int idx;
						
						for (idx = 0; idx < 6; idx++) {
							if (tBtDeviceAddr.data[idx] != gMasterBluetoothAddress.data[idx]) {
								masterBluetoothAddressesMatch = FALSE;
								break;
							}
						}
					}
				} else {
					//printf("%s, PS3_SetMasterBluetoothAddress error: %ld (0x%08lX ).\n", __PRETTY_FUNCTION__, (long int) ioReturn, (long int) ioReturn);
					[target sendDeviceConnectionError:106];
				}
			}
		} while (0);
#endif // ( DO_BLUETOOTH && DO_SET_MASTER )
	}
	
	CFIndex reportSize = 64;
	uint8_t*report = malloc(reportSize);
	IOHIDDeviceRegisterInputReportCallback(inIOHIDDeviceRef, report, reportSize, Handle_IOHIDDeviceIOHIDReportCallback, nil);

	[target sendDeviceConnected];
}

// this will be called when a HID device is removed (unplugged)
static void Handle_RemovalCallback(void* inContext, IOReturn inResult, void* inSender, IOHIDDeviceRef inIOHIDDeviceRef) {
	if (gIOHIDDeviceRef == inIOHIDDeviceRef) {
		gIOHIDDeviceRef = NULL;
		[target sendDeviceDisconnected];
	}
}

-(void)sendDeviceConnected {
	isConnected = YES;
	if ([delegate respondsToSelector:@selector(onDeviceConnected)]) {
		[delegate onDeviceConnected];
	}
}

-(void)sendDeviceDisconnected {
	isConnected = NO;
	[self disconnect];
	if ([delegate respondsToSelector:@selector(onDeviceDisconnected)]) {
		[delegate onDeviceDisconnected];
	}
}

-(void)sendDeviceConnectionError:(NSInteger)error {
	isConnected = NO;
	if ([delegate respondsToSelector:@selector(onDeviceConnectionError:)]) {
		[delegate onDeviceConnectionError:error];
	}
}

- (void) parseUnBuffered:(uint8_t*)data l:(CFIndex)length {
	
}

-(void)parse:(uint8_t*)data l:(CFIndex)length {
#pragma mark ButtonStates
	//unsigned char ButtonState;
	//memcpy( &ButtonState, &data[3], sizeof( unsigned char ) );
	//printf("data[3] %u\n", data[3]);
	switch (data[3]) {
		case kButtonsRelease:
			// release all Buttons
			isTriangleButtonDown = NO;
			isCircleButtonDown = NO;
			isCrossButtonDown = NO;
			isSquareButtonDown = NO;
			isL1ButtonDown = NO;
			isL2ButtonDown = NO;
			isR1ButtonDown = NO;
			isR2ButtonDown = NO;
			break;
		case kTriangleButton:
			isTriangleButtonDown = YES;
			isCircleButtonDown = NO;
			isCrossButtonDown = NO;
			isSquareButtonDown = NO;
			break;
		case kTriangleAndCircleButton:
			isTriangleButtonDown = YES;
			isCircleButtonDown = YES;
			isCrossButtonDown = NO;
			isSquareButtonDown = NO;
			break;
		case kTriangleAndCrossButton:
			isTriangleButtonDown = YES;
			isCircleButtonDown = NO;
			isCrossButtonDown = YES;
			isSquareButtonDown = NO;
			break;
		case kTriangleAndSquareButton:
			isTriangleButtonDown = YES;
			isCircleButtonDown = NO;
			isCrossButtonDown = NO;
			isSquareButtonDown = YES;
			break;
		case kCircleButton:
			isTriangleButtonDown = NO;
			isCircleButtonDown = YES;
			isCrossButtonDown = NO;
			isSquareButtonDown = NO;
			break;
		case kCircleAndCrossButton:
			isTriangleButtonDown = NO;
			isCircleButtonDown = YES;
			isCrossButtonDown = YES;
			isSquareButtonDown = NO;
			break;
		case kCircleAndSquareButton:
			isTriangleButtonDown = NO;
			isCircleButtonDown = YES;
			isCrossButtonDown = NO;
			isSquareButtonDown = YES;
			break;
		case kCrossButton:
			isTriangleButtonDown = NO;
			isCircleButtonDown = NO;
			isCrossButtonDown = YES;
			isSquareButtonDown = NO;
			break;
		case kCrossAndSquareButton:
			isTriangleButtonDown = NO;
			isCircleButtonDown = NO;
			isCrossButtonDown = YES;
			isSquareButtonDown = YES;
			break;
		case kSquareButton:
			isTriangleButtonDown = NO;
			isCircleButtonDown = NO;
			isCrossButtonDown = NO;
			isSquareButtonDown = YES;
			break;
		case kTriangleAndCircleAndCrossButton:
			isTriangleButtonDown = YES;
			isCircleButtonDown = YES;
			isCrossButtonDown = YES;
			isSquareButtonDown = NO;
			break;
		case kTriangleAndSquareAndCircleButton:
			isTriangleButtonDown = YES;
			isCircleButtonDown = YES;
			isCrossButtonDown = NO;
			isSquareButtonDown = YES;
			break;
		case kCrossAndSquareAndTriangleButton:
			isTriangleButtonDown = YES;
			isCircleButtonDown = NO;
			isCrossButtonDown = YES;
			isSquareButtonDown = YES;
			break;
		case kCircleAndCrossAndSquareButton:
			isTriangleButtonDown = NO;
			isCircleButtonDown = YES;
			isCrossButtonDown = YES;
			isSquareButtonDown = YES;
			break;
		case kCircleAndCrossAndSquareAndTriangleButton:
			isTriangleButtonDown = YES;
			isCircleButtonDown = YES;
			isCrossButtonDown = YES;
			isSquareButtonDown = YES;
			break;
		case kL1:
			isL1ButtonDown = YES;
			isL2ButtonDown = NO;
			isR1ButtonDown = NO;
			isR2ButtonDown = NO;
			break;
		case kL2:
			isL1ButtonDown = NO;
			isL2ButtonDown = YES;
			isR1ButtonDown = NO;
			isR2ButtonDown = NO;
			break;
		case kR1:
			isL1ButtonDown = NO;
			isL2ButtonDown = NO;
			isR1ButtonDown = YES;
			isR2ButtonDown = NO;
			break;
		case kR2:
			isL1ButtonDown = NO;
			isL2ButtonDown = NO;
			isR1ButtonDown = NO;
			isR2ButtonDown = YES;
			break;
		case kL2R2:
			isL1ButtonDown = NO;
			isL2ButtonDown = YES;
			isR1ButtonDown = NO;
			isR2ButtonDown = YES;
			break;
		case kL1L2:
			isL1ButtonDown = YES;
			isL2ButtonDown = YES;
			isR1ButtonDown = NO;
			isR2ButtonDown = NO;
			break;
		case kL1R2:
			isL1ButtonDown = YES;
			isL2ButtonDown = NO;
			isR1ButtonDown = NO;
			isR2ButtonDown = YES;
			break;
		case kL1L2R2:
			isL1ButtonDown = YES;
			isL2ButtonDown = YES;
			isR1ButtonDown = NO;
			isR2ButtonDown = YES;
			break;
		case kR1L2:
			isL1ButtonDown = NO;
			isL2ButtonDown = YES;
			isR1ButtonDown = YES;
			isR2ButtonDown = NO;
			break;
		case kR1R2:
			isL1ButtonDown = NO;
			isL2ButtonDown = NO;
			isR1ButtonDown = YES;
			isR2ButtonDown = YES;
			break;
		case kR1R2L2:
			isL1ButtonDown = NO;
			isL2ButtonDown = YES;
			isR1ButtonDown = YES;
			isR2ButtonDown = YES;
			break;
		case kL1R1:
			isL1ButtonDown = YES;
			isL2ButtonDown = NO;
			isR1ButtonDown = YES;
			isR2ButtonDown = NO;
			break;
		case kL1L2R1:
			isL1ButtonDown = YES;
			isL2ButtonDown = YES;
			isR1ButtonDown = YES;
			isR2ButtonDown = NO;
			break;
		case kL1R1R2:
			isL1ButtonDown = YES;
			isL2ButtonDown = NO;
			isR1ButtonDown = YES;
			isR2ButtonDown = YES;
			break;
		case kL1L2R1R2:
			isL1ButtonDown = YES;
			isL2ButtonDown = YES;
			isR1ButtonDown = YES;
			isR2ButtonDown = YES;
			break;
		default:
			break;
	}
#pragma mark DirectionButtons
	//unsigned char DirectionButtonState;
	//memcpy( &DirectionButtonState, &data[2], sizeof( unsigned char ) );
	//printf( "DirectionButtonState: %u\n", data[2] );
	switch (data[2]) {
		case kDirectionButtonsRelease:
			// release all Buttons
			isNorthButtonDown = NO;
			isEastButtonDown = NO;
			isSouthButtonDown = NO;
			isWestButtonDown = NO;
			isLeftStickDown = NO;
			isRightStickDown = NO;
			isSelectButtonDown = NO;
			isStartButtonDown = NO;
			break;
		case kNorthButton:
			isNorthButtonDown = YES;
			isEastButtonDown = NO;
			isSouthButtonDown = NO;
			isWestButtonDown = NO;
			break;
		case kEastButton:
			isNorthButtonDown = NO;
			isEastButtonDown = YES;
			isSouthButtonDown = NO;
			isWestButtonDown = NO;
			break;
		case kSouthButton:
			isNorthButtonDown = NO;
			isEastButtonDown = NO;
			isSouthButtonDown = YES;
			isWestButtonDown = NO;
			break;
		case kWestButton:
			isNorthButtonDown = NO;
			isEastButtonDown = NO;
			isSouthButtonDown = NO;
			isWestButtonDown = YES;
			break;
		case kNorthEastButton:
			isNorthButtonDown = YES;
			isEastButtonDown = YES;
			isSouthButtonDown = NO;
			isWestButtonDown = NO;
			break;
		case kEastSouthButton:
			isNorthButtonDown = NO;
			isEastButtonDown = YES;
			isSouthButtonDown = YES;
			isWestButtonDown = NO;
			break;
		case kWestNorthButton:
			isNorthButtonDown = YES;
			isEastButtonDown = NO;
			isSouthButtonDown = NO;
			isWestButtonDown = YES;
			break;
		case kWestSouthButton:
			isNorthButtonDown = NO;
			isEastButtonDown = NO;
			isSouthButtonDown = YES;
			isWestButtonDown = YES;			
			break;
		case kLeftStickButton:
			isLeftStickDown = YES;
			break;
		case kRightStickButton:
			isRightStickDown = YES;
			break;
		case kLeftAndRightStickButton:
			isLeftStickDown = YES;
			isRightStickDown = YES;
			break;
		case kSelectButton:
			isSelectButtonDown = YES;
			break;
		case kStartButton:
			isStartButtonDown = YES;
			break;
		case kSelectAndStartButton:
			isSelectButtonDown = YES;
			isStartButtonDown = YES;
			break;
		default:
			break;
	}

#pragma mark select and start button
	if (isSelectButtonDown != preIsSelectButtonDown) {
		if ([delegate respondsToSelector:@selector(onSelectButton:)]) {
			[delegate onSelectButton:isSelectButtonDown];
		}
		preIsSelectButtonDown = isSelectButtonDown;
	}
	if (isStartButtonDown != preIsStartButtonDown) {
		if ([delegate respondsToSelector:@selector(onStartButton:)]) {
			[delegate onStartButton:isStartButtonDown];
		}
		preIsStartButtonDown = isStartButtonDown;
	}

#pragma mark PSButton
	//unsigned char PSButtonState;
	//memcpy( &PSButtonState, &data[4], sizeof( unsigned char ) );
	BOOL psb = (BOOL)data[4];
	if (psb != preIsPSButtonDown) {
		if ([delegate respondsToSelector:@selector(onPSButton:)]) {
			[delegate onPSButton:psb];
		}
		preIsPSButtonDown = psb;
	}
	
#pragma mark LeftStick
	/*
	unsigned char LeftStickX; // left Joystick X axis 0 - 255, 128 is mid
    unsigned char LeftStickY; // left Joystick Y axis 0 - 255, 128 is mid
	memcpy( &LeftStickX, &data[6], sizeof( unsigned char ) );
	memcpy( &LeftStickY, &data[7], sizeof( unsigned char ) );
	int leftStickX = (int)LeftStickX;
	int leftStickY = (int)LeftStickY;
	*/
	int leftStickX = (int)data[6];
	int leftStickY = (int)data[7];
	if ((leftStickX != preLeftStickX) && (leftStickY != preLeftStickY)) {
		/*
		if ((preLeftStickX < 125 || preLeftStickX > 131) && (preLeftStickY < 125 || preLeftStickY > 131)) {
			
		} else {
			preLeftStickX = 128;
			preLeftStickY = 128;
		}
		*/
		//printf( "LeftStick: %d, %d\n", (int)LeftStickX, (int)LeftStickY );
		if ([delegate respondsToSelector:@selector(onLeftStick:pressed:)]) {
			[delegate onLeftStick:NSMakePoint((float)data[6], (float)data[7]) pressed:isLeftStickDown];
		}
		preLeftStickX = leftStickX;
		preLeftStickY = leftStickY;
	}
	
#pragma mark RightStick
	/*
	unsigned char RightStickX; // right Joystick X axis 0 - 255, 128 is mid
    unsigned char RightStickY; // right Joystick Y axis 0 - 255, 128 is mid
	memcpy( &RightStickX, &data[8], sizeof( unsigned char ) );
	memcpy( &RightStickY, &data[9], sizeof( unsigned char ) );
	int rsx = (int)RightStickX;
	int rsy = (int)RightStickY;
	*/
	int rsx = (int)data[8];
	int rsy = (int)data[9];
	if ((rsx != preRightStickX) && (rsy != preRightStickY)) {
		/*
		 if ((preRightStickX < 125 || preRightStickX > 131) && (preRightStickY < 125 || preRightStickY > 131)) {
		 
		 } else {
		 preRightStickX = 128;
		 preRightStickY = 128;
		 }
		 */
		//printf( "RightStick: %d, %d\n", (int)RightStickX, (int)RightStickY );
		if ([delegate respondsToSelector:@selector(onRightStick:pressed:)]) {
			[delegate onRightStick:NSMakePoint((float)data[8], (float)data[9]) pressed:isRightStickDown];
		}
		preRightStickX = rsx;
		preRightStickY = rsy;
	}
	
#pragma mark Buttons
	// digital Pad Triangle button Trigger
	if(isTriangleButtonDown != preIsTriangleButtonDown) {
		if (!isTriangleButtonDown && [delegate respondsToSelector:@selector(onTriangleButtonWithPressure:)]) {
			[delegate onTriangleButtonWithPressure:0];
		}
		if ([delegate respondsToSelector:@selector(onTriangleButton:)]) {
			[delegate onTriangleButton:isTriangleButtonDown];
		}
		preIsTriangleButtonDown = isTriangleButtonDown;
	}
	// digital Pad Triangle button Pressure 0 - 255
	if(isTriangleButtonDown) {
		if ([delegate respondsToSelector:@selector(onTriangleButtonWithPressure:)]) {
			//unsigned char PressureTriangle;
			//memcpy( &PressureTriangle, &data[22], sizeof( unsigned char ) );
			[delegate onTriangleButtonWithPressure:(NSInteger)data[22]];
		}
	}
	// digital Pad Circle button Trigger
	if(isCircleButtonDown != preIsCircleButtonDown) {
		if (!isCircleButtonDown && [delegate respondsToSelector:@selector(onCircleButtonWithPressure:)]) {
			[delegate onCircleButtonWithPressure:0];
		}
		if ([delegate respondsToSelector:@selector(onCircleButton:)]) {
			[delegate onCircleButton:isCircleButtonDown];
		}
		preIsCircleButtonDown = isCircleButtonDown;
	}
	// digital Pad Circle button Pressure 0 - 255
	if(isCircleButtonDown) {
		if ([delegate respondsToSelector:@selector(onCircleButtonWithPressure:)]) {
			//unsigned char PressureCircle;
			//memcpy( &PressureCircle, &data[23], sizeof( unsigned char ) );
			[delegate onCircleButtonWithPressure:(NSInteger)data[23]];
		}
	}
	
	// Cross Button
	// digital Pad Cross button Trigger
	if(isCrossButtonDown != preIsCrossButtonDown) {
		if (!isCrossButtonDown && [delegate respondsToSelector:@selector(onCrossButtonWithPressure:)]) {
			[delegate onCrossButtonWithPressure:0];
		}		
		if ([delegate respondsToSelector:@selector(onCrossButton:)]) {
			[delegate onCrossButton:isCrossButtonDown];
		}
		preIsCrossButtonDown = isCrossButtonDown;
	}
	// digital Pad Cross button Pressure 0 - 255	
	if(isCrossButtonDown) {
		if ([delegate respondsToSelector:@selector(onCrossButtonWithPressure:)]) {
			//unsigned char PressureCross;
			//memcpy( &PressureCross, &data[24], sizeof( unsigned char ) );
			[delegate onCrossButtonWithPressure:(NSInteger)data[24]];
		}
	}
	
	// Square Button
	// digital Pad Square button Trigger
	if(isSquareButtonDown != preIsSquareButtonDown) {
		if (!isSquareButtonDown && [delegate respondsToSelector:@selector(onSquareButtonWithPressure:)]) {
			[delegate onSquareButtonWithPressure:0];
		}
		if ([delegate respondsToSelector:@selector(onSquareButton:)]) {
			[delegate onSquareButton:isSquareButtonDown];
		}
		preIsSquareButtonDown = isSquareButtonDown;
	}
	// digital Pad Square button Pressure 0 - 255
	if(isSquareButtonDown) {
		if ([delegate respondsToSelector:@selector(onSquareButtonWithPressure:)]) {
			//unsigned char PressureSquare;
			//memcpy( &PressureSquare, &data[25], sizeof( unsigned char ) );
			[delegate onSquareButtonWithPressure:(NSInteger)data[25]];
		}
	}
	
	// L2 Button
	// digital Pad L2 button Trigger
	if(isL2ButtonDown != preIsL2ButtonDown) {
		if (!isL2ButtonDown && [delegate respondsToSelector:@selector(onL2ButtonWithPressure:)]) {
			[delegate onL2ButtonWithPressure:0];
		}
		if ([delegate respondsToSelector:@selector(onL2Button:)]) {
			[delegate onL2Button:isL2ButtonDown];
		}
		preIsL2ButtonDown = isL2ButtonDown;
	}
	// digital Pad L2 button Pressure 0 - 255
	if(isL2ButtonDown) {
		if ([delegate respondsToSelector:@selector(onL2ButtonWithPressure:)]) {
			//unsigned char PressureL2;
			//memcpy( &PressureL2, &data[18], sizeof( unsigned char ) );
			[delegate onL2ButtonWithPressure:(NSInteger)data[18]];
		}
	}
	
	// R2 Button
	// digital Pad R2 button Trigger
	if(isR2ButtonDown != preIsR2ButtonDown) {
		if (!isR2ButtonDown && [delegate respondsToSelector:@selector(onR2ButtonWithPressure:)]) {
			[delegate onR2ButtonWithPressure:0];
		}
		if ([delegate respondsToSelector:@selector(onR2Button:)]) {
			[delegate onR2Button:isR2ButtonDown];
		}
		preIsR2ButtonDown = isR2ButtonDown;
	}
	// digital Pad R2 button Pressure 0 - 255
	if(isR2ButtonDown) {
		if ([delegate respondsToSelector:@selector(onR2ButtonWithPressure:)]) {
			//unsigned char PressureR2;
			//memcpy( &PressureR2, &data[19], sizeof( unsigned char ) );
			[delegate onR2ButtonWithPressure:(NSInteger)data[19]];
		}
	}
	
	// L1 Button
	// digital Pad L1 button Trigger
	if(isL1ButtonDown != preIsL1ButtonDown) {
		if (!isL1ButtonDown && [delegate respondsToSelector:@selector(onL1ButtonWithPressure:)]) {
			[delegate onL1ButtonWithPressure:0];
		}
		if ([delegate respondsToSelector:@selector(onL1Button:)]) {
			[delegate onL1Button:isL1ButtonDown];
		}
		preIsL1ButtonDown = isL1ButtonDown;
	}
	// digital Pad L1 button Pressure 0 - 255
	if(isL1ButtonDown) {
		if ([delegate respondsToSelector:@selector(onL1ButtonWithPressure:)]) {
			//unsigned char PressureL1;
			//memcpy( &PressureL1, &data[20], sizeof( unsigned char ) );
			[delegate onL1ButtonWithPressure:(NSInteger)data[20]];
		}
	}
	
	// R1 Button
	// digital Pad R1 button Trigger
	if(isR1ButtonDown != preIsR1ButtonDown) {
		if (!isR1ButtonDown && [delegate respondsToSelector:@selector(onR1ButtonWithPressure:)]) {
			[delegate onR1ButtonWithPressure:0];
		}
		if ([delegate respondsToSelector:@selector(onR1Button:)]) {
			[delegate onR1Button:isR1ButtonDown];
		}
		preIsR1ButtonDown = isR1ButtonDown;
	}
	// digital Pad R1 button Pressure 0 - 255
	if(isR1ButtonDown) {
		if ([delegate respondsToSelector:@selector(onR1ButtonWithPressure:)]) {
			//unsigned char PressureR1;
			//memcpy( &PressureR1, &data[21], sizeof( unsigned char ) );
			[delegate onR1ButtonWithPressure:(NSInteger)data[21]];
		}
	}

	// North Button
	// Cross North button Trigger
	if(isNorthButtonDown != preIsNorthButtonDown) {
		if (!isNorthButtonDown && [delegate respondsToSelector:@selector(onNorthButtonWithPressure:)]) {
			[delegate onNorthButtonWithPressure:0];
		}
		if ([delegate respondsToSelector:@selector(onNorthButton:)]) {
			[delegate onNorthButton:isNorthButtonDown];
		}
		preIsNorthButtonDown = isNorthButtonDown;
	}
	// Cross North button Pressure 0 - 255
	if(isNorthButtonDown) {
		if ([delegate respondsToSelector:@selector(onNorthButtonWithPressure:)]) {
			//unsigned char PressureNorth;
			//memcpy( &PressureNorth, &data[14], sizeof( unsigned char ) );
			[delegate onNorthButtonWithPressure:(NSInteger)data[14]];
		}
	}
	
	// East Button
	// Cross East button Trigger
	if(isEastButtonDown != preIsEastButtonDown) {
		if (!isEastButtonDown && [delegate respondsToSelector:@selector(onEastButtonWithPressure:)]) {
			[delegate onEastButtonWithPressure:0];
		}
		if ([delegate respondsToSelector:@selector(onEastButton:)]) {
			[delegate onEastButton:isEastButtonDown];
		}
		preIsEastButtonDown = isEastButtonDown;
	}
	// Cross East button Pressure 0 - 255
	if(isEastButtonDown) {
		if ([delegate respondsToSelector:@selector(onEastButtonWithPressure:)]) {
			//unsigned char PressureEast;
			//memcpy( &PressureEast, &data[15], sizeof( unsigned char ) );
			[delegate onEastButtonWithPressure:(NSInteger)data[15]];
		}
	}
	
	// South Button
	// Cross South button Trigger
	if(isSouthButtonDown != preIsSouthButtonDown) {
		if (!isSouthButtonDown && [delegate respondsToSelector:@selector(onSouthButtonWithPressure:)]) {
			[delegate onSouthButtonWithPressure:0];
		}
		if ([delegate respondsToSelector:@selector(onSouthButton:)]) {
			[delegate onSouthButton:isSouthButtonDown];
		}
		preIsSouthButtonDown = isSouthButtonDown;
	}
	// Cross South button Pressure 0 - 255
	if(isSouthButtonDown) {
		if ([delegate respondsToSelector:@selector(onSouthButtonWithPressure:)]) {
			//unsigned char PressureSouth;
			//memcpy( &PressureSouth, &data[16], sizeof( unsigned char ) );
			[delegate onSouthButtonWithPressure:(NSInteger)data[16]];
		}
	}
	
	// West Button
	// Cross West button Trigger
	if(isWestButtonDown != preIsWestButtonDown) {
		if (!isWestButtonDown && [delegate respondsToSelector:@selector(onWestButtonWithPressure:)]) {
			[delegate onWestButtonWithPressure:0];
		}
		if ([delegate respondsToSelector:@selector(onWestButton:)]) {
			[delegate onWestButton:isWestButtonDown];
		}
		preIsWestButtonDown = isWestButtonDown;
	}
	// Cross West button Pressure 0 - 255
	if(isWestButtonDown) {
		if ([delegate respondsToSelector:@selector(onWestButtonWithPressure:)]) {
			//unsigned char PressureWest;
			//memcpy( &PressureWest, &data[17], sizeof( unsigned char ) );
			[delegate onWestButtonWithPressure:(NSInteger)data[17]];
		}
	}
	
	/*
	 Accelerometer data
	 Field	 Example	 Purpose	 Note
	 1	0208	 accX / sin(roll)	 On my sixaxis, +11 is rest, +126 is 90deg left, -100 is 90deg right
	 2	01f2	 accY / sin(pitch)	 On my sixaxis, -19 is rest, -117 is 90deg nose down, +114 is 90deg, controls facing you
	 3	0193	 accZ / gravity	 On my sixaxis, sat on the table is -93, upside down is 131
	*/
	/*
	unsigned char ax1;
	unsigned char ax2;
	unsigned char ay1;
	unsigned char ay2;
	unsigned char az1;
	unsigned char az2;
	memcpy( &ax1, &data[40], sizeof( unsigned char ) );
	memcpy( &ax2, &data[41], sizeof( unsigned char ) );
	memcpy( &ay1, &data[42], sizeof( unsigned char ) );
	memcpy( &ay2, &data[43], sizeof( unsigned char ) );
	memcpy( &az1, &data[44], sizeof( unsigned char ) );
	memcpy( &az2, &data[45], sizeof( unsigned char ) );
	*/
	/* Accelerometers */
	
	/*
	*(uint16_t *)&data[40] = htons(clamp(0, mx + 512, 1023));
	*(uint16_t *)&data[42] = htons(clamp(0, my + 512, 1023));
	*(uint16_t *)&data[44] = htons(clamp(0, mz + 512, 1023));
	
	mx = ntohs(*(uint16_t *)&data[40]) - 512;
	my = ntohs(*(uint16_t *)&data[42]) - 512;
	mz = ntohs(*(uint16_t *)&data[44]) - 512;
	*/
	mx = data[40] | (data[41] << 8);
	my = data[42] | (data[43] << 8);
	mz = data[44] | (data[45] << 8);
//	*(uint16_t *)&data[46] = htons(clamp(0, u->accel.gyro + 512, 1023));
	
	
	//memcpy( &GyroZ, &data[46], sizeof( long int ) );
	//#define byteswap(x) ((x >> 8) | (x << 8))
	//int ax = (ax1 >> 8) | (ax2 << 8);
    //int ay = (ay1 >> 8) | (ay2 << 8);
    //int az = (az1 >> 8) | (az2 << 8);
	//char ax = byteswap(ax2) + ax1;
    //char ay = byteswap(ay2) + ay1;
    //char az = byteswap(az2) + az1;
    //int rz = data[46]<<8 | data[47]; // Needs another patch.
	
	if ([delegate respondsToSelector:@selector(onAxisX:Y:Z:)]) {
		[delegate onAxisX:mx Y:my Z:mz];
	}
}

int clamp(int min, int val, int max)
{
	if (val < min) return min;
	if (val > max) return max;
	return val;		
}

@end

@implementation PS3SixAxis

+ (id)sixAixisController {
	return [[self alloc] init];
}

+ (id)sixAixisControllerWithDelegate:(id<PS3SixAxisDelegate>)aDelegate {
	return [[self alloc] initSixAixisControllerWithDelegate:aDelegate];
}

- (id) initSixAixisControllerWithDelegate:(id<PS3SixAxisDelegate>)aDelegate {
	self = [self init];
	if (self) {
		delegate = aDelegate;
	}
	return self;
}

- (id) init {
	self = [super init];
	if(self) {
		target = self;
	}
	return self;
}

- (void) connect:(BOOL)enableBluetooth {
	
	if (hidManagerRef) {
		if(isConnected) {
			if ([delegate respondsToSelector:@selector(onDeviceConnected)]) {
				[delegate onDeviceConnected];
			}
		}
		return;
	}
	
	int error = 0;
	
	if(enableBluetooth) {
		IOBluetoothHostController*defaultController = [IOBluetoothHostController defaultController];
		if (!defaultController) {
			error = 1;
		}
		
		if ([defaultController getAddress:&gMasterBluetoothAddress] != kIOReturnSuccess) {
			error = 2;
		}
		gMasterBluetoothAddressValid = TRUE;
	}
	
	doBluetooth = enableBluetooth;
	if (enableBluetooth && error != 0) {
		if ([delegate respondsToSelector:@selector(onDeviceConnectionError:)]) {
			[delegate onDeviceConnectionError:error];
		}
		return;
	}
	
	hidManagerRef = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDOptionsTypeNone);
	if (hidManagerRef) {
		// match all devices
		IOHIDManagerSetDeviceMatching(hidManagerRef, NULL);
		
		// Register device matching callback routine
		// This routine will be called when a new (matching) device is connected.
		IOHIDManagerRegisterDeviceMatchingCallback(hidManagerRef, Handle_DeviceMatchingCallback, self);
		
		// Registers a routine to be called when any currently enumerated device is removed.
		// This routine will be called when a (matching) device is disconnected.
		IOHIDManagerRegisterDeviceRemovalCallback(hidManagerRef,Handle_RemovalCallback, self);
		
		// schedule us with the runloop
		IOHIDManagerScheduleWithRunLoop(hidManagerRef, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
		
		IOReturn ioReturn = IOHIDManagerOpen(hidManagerRef, kIOHIDOptionsTypeNone);
		if (noErr != ioReturn) {
			if ([delegate respondsToSelector:@selector(onDeviceConnectionError:)]) {
				[delegate onDeviceConnectionError:(long int)ioReturn];
			}
			//fprintf(stderr, "%s, IOHIDDeviceOpen error: %ld (0x%08lX ).\n", __PRETTY_FUNCTION__, (long int) ioReturn, (long int) ioReturn);
		}
	} else {
		if ([delegate respondsToSelector:@selector(onDeviceConnectionError:)]) {
			[delegate onDeviceConnectionError:3];
		}
	}

}

- (void)disconnect {
	if (hidManagerRef) {
		isConnected = NO;
		IOReturn ioReturn = IOHIDManagerClose(hidManagerRef, kIOHIDOptionsTypeNone);
		if (noErr != ioReturn) {
			//fprintf(stderr, "%s, IOHIDManagerClose error: %ld (0x%08lX ).\n", __PRETTY_FUNCTION__, (long int) ioReturn, (long int) ioReturn);
		}
		CFRelease(hidManagerRef);
		hidManagerRef = NULL;
		if ([delegate respondsToSelector:@selector(onDeviceDisconnected)]) {
			[delegate onDeviceDisconnected];
		}
	}
}

- (void) setDelegate:(id<PS3SixAxisDelegate>)aDelegate {
	delegate = aDelegate;
}

- (id<PS3SixAxisDelegate>)delegate {
	return delegate;
}

- (void)setUseBuffered:(BOOL)doUseBuffered {
	useBuffered = isUseBuffered = doUseBuffered;
}

- (BOOL)useBuffered {
	return useBuffered;
}

@end
