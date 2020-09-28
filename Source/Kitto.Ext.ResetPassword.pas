{-------------------------------------------------------------------------------
   Copyright 2018 Ethea S.r.l.

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

unit Kitto.Ext.ResetPassword;

{$I Kitto.Defines.inc}

interface

uses
  SysUtils,
  ExtPascal, Ext, ExtForm,
  EF.Tree,
  Kitto.Ext.Base, Kitto.Ext.BorderPanel;

type
  // Utility class uses in the reset password controllers.
  TKExtResetPasswordFormPanel = class(TExtFormFormPanel)
  private
    FUserName: TExtFormTextField;
    FEmailAddress: TExtFormTextField;
    FSendButton: TKExtButton;
    FStatusBar: TKExtStatusBar;
    FAfterSend: TProc;
    function GetEnableButtonJS: string;
    function GetSubmitJS: string;
  protected
    procedure InitDefaults; override;
  public
    property AfterSend: TProc read FAfterSend write FAfterSend;
    procedure Display(const AEditWidth: Integer; const AConfig: TEFNode; var ACurrentHeight: Integer);
  published
    procedure DoSend;
  end;

  // A reset password panel, suitable for embedding into HTML code.
  // requires the ContainerElementId config property to be set,
  // otherwise it is not displayed.
  TKExtResetPasswordPanel = class(TKExtPanelControllerBase)
  strict protected
    procedure DoDisplay; override;
  end;

implementation

uses
  Math,
  ExtPascalUtils,
  EF.Classes, EF.Localization, EF.Macros,
  Kitto.Types,
  Kitto.Ext.Session, Kitto.Ext.Controller;

{ TKExtResetPasswordPanel }

procedure TKExtResetPasswordPanel.DoDisplay;
var
  LDummyHeight: Integer;
  LFormPanel: TKExtResetPasswordFormPanel;
  LFormPanelBodyStyle: string;
  LBorderPanelConfigNode: TEFNode;
  LBorderPanel: TKExtBorderPanelController;
begin
  inherited;
  Frame := False;
  Border := False;
  Layout := lyFit;
  Title := Config.GetString('Title');
  Width := Config.GetInteger('Width', 600);
  Height := Config.GetInteger('Height', 190);
  PaddingString := Config.GetString('Padding', '0px');
  RenderTo := Config.GetString('ContainerElementId');

  //If BorderPanel configuration Node exists, use a BorderPanelController
  LBorderPanelConfigNode := Config.FindNode('BorderPanel');
  if Assigned(LBorderPanelConfigNode) then
  begin
    LBorderPanel := TKExtBorderPanelController.CreateAndAddTo(Items);
    LBorderPanel.Config.Assign(LBorderPanelConfigNode);
    //FBorderPanel.Border := False;
    LBorderPanel.Frame := False;
    LBorderPanel.View := View;
    LBorderPanel.Display;
    LFormPanel := TKExtResetPasswordFormPanel.CreateAndAddTo(LBorderPanel.Items);
    LFormPanel.Region := rgCenter;
  end
  else
    LFormPanel := TKExtResetPasswordFormPanel.CreateAndAddTo(Items);

  LFormPanel.LabelWidth := Config.GetInteger('FormPanel/LabelWidth', 150);
  LFormPanelBodyStyle := Config.GetString('FormPanel/BodyStyle');
  if LFormPanelBodyStyle <> '' then
    LFormPanel.BodyStyle := LFormPanelBodyStyle;
  LFormPanel.AfterSend :=
    procedure
    begin
      Delete;
      NotifyObservers('PasswordResetDone');
      NotifyObservers('Closed');
    end;
  LDummyHeight := 0;
  LFormPanel.Display(Config.GetInteger('FormPanel/EditWidth', 200), Config, LDummyHeight);
end;

{ TKExtResetPasswordFormPanel }

function TKExtResetPasswordFormPanel.GetEnableButtonJS: string;
begin
  Result := Format(
    '%0:s.setDisabled((%1:s.getValue() == "") || !Ext.form.VTypes.email(%1:s.getValue()) || (%2:s.getValue() == "") );',
    [FSendButton.JSName, FEmailAddress.JSName, FUserName.JSName]);
end;

function TKExtResetPasswordFormPanel.GetSubmitJS: string;
begin
  Result := Format(
    // For some reason != does not survive rendering.
    'if (e.getKey() == 13 && !(%s.getValue() == "") && !(%s.getValue() == "")) %s.handler.call(%s.scope, %s);',
    [FUserName.JSName, FEmailAddress.JSName, FSendButton.JSName, FSendButton.JSName, FSendButton.JSName]);
end;

procedure TKExtResetPasswordFormPanel.Display(const AEditWidth: Integer; const AConfig: TEFNode;
  var ACurrentHeight: Integer);
const
  CONTROL_HEIGHT = 30;

  function AddFormTextField(const AName, ALabel: string): TExtFormTextField;
  begin
    Result := TExtFormTextField.CreateAndAddTo(Items);
    Result.Name := AName;
    Result.FieldLabel := AConfig.GetString('FormPanel/'+AName, ALabel);
    Result.AllowBlank := False;
    Result.EnableKeyEvents := True;
    Result.SelectOnFocus := True;
    Result.Width := AEditWidth;
    Inc(ACurrentHeight, CONTROL_HEIGHT);
  end;

begin
  FStatusBar := TKExtStatusBar.Create(Self);
  FStatusBar.DefaultText := '';
  FStatusBar.BusyText := _('Generating new password...');
  Bbar := FStatusBar;

  FSendButton := TKExtButton.CreateAndAddTo(FStatusBar.Items);
  FSendButton.SetIconAndScale('email_go', 'medium');
  FSendButton.Text := _('Send');

  with TExtBoxComponent.CreateAndAddTo(Items) do
    Height := 10;

  FUserName := AddFormTextField('UserName', _('User Name'));
  FEmailAddress := AddFormTextField('EmailAddress', _('Email address'));
  FUserName.On('specialkey', JSFunction('field, e', GetSubmitJS));
  FEmailAddress.On('specialkey', JSFunction('field, e', GetSubmitJS));

  Session.ResponseItems.ExecuteJSCode(Self, Format(
    '%s.enableTask = Ext.TaskMgr.start({ ' + sLineBreak +
    '  run: function() {' + GetEnableButtonJS + '},' + sLineBreak +
    '  interval: 500});', [JSName]));
  On('beforedestroy', JSFunction(Format('Ext.TaskMgr.stop(%s.enableTask);', [JSName])));

  FSendButton.Handler := Ajax(DoSend, ['Dummy', FStatusBar.ShowBusy, 'UserName', FUserName.GetValue, 'EmailAddress', FEmailAddress.GetValue]);
  FSendButton.Disabled := (FEmailAddress.Value = '') or (FUserName.Value = '');
  FUserName.Focus(False, 750);
end;

procedure TKExtResetPasswordFormPanel.InitDefaults;
begin
  inherited;
  LabelAlign := laRight;
  Border := False;
  Frame := False;
  AutoScroll := True;
  MonitorValid := True;
end;

procedure TKExtResetPasswordFormPanel.DoSend;
var
  LParams: TEFNode;
begin
  LParams := TEFNode.Create;
  try
    LParams.SetString('UserName', Session.Query['UserName']);
    LParams.SetString('EmailAddress', Session.Query['EmailAddress']);
    try
      Session.Config.Authenticator.ResetPassword(LParams);
      Session.ShowMessage(emtInfo, _('Reset Password'), _('A new temporary password was generated and sent to the specified e-mail address.'));
      Assert(Assigned(FAfterSend));
      FAfterSend();
    except
      on E: Exception do
      begin
        FStatusBar.SetErrorStatus(E.Message);
        FEmailAddress.Focus(False, 750);
      end;
    end;
  finally
    FreeAndNil(LParams);
  end;
end;

initialization
  TKExtControllerRegistry.Instance.RegisterClass('ResetPassword', TKExtResetPasswordPanel);

finalization
  TKExtControllerRegistry.Instance.UnregisterClass('ResetPassword');

end.
