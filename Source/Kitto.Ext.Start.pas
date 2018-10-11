{-------------------------------------------------------------------------------
   Copyright 2012 Ethea S.r.l.

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
-------------------------------------------------------------------------------}

unit Kitto.Ext.Start;

interface

type
  TKExtStart = class
  private
    class var FIsService: Boolean;
  public
    class procedure Start;

    class property IsService: Boolean read FIsService;
  end;

implementation

uses
  SysUtils, Forms, Classes, SvcMgr, ShlObj, Themes, Styles,
  EF.SysUtils, EF.Logger, EF.Localization, EF.Tree,
  Kitto.Config,
  Kitto.Ext.MainFormUnit, Kitto.Ext.Service;

{ TKExtStart }

class procedure TKExtStart.Start;

  procedure Configure;
  var
    LConfig: TKConfig;
    LLogNode: TEFNode;
  begin
    LConfig := TKConfig.Create;
    try
      LLogNode := LConfig.Config.FindNode('Log');
      TEFLogger.Instance.Configure(LLogNode, LConfig.MacroExpansionEngine);
      TEFLogger.Instance.Log(Format('Using configuration: %s',[LConfig.BaseConfigFileName]));
    finally
      FreeAndNil(LConfig);
    end;
  end;

begin
  FIsService := not FindCmdLineSwitch('a');
  if FIsService then
  begin
    Configure;
    TEFLogger.Instance.Log('Starting as service.');
    if not SvcMgr.Application.DelayInitialize or SvcMgr.Application.Installing then
      SvcMgr.Application.Initialize;
    SvcMgr.Application.CreateForm(TKExtService, KExtService);
    SvcMgr.Application.Run;
  end
  else
  begin
    if FindCmdLineSwitch('c') then
      TKConfig.BaseConfigFileName := ParamStr(3);
    Configure;
    TEFLogger.Instance.Log('Starting as application.');
    Forms.Application.Initialize;
    Forms.Application.CreateForm(TKExtMainForm, KExtMainForm);
    Forms.Application.Run;
  end;
end;

initialization
  {$IFDEF WIN32}
  ReportMemoryLeaksOnShutdown := DebugHook <> 0;
  {$ENDIF}

end.
