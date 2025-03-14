// License
//
// The contents of this file are subject to the Mozilla Public License
// Version 1.1 (the "License"); you may not use this file except in
// compliance with the License. You may obtain a copy of the License at
// http://www.mozilla.org/MPL/
//
// Software distributed under the License is distributed on an "AS IS"
// basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See the
// License for the specific language governing rights and limitations
// under the License.
//
// The Original Code is SendInputHelper.pas.
//
// The Initial Developer of the Original Code is Waldemar Derr.
// Portions created by Waldemar Derr are Copyright (C) Waldemar Derr.
// All Rights Reserved.
//
//
// Acknowledgements
//
// - Thanks to Marco Warm for his code suggest to support any unicode chars
//   <http://www.delphipraxis.net/1063517-post4.html>
// - Thanks to PeterPanino for his bug fix
//   <https://www.delphipraxis.net/1188701-post17.html>
//
// @author Waldemar Derr <furevest@gmail.com>
// Altered by Edward G. <nbuyer@gmail.com> 2025-03

unit SendInputHelper;

// EdwardG: compatible with VCL/FMX
{$IF DECLARED(FireMonkeyVersion)}
  {$DEFINE FRAMEWORK_FMX}
{$ELSE}
{$IFNDEF FRAMEWORK_FMX}
  {$DEFINE FRAMEWORK_VCL}
{$ENDIF}
{$IFEND}


interface

uses
  System.SysUtils,
  System.Classes,
  System.Types,
  System.UITypes,
{$IFDEF FRAMEWORK_FMX}
  FMX.Forms,
{$ELSE}
  Forms,
{$ENDIF}
  Generics.Collections,
  Winapi.Windows;

type
  TInputArray = array of TInput;

  // Local ShiftState type, with the supported subset and the new ssWin entry
  TSIHShiftState = set of (
    sssShift = Ord(System.Classes.ssShift),
    sssAlt = Ord(System.Classes.ssAlt),
    sssCtrl = Ord(System.Classes.ssCtrl),
    sssWin = Ord(System.Classes.ssCommand)); // EdwardG: name conflict

  TSendInputHelper = class(TList<TInput>)
  protected
    class function MergeInputs(InputsBatch: array of TInputArray): TInputArray;
  public
    class function ConvertShiftState(ClassesShiftState: System.Classes.TShiftState): TSIHShiftState;
    class function GetKeyboardInput(VirtualKey, ScanCode: Word; Flags, Time: Cardinal): TInput;
    class function GetVirtualKey(VirtualKey: Word; Press, Release: Boolean): TInputArray;
    class function GetShift(ShiftState: TSIHShiftState; Press, Release: Boolean): TInputArray;
    class function GetChar(SendChar: Char; Press, Release: Boolean): TInputArray;
    class function GetUnicodeChar(SendChar: Char; Press, Release: Boolean): TInputArray;
    class function GetText(SendText: string; AppendReturn: Boolean): TInputArray;
    class function GetShortCut(ShiftState: TSIHShiftState; ShortChar: Char): TInputArray; overload;
    class function GetShortCut(ShiftState: TSIHShiftState; ShortVK: Word): TInputArray; overload;

    class function GetMouseInput(X, Y: Integer; MouseData, Flags, Time: DWORD): TInput;
    class function GetMouseClick(MouseButton: TMouseButton; Press, Release: Boolean): TInputArray;
    class function GetRelativeMouseMove(DeltaX, DeltaY: Integer): TInputArray;
    class function GetAbsoluteMouseMove(X, Y: Integer; DesktopCoordinates: Boolean): TInputArray;
    class function GetMouseWheel(var p: TPoint; Delta: Integer): TInputArray; // EdwardG

    class function IsVirtualKeyPressed(VirtualKey: Word): Boolean;

    procedure AddKeyboardInput(VirtualKey, ScanCode: Word; Flags, Time: Cardinal);
    procedure AddVirtualKey(VirtualKey: Word; Press: Boolean = True; Release: Boolean = True);

    procedure AddShift(ShiftState: TSIHShiftState; Press, Release: Boolean); overload;
    procedure AddShift(ShiftState: System.Classes.TShiftState; Press, Release: Boolean); overload;
    procedure AddShortCut(ShiftState: TSIHShiftState; ShortChar: Char); overload;
    procedure AddShortCut(ShiftState: TSIHShiftState; ShortVK: Word); overload;
    procedure AddShortCut(ShiftState: System.Classes.TShiftState; ShortChar: Char); overload;
    procedure AddShortCut(ShiftState: System.Classes.TShiftState; ShortVK: Word); overload;
    procedure AddChar(SendChar: Char; Press: Boolean = True; Release: Boolean = True);
    procedure AddText(SendText: string; AppendReturn: Boolean = False);

    procedure AddMouseClick(MouseButton: TMouseButton; Press: Boolean = True; Release: Boolean = True);
    procedure AddRelativeMouseMove(DeltaX, DeltaY: Integer);
    procedure AddAbsoluteMouseMove(X, Y: Integer; DesktopCoordinates: Boolean = True);
    procedure AddMouseWheel(var p: TPoint; Delta: Integer=WHEEL_DELTA); // EdwardG

    procedure AddDelay(Milliseconds: Cardinal);

    function GetInputArray: TInputArray;
    procedure Flush;
  end;

  // Declaration in Windows.pas (until Delphi 2010) is corrupted, this one is correct:
  function SendInput(cInputs: Cardinal; pInputs: TInputArray; cbSize: Integer): Cardinal; stdcall;

implementation

const
   // This constant is used as a fake input type for a delay
   //
   // @see AddDelay and Flush
  INPUT_DELAY = INPUT_HARDWARE + 1;

  // Missing constant in Windows.pas until D2010
  KEYEVENTF_UNICODE = 4;

function SendInput; external user32 name 'SendInput';

{ TSendInputHelper }

// Add inputs, that are required to produce the passed char
//
// @see GetChar
procedure TSendInputHelper.AddChar(SendChar: Char; Press, Release: Boolean);
var
  Inputs: TInputArray;
begin
  Inputs := GetChar(SendChar, Press, Release);
  if Assigned(Inputs) then
    AddRange(Inputs);
end;

procedure TSendInputHelper.AddMouseClick(MouseButton: TMouseButton; Press, Release: Boolean);
var
  Inputs: TInputArray;
begin
  Inputs := GetMouseClick(MouseButton, Press, Release);
  if Assigned(Inputs) then
    AddRange(Inputs);
end;

procedure TSendInputHelper.AddMouseWheel(var p: TPoint; Delta: Integer);
var
  Inputs: TInputArray;
begin
  Inputs := GetMouseWheel(p, Delta);
  if Assigned(Inputs) then
    AddRange(Inputs);
end;

procedure TSendInputHelper.AddRelativeMouseMove(DeltaX, DeltaY: Integer);
var
  Inputs: TInputArray;
begin
  Inputs := GetRelativeMouseMove(DeltaX, DeltaY);
  if Assigned(Inputs) then
    AddRange(Inputs);
end;

procedure TSendInputHelper.AddAbsoluteMouseMove(X, Y: Integer; DesktopCoordinates: Boolean);
var
  Inputs: TInputArray;
begin
  Inputs := GetAbsoluteMouseMove(X, Y, DesktopCoordinates);
  if Assigned(Inputs) then
    AddRange(Inputs);
end;

// Add a delay for passed milliseconds
//
// This is not a part of the SendInput call, but a extension from this class and is exclusively
// supported by using the Flush method.
//
// @see Flush
procedure TSendInputHelper.AddDelay(Milliseconds: Cardinal);
var
  DelayInput: TInput;
begin
  DelayInput.Itype := INPUT_DELAY;
  DelayInput.ki.time := Milliseconds;
  Add(DelayInput);
end;

// Add a single keyboard input
//
// @see GetKeyboardInput
procedure TSendInputHelper.AddKeyboardInput(VirtualKey, ScanCode: Word; Flags, Time: Cardinal);
begin
  Add(GetKeyboardInput(VirtualKey, ScanCode, Flags, Time));
end;

// Add combined "Shift" keys input, this are Ctrl, Alt, Win or the Shift key
//
// @see GetShift
procedure TSendInputHelper.AddShift(ShiftState: TSIHShiftState; Press, Release: Boolean);
var
  Inputs: TInputArray;
begin
  Inputs := GetShift(ShiftState, Press, Release);
  if Assigned(Inputs) then
    AddRange(Inputs);
end;

procedure TSendInputHelper.AddShift(ShiftState: System.Classes.TShiftState;
  Press, Release: Boolean);
begin
  AddShift(ConvertShiftState(ShiftState), Press, Release);
end;

// Add required keyboard inputs, to produce a regular keyboard short cut
//
// @see GetShortCut
procedure TSendInputHelper.AddShortCut(ShiftState: TSIHShiftState; ShortVK: Word);
var
  Inputs: TInputArray;
begin
  Inputs := GetShortCut(ShiftState, ShortVK);
  if Assigned(Inputs) then
    AddRange(Inputs);
end;

procedure TSendInputHelper.AddShortCut(ShiftState: TSIHShiftState; ShortChar: Char);
var
  Inputs: TInputArray;
begin
  Inputs := GetShortCut(ShiftState, ShortChar);
  if Assigned(Inputs) then
    AddRange(Inputs);
end;

procedure TSendInputHelper.AddShortCut(ShiftState: System.Classes.TShiftState; ShortChar: Char);
begin
  AddShortCut(ConvertShiftState(ShiftState), ShortChar);
end;

procedure TSendInputHelper.AddShortCut(ShiftState: System.Classes.TShiftState; ShortVK: Word);
begin
  AddShortCut(ConvertShiftState(ShiftState), ShortVK);
end;

// Add keyboard strokes, to produce the passed string
//
// @see GetText
procedure TSendInputHelper.AddText(SendText: string; AppendReturn: Boolean);
var
  Inputs: TInputArray;
begin
  Inputs := GetText(SendText, AppendReturn);
  if Assigned(Inputs) then
    AddRange(Inputs);
end;

// Add (optional) a press or release keyboard input for the passed VirtualKey
//
// @see GetVirtualKey
procedure TSendInputHelper.AddVirtualKey(VirtualKey: Word; Press, Release: Boolean);
var
  Inputs: TInputArray;
begin
  Inputs := GetVirtualKey(VirtualKey, Press, Release);
  if Assigned(Inputs) then
    AddRange(Inputs);
end;

class function TSendInputHelper.ConvertShiftState(
  ClassesShiftState: System.Classes.TShiftState): TSIHShiftState;
begin
  Result := [];
  if System.Classes.ssShift in ClassesShiftState then
    Include(Result, sssShift);
  if System.Classes.ssAlt in ClassesShiftState then
    Include(Result, sssAlt);
  if System.Classes.ssCtrl in ClassesShiftState then
    Include(Result, sssCtrl);
  if System.Classes.ssCommand in ClassesShiftState then // EdwardG
    Include(Result, sssWin);
end;

// Flushes all added inputs to SendInput
//
// This method is blocking for summarized milliseconds, if any delays are previously added
// through AddDelay.
//
// After calling it, the list get cleared.
procedure TSendInputHelper.Flush;
var
  Input: TInput;
  Inputs: TInputArray;
  InputsCount: Integer;

  procedure LocalSendInput;
  begin
    SendInput(InputsCount, Inputs, SizeOf(TInput));
  end;

begin
  if Count = 0 then
    Exit;

  // Neutralize the real current keyboard state
  if GetKeyState(VK_CAPITAL) = 1 then
  begin
    InsertRange(0, GetVirtualKey(VK_CAPITAL, True, True));
    AddVirtualKey(VK_CAPITAL, True, True);
  end;

  InputsCount := 0;
  SetLength(Inputs, Count);
  for Input in Self do
  begin
    if Input.Itype = INPUT_DELAY then
    begin
      LocalSendInput;
      Sleep(Input.ki.time);
      InputsCount := 0;
      Continue;
    end;
    Inputs[InputsCount] := Input;
    Inc(InputsCount);
  end;
  LocalSendInput;
  Clear;
end;

class function TSendInputHelper.GetUnicodeChar(SendChar: Char; Press, Release: Boolean): TInputArray;
var
  KeyDown, KeyUp: TInput;
begin
  if not (Press or Release) then
    Exit(nil);

  KeyDown.Itype := INPUT_KEYBOARD;
  KeyDown.ki.wVk := 0;
  KeyDown.ki.wScan := Word(SendChar);
  KeyDown.ki.dwFlags := KEYEVENTF_UNICODE;
  KeyDown.ki.time := 0;
  KeyDown.ki.dwExtraInfo := GetMessageExtraInfo;

  SetLength(Result, Ord(Press) + Ord(Release));

  if Press then
    Result[0] := KeyDown;
  if Release then
  begin
    KeyUp := KeyDown;
    KeyUp.ki.dwFlags := KeyUp.ki.dwFlags or KEYEVENTF_KEYUP;
    Result[Ord(Press)] := KeyUp;
  end;
end;

// Return a TInputArray with keyboard inputs, that are required to produce the passed char.
class function TSendInputHelper.GetChar(SendChar: Char; Press, Release: Boolean): TInputArray;
var
  ScanCode: Word;
  ShiftState: TSIHShiftState;
  PreShifts, Chars, AppShifts: TInputArray;
begin
  if not (Press or Release) then
    Exit(nil);
  if not ((Ord(SendChar) > 0) and (Ord(SendChar) < 127)) then
  begin
    Result := GetUnicodeChar(SendChar, Press, Release);
    Exit;
  end;

  ScanCode := VkKeyScan(SendChar);
  PreShifts := nil;
  Chars := nil;
  AppShifts := nil;
  ShiftState := [];
  // Shift
  if (ScanCode and $100) <> 0 then
    Include(ShiftState, sssShift);
  // Control
  if (ScanCode and $200) <> 0 then
    Include(ShiftState, sssCtrl);
  // Alt
  if (ScanCode and $400) <> 0 then
    Include(ShiftState, sssAlt);

  Chars := GetVirtualKey(ScanCode, Press, Release);
  if Press then
  begin
    PreShifts := GetShift(ShiftState, True, False);
    AppShifts := GetShift(ShiftState, False, True);
  end;
  Result := MergeInputs([PreShifts, Chars, AppShifts]);
end;

// Return a TInputArray with all previously added inputs
//
// This is useful, when you plan to modify or process it further in your custom code.
//
// Notice, that the misused input entries, that are added by AddDelay, are included too, but are
// not suitable for direct flush to SendInput. At best, don't use AddDelay if you use the returned
// array by this method.
function TSendInputHelper.GetInputArray: TInputArray;
var
  Input: TInput;
  cc: Integer;
begin
  SetLength(Result, Count);
  cc := 0;
  for Input in Self do
  begin
    Result[cc] := Input;
    Inc(cc);
  end;
end;

// Return a single keyboard input entry
class function TSendInputHelper.GetKeyboardInput(VirtualKey, ScanCode: Word; Flags,
  Time: Cardinal): TInput;
begin
  Result.Itype := INPUT_KEYBOARD;
  Result.ki.wVk := VirtualKey;
  Result.ki.wScan := ScanCode;
  Result.ki.dwFlags := Flags;
  Result.ki.time := Time;
end;

// Return combined TInputArray with "shift" keys input, this are Ctrl, Alt, Win or the Shift key
class function TSendInputHelper.GetShift(ShiftState: TSIHShiftState;
  Press, Release: Boolean): TInputArray;
var
  Shifts, Ctrls, Alts, Wins: TInputArray;
begin
  if sssShift in ShiftState then
    Shifts := GetVirtualKey(VK_SHIFT, Press, Release)
  else
    Shifts := nil;

  if sssCtrl in ShiftState then
    Ctrls := GetVirtualKey(VK_CONTROL, Press, Release)
  else
    Ctrls := nil;

  if sssAlt in ShiftState then
    Alts := GetVirtualKey(VK_MENU, Press, Release)
  else
    Alts := nil;

  if sssWin in ShiftState then
    Wins := GetVirtualKey(VK_LWIN, Press, Release)
  else
    Wins := nil;

  Result := MergeInputs([Ctrls, Alts, Wins, Shifts]);
end;

// Return required keyboard inputs in a TInputArray, to produce a regular keyboard short cut
class function TSendInputHelper.GetShortCut(ShiftState: TSIHShiftState; ShortChar: Char): TInputArray;
var
  PreShifts, Chars, AppShifts: TInputArray;
begin
  PreShifts := GetShift(ShiftState, True, False);
  Chars := GetChar(ShortChar, True, True);
  AppShifts := GetShift(ShiftState, False, True);
  Result := MergeInputs([PreShifts, Chars, AppShifts]);
end;

class function TSendInputHelper.GetShortCut(ShiftState: TSIHShiftState; ShortVK: Word): TInputArray;
var
  PreShifts, VKs, AppShifts: TInputArray;
begin
  PreShifts := GetShift(ShiftState, True, False);
  VKs := GetVirtualKey(ShortVK, True, True);
  AppShifts := GetShift(ShiftState, False, True);
  Result := MergeInputs([PreShifts, VKs, AppShifts]);
end;

class function TSendInputHelper.GetMouseInput(X, Y: Integer; MouseData, Flags, Time: DWORD): TInput;
begin
  Result.Itype := INPUT_MOUSE;
  Result.mi.dx := X;
  Result.mi.dy := Y;
  Result.mi.mouseData := MouseData;
  Result.mi.dwFlags := Flags;
  Result.mi.time := Time;
end;

class function TSendInputHelper.GetMouseWheel(var p: TPoint; Delta: Integer): TInputArray;
begin
  if p.X<0 then GetCursorPos(p);
  SetLength(Result, 1);
  Result[0] := GetMouseInput(p.x, p.y, Delta, MOUSEEVENTF_WHEEL, 0);
end;

class function TSendInputHelper.GetMouseClick(MouseButton: TMouseButton;
  Press, Release: Boolean): TInputArray;

  function PressFlags: Cardinal;
  begin
    case MouseButton of
      TMouseButton.mbLeft:
        Result := MOUSEEVENTF_LEFTDOWN;
      TMouseButton.mbRight:
        Result := MOUSEEVENTF_RIGHTDOWN;
      TMouseButton.mbMiddle:
        Result := MOUSEEVENTF_MIDDLEDOWN;
    else
      Result := 0;
    end;
  end;

  function ReleaseFlags: Cardinal;
  begin
    case MouseButton of
      TMouseButton.mbLeft:
        Result := MOUSEEVENTF_LEFTUP;
      TMouseButton.mbRight:
        Result := MOUSEEVENTF_RIGHTUP;
      TMouseButton.mbMiddle:
        Result := MOUSEEVENTF_MIDDLEUP;
    else
      Result := 0;
    end;
  end;

begin
  if not (Press or Release) then
    Exit(nil);
  SetLength(Result, Ord(Press) + Ord(Release));
  if Press then
    Result[0] := GetMouseInput(0, 0, 0, PressFlags, 0);
  if Release then
    Result[Ord(Press)] := GetMouseInput(0, 0, 0, ReleaseFlags, 0);
end;

class function TSendInputHelper.GetRelativeMouseMove(DeltaX, DeltaY: Integer): TInputArray;
begin
  SetLength(Result, 1);
  Result[0] := GetMouseInput(DeltaX, DeltaY, 0, MOUSEEVENTF_MOVE, 0);
end;

class function TSendInputHelper.GetAbsoluteMouseMove(X, Y: Integer;
  DesktopCoordinates: Boolean): TInputArray;
const
  MOUSEEVENTF_VIRTUALDESK = $4000;
  COORDINATE_MAX = $FFFF;

  function NormalizeDimension(Value, RefValue: Integer): Integer;
  begin
    Result := Round(Value * (COORDINATE_MAX / RefValue));
  end;

{$IFNDEF FRAMEWORK_FMX}
var
  Flags: Cardinal;
  RefSize: TSize;
  DesktopRect: TRect;
begin
  SetLength(Result, 1);
  Flags := MOUSEEVENTF_MOVE or MOUSEEVENTF_ABSOLUTE;

  if DesktopCoordinates then
  begin
    DesktopRect := Screen.DesktopRect;
    RefSize := DesktopRect.Size;

    // Offset the origin to get the virtual screen coordinates
    // This is only in multi monitor setups required.
    if DesktopRect.Left <> 0 then
      X := X - DesktopRect.Left;
    if DesktopRect.Top <> 0 then
      Y := Y - DesktopRect.Top;

    Flags := Flags or MOUSEEVENTF_VIRTUALDESK
  end
  else
    RefSize := Screen.PrimaryMonitor.BoundsRect.Size;


  Result[0] := GetMouseInput(
    NormalizeDimension(X, RefSize.cx), NormalizeDimension(Y, RefSize.cy), 0, Flags, 0);
end;
{$ELSE !FRAMEWORK_FMX}
// EdwardG: made compiler shutup, not tested
var
  Flags: Cardinal;
  RefSize: TSizeF;
  DesktopRect: TRectF;
begin
  SetLength(Result, 1);
  Flags := MOUSEEVENTF_MOVE or MOUSEEVENTF_ABSOLUTE;

  if DesktopCoordinates then
  begin
    DesktopRect := Screen.DesktopRect;
    RefSize := DesktopRect.Size;

    // Offset the origin to get the virtual screen coordinates
    // This is only in multi monitor setups required.
    if DesktopRect.Left <> 0 then
      X := X - Trunc(DesktopRect.Left);
    if DesktopRect.Top <> 0 then
      Y := Y - Trunc(DesktopRect.Top);

    Flags := Flags or MOUSEEVENTF_VIRTUALDESK
  end else
  begin
    RefSize := Screen.Displays[0].BoundsRect.Size;
  end;

  Result[0] := GetMouseInput(
    NormalizeDimension(X, Trunc(RefSize.cx)), NormalizeDimension(Y, Trunc(RefSize.cy)), 0, Flags, 0);
end;
{$ENDIF !FRAMEWORK_FMX}

// Return a TInputArray with keyboard inputs, to produce the passed string
//
// @see GetText
class function TSendInputHelper.GetText(SendText: string; AppendReturn: Boolean): TInputArray;
var
  cc: Integer;
begin
  Result := nil;
  for cc := 1 to Length(SendText) do
    Result := MergeInputs([Result, GetChar(SendText[cc], True, True)]);
  if Assigned(Result) and AppendReturn then
    Result := MergeInputs([Result, GetVirtualKey(VK_RETURN, True, True)]);
end;

// Return a TInputArray that contains entries for a press or release for the passed VirtualKey
//
// @see GetVirtualKey
class function TSendInputHelper.GetVirtualKey(VirtualKey: Word;
  Press, Release: Boolean): TInputArray;
begin
  if not (Press or Release) then
    Exit(nil);
  SetLength(Result, Ord(Press) + Ord(Release));
  if Press then
    Result[0] := GetKeyboardInput(VirtualKey, 0, 0, 0);
  if Release then
    Result[Ord(Press)] := GetKeyboardInput(VirtualKey, 0, KEYEVENTF_KEYUP, 0);
end;

// Determine, whether at the time of call, the passed key is pressed or not
class function TSendInputHelper.IsVirtualKeyPressed(VirtualKey: Word): Boolean;
begin
  Result := (GetAsyncKeyState(VirtualKey) and $8000 shr 15) = 1;
end;

// Merges several TInputArray's into one and return it
//
// If all passed TInputArray's are nil or empty, then nil is returned.
class function TSendInputHelper.MergeInputs(InputsBatch: array of TInputArray): TInputArray;
var
  Inputs: TInputArray;
  InputsLength, Index: Integer;
  cc, ccc: Integer;
begin
  Result := nil;
  InputsLength := 0;
  for cc := 0 to Length(InputsBatch) - 1 do
    if Assigned(InputsBatch[cc]) then
      InputsLength := InputsLength + Length(InputsBatch[cc]);
  if InputsLength = 0 then
    Exit;
  SetLength(Result, InputsLength);
  Index := 0;
  for cc := 0 to Length(InputsBatch) - 1 do
  begin
    if not Assigned(InputsBatch[cc]) then
      Continue;
    Inputs := InputsBatch[cc];
    for ccc := 0 to Length(Inputs)- 1 do
    begin
      Result[Index] := Inputs[ccc];
      Inc(Index);
    end;
  end;
end;

end.
