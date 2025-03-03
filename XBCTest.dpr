program XBCTest;
{$APPTYPE CONSOLE}
{$I-,Q-,R-}

{$R *.res}

uses
  SysUtils, Classes, UXBCSim;

var
  cThrd: TXControllerSimThread;
begin
  Writeln('XBox controller simulator test');
  // MUST define DEBUGXBC in "Conditional defines" of project
{$IFNDEF DEBUGXBC}
  Writeln('You MUST define DEBUGXBC in "Conditional defines" to output messages!');
{$ENDIF}
  cThrd := TXControllerSimThread.Create(0);
  while True do Sleep(20);
  cThrd.Free;
end.
