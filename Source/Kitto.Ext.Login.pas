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

unit Kitto.Ext.Login;

{$I Kitto.Defines.inc}

interface

uses
  SysUtils,
  ExtPascal, Ext, ExtForm,
  EF.Tree, EF.ObserverIntf,
  Kitto.Ext.Base, Kitto.Ext.BorderPanel, Kitto.Config;

type
  // Utility class uses in login controllers. A form panel with standard login
  // controls and logic. It can be embedded in a login window, viewport or other
  // container for flexible login page appearance.
  TKExtLoginFormPanel = class(TExtFormFormPanel)
  private
    FUserName: TExtFormTextField;
    FPassword: TExtFormTextField;
    FLanguage: TExtFormComboBox;
    FTokenField: TExtFormTextField;
    FLocalStorageEnabled: TExtFormCheckbox;
    FResetPasswordLink: TExtBoxComponent;
    FRegisterNewUserLink: TExtBoxComponent;
    FPrivacyPolicyLink: TExtBoxComponent;
    FSendQRLink: TExtBoxComponent;
    FLoginButton: TKExtButton;
    FStatusBar: TKExtStatusBar;
    FLocalStorageMode: string;
    FLocalStorageAskUser: Boolean;
    FAfterLogin: TProc;
    FResetPasswordNode: TEFNode;
    FRegisterNewUserNode: TEFNode;
    FPrivacyPolicyNode: TEFNode;
    FLoginTypeNode: TEFNode;
    FSendQRNode: TEFNode;
    function GetEnableButtonJS: string;
    function GetSubmitJS: string;
    function GetLocalStorageSaveJSCode(const AMode: string; const AAskUser: Boolean): string;
    function GetLocalStorageRetrieveJSCode(const AMode: string; const AAutoLogin: Boolean): string;
  protected
    procedure InitDefaults; override;
  public
    property AfterLogin: TProc read FAfterLogin write FAfterLogin;
    procedure Display(const AEditWidth: Integer; const AConfig: TEFNode; var ACurrentHeight: Integer);
  published
    procedure DoLogin;
    procedure DoResetPassword;
    procedure DoRegisterNewUser;
    procedure DoPrivacyPolicy;
    procedure DoSendQR;
  end;

  // A login window, suitable as a stand-alone login interface.
  TKExtLoginWindow = class(TKExtWindowControllerBase)
  strict protected
    procedure DoDisplay; override;
  end;

  // A login panel, suitable for embedding into HTML code.
  // requires the ContainerElementId config property to be set,
  // otherwise it is not displayed.
  TKExtLoginPanel = class(TKExtPanelControllerBase)
  strict protected
    procedure DoDisplay; override;
  end;

implementation

uses
  Math, StrUtils,
  ExtPascalUtils,
  EF.Classes, EF.Localization, EF.Macros,
  Kitto.Types, Kitto.Utils,
  Kitto.Ext.Session, Kitto.Ext.Controller;

{ TKExtLoginWindow }

procedure TKExtLoginWindow.DoDisplay;
const
  STANDARD_HEIGHT = 82;
var
  LBorderPanel: TKExtBorderPanelController;
  LFormPanel: TKExtLoginFormPanel;
  LWidth, LHeight, LLabelWidth, LEditWidth: Integer;
  LFormPanelBodyStyle: string;
  LTitle: TEFNode;

  function GetHorizontalMargin: Integer;
  begin
    if Maximized then
      Result := Session.ViewportWidth div 4
    else
      Result := 20;
  end;

begin
  Draggable := View.GetBoolean('Controller/Movable', False);
  Maximized := Session.IsMobileBrowser;
  Border := not Maximized;
  if Maximized then
    LWidth := Session.ViewportWidth
  else
    LWidth := Max(Config.GetInteger('ExtraWidth'), 236);
  LHeight := Max(Config.GetInteger('ExtraHeight'), 0) + STANDARD_HEIGHT;

  if Maximized then
  begin
    LLabelWidth := Trunc(Session.ViewportWidth * 0.4);
    LEditWidth := Trunc(Session.ViewportWidth * 0.8) - GetHorizontalMargin;
  end
  else
  begin
    LLabelWidth := Max(Config.GetInteger('LabelWidth'), 100);
    LEditWidth := Max(LWidth - LLabelWidth - GetHorizontalMargin * 2, 96);
  end;
  if not Maximized then
    Width := LWidth;

  LTitle := Config.FindNode('Title');
  if Assigned(LTitle) then
    Title := LTitle.AsExpandedString
  else
    Title := Session.Config.AppTitle;
  Closable := False;
  Resizable := False;

  LBorderPanel := TKExtBorderPanelController.CreateAndAddTo(Items);
  LBorderPanel.Config.Assign(Config.FindNode('BorderPanel'));
  //FBorderPanel.Border := False;
  LBorderPanel.Frame := False;
  LBorderPanel.View := View;
  LBorderPanel.Display;

  LFormPanel := TKExtLoginFormPanel.CreateAndAddTo(LBorderPanel.Items);
  LFormPanel.Region := rgCenter;
  LFormPanel.LabelWidth := LLabelWidth;
  LFormPanelBodyStyle := Config.GetString('FormPanel/BodyStyle');
  if LFormPanelBodyStyle <> '' then
    LFormPanel.BodyStyle := LFormPanelBodyStyle;
  LFormPanel.AfterLogin :=
    procedure
    begin
      Close;
      NotifyObservers('LoggedIn');
    end;
  LFormPanel.Display(LEditWidth, Config, LHeight);
  Height := LHeight;
  inherited;
end;

{ TKExtLoginPanel }

procedure TKExtLoginPanel.DoDisplay;
var
  LDummyHeight: Integer;
  LFormPanel: TKExtLoginFormPanel;
  LBorderPanel: TKExtBorderPanelController;
  LFormPanelBodyStyle: string;
  LBorderPanelConfigNode: TEFNode;
begin
  inherited;
  Frame := False;
  Border := False;
  Layout := lyFit;
  Title := Config.GetString('Title');
  Width := Config.GetInteger('Width', 300);
  Height := Config.GetInteger('Height', 160);
  PaddingString := Config.GetString('Padding', '10px');
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
    LFormPanel := TKExtLoginFormPanel.CreateAndAddTo(LBorderPanel.Items);
    LFormPanel.Region := rgCenter;
  end
  else
    LFormPanel := TKExtLoginFormPanel.CreateAndAddTo(Items);

  LFormPanel.LabelWidth := Config.GetInteger('FormPanel/LabelWidth', 150);
  LFormPanelBodyStyle := Config.GetString('FormPanel/BodyStyle');
  if LFormPanelBodyStyle <> '' then
    LFormPanel.BodyStyle := LFormPanelBodyStyle;
  LFormPanel.AfterLogin :=
    procedure
    begin
      Delete;
      NotifyObservers('LoggedIn');
    end;
  LDummyHeight := 0;
  LFormPanel.Display(Config.GetInteger('FormPanel/EditWidth', 150), Config, LDummyHeight);
end;

{ TKExtLoginFormPanel }

function TKExtLoginFormPanel.GetEnableButtonJS: string;
begin
  if (Assigned(FLoginTypeNode)) and (AnsiUpperCase(FLoginTypeNode.AsString) = 'PIN') then
    Result := Format(
      '%s.setDisabled(%s.getValue() == "" || !(%s.getValue().length == 6) );',
      [FLoginButton.JSName, FUserName.JSName, FTokenField.JSName])
  else
    Result := Format(
      '%s.setDisabled(%s.getValue() == "" || %s.getValue() == "");',
      [FLoginButton.JSName, FUserName.JSName, FPassword.JSName]);
end;

function TKExtLoginFormPanel.GetSubmitJS: string;
begin
  if (Assigned(FLoginTypeNode)) and (AnsiUpperCase(FLoginTypeNode.AsString) = 'PIN') then
    Result := Format(
      // For some reason != does not survive rendering.
      'if (e.getKey() == 13 && !(%s.getValue() == "") && !(%s.getValue() == "")) %s.handler.call(%s.scope, %s);',
      [FUserName.JSName, FTokenField.JSName, FLoginButton.JSName, FLoginButton.JSName, FLoginButton.JSName])
  else
    Result := Format(
      // For some reason != does not survive rendering.
      'if (e.getKey() == 13 && !(%s.getValue() == "") && !(%s.getValue() == "")) %s.handler.call(%s.scope, %s);',
      [FUserName.JSName, FPassword.JSName, FLoginButton.JSName, FLoginButton.JSName, FLoginButton.JSName]);
end;

procedure TKExtLoginFormPanel.Display(const AEditWidth: Integer; const AConfig: TEFNode; var ACurrentHeight: Integer);
const
  CONTROL_HEIGHT = 30;
var
  LLocalStorageAskUserDefault: Boolean;
  LLocalStorageAutoLogin: Boolean;
  LLocalStorageOptions: TEFNode;
  LInputStyle, LResetPasswordStyle, LRegisterNewUserStyle, LRegisterNewUserLinkText, LResetPasswordNodeLinkText, LPrivacyPolicyStyle, LPrivacyPolicyNodeLinkText, LSendQRNodeLinkText, LSendQRStyle, LButtonStyle: string;

  function ReplaceMacros(const ACode: string): string;
  begin
    Result := ACode;
    Result := ReplaceStr(Result, '%STATUSBAR%', FStatusBar.JSName);
    Result := ReplaceStr(Result, '%CAPS_ON%', _('Caps On'));
  end;

  function GetCheckCapsLockJS: string;
  begin
    Result := ReplaceMacros(
      'if (event.keyCode !== 13 && event.getModifierState("CapsLock")) ' +
      '{%STATUSBAR%.setText(''%CAPS_ON%''); %STATUSBAR%.setIcon('''');} ' +
      'else {%STATUSBAR%.setText('''');}');
  end;

begin
  FStatusBar := TKExtStatusBar.Create(Self);
  FStatusBar.DefaultText := '';
  FStatusBar.StatusAlign := AConfig.GetString('FormPanel/StatusAlign', 'left');
  FStatusBar.BusyText := _('Logging in...');
  Bbar := FStatusBar;

  FLoginButton := TKExtButton.CreateAndAddTo(FStatusBar.Items);
  FLoginButton.SetIconAndScale('login', 'medium');
  FLoginButton.Text := _('Login');
  LButtonStyle := AConfig.GetString('FormPanel/ButtonStyle');
  if LButtonStyle <> '' then
    FLoginButton.Style := LButtonStyle;

  with TExtBoxComponent.CreateAndAddTo(Items) do
    Height := 10;

  LInputStyle := AConfig.GetString('FormPanel/InputStyle');

  FUserName := TExtFormTextField.CreateAndAddTo(Items);
  FUserName.Name := 'UserName';
  FUserName.Value := Session.Config.Authenticator.AuthData.GetExpandedString('UserName');
  FUserName.FieldLabel := AConfig.GetString('FormPanel/UserName',_('User Name'));
  FUserName.AllowBlank := False;
  FUserName.EnableKeyEvents := True;
  FUserName.SelectOnFocus := True;
  FUserName.Width := AEditWidth;
  if LInputStyle <> '' then
    FUserName.Style := LInputStyle;

  Inc(ACurrentHeight, CONTROL_HEIGHT);

  FLoginTypeNode := Session.Config.Instance.Config.FindNode('Auth/LoginType');
  if (Assigned(FLoginTypeNode)) and (AnsiUpperCase(FLoginTypeNode.AsString) = 'PIN') then
  begin
    FTokenField := TExtFormTextField.CreateAndAddTo(Items);
    FTokenField.Name := 'PIN';
    FTokenField.FieldLabel := _('Google Authenticator PIN');
    FTokenField.AllowBlank := False;
    FTokenField.EnableKeyEvents := True;
    FTokenField.SelectOnFocus := True;
    FTokenField.Width := AEditWidth;
//    FTokenField.On('keyup', JSFunction(GetEnableButtonJS));
    FTokenField.On('keydown', JSFunction(GetCheckCapsLockJS));
    FTokenField.On('specialkey', JSFunction('field, e', GetSubmitJS));
  end
  else
  begin
    FPassword := TExtFormTextField.CreateAndAddTo(Items);
    FPassword.Name := 'Password';
    FPassword.Value := Session.Config.Authenticator.AuthData.GetExpandedString('Password');
    FPassword.FieldLabel := AConfig.GetString('FormPanel/Password',_('Password'));
    FPassword.InputType := itPassword;
    FPassword.AllowBlank := False;
    FPassword.EnableKeyEvents := True;
    FPassword.SelectOnFocus := True;
    FPassword.Width := AEditWidth;
    if LInputStyle <> '' then
      FPassword.Style := LInputStyle;
    Inc(ACurrentHeight, CONTROL_HEIGHT);

    FPassword.On('keydown', JSFunction(GetCheckCapsLockJS));
    FPassword.On('specialkey', JSFunction('field, e', GetSubmitJS));
  end;

  FUserName.On('specialkey', JSFunction('field, e', GetSubmitJS));


  Session.ResponseItems.ExecuteJSCode(Self, Format(
    '%s.enableTask = Ext.TaskMgr.start({ ' + sLineBreak +
    '  run: function() {' + GetEnableButtonJS + '},' + sLineBreak +
    '  interval: 500});', [JSName]));

  if Session.Config.LanguagePerSession then
  begin
    FLanguage := TExtFormComboBox.CreateAndAddTo(Items);
    FLanguage.StoreArray := JSArray('["it", "Italiano"], ["en", "English"]');
    FLanguage.HiddenName := 'Language';
    FLanguage.Value := Session.Config.Authenticator.AuthData.GetExpandedString('Language');
    if FLanguage.Value = '' then
      FLanguage.Value := Session.Config.Config.GetString('LanguageId');
    FLanguage.FieldLabel := _('Language');
    //FLanguage.EnableKeyEvents := True;
    //FLanguage.SelectOnFocus := True;
    FLanguage.ForceSelection := True;
    FLanguage.TriggerAction := 'all'; // Disable filtering list items based on current value.
    FLanguage.Width := AEditWidth;
    if LInputStyle <> '' then
      FLanguage.Style := LInputStyle;

    Inc(ACurrentHeight, CONTROL_HEIGHT);
  end
  else
    FLanguage := nil;

  LLocalStorageOptions := AConfig.FindNode('LocalStorage');
  if Assigned(LLocalStorageOptions) then
  begin
    FLocalStorageMode := LLocalStorageOptions.GetString('Mode');
    FLocalStorageAskUser := LLocalStorageOptions.GetBoolean('AskUser');
    LLocalStorageAskUserDefault := LLocalStorageOptions.GetBoolean('AskUser/Default', True);
    LLocalStorageAutoLogin := LLocalStorageOptions.GetBoolean('AutoLogin', False);
  end
  else
  begin
    FLocalStorageMode := '';
    FLocalStorageAskUser := False;
    LLocalStorageAskUserDefault := False;
    LLocalStorageAutoLogin := False;
  end;

  if (FLocalStorageMode <> '') and FLocalStorageAskUser then
  begin
    FLocalStorageEnabled := TExtFormCheckbox.CreateAndAddTo(Items);
    FLocalStorageEnabled.Name := 'LocalStorageEnabled';
    FLocalStorageEnabled.Checked := LLocalStorageAskUserDefault;
    if SameText(FLocalStorageMode, 'Password') then
      FLocalStorageEnabled.FieldLabel := _('Remember Credentials')
    else
      FLocalStorageEnabled.FieldLabel := _('Remember User Name');
    Inc(ACurrentHeight, CONTROL_HEIGHT);
  end
  else
    FLocalStorageEnabled := nil;
  if (Assigned(FLoginTypeNode)) and (AnsiUpperCase(FLoginTypeNode.AsString) = 'PIN') then
    if Assigned(FLanguage) then
    begin
      if Assigned(FLocalStorageEnabled) then
        FLoginButton.Handler := Ajax(DoLogin, ['Dummy', FStatusBar.ShowBusy,
          'UserName', FUserName.GetValue, 'Password', FTokenField.GetValue, 'Language', FLanguage.GetValue,
          'LocalStorageEnabled', FLocalStorageEnabled.GetValue])
      else
        FLoginButton.Handler := Ajax(DoLogin, ['Dummy', FStatusBar.ShowBusy,
          'UserName', FUserName.GetValue, 'Password', FTokenField.GetValue, 'Language', FLanguage.GetValue]);
    end
    else
    begin
      if Assigned(FLocalStorageEnabled) then
        FLoginButton.Handler := Ajax(DoLogin, ['Dummy', FStatusBar.ShowBusy,
          'UserName', FUserName.GetValue, 'Password', FTokenField.GetValue,
          'LocalStorageEnabled', FLocalStorageEnabled.GetValue])
      else
        FLoginButton.Handler := Ajax(DoLogin, ['Dummy', FStatusBar.ShowBusy,
          'UserName', FUserName.GetValue, 'Password', FTokenField.GetValue]);
    end
  else
    if Assigned(FLanguage) then
    begin
      if Assigned(FLocalStorageEnabled) then
        FLoginButton.Handler := Ajax(DoLogin, ['Dummy', FStatusBar.ShowBusy,
          'UserName', FUserName.GetValue, 'Password', FPassword.GetValue, 'Language', FLanguage.GetValue,
          'LocalStorageEnabled', FLocalStorageEnabled.GetValue])
      else
        FLoginButton.Handler := Ajax(DoLogin, ['Dummy', FStatusBar.ShowBusy,
          'UserName', FUserName.GetValue, 'Password', FPassword.GetValue, 'Language', FLanguage.GetValue]);
    end
    else
    begin
      if Assigned(FLocalStorageEnabled) then
        FLoginButton.Handler := Ajax(DoLogin, ['Dummy', FStatusBar.ShowBusy,
          'UserName', FUserName.GetValue, 'Password', FPassword.GetValue,
          'LocalStorageEnabled', FLocalStorageEnabled.GetValue])
      else
        FLoginButton.Handler := Ajax(DoLogin, ['Dummy', FStatusBar.ShowBusy,
          'UserName', FUserName.GetValue, 'Password', FPassword.GetValue]);
    end;

  if Assigned(FLanguage) then
    FLoginButton.Disabled := (FUserName.Value = '') or (FPassword.Value = '') or (FLanguage.Value = '')
  else
    FLoginButton.Disabled := (FUserName.Value = '') or (FPassword.Value = '');

  if (FUserName.Value <> '') and (FPassword.Value = '') then
    FPassword.Focus(False, 750)
  else
    FUserName.Focus(False, 750);

  On('render', JSFunction(GetLocalStorageRetrieveJSCode(FLocalStorageMode, LLocalStorageAutoLogin)));

  FResetPasswordNode := AConfig.FindNode('ResetPassword');
  if Assigned(FResetPasswordNode) and FResetPasswordNode.AsBoolean then
  begin
    LResetPasswordNodeLinkText := FResetPasswordNode.GetString('LinkText');
    if LResetPasswordNodeLinkText = '' then
      LResetPasswordNodeLinkText := _('Password forgotten?');
    LResetPasswordStyle := FResetPasswordNode.GetString('Style');
    FResetPasswordLink := TExtBoxComponent.CreateAndAddTo(Items);
    FResetPasswordLink.Html := Format(
      '<div style="text-align:right"><a style="%s" href="#" onclick="%s">%s</a></div>',
      [FResetPasswordNode.GetString('HrefStyle'),
       HTMLEncode(JSMethod(Ajax(DoResetPassword))),
       HTMLEncode(LResetPasswordNodeLinkText)]);
    FResetPasswordLink.Width := AEditWidth + LabelWidth;
    if LResetPasswordStyle <> '' then
      FResetPasswordLink.Style := LResetPasswordStyle;

    Inc(ACurrentHeight, CONTROL_HEIGHT);
  end
  else
    FResetPasswordLink := nil;

  FRegisterNewUserNode := AConfig.FindNode('RegisterNewUser');
  if Assigned(FRegisterNewUserNode) and FRegisterNewUserNode.AsBoolean then
  begin
    LRegisterNewUserLinkText := FRegisterNewUserNode.GetString('LinkText');
    if LRegisterNewUserLinkText = '' then
      LRegisterNewUserLinkText := _('New User? Register...');
    LRegisterNewUserStyle := FRegisterNewUserNode.GetString('Style');
    FRegisterNewUserLink := TExtBoxComponent.CreateAndAddTo(Items);
    FRegisterNewUserLink.Html := Format(
      '<div style="text-align:right"><a style="%s" href="#" onclick="%s">%s</a></div>',
      [FRegisterNewUserNode.GetString('HrefStyle'),
       HTMLEncode(JSMethod(Ajax(DoRegisterNewUser))),
       HTMLEncode(LRegisterNewUserLinkText)]);
    FRegisterNewUserLink.Width := AEditWidth + LabelWidth;
    if LRegisterNewUserStyle <> '' then
      FRegisterNewUserLink.Style := LRegisterNewUserStyle;

    Inc(ACurrentHeight, CONTROL_HEIGHT);
  end
  else
    FRegisterNewUserLink := nil;

  FPrivacyPolicyNode := AConfig.FindNode('PrivacyPolicy');
  if Assigned(FPrivacyPolicyNode) and FPrivacyPolicyNode.AsBoolean then
  begin
    LPrivacyPolicyNodeLinkText := FPrivacyPolicyNode.GetString('LinkText');
    if LPrivacyPolicyNodeLinkText = '' then
      LPrivacyPolicyNodeLinkText := _('Privacy policy...');
    LPrivacyPolicyStyle := FPrivacyPolicyNode.GetString('Style');
    FPrivacyPolicyLink := TExtBoxComponent.CreateAndAddTo(Items);
    FPrivacyPolicyLink.Html := Format(
      '<div style="text-align:right"><a style="%s" href="#" onclick="%s">%s</a></div>',
      [FPrivacyPolicyNode.GetString('HrefStyle'),
       HTMLEncode(JSMethod(Ajax(DoPrivacyPolicy))),
       HTMLEncode(LPrivacyPolicyNodeLinkText)]);
    FPrivacyPolicyLink.Width := AEditWidth + LabelWidth;
    if LPrivacyPolicyStyle <> '' then
      FPrivacyPolicyLink.Style := LPrivacyPolicyStyle;

    Inc(ACurrentHeight, CONTROL_HEIGHT);
  end
  else
    FPrivacyPolicyLink := nil;

  FSendQRNode := AConfig.FindNode('SendQR');
  if Assigned(FSendQRNode) and FSendQRNode.AsBoolean then
  begin
    LSendQRNodeLinkText := FSendQRNode.GetString('LinkText');
    if LSendQRNodeLinkText = '' then
      LSendQRNodeLinkText := _('Lost QR code?');
    LSendQRStyle := FSendQRNode.GetString('Style');
    FSendQRLink := TExtBoxComponent.CreateAndAddTo(Items);
    FSendQRLink.Html := Format(
      '<div style="text-align:right"><a style="%s" href="#" onclick="%s">%s</a></div>',
      [FSendQRNode.GetString('HrefStyle'),
       HTMLEncode(JSMethod(Ajax(DoSendQR))),
       HTMLEncode(LSendQRNodeLinkText)]);
    FSendQRLink.Width := AEditWidth + LabelWidth;
    if LSendQRStyle <> '' then
      FSendQRLink.Style := LSendQRStyle;

    Inc(ACurrentHeight, CONTROL_HEIGHT);
  end
  else
    FSendQRLink := nil;
end;

procedure TKExtLoginFormPanel.InitDefaults;
begin
  inherited;
  LabelAlign := laRight;
  Border := False;
  Frame := False;
  AutoScroll := True;
  MonitorValid := True;
end;

procedure TKExtLoginFormPanel.DoLogin;
begin
  if Session.Authenticate then
  begin
    Session.ResponseItems.ExecuteJSCode(Format('Ext.TaskMgr.stop(%s.enableTask);', [JSName]));
    Session.ResponseItems.ExecuteJSCode(GetLocalStorageSaveJSCode(FLocalStorageMode, FLocalStorageAskUser));
    Assert(Assigned(FAfterLogin));
    FAfterLogin();
  end
  else
  begin
    FStatusBar.SetErrorStatus(_('Invalid login.'));
    if Assigned(FLoginTypeNode) and (AnsiUpperCase(FLoginTypeNode.AsString) = 'PIN') then
      FTokenField.Focus(False,750)
    else
      FPassword.Focus(False, 750);
  end;
end;

procedure TKExtLoginFormPanel.DoPrivacyPolicy;
begin
  Assert(Assigned(FPrivacyPolicyNode));

  { TODO : Add a way to open standard/system views without needing to store them in a yaml file.
    Maybe a json definition passed as a string? }
  Session.DisplayView('PrivacyPolicy');
end;

procedure TKExtLoginFormPanel.DoRegisterNewUser;
begin
  Assert(Assigned(FRegisterNewUserLink));

  { TODO : Add a way to open standard/system views without needing to store them in a yaml file.
    Maybe a json definition passed as a string? }
  Session.DisplayView('RegisterNewUser');
end;

procedure TKExtLoginFormPanel.DoResetPassword;
begin
  Assert(Assigned(FResetPasswordNode));

  { TODO : Add a way to open standard/system views without needing to store them in a yaml file.
    Maybe a json definition passed as a string? }
  Session.DisplayView('ResetPassword');
end;

procedure TKExtLoginFormPanel.DoSendQR;
begin
  Assert(Assigned(FSendQRNode));

  { TODO : Add a way to open standard/system views without needing to store them in a yaml file.
    Maybe a json definition passed as a string? }
  Session.DisplayView('SendQR');
end;

function TKExtLoginFormPanel.GetLocalStorageSaveJSCode(const AMode: string; const AAskUser: Boolean): string;

  function IfChecked: string;
  begin
    if Assigned(FLocalStorageEnabled) then
      Result := 'if (' + FLocalStorageEnabled.JSName + '.getValue())'
    else
      Result := 'if (true)';
  end;

  function GetDeleteCode: string;
  begin
    Result := 'delete localStorage.' + Session.Config.AppName + '_UserName;' + sLineBreak;
    Result := Result + 'delete localStorage.' + Session.Config.AppName + '_Password;' + sLineBreak;
    Result := Result + 'delete localStorage.' + Session.Config.AppName + '_LocalStorageEnabled;' + sLineBreak;
  end;

begin
  Result := '';
  if (AMode <> '') then
  begin
    Result := Result + IfChecked + '{';
    if SameText(AMode, 'UserName') or SameText(AMode, 'Password') then
      Result := Result + 'localStorage.' + Session.Config.AppName + '_UserName = "' + Session.Query['UserName'] + '";';
    if SameText(AMode, 'Password') then
      Result := Result + 'localStorage.' + Session.Config.AppName + '_Password = "' + Session.Query['Password'] + '";';
    if AAskUser then
      Result := Result + 'localStorage.' + Session.Config.AppName + '_LocalStorageEnabled = "' + Session.Query['LocalStorageEnabled'] + '";';
    Result := Result + '} else {' + GetDeleteCode + '};';
  end
  else
    Result := GetDeleteCode;
end;

function TKExtLoginFormPanel.GetLocalStorageRetrieveJSCode(const AMode: string; const AAutoLogin: Boolean): string;
begin
  if SameText(AMode, 'UserName') or SameText(AMode, 'Password') then
    Result := Result + 'var u = localStorage.' + Session.Config.AppName + '_UserName; if (u) ' + FUserName.JSName + '.setValue(u);';
  if SameText(AMode, 'Password') then
    Result := Result + 'var p = localStorage.' + Session.Config.AppName + '_Password; if (p) ' + FPassword.JSName + '.setValue(p);';
  if Assigned(FLocalStorageEnabled) then
    Result := Result + 'var l = localStorage.' + Session.Config.AppName + '_LocalStorageEnabled; if (l) ' + FLocalStorageEnabled.JSName + '.setValue(l);';
  if AAutoLogin then
    Result := Result + Format('setTimeout(function(){ %s.getEl().dom.click(); }, 100);', [FLoginButton.JSName]);
end;

initialization
  TKExtControllerRegistry.Instance.RegisterClass('Login', TKExtLoginWindow);
  TKExtControllerRegistry.Instance.RegisterClass('LoginPanel', TKExtLoginPanel);

finalization
  TKExtControllerRegistry.Instance.UnregisterClass('Login');
  TKExtControllerRegistry.Instance.UnregisterClass('LoginPanel');

end.
