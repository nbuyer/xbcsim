unit UXBCSim;
{
 XBox controller keyboard/mouse simulator by Edward G.
 v0.3 2025-03-04
 * Added workaround to ignore wakeup key by delaying 1 second
 v0.2 2025-03-03
 * Replaced Sleep() with DoSleep()
 v0.1 2025-03-02
 * Initial version
}

{.$DEFINE DEBUGXBC} // debug output message

interface

uses
  SysUtils, Classes, UITypes, Diagnostics, TimeSpan,
  Windows, XInput, SendInputHelper;

const
  XBC_DEF_CHK_MS = 30; // Default check controller states interval

  DIV_TRIGGER = 4; // 0..3
  TRIGGER_TRIGGER = (DIV_TRIGGER div 2);
  DIV_TRIGGER_VAL = (256 div 4);
  DIV_THUMB = 8; // -8..+8
  DIV_THUMB_VAL = (32768 div DIV_THUMB);
  TRIGGER_THUMB = (DIV_THUMB div 2);

  VK_REPEAT = $8000; // This key will be sent repeatly when holding button
  VK_MASK = $0FFF; // Actual virtual key code bits

  // Return flags of XCBtnSim() and XCThumbStickSim()
  SIM_FLAG_KB = $01;          // sent keyboard key(s)
  SIM_FLAG_MB_LEFT = $02;     // sent mouse left button
  SIM_FLAG_MB_RIGHT = $04;    // sent mouse right button
  SIM_FLAG_MB_MID = $08;      // sent moues middle button
  SIM_FLAG_MOUSE_MOVE = $10;  // sent mouse movement
  SIM_FLAG_REPEAT_KEY = $20;  // repeat key(s) sent

const TXCButtonsBits = 16;
type  TXCButtonsWord = Word; // same size for TXCButtons

type
  // XBox controllor button set
  TXCButton = (xbUp, xbDown, xbLeft, xbRight, xbStart, xbBack,
    xbLThumb, xbRThumb, xbLShoulder, xbRShoulder, xbA, xbB, xbX, xbY,
    xbNone);

  TXCButtons = set of TXCButton;

  TXControllerThumbData = record
    LT: Byte; // Left trigger
    RT: Byte; // Right trigger
    LX: Integer; // LeftThumbstickX
    LY: Integer; // LeftThumbstickY
    RX: Integer; // RightThumbstickX
    RY: Integer; // RightThumbstickY
    nDelayLT: Integer; // delay # rounds of left trigger
    nDelayRT: Integer; // delay # rounds of right trigger
    nDelayLS: Integer; // delay # rounds of left thumbstick
    nDelayRS: Integer; // delay # rounds of right thumbstick
  end;

  TXControllerData = record
    B: TXCButtons;
    T: TXControllerThumbData;
  end;

  // Controller simulate keyboard/mouse thread
  TXControllerSimThread = class(TThread)
  private
    m_hDev: Integer;  // device id, 0-3
    m_nInterval: Integer; // check interval, default is XBC_DEF_CHK_MS
    m_bDisable: Boolean; // temp disable checking
    m_aWakeupBtn: TXCButton;
    m_eOnWakeUp: TNotifyEvent;
  protected
    procedure Execute; override;
  public
    constructor Create(nDev: Integer; nInterval: Integer = XBC_DEF_CHK_MS; bDisable: Boolean = False);
    destructor Destroy; override;
    procedure SetWakeupButton(aBtn: TXCButton; eOnWakeUp: TNotifyEvent);
  public
    property DeviceID: Integer read m_hDev;
    property Interval: Integer read m_nInterval;
    property Disabled: Boolean read m_bDisable write m_bDisable;
  end;

  // Thread to wait controller's one key and call wakeup
  // only useful when TXControllerSimThread is disabled and no wakeup button
  TXControllerWakeupThread = class(TThread)
  private
    m_hDev: Integer;
    m_nWait: Integer;
    m_aBtn: TXCButton;
    m_eOnWakeUp: TNotifyEvent;
  protected
    procedure Execute; override;
  public
    // eOnWakeUp event will be called in another thread, not main thread
    constructor Create(hDev: Integer; nWait: Integer; aBtn: TXCButton; eOnWakeUp: TNotifyEvent);
  end;

{
  Get XBox controller data
  Returns:
    0: success
    -1: invalid parameter
    -2: no device connected
    -3: not support, no DLL
    -4: other error
}
function GetXBControllerData(nDev: Integer; var rCD: TXControllerData): Integer;

var
  // Change these arrays to control keys you want to simulate
  // VK_OEM_4=[, VK_OEM_6=]
  // add "or VK_REPEAT" if you need this key repeatly sending when pressing button
  g_yXCSimKeys: array[TXCButton] of Word = (VK_UP or VK_REPEAT, VK_DOWN or VK_REPEAT,
    VK_LEFT or VK_REPEAT, VK_RIGHT or VK_REPEAT, VK_HOME, VK_END, 0, 0,
    VK_PRIOR or VK_REPEAT, VK_NEXT or VK_REPEAT, VK_RETURN, VK_ESCAPE,
    VK_TAB, VK_TAB, 0);
  g_yXCSimShifts: array[TXCButton] of TShiftState = ([], [],
    [], [], [ssCtrl], [ssCtrl], [ssLeft], [ssRight],
    [], [], [], [],
    [ssShift], [], []);
  // User can also change these vars
  // trigger greater than this will sim click
  g_nXCTriggerClick: Byte = TRIGGER_TRIGGER-1;
  // Simulate which mouse button when trigger pressed
  g_eXCTriggerLeft: TMouseButton = TMouseButton.mbRight;
  g_eXCTriggerRight: TMouseButton = TMouseButton.mbLeft;
  // Delay of right thumbstick to avoid too fast sending arrow keys
  g_nXCDelayRS: Integer = 3;
  // Mouse movement sleep in MS
  g_nXCMouseMoveSleep: Integer = 10;
  // Repeated button sleep in MS
  g_nXCRepeatSleep: Integer = 150;
  // Wakeup sleep in MS
  g_nXCWakeupSleep: Integer = 1000;

implementation

const
  yXCBtnNames: array[TXCButton] of string = ('Up', 'Down', 'Left', 'Right',
    'Start', 'Back', 'LeftThumb', 'RightThumb', 'LeftShoulder', 'RightShoulder',
    'A', 'B', 'X', 'Y', 'n/a');

function XIGetState(hDev: Integer; var rST: XINPUT_STATE): DWORD;
begin
  FillChar(rST, SizeOf(rST), 0);
  Result := XInputGetState(hDev, rST);
end;

function ConvertToButtons(Buttons: WORD): TXCButtons;
begin
  Result := [];
  if (Buttons and XINPUT_GAMEPAD_DPAD_UP)<>0 then
    Include(Result, xbUp);
  if (Buttons and XINPUT_GAMEPAD_DPAD_DOWN)<>0 then
    Include(Result, xbDown);
  if (Buttons and XINPUT_GAMEPAD_DPAD_LEFT)<>0 then
    Include(Result, xbLeft);
  if (Buttons and XINPUT_GAMEPAD_DPAD_RIGHT)<>0 then
    Include(Result, xbRight);
  if (Buttons and XINPUT_GAMEPAD_START)<>0 then
    Include(Result, xbStart);
  if (Buttons and XINPUT_GAMEPAD_BACK)<>0 then
    Include(Result, xbBack);
  if (Buttons and XINPUT_GAMEPAD_LEFT_THUMB)<>0 then
    Include(Result, xbLThumb);
  if (Buttons and XINPUT_GAMEPAD_RIGHT_THUMB)<>0 then
    Include(Result, xbRThumb);
  if (Buttons and XINPUT_GAMEPAD_LEFT_SHOULDER)<>0 then
    Include(Result, xbLShoulder);
  if (Buttons and XINPUT_GAMEPAD_RIGHT_SHOULDER)<>0 then
    Include(Result, xbRShoulder);
  if (Buttons and XINPUT_GAMEPAD_A)<>0 then
    Include(Result, xbA);
  if (Buttons and XINPUT_GAMEPAD_B)<>0 then
    Include(Result, xbB);
  if (Buttons and XINPUT_GAMEPAD_X)<>0 then
    Include(Result, xbX);
  if (Buttons and XINPUT_GAMEPAD_Y)<>0 then
    Include(Result, xbY);
end;

const ERROR_DEVICE_NOT_CONNECTED = 1167;

function GetXBControllerData(nDev: Integer; var rCD: TXControllerData): Integer;
var
  rST: XINPUT_STATE;
begin
  Result := -1;
  FillChar(rCD, sizeof(rCD), 0);
  if (nDev<0) or (nDev>XUSER_MAX_COUNT) then Exit;

  if not Assigned(XInputGetState) then
  begin
    Result := -3;
    Exit;
  end;

  case XIGetState(nDev, rST) of
  ERROR_SUCCESS: ;
  ERROR_DEVICE_NOT_CONNECTED:
    begin
      Result := -2;
      Exit;
    end;
  else
    begin
      Result := -4;
      Exit;
    end;
  end;

{$IFDEF DEBUG}
  if rST.Gamepad.wButtons<>0 then
  begin
    if rST.dwPacketNumber<>0 then ; // set break point here
  end;
{$ENDIF}
  rCD.B := ConvertToButtons(rST.Gamepad.wButtons);

  // 0-255
  rCD.T.LT := rST.Gamepad.bLeftTrigger;
  rCD.T.RT := rST.Gamepad.bRightTrigger;
  // X=-32768 if left most
  rCD.T.LX := rST.Gamepad.sThumbLX;
  // Y=-32768 if bottom most
  rCD.T.LY := rST.Gamepad.sThumbLY;
  rCD.T.RX := rST.Gamepad.sThumbRX;
  rCD.T.RY := rST.Gamepad.sThumbRY;

  Result := 0;
end;

// Convert thumbstick values to little numbers
function GetXBControllerDataDiv(nDev: Integer; var rCD: TXControllerData): Integer;
begin
  Result := GetXBControllerData(nDev, rCD);
  if Result=0 then
  begin
    rCD.T.LT := rCD.T.LT div DIV_TRIGGER_VAL;
    rCD.T.RT := rCD.T.RT div DIV_TRIGGER_VAL;
    rCD.T.LX := rCD.T.LX div DIV_THUMB_VAL;
    rCD.T.LY := rCD.T.LY div DIV_THUMB_VAL;
    rCD.T.RX := rCD.T.RX div DIV_THUMB_VAL;
    rCD.T.RY := rCD.T.RY div DIV_THUMB_VAL;
  end;
end;

// Button simulation
function XCBtnSim(SIH: TSendInputHelper; var Current, Last: TXCButtons): UInt32;
var
  aChgBtns: TXCButtons;
  i: Integer;
  w: TXCButtonsWord;
  btnChg: TXCButton;
  bPress, bRelease, bRepeat: Boolean;
  VK: Word;
  ss: TShiftState;
begin
  aChgBtns := TXCButtons(TXCButtonsWord(Current) xor TXCButtonsWord(Last));
  Result := 0;

  if aChgBtns=[] then
  begin
    // no changing since last
    // check only keys allow repeat
    for i := 0 to TXCButtonsBits-1 do
    begin
      w := TXCButtonsWord(Current) and (1 shl i);
      if w<>0 then
      begin
        btnChg := TXCButton(i);
        ss := g_yXCSimShifts[btnChg];
        VK := g_yXCSimKeys[btnChg];
        if VK and VK_REPEAT<>0 then
        begin
          VK := VK and VK_MASK;
          if (ss<>[]) then SIH.AddShift(ss, True, False);
          SIH.AddVirtualKey(VK);
          if (ss<>[]) then SIH.AddShift(ss, False, True);
          Result := Result or SIM_FLAG_REPEAT_KEY;
  {$IFDEF DEBUGXBC}
          Writeln(Format('XBC "%s" repeat: VK=%d, SS=%d', [yXCBtnNames[btnChg], VK, Word(ss)]));
  {$ENDIF}
        end;
      end;
    end;
  end else
  begin
    for i := 0 to TXCButtonsBits-1 do
    begin
      w := TXCButtonsWord(aChgBtns) and (1 shl i);
      if w<>0 then
      begin
        btnChg := TXCButton(i);
        bPress := btnChg in Current;
        bRelease := not bPress;
        VK := g_yXCSimKeys[btnChg];
        ss := g_yXCSimShifts[btnChg];
  {$IFDEF DEBUGXBC}
        Writeln(Format('XBC "%s" pressed: %d, VK=%d, SS=%d', [yXCBtnNames[btnChg],
          Byte(bPress), VK, Word(ss)]));
  {$ENDIF}
        if VK<>0 then
        begin
          bRepeat := VK and VK_REPEAT<>0;
          VK := VK and VK_MASK;
          if not bRepeat then // repeat key will not be sent in Down/Up process
          begin
            if bPress and (ss<>[]) then SIH.AddShift(ss, True, False);
            // Send key
            SIH.AddVirtualKey(VK, bPress, bRelease);
            // Send up
            if bRelease and (ss<>[]) then SIH.AddShift(ss, False, True);
          end;
          Result := Result or SIM_FLAG_KB;
        end else
        begin
          // not a key, check mouse from shiftstate
          if ss=[ssLeft] then
          begin
            // Send mouse left click
            SIH.AddMouseClick(TMouseButton.mbLeft, bPress, bRelease);
            Result := Result or SIM_FLAG_MB_LEFT;
          end else
          if ss=[ssRight] then
          begin
            // Send mouse right click
            SIH.AddMouseClick(TMouseButton.mbRight, bPress, bRelease);
            Result := Result or SIM_FLAG_MB_RIGHT;
          end else
          if ss=[ssMiddle] then
          begin
            // Send mouse middle click
            SIH.AddMouseClick(TMouseButton.mbMiddle, bPress, bRelease);
            Result := Result or SIM_FLAG_MB_MID;
          end;
        end;
      end;
    end;
  end;
end;

// ThumbStick simulation
function XCThumbStickSim(SIH: TSendInputHelper; var Current, Last: TXControllerThumbData): UInt32;
begin
  Result := 0;
  // Now all -3..3  or 0..3
  
  if Current.LT<>Last.LT then
  begin
{$IFDEF DEBUGXBC}
    Writeln(Format('LT=%d:%d', [Current.LT, Last.LT]));
{$ENDIF}
    if Last.nDelayLT>0 then Last.nDelayLT := 3; // wait until release
    // Last LT low and current LT high
    if (Current.LT>=g_nXCTriggerClick) and (Last.LT<=g_nXCTriggerClick-1) then
    begin
      // send click
      if Last.nDelayLT=0 then
      begin
        SIH.AddMouseClick(g_eXCTriggerLeft);
        case g_eXCTriggerLeft of
        TMouseButton.mbLeft: Result := Result or SIM_FLAG_MB_LEFT;
        TMouseButton.mbRight: Result := Result or SIM_FLAG_MB_RIGHT;
        TMouseButton.mbMiddle: Result := Result or SIM_FLAG_MB_MID;
        end;
        Last.nDelayLT := 3;
      end;
    end else
    begin
      // Last LT high and current LT low, reset counter
      if (Last.LT>=g_nXCTriggerClick) and (Current.LT<=g_nXCTriggerClick-1) then
      begin
        Last.nDelayLT := 0;
      end;
    end;
  end;

  if Current.RT<>Last.RT then
  begin
{$IFDEF DEBUGXBC}
    Writeln(Format('RT=%d:%d', [Current.RT, Last.RT]));
{$ENDIF}
    if Last.nDelayRT>0 then Last.nDelayRT := 3; // wait until release
    // Last RT low and current RT high
    if (Current.RT>=g_nXCTriggerClick) and (Last.RT<=g_nXCTriggerClick-1) then
    begin
      // send click
      if Last.nDelayRT=0 then
      begin
        SIH.AddMouseClick(g_eXCTriggerRight);
        case g_eXCTriggerRight of
        TMouseButton.mbLeft: Result := Result or SIM_FLAG_MB_LEFT;
        TMouseButton.mbRight: Result := Result or SIM_FLAG_MB_RIGHT;
        TMouseButton.mbMiddle: Result := Result or SIM_FLAG_MB_MID;
        end;
        Last.nDelayRT := 3;
      end;
    end else
    begin
      // Last RT high and current RT low, reset counter
      if (Last.RT>=g_nXCTriggerClick) and (Current.RT<=g_nXCTriggerClick-1) then
      begin
        Last.nDelayRT := 0;
      end;
    end;
  end;

  if Last.nDelayLS=0 then
  begin
    if (Current.LX<>0) or (Current.LY<>0) then
    begin
      SIH.AddRelativeMouseMove(Current.LX, -Current.LY);
      Result := Result or SIM_FLAG_MOUSE_MOVE;
    end;
  end;

  if Last.nDelayRS=0 then
  begin
    if Current.RX<=-TRIGGER_THUMB then
    begin
{$IFDEF DEBUGXBC}
      Writeln(Format('RX=%d:%d', [Current.RX, Last.RX]));
{$ENDIF}
      SIH.AddVirtualKey(VK_LEFT);
      Result := Result or SIM_FLAG_KB;
      Last.nDelayRS := g_nXCDelayRS;
    end else
    if Current.RX>=TRIGGER_THUMB then
    begin
{$IFDEF DEBUGXBC}
      Writeln(Format('RX=%d:%d', [Current.RX, Last.RX]));
{$ENDIF}
      SIH.AddVirtualKey(VK_RIGHT);
      Result := Result or SIM_FLAG_KB;
      Last.nDelayRS := g_nXCDelayRS;
    end;

    if Current.RY<=-TRIGGER_THUMB then
    begin
{$IFDEF DEBUGXBC}
      Writeln(Format('RY=%d:%d', [Current.RY, Last.RY]));
{$ENDIF}
      SIH.AddVirtualKey(VK_DOWN);
      Result := Result or SIM_FLAG_KB;
      Last.nDelayRS := g_nXCDelayRS;
    end else
    if Current.RY>=TRIGGER_THUMB then
    begin
{$IFDEF DEBUGXBC}
      Writeln(Format('RY=%d:%d', [Current.RY, Last.RY]));
{$ENDIF}
      SIH.AddVirtualKey(VK_UP);
      Result := Result or SIM_FLAG_KB;
      Last.nDelayRS := g_nXCDelayRS;
    end;
  end;

  // Sub one round
  if Last.nDelayLT>0 then
  begin
    Dec(Last.nDelayLT);
    Current.nDelayLT := Last.nDelayLT;
  end;
  if Last.nDelayRT>0 then
  begin
    Dec(Last.nDelayRT);
    Current.nDelayRT := Last.nDelayRT;
  end;
  if Last.nDelayLS>0 then
  begin
    Dec(Last.nDelayLS);
    Current.nDelayLS := Last.nDelayLS;
  end;
  if Last.nDelayRS>0 then
  begin
    Dec(Last.nDelayRS);
    Current.nDelayRS := Last.nDelayRS;
  end;
end;

function DoSleep(nMS: Integer; pbCancel: PBoolean): Integer;
var
  cSW: TStopWatch;
  nTick, nTick2: Int64;
begin
  Result := 0;
  cSW := TStopWatch.Create;
  nTick := cSW.GetTimeStamp;
  nTick2 := nTick+(TTimeSpan.TicksPerMillisecond)*nMS;
  repeat
    SysUtils.Sleep(10);
    if pbCancel<>nil then
      if pbCancel^ then
      begin
        Result := -1;
        Break;
      end;
    nTick := cSW.GetTimeStamp;
  until nTick>=nTick2;
end;

{ TXControllerSimThread }

constructor TXControllerSimThread.Create(nDev, nInterval: Integer; bDisable: Boolean);
begin
  m_hDev := nDev;
  m_nInterval := nInterval;
  if m_nInterval<=0 then m_nInterval := XBC_DEF_CHK_MS;
  m_bDisable := bDisable;
  m_aWakeupBtn := xbNone;
  inherited Create;
end;

destructor TXControllerSimThread.Destroy;
begin
  inherited;
end;

procedure TXControllerSimThread.Execute;
label lblAgain;
var
  rCD, rLastCD: TXControllerData;
  SIH: TSendInputHelper;
  bFirst: Boolean;
  n1, n2: Integer;
begin
  FillChar(rCD, sizeof(rCD), 0);
  FillChar(rLastCD, sizeof(rLastCD), 0);
  bFirst := True;

  SIH := TSendInputHelper.Create;
  try
    while not Terminated do
    begin
      DoSleep(m_nInterval, @Terminated);
lblAgain:
      if Terminated then Break;
      if not m_bDisable then
      begin
        if GetXBControllerDataDiv(m_hDev, rCD)<>0 then Continue;
        if bFirst then
        begin
          bFirst := False;
          rLastCD := rCD;
        end;

        // Check wakeup button?
        if m_aWakeupBtn<>xbNone then
        begin
          if m_aWakeupBtn in rCD.B then
          begin
            m_aWakeupBtn := xbNone;
            if Assigned(m_eOnWakeUp) then
            try
              m_eOnWakeUp(Self);
            except
            end;
            rLastCD := rCD;
            Continue;
          end;
        end;

        // Has to check buttons for repeat keys
        n1 := XCBtnSim(SIH, rCD.B, rLastCD.B);
        // Has to check joystick to continuous moving mouse
        n2 := XCThumbStickSim(SIH, rCD.T, rLastCD.T);
        SIH.Flush;
        rLastCD := rCD;
        if n2 and SIM_FLAG_MOUSE_MOVE<>0 then
        begin
          // mouse move, no custom sleep
          DoSleep(g_nXCMouseMoveSleep, @Terminated);  // too fast if no sleep
          goto lblAgain;
        end;
        if n1 and SIM_FLAG_REPEAT_KEY<>0 then
        begin
          // repeated key
          if g_nXCRepeatSleep>0 then DoSleep(g_nXCRepeatSleep, @Terminated);
        end;
      end else
      begin
        if m_aWakeupBtn<>xbNone then
        begin
          // still monitor wakeup button even disabled
          if GetXBControllerDataDiv(m_hDev, rCD)=0 then
          begin
            rLastCD := rCD;
            if m_aWakeupBtn in rCD.B then
            begin
              m_aWakeupBtn := xbNone;
              if Assigned(m_eOnWakeUp) then
              try
                m_eOnWakeUp(Self);
              except
              end;
              // Workaround to ignore this key's up by waiting (1) second
              DoSleep(g_nXCWakeupSleep, @Terminated);
              if GetXBControllerDataDiv(m_hDev, rCD)=0 then rLastCD := rCD;
            end;
          end;
        end;
      end;
    end;
  except
  end;
  SIH.Free;
end;

procedure TXControllerSimThread.SetWakeupButton(aBtn: TXCButton;
  eOnWakeUp: TNotifyEvent);
begin
  // need a lock?
  m_eOnWakeUp := eOnWakeUp;
  m_aWakeupBtn := aBtn;
end;

{ TXControllerWakeupThread }

constructor TXControllerWakeupThread.Create(hDev: Integer; nWait: Integer;
  aBtn: TXCButton; eOnWakeUp: TNotifyEvent);
begin
  m_hDev := hDev;
  m_nWait := nWait; // 300ms maybe
  m_aBtn := aBtn;
  m_eOnWakeUp := eOnWakeUp;
  inherited Create(False);
  //FreeOnTerminate := True;
end;

procedure TXControllerWakeupThread.Execute;
var
  rCD: TXControllerData;
begin
  // wait for a while
  DoSleep(m_nWait, @Terminated);
  while not Terminated do
  begin
    DoSleep(XBC_DEF_CHK_MS, @Terminated);
    try
      if GetXBControllerDataDiv(m_hDev, rCD)<>0 then Continue;
      begin
        if (rCD.B<>[]) then
        begin
          if m_aBtn in rCD.B then
          begin
            m_eOnWakeUp(Self);
            Break;
          end;
        end;
      end;
    except
      Break;
    end;
  end;
end;

end.
