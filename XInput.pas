(***************************************************************************
*                                                                          *
*   XInput.h -- This module defines Xbox 360 Common Controller APIs        *
*               and constants for the Windows platform.                    *
*                                                                          *
*   Copyright (c) Microsoft Corp. All rights reserved.                     *
*                                                                          *
***************************************************************************)

unit XInput;

{$ALIGN ON}
{$MINENUMSIZE 4}
{$WEAKPACKAGEUNIT}

interface

uses SysUtils, Windows;

// Current name of the DLL shipped in the same SDK as this header.
// The name reflects the current version

const
  XINPUT_DLL = 'xinput1_4.dll';

//
// Device types available in XINPUT_CAPABILITIES
//

const
  XINPUT_DEVTYPE_GAMEPAD = $01;

//
// Device subtypes available in XINPUT_CAPABILITIES
//

const
  XINPUT_DEVSUBTYPE_GAMEPAD          = $01;

  XINPUT_DEVSUBTYPE_UNKNOWN          = $00;
  XINPUT_DEVSUBTYPE_WHEEL            = $02;
  XINPUT_DEVSUBTYPE_ARCADE_STICK     = $03;
  XINPUT_DEVSUBTYPE_FLIGHT_STICK     = $04;
  XINPUT_DEVSUBTYPE_DANCE_PAD        = $05;
  XINPUT_DEVSUBTYPE_GUITAR           = $06;
  XINPUT_DEVSUBTYPE_GUITAR_ALTERNATE = $07;
  XINPUT_DEVSUBTYPE_DRUM_KIT         = $08;
  XINPUT_DEVSUBTYPE_GUITAR_BASS      = $0B;
  XINPUT_DEVSUBTYPE_ARCADE_PAD       = $13;

//
// Flags for XINPUT_CAPABILITIES
//

const
  XINPUT_CAPS_VOICE_SUPPORTED = $0004;

  XINPUT_CAPS_FFB_SUPPORTED   = $0001;
  XINPUT_CAPS_WIRELESS        = $0002;
  XINPUT_CAPS_PMD_SUPPORTED   = $0008;
  XINPUT_CAPS_NO_NAVIGATION   = $0010;

//
// Constants for gamepad buttons
//

const
  XINPUT_GAMEPAD_DPAD_UP        = $0001;
  XINPUT_GAMEPAD_DPAD_DOWN      = $0002;
  XINPUT_GAMEPAD_DPAD_LEFT      = $0004;
  XINPUT_GAMEPAD_DPAD_RIGHT     = $0008;
  XINPUT_GAMEPAD_START          = $0010;
  XINPUT_GAMEPAD_BACK           = $0020;
  XINPUT_GAMEPAD_LEFT_THUMB     = $0040;
  XINPUT_GAMEPAD_RIGHT_THUMB    = $0080;
  XINPUT_GAMEPAD_LEFT_SHOULDER  = $0100;
  XINPUT_GAMEPAD_RIGHT_SHOULDER = $0200;
  XINPUT_GAMEPAD_A              = $1000;
  XINPUT_GAMEPAD_B              = $2000;
  XINPUT_GAMEPAD_X              = $4000;
  XINPUT_GAMEPAD_Y              = $8000;

//
// Gamepad thresholds
//

const
  XINPUT_GAMEPAD_LEFT_THUMB_DEADZONE  = 7849;
  XINPUT_GAMEPAD_RIGHT_THUMB_DEADZONE = 8689;
  XINPUT_GAMEPAD_TRIGGER_THRESHOLD    = 30;

//
// Flags to pass to XInputGetCapabilities
//

const
  XINPUT_FLAG_GAMEPAD = $00000001;

//
// Devices that support batteries
//

const
  BATTERY_DEVTYPE_GAMEPAD = $00;
  BATTERY_DEVTYPE_HEADSET = $01;

//
// Flags for battery status level
//

const
  BATTERY_TYPE_DISCONNECTED = $00; // This device is not connected
  BATTERY_TYPE_WIRED        = $01; // Wired device, no battery
  BATTERY_TYPE_ALKALINE     = $02; // Alkaline battery source
  BATTERY_TYPE_NIMH         = $03; // Nickel Metal Hydride battery source
  BATTERY_TYPE_UNKNOWN      = $FF; // Cannot determine the battery type

// These are only valid for wireless, connected devices, with known battery types
// The amount of use time remaining depends on the type of device.

  BATTERY_LEVEL_EMPTY  = $00;
  BATTERY_LEVEL_LOW    = $01;
  BATTERY_LEVEL_MEDIUM = $02;
  BATTERY_LEVEL_FULL   = $03;

// User index definitions

const
  XUSER_MAX_COUNT = 4;

  XUSER_INDEX_ANY = $000000FF;

//
// Codes returned for the gamepad keystroke
//

const
  VK_PAD_A                = $5800;
  VK_PAD_B                = $5801;
  VK_PAD_X                = $5802;
  VK_PAD_Y                = $5803;
  VK_PAD_RSHOULDER        = $5804;
  VK_PAD_LSHOULDER        = $5805;
  VK_PAD_LTRIGGER         = $5806;
  VK_PAD_RTRIGGER         = $5807;

  VK_PAD_DPAD_UP          = $5810;
  VK_PAD_DPAD_DOWN        = $5811;
  VK_PAD_DPAD_LEFT        = $5812;
  VK_PAD_DPAD_RIGHT       = $5813;
  VK_PAD_START            = $5814;
  VK_PAD_BACK             = $5815;
  VK_PAD_LTHUMB_PRESS     = $5816;
  VK_PAD_RTHUMB_PRESS     = $5817;

  VK_PAD_LTHUMB_UP        = $5820;
  VK_PAD_LTHUMB_DOWN      = $5821;
  VK_PAD_LTHUMB_RIGHT     = $5822;
  VK_PAD_LTHUMB_LEFT      = $5823;
  VK_PAD_LTHUMB_UPLEFT    = $5824;
  VK_PAD_LTHUMB_UPRIGHT   = $5825;
  VK_PAD_LTHUMB_DOWNRIGHT = $5826;
  VK_PAD_LTHUMB_DOWNLEFT  = $5827;

  VK_PAD_RTHUMB_UP        = $5830;
  VK_PAD_RTHUMB_DOWN      = $5831;
  VK_PAD_RTHUMB_RIGHT     = $5832;
  VK_PAD_RTHUMB_LEFT      = $5833;
  VK_PAD_RTHUMB_UPLEFT    = $5834;
  VK_PAD_RTHUMB_UPRIGHT   = $5835;
  VK_PAD_RTHUMB_DOWNRIGHT = $5836;
  VK_PAD_RTHUMB_DOWNLEFT  = $5837;

//
// Flags used in XINPUT_KEYSTROKE
//

const
  XINPUT_KEYSTROKE_KEYDOWN = $0001;
  XINPUT_KEYSTROKE_KEYUP   = $0002;
  XINPUT_KEYSTROKE_REPEAT  = $0004;

//
// Structures used by XInput APIs
//

type
  XINPUT_GAMEPAD = record
    wButtons: WORD;
    bLeftTrigger: BYTE;
    bRightTrigger: BYTE;
    sThumbLX: SHORT;
    sThumbLY: SHORT;
    sThumbRX: SHORT;
    sThumbRY: SHORT;
  end;
  PXINPUT_GAMEPAD = ^XINPUT_GAMEPAD;

  XINPUT_STATE = record
    dwPacketNumber: DWORD;
    Gamepad: XINPUT_GAMEPAD;
  end;
  PXINPUT_STATE = ^XINPUT_STATE;

  XINPUT_VIBRATION = record
    wLeftMotorSpeed: WORD;
    wRightMotorSpeed: WORD;
  end;
  PXINPUT_VIBRATION = ^XINPUT_VIBRATION;

  XINPUT_CAPABILITIES = record
    Type_: BYTE;
    SubType: BYTE;
    Flags: WORD;
    Gamepad: XINPUT_GAMEPAD;
    Vibration: XINPUT_VIBRATION;
  end;
  PXINPUT_CAPABILITIES = ^XINPUT_CAPABILITIES;

  XINPUT_BATTERY_INFORMATION = record
    BatteryType: BYTE;
    BatteryLevel: BYTE;
  end;
  PXINPUT_BATTERY_INFORMATION = ^XINPUT_BATTERY_INFORMATION;

  XINPUT_KEYSTROKE = record
    VirtualKey: WORD;
    Unicode: WCHAR;
    Flags: WORD;
    UserIndex: BYTE;
    HidCode: BYTE;
  end;
  PXINPUT_KEYSTROKE = ^XINPUT_KEYSTROKE;

//
// XInput APIs
//

TXInputGetState = function
(
    {_In_}  dwUserIndex: DWORD;      // Index of the gamer associated with the device
    {_Out_} out pState: XINPUT_STATE // Receives the current state
): DWORD; stdcall;

TXInputSetState = function
(
    {_In_} dwUserIndex: DWORD;              // Index of the gamer associated with the device
    {_In_} var pVibration: XINPUT_VIBRATION // The vibration information to send to the controller
): DWORD; stdcall;

TXInputGetCapabilities = function
(
    {_In_}  dwUserIndex: DWORD;                    // Index of the gamer associated with the device
    {_In_}  dwFlags: DWORD;                        // Input flags that identify the device type
    {_Out_} out pCapabilities: XINPUT_CAPABILITIES // Receives the capabilities
): DWORD; stdcall;

TXInputEnable = procedure
(
    {_In_} enable: BOOL // [in] Indicates whether xinput is enabled or disabled.
); stdcall; { deprecated }

TXInputGetAudioDeviceIds = function
(
    {_In_}                             dwUserIndex: DWORD;       // Index of the gamer associated with the device
    {_Out_writes_opt_(*pRenderCount)}  pRenderDeviceId: LPWSTR;  // Windows Core Audio device ID string for render (speakers)
    {_Inout_opt_}                      var pRenderCount: UINT;   // Size of render device ID string buffer (in wide-chars)
    {_Out_writes_opt_(*pCaptureCount)} pCaptureDeviceId: LPWSTR; // Windows Core Audio device ID string for capture (microphone)
    {_Inout_opt_}                      var pCaptureCount: UINT   // Size of capture device ID string buffer (in wide-chars)
): DWORD; stdcall;

TXInputGetBatteryInformation = function
(
    {_In_}  dwUserIndex: DWORD;                                 // Index of the gamer associated with the device
    {_In_}  devType: BYTE;                                      // Which device on this user index
    {_Out_} out pBatteryInformation: XINPUT_BATTERY_INFORMATION // Contains the level and types of batteries
): DWORD; stdcall;

TXInputGetKeystroke = function
(
    {_In_}       dwUserIndex: DWORD;               // Index of the gamer associated with the device
    {_Reserved_} dwReserved: DWORD;                // Reserved for future use
    {_Out_}      out pKeystroke: PXINPUT_KEYSTROKE // Pointer to an XINPUT_KEYSTROKE structure that receives an input event.
): DWORD; stdcall;

TXInputGetDSoundAudioDeviceGuids = function
(
    {_In_}  dwUserIndex: DWORD;           // Index of the gamer associated with the device
    {_Out_} out pDSoundRenderGuid: TGUID; // DSound device ID for render (speakers)
    {_Out_} out pDSoundCaptureGuid: TGUID // DSound device ID for capture (microphone)
): DWORD; stdcall; //deprecated;

const
  FN_XInputGetState = 'XInputGetState';
  FN_XInputSetState = 'XInputSetState';
  FN_XInputGetCapabilities = 'XInputGetCapabilities';
  FN_XInputEnable = 'XInputEnable';
  FN_XInputGetAudioDeviceIds = 'XInputGetAudioDeviceIds';
  FN_XInputGetBatteryInformation = 'XInputGetBatteryInformation';
  FN_XInputGetKeystroke = 'XInputGetKeystroke';
  FN_XInputGetDSoundAudioDeviceGuids = 'XInputGetDSoundAudioDeviceGuids';

var
  XInputGetState: TXInputGetState = nil;
  XInputSetState: TXInputSetState = nil;
  XInputGetCapabilities: TXInputGetCapabilities = nil;
  XInputEnable: TXInputEnable = nil;
  XInputGetAudioDeviceIds: TXInputGetAudioDeviceIds = nil;
  XInputGetBatteryInformation: TXInputGetBatteryInformation = nil;
  XInputGetKeystroke: TXInputGetKeystroke = nil;
  XInputGetDSoundAudioDeviceGuids: TXInputGetDSoundAudioDeviceGuids = nil;

implementation

var
  hXInput: HMODULE = 0;

procedure LoadXInputDLL;
begin
  if hXInput<>0 then Exit;
  hXInput := SysUtils.SafeLoadLibrary(XINPUT_DLL);
  if hXInput<>0 then
  begin
    XInputGetState := TXInputGetState(GetProcAddress(hXInput, FN_XInputGetState));
    XInputSetState := TXInputSetState(GetProcAddress(hXInput, FN_XInputSetState));
    XInputGetCapabilities := TXInputGetCapabilities(GetProcAddress(hXInput, FN_XInputGetCapabilities));
    XInputEnable := TXInputEnable(GetProcAddress(hXInput, FN_XInputEnable));
    XInputGetAudioDeviceIds := TXInputGetAudioDeviceIds(GetProcAddress(hXInput, FN_XInputGetAudioDeviceIds));
    XInputGetBatteryInformation := TXInputGetBatteryInformation(GetProcAddress(hXInput, FN_XInputGetBatteryInformation));
    XInputGetKeystroke := TXInputGetKeystroke(GetProcAddress(hXInput, FN_XInputGetKeystroke));
    XInputGetDSoundAudioDeviceGuids := TXInputGetDSoundAudioDeviceGuids(GetProcAddress(hXInput, FN_XInputGetDSoundAudioDeviceGuids));
  end;
end;

procedure UnloadXInputDLL;
begin
  if hXInput<>0 then
  begin
    FreeLibrary(hXInput);
    hXInput := 0;
  end;
end;

initialization
  LoadXInputDLL;
finalization
  UnloadXInputDLL;

end.
