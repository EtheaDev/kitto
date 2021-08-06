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

unit Kitto.Ext.InputPIN;

{$I Kitto.Defines.inc}

interface

uses
  Ext, ExtForm,
  Kitto.Ext.Base;

type
  TKExtInputPINWindow = class(TKExtWindowControllerBase)
  private
    FSecretCode: string;
    FTokenField: TExtFormTextField;
    FTokenFieldRules: TExtFormLabel;
    FConfirmButton: TKExtButton;
    FStatusBar: TKExtStatusBar;
    FFormPanel: TExtFormFormPanel;
  strict protected
    procedure DoDisplay; override;
  protected
    procedure InitDefaults; override;
  public
    ///	<summary>Returns the display label to use by default when not specified
    ///	at the view or other level. Called through RTTI.</summary>
    class function GetDefaultDisplayLabel: string;

    ///	<summary>Returns the image name to use by default when not specified at
    ///	the view or other level. Called through RTTI.</summary>
    class function GetDefaultImageName: string;
  published
    procedure DoCheckPIN;
  end;

implementation

uses
  SysUtils, StrUtils, Math,
  ExtPascalUtils, ExtPascal,
  EF.Classes, EF.Localization, EF.Tree, EF.StrUtils,
  Kitto.Types, Kitto.Config,
  Kitto.Ext.Controller, Kitto.Ext.Session;
  //GoogleOTP, Base32U;

{ TKExtInputPINWindow }

procedure TKExtInputPINWindow.DoCheckPIN;
var
  LTokenValue: integer;
begin
  if not TryStrToInt(Session.Query['PIN'],LTokenValue)  then
  begin
    FStatusBar.SetErrorStatus(_('PIN must be a 6-digit number.'));
    FTokenField.Focus(False, 500);
  end
(*
  else if not ValidateTOPT(FSecretCode,LTokenValue) then
  begin
    FStatusBar.SetErrorStatus(_('6-digit token is wrong.'));
    FTokenField.Focus(False, 500);
  end
*)
  else
  begin
    Close;
    Session.Config.Authenticator.MustInputPIN := False;
    Session.UpdateObserver(Self,'LoggedIn');
  end;
end;

procedure TKExtInputPINWindow.DoDisplay;
var
  LEditWidth: Integer;
begin
  Title := Config.GetString('DisplayLabel', GetDefaultDisplayLabel);
  Width := Config.GetInteger('FormPanel/Width', 300);
  Height := Config.GetInteger('FormPanel/Height', 120);
  LEditWidth := Config.GetInteger('FormPanel/EditWidth', 120);
  FTokenField.Width := LEditWidth;
  Self.Closable := Config.GetBoolean('AllowClose', True);
  inherited;
end;

class function TKExtInputPINWindow.GetDefaultDisplayLabel: string;
begin
  Result := _('Input PIN');
end;

class function TKExtInputPINWindow.GetDefaultImageName: string;
begin
  Result := 'password';
end;

procedure TKExtInputPINWindow.InitDefaults;
var
  LTokenRules: string;

  function ReplaceMacros(const ACode: string): string;
  begin
    Result := ReplaceStr(ACode, '%BUTTON%', FConfirmButton.JSName);
    Result := ReplaceStr(Result, '%TOKEN%', FTokenField.JSName);
    Result := ReplaceStr(Result, '%STATUSBAR%', FStatusBar.JSName);
    Result := ReplaceStr(Result, '%CAPS_ON%', _('Caps On'));
  end;

  function GetEnableButtonJS: string;
  begin
    Result := ReplaceMacros(
      '%BUTTON%.setDisabled(%TOKEN%.getValue() == "" ' +
      '|| !(%TOKEN%.getValue().length == 6));')
  end;

  function GetCheckCapsLockJS: string;
  begin
    Result := ReplaceMacros(
      'if (event.keyCode !== 13 && event.getModifierState("CapsLock")) ' +
      '{%STATUSBAR%.setText(''%CAPS_ON%''); %STATUSBAR%.setIcon('''');} ' +
      'else {%STATUSBAR%.setText('''');}');
  end;

  function GetSubmitJS: string;
  begin
    Result := ReplaceMacros(
      'if (e.getKey() == 13 && !(%TOKEN%.getValue() == "") ' +
      '&& %TOKEN%.length == 6) %BUTTON%.handler.call(%BUTTON%.scope, %BUTTON%);');
  end;

begin
  inherited;
  FSecretCode := Session.Config.Authenticator.SecretCode;
  Modal := True;
  Maximized := Session.IsMobileBrowser;
  Border := not Maximized;
  Closable := True;
  Resizable := False;

  FStatusBar := TKExtStatusBar.Create(Self);
  FStatusBar.DefaultText := '';
  FStatusBar.BusyText := _('Processing PIN...');

  FFormPanel := TExtFormFormPanel.CreateAndAddTo(Items);
  FFormPanel.Region := rgCenter;
  FFormPanel.LabelWidth := Config.GetInteger('FormPanel/LabelWidth', 150);
  FFormPanel.LabelAlign := laRight;
  FFormPanel.Border := False;
  FFormPanel.BodyStyle := SetPaddings(5, 5);
  FFormPanel.Frame := False;
  FFormPanel.MonitorValid := True;
  FFormPanel.Bbar := FStatusBar;

  FConfirmButton := TKExtButton.CreateAndAddTo(FStatusBar.Items);
  FConfirmButton.SetIconAndScale('password', 'medium');
  FConfirmButton.Text := _('Check PIN');

  FTokenField := TExtFormTextField.CreateAndAddTo(FFormPanel.Items);
  FTokenField.Name := 'PIN';
  //FTokenField.Value := ...
  FTokenField.FieldLabel := _('PIN');
  //FTokenField.InputType := itPassword;
  FTokenField.AllowBlank := False;
  FTokenField.EnableKeyEvents := True;

  LTokenRules := _('Input Authenticator''s 6-digit PIN');
  if LTokenRules <> '' then
  begin
    FTokenFieldRules := TExtFormLabel.CreateAndAddTo(FFormPanel.Items);
    FTokenFieldRules.Text := LTokenRules;
    FTokenFieldRules.Width := CharsToPixels(Length(FTokenFieldRules.Text));
    Height := Height + 30;
  end;

  FTokenField.On('keyup', JSFunction(GetEnableButtonJS));
  FTokenField.On('keydown', JSFunction(GetCheckCapsLockJS));
  FTokenField.On('specialkey', JSFunction('field, e', GetSubmitJS));

  FConfirmButton.Handler := Ajax(DoCheckPIN, ['Dummy', FStatusBar.ShowBusy,
    'PIN', FTokenField.GetValue]);

  FConfirmButton.Disabled := True;

  FTokenField.Focus(False, 500);
end;

initialization
  TKExtControllerRegistry.Instance.RegisterClass('InputPIN', TKExtInputPINWindow);

finalization
  TKExtControllerRegistry.Instance.UnregisterClass('InputPIN');

end.

