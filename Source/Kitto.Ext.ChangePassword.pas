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

unit Kitto.Ext.ChangePassword;

{$I Kitto.Defines.inc}

interface

uses
  Ext, ExtForm,
  Kitto.Ext.Base;

type
  TKExtChangePasswordWindow = class(TKExtWindowControllerBase)
  private
    FShowOldPassword: Boolean;
    FOldPassword: TExtFormTextField;
    FNewPassword: TExtFormTextField;
    FConfirmNewPassword: TExtFormTextField;
    FPasswordRules: TExtFormLabel;
    FConfirmButton: TKExtButton;
    FStatusBar: TKExtStatusBar;
    FFormPanel: TExtFormFormPanel;
    FOldPasswordHash: string;
    function GetPasswordHash(const AClearPassword: string): string;
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
    procedure DoChangePassword;
  end;

implementation

uses
  SysUtils, StrUtils, Math,
  ExtPascalUtils, ExtPascal,
  EF.Classes, EF.Localization, EF.Tree, EF.StrUtils,
  Kitto.Types, Kitto.Config, Kitto.Auth.DB,
  Kitto.Ext.Controller, Kitto.Ext.Session;

{ TKExtChangePasswordWindow }

function TKExtChangePasswordWindow.GetPasswordHash(const AClearPassword: string): string;
begin
  if Session.Config.Authenticator.IsClearPassword then
    Result := AClearPassword
  else
  begin
    Result := GetStringHash(AClearPassword);
    if Session.Config.Authenticator.IsBCrypted then
      Result := AClearPassword;
  end;
end;

procedure TKExtChangePasswordWindow.DoChangePassword;
begin
  if FShowOldPassword and (not Session.Config.Authenticator.IsPasswordMatching(GetPasswordHash(Session.Query['OldPassword']),FOldPasswordHash)) then
  begin
    FStatusBar.SetErrorStatus(_('Old Password is wrong.'));
    FOldPassword.Focus(False, 500);
  end
  else if Session.Config.Authenticator.IsPasswordMatching(GetPasswordHash(Session.Query['NewPassword']),FOldPasswordHash) then
  begin
    FStatusBar.SetErrorStatus(_('New Password must be different than old password.'));
    FNewPassword.Focus(False, 500);
  end
  else if Session.Query['NewPassword'] <> Session.Query['ConfirmNewPassword'] then
  begin
    FStatusBar.SetErrorStatus(_('Confirm New Password is wrong.'));
    FConfirmNewPassword.Focus(False, 500);
  end
  else
  begin
    try
      Session.Config.Authenticator.Password := Session.Query['ConfirmNewPassword'];
      Close;
      Session.Logout;
    except
      on E: ERedirectError do raise; //Reraise ERedirectError
      on E: Exception do
      begin
        FStatusBar.SetErrorStatus(E.Message);
        FNewPassword.Focus(False, 500);
      end;
    end;
  end;
end;

procedure TKExtChangePasswordWindow.DoDisplay;
var
  LEditWidth: Integer;
begin
  Title := Config.GetString('DisplayLabel', GetDefaultDisplayLabel);
  Width := Config.GetInteger('FormPanel/Width', 420);
  Height := Config.GetInteger('FormPanel/Height', 200);
  LEditWidth := Config.GetInteger('FormPanel/EditWidth', 220);
  if Assigned(FOldPassword) then
    FOldPassword.Width := LEditWidth;
  if Assigned(FNewPassword) then
    FNewPassword.Width := LEditWidth;
  if Assigned(FConfirmNewPassword) then
    FConfirmNewPassword.Width := LEditWidth;
  Self.Closable := Config.GetBoolean('AllowClose', True);
  inherited;
end;

class function TKExtChangePasswordWindow.GetDefaultDisplayLabel: string;
begin
  Result := _('Change Password');
end;

class function TKExtChangePasswordWindow.GetDefaultImageName: string;
begin
  Result := 'password';
end;

procedure TKExtChangePasswordWindow.InitDefaults;
var
  LPasswordRules: string;

  function ReplaceMacros(const ACode: string): string;
  begin
    Result := ReplaceStr(ACode, '%BUTTON%', FConfirmButton.JSName);
    if FShowOldPassword then
      Result := ReplaceStr(Result, '%OLDPW%', FOldPassword.JSName);
    Result := ReplaceStr(Result, '%NEWPW%', FNewPassword.JSName);
    Result := ReplaceStr(Result, '%NEWPW2%', FConfirmNewPassword.JSName);
    Result := ReplaceStr(Result, '%STATUSBAR%', FStatusBar.JSName);
    Result := ReplaceStr(Result, '%CAPS_ON%', _('Caps On'));
  end;

  function GetEnableButtonJS: string;
  begin
    if FShowOldPassword then
      Result := ReplaceMacros(
        '%BUTTON%.setDisabled(%OLDPW%.getValue() == "" || %NEWPW%.getValue() == "" ' +
        '|| !(%NEWPW%.getValue() == %NEWPW2%.getValue()));')
    else
      Result := ReplaceMacros(
        '%BUTTON%.setDisabled(%NEWPW%.getValue() == "" ' +
        '|| !(%NEWPW%.getValue() == %NEWPW2%.getValue()));')
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
    if FShowOldPassword then
      Result := ReplaceMacros(
        'if (e.getKey() == 13 && !(%OLDPW%.getValue() == "") && !(%NEWPW%.getValue() == "") ' +
        '&& %NEWPW%.getValue() == %NEWPW2%.getValue()) %BUTTON%.handler.call(%BUTTON%.scope, %BUTTON%);')
    else
      Result := ReplaceMacros(
        'if (e.getKey() == 13 && !(%NEWPW%.getValue() == "") ' +
        '&& %NEWPW%.getValue() == %NEWPW2%.getValue()) %BUTTON%.handler.call(%BUTTON%.scope, %BUTTON%);');
  end;

begin
  inherited;
  FOldPasswordHash := Session.Config.Authenticator.Password;
  //Old password is required only when user request to change-it
  //If the request is made after login with password expires the old password
  //was already requested to the user
  FShowOldPassword := not Session.Config.Authenticator.MustChangePassword;

  Modal := True;
  Maximized := Session.IsMobileBrowser;
  Border := not Maximized;
  Closable := True;
  Resizable := False;

  FStatusBar := TKExtStatusBar.Create(Self);
  FStatusBar.DefaultText := '';
  FStatusBar.BusyText := _('Changing password...');

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
  FConfirmButton.Text := _('Change password');

  if FShowOldPassword then
  begin
    FOldPassword := TExtFormTextField.CreateAndAddTo(FFormPanel.Items);
    FOldPassword.Name := 'OldPassword';
    //FOldPassword.Value := FOldPasswordHash;
    FOldPassword.FieldLabel := _('Old Password');
    FOldPassword.InputType := itPassword;
    FOldPassword.AllowBlank := False;
    FOldPassword.EnableKeyEvents := True;
  end
  else
    FOldPassword := nil;

  FNewPassword := TExtFormTextField.CreateAndAddTo(FFormPanel.Items);
  FNewPassword.Name := 'NewPassword';
  //FNewPassword.Value := ...
  FNewPassword.FieldLabel := _('New Password');
  FNewPassword.InputType := itPassword;
  FNewPassword.AllowBlank := False;
  FNewPassword.EnableKeyEvents := True;

  FConfirmNewPassword := TExtFormTextField.CreateAndAddTo(FFormPanel.Items);
  FConfirmNewPassword.Name := 'ConfirmNewPassword';
  //FConfirmNewPassword.Value := ...
  FConfirmNewPassword.FieldLabel := _('Confirm New Password');
  FConfirmNewPassword.InputType := itPassword;
  FConfirmNewPassword.AllowBlank := False;
  FConfirmNewPassword.EnableKeyEvents := True;

  LPasswordRules := TKConfig.Instance.Config.GetString('Auth/ValidatePassword/Message');
  if LPasswordRules <> '' then
  begin
    FPasswordRules := TExtFormLabel.CreateAndAddTo(FFormPanel.Items);
    FPasswordRules.Text := LPasswordRules;
    FPasswordRules.Width := CharsToPixels(Length(FPasswordRules.Text));
    Height := Height + 30;
  end;

  if FShowOldPassword then
    FOldPassword.On('keyup', JSFunction(GetEnableButtonJS));
  FNewPassword.On('keyup', JSFunction(GetEnableButtonJS));
  FConfirmNewPassword.On('keyup', JSFunction(GetEnableButtonJS));

  if FShowOldPassword then
    FOldPassword.On('keydown', JSFunction(GetCheckCapsLockJS));
  FNewPassword.On('keydown', JSFunction(GetCheckCapsLockJS));
  FConfirmNewPassword.On('keydown', JSFunction(GetCheckCapsLockJS));

  if FShowOldPassword then
    FOldPassword.On('specialkey', JSFunction('field, e', GetSubmitJS));
  FNewPassword.On('specialkey', JSFunction('field, e', GetSubmitJS));
  FConfirmNewPassword.On('specialkey', JSFunction('field, e', GetSubmitJS));

  if FShowOldPassword then
  begin
    FConfirmButton.Handler := Ajax(DoChangePassword, ['Dummy', FStatusBar.ShowBusy,
      'OldPassword', FOldPassword.GetValue, 'NewPassword', FNewPassword.GetValue,
      'ConfirmNewPassword', FConfirmNewPassword.GetValue]);
  end
  else
  begin
    FConfirmButton.Handler := Ajax(DoChangePassword, ['Dummy', FStatusBar.ShowBusy,
      'NewPassword', FNewPassword.GetValue,
      'ConfirmNewPassword', FConfirmNewPassword.GetValue]);
  end;

  FConfirmButton.Disabled := True;

  if FShowOldPassword then
    FOldPassword.Focus(False, 500)
  else
    FNewPassword.Focus(False, 500);
end;

initialization
  TKExtControllerRegistry.Instance.RegisterClass('ChangePassword', TKExtChangePasswordWindow);

finalization
  TKExtControllerRegistry.Instance.UnregisterClass('ChangePassword');

end.

