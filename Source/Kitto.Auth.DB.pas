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

/// <summary>
///  Defines the DB authenticator, an authenticator that uses a custom
///  table on the database to store users and passwords.
/// </summary>
unit Kitto.Auth.DB;

{$I Kitto.Defines.inc}

interface

uses
  EF.DB, EF.Tree,
  Kitto.Auth, RegularExpressions, Vcl.Graphics;

const
  DEFAULT_READUSERCOMMANDTEXT =
    'select USER_NAME, PASSWORD_HASH, EMAIL_ADDRESS, MUST_CHANGE_PASSWORD from KITTO_USERS where IS_ACTIVE = 1 and USER_NAME = :USER_NAME';
  DEFAULT_SETPASSWORDCOMMANDTEXT =
    'update KITTO_USERS set PASSWORD_HASH = :PASSWORD_HASH, MUST_CHANGE_PASSWORD = 0 where IS_ACTIVE = 1 and USER_NAME = :USER_NAME';
  DEFAULT_RESETPASSWORDCOMMANDTEXT =
    'update KITTO_USERS set PASSWORD_HASH = :PASSWORD_HASH, MUST_CHANGE_PASSWORD = 1 where IS_ACTIVE = 1 and EMAIL_ADDRESS = :EMAIL_ADDRESS AND USER_NAME = :USER_NAME';
  DEFAULT_REGISTERNEWUSERCOMMANDTEXT =
    'insert into KITTO_USERS (USER_NAME, PASSWORD_HASH, IS_ACTIVE, MUST_CHANGE_PASSWORD, EMAIL_ADDRESS) VALUES (:USER_NAME, :PASSWORD_HASH, 1, 1, :EMAIL_ADDRESS)';
  DEFAULT_BCRYPT_READUSERCOMMANDTEXT =
    'select USER_NAME, PASSWORD_HASH, PASSWORD_B_HASH, EMAIL_ADDRESS, MUST_CHANGE_PASSWORD from KITTO_USERS where IS_ACTIVE = 1 and USER_NAME = :USER_NAME';
  DEFAULT_BCRYPT_SETPASSWORDCOMMANDTEXT =
    'update KITTO_USERS set PASSWORD_B_HASH = :PASSWORD_HASH, PASSWORD_HASH = null, MUST_CHANGE_PASSWORD = 0 where IS_ACTIVE = 1 and USER_NAME = :USER_NAME';
  DEFAULT_BCRYPT_RESETPASSWORDCOMMANDTEXT =
    'update KITTO_USERS set PASSWORD_B_HASH = :PASSWORD_HASH, PASSWORD_HASH = null, MUST_CHANGE_PASSWORD = 1 where IS_ACTIVE = 1 and EMAIL_ADDRESS = :EMAIL_ADDRESS AND USER_NAME = :USER_NAME';

type
  /// <summary>User data read from the database. Used internally as a helper
  /// class.</summary>
  TKAuthUser = class
  private
    FName: string;
    FPasswordHash: string;
  public
    property Name: string read FName write FName;
    property PasswordHash: string read FPasswordHash write FPasswordHash;
  end;

  /// <summary>
  ///   <para>The DB authenticator uses a custom table in the database to
  ///   authenticate users. The table has fixed name and structure. To use a
  ///   different table name or structure, set parameters or create a
  ///   descendant. The authenticator needs the same auth items as its ancestor
  ///   <see cref="TKClassicAuthenticator" />.</para>
  ///   <para>In order for this authenticator to work, it is required that the
  ///   database contains a table called KITTO_USERS with the following
  ///   structure:</para>
  ///   <list type="table">
  ///     <listheader>
  ///       <term>Term</term>
  ///       <description>Description</description>
  ///     </listheader>
  ///     <item>
  ///       <term>USER_NAME</term>
  ///       <description>String uniquely identifying the user.</description>
  ///     </item>
  ///     <item>
  ///       <term>EMAIL_ADDRESS</term>
  ///       <description>Unique e-mail address for the user. This is optional,
  ///       and only used by ResetPassword.</description>
  ///     </item>
  ///     <item>
  ///       <term>PASSWORD_HASH</term>
  ///       <description>String containing the MD5 hash of the user's
  ///       password.</description>
  ///     </item>
  ///     <item>
  ///       <term>IS_ACTIVE</term>
  ///       <description>Set to 0 to disable (ignore) a user. Disabled users
  ///       will not be able to log in.</description>
  ///     </item>
  ///   </list>
  ///   <para>When Authenticate is called, the authenticator fetches the user
  ///   record (if active) and checks the supplied password against the MD5
  ///   hash stored there. You can use clear-text passwords instead of MD5
  ///   hashes if you set the IsClearPassword parameter to True. You can also
  ///   override the SQL select statement used to get the user record through
  ///   the ReadUserCommandText parameter, which allows you to use a different
  ///   structure without the need to define an inherited authenticator.</para>
  ///   <para>Parameters:</para>
  ///   <list type="table">
  ///     <listheader>
  ///       <term>Term</term>
  ///       <description>Description</description>
  ///     </listheader>
  ///     <item>
  ///       <term>IsClearPassword</term>
  ///       <description>Set this item to True to signify that the password is
  ///       stored in clear, and not hashed, in the database. Default
  ///       False.</description>
  ///     </item>
  ///     <item>
  ///       <term>ReadUserCommandText</term>
  ///       <description>A SQL select statement that selects a single user
  ///       record, with the fields USER_NAME and PASSWORD_HASH and a single
  ///       string parameter that will be filled in with the user name.
  ///       Example: select UNAME as USER_NAME, pwd as PASSWORD_HASH from USERS
  ///       where ENABLED = 1 and UNAME = :P1 Any additional fields returned by
  ///       the statement are kept as part of the auth data. Example: select
  ///       USER_NAME, PASSWORD_HASH, SOMEFIELD from USERS where IS_ACTIVE = 1
  ///       and USER_NAME = :P1 The item SOMEFIELD will be available as part of
  ///       the auth data (and as such, through the authentication-related
  ///       macros as well) for as long as the user is logged in. The item will
  ///       be of whatever data type SOMEFIELD is. You can have more than one
  ///       such items. This technique is useful to apply fixed user-dependent
  ///       filters to data sets and data partitioning among users, for
  ///       example.</description>
  ///     </item>
  ///     <item>
  ///       <term>IsPassepartoutEnabled</term>
  ///       <description>Set this item to True to signify that the passepartout
  ///       password is enabled (that means that a user can authenticate wither
  ///       with her own password or the passepartout password). If the
  ///       passepartout password is used to log in, the
  ///       IsPassepartoutAuthentication Boolean item is set to True into
  ///       AuthData.</description>
  ///     </item>
  ///     <item>
  ///       <term>PassepartoutPassword</term>
  ///       <description>A password to be used as a passepartout for every user
  ///       account. Setting this parameter has no effect if
  ///       IsPassepartoutEnabled is not True. The value of this parameter
  ///       represents a cleartext or hashed password depending on the value of
  ///       IsClearPassword.</description>
  ///     </item>
  ///     <item>
  ///       <term>AfterAuthenticateCommandText</term>
  ///       <description>Optional SQL statement that will be executed just
  ///       after authentication. Supports macros, even authentication-related
  ///       ones.</description>
  ///     </item>
  ///     <item>
  ///       <term>SetPasswordCommandText</term>
  ///       <description>A SQL update statement that updates the password field
  ///       of a given user's record. The statement must have two params named
  ///       USER_NAME (that will be filled with the current user's name) and
  ///       PASSWORD_HASH (that will be filled with the new password or
  ///       password hash depending on the state of IsClearPassword). By
  ///       default, the standard KITTO_USERS table is updated. This statement
  ///       is executed when the authenticator's Password property is set in
  ///       code.</description>
  ///     </item>
  ///   </list>
  /// </summary>
  TKDBAuthenticator = class(TKClassicAuthenticator)
  strict protected
    function GetIsClearPassword: Boolean; override;
    procedure SetPassword(const AValue: string); override;

    /// <summary>Generates and returns a random password. Apply application-defined
    /// rules by overriding this method.</summary>
    function GenerateRandomPassword: string; virtual;

    /// <summary>Returns True if the passepartout mechanism is enabled and the
    /// supplied password matches the passpartout password.</summary>
    function InternalAuthenticate(const AAuthData: TEFNode): Boolean; override;

    function GetDatabaseName: string;

    /// <summary>Returns the SQL statement to be used to update the password
    /// (or password hash) in a user's record in the database. Override this
    /// method to change the name or the structure of the predefined table of
    /// users.</summary>
    /// <remarks>The statement should have two params named PASSWORD_HASH and
    /// USER_NAME that will be filled in with the data used to locate the
    /// record and update the password.</remarks>
    function GetSetPasswordCommandText: string;

    /// <summary>Returns the SQL statement to be used to reset the password
    /// (or password hash) in a user's record in the database. Override this
    /// method to change the name or the structure of the predefined table of
    /// users.</summary>
    /// <remarks>The statement should have two params named PASSWORD_HASH and
    /// EMAIL_ADDRESS that will be filled in with the data used to locate the
    /// record and update the password.</remarks>
    function GetResetPasswordCommandText: string;

    /// <summary>Returns the SQL statement to be used to register a new user
    /// (with temporary password hash) in a user's record in the database.
    /// Override this method to change the name or the structure of the predefined
    /// table of users.</summary>
    /// <remarks>The statement should have three params named USER_NAME, PASSWORD_HASH
    /// and EMAIL_ADDRESS that will be filled in with the data used to locate the
    /// record and update the password.</remarks>
    function GetRegisterNewUserCommandText: string;

    /// <summary>Creates and returns an object with the user data read from the
    /// database. It is actually a template method that calls a set of virtual
    /// methods to do its job.</summary>
    function CreateAndReadUser(const AUserName: string; const AAuthData: TEFNode): TKAuthUser;

    /// <summary>Executes the AfterAuthenticateCommandText, if any
    /// provided.</summary>
    procedure InternalAfterAuthenticate(const AAuthData: TEFNode); override;

    /// <summary>Creates and returns an empty instance of TKAuthUser. Override
    /// this method if you need to use a descendant instead.</summary>
    function CreateUser: TKAuthUser; virtual;

    /// <summary>Returns the SQL statement to be executed just after
    /// authentication succeeded.</summary>
    function GetAfterAuthenticateCommandText: string; virtual;

    /// <summary>Returns the SQL statement to be used to read the user data
    /// from the database. Override this method to change the name or the
    /// structure of the predefined table of users.</summary>
    function GetReadUserCommandText(const AUserName: string): string; virtual;

    procedure GetSuppliedAuthData(const AAuthData: TEFNode; const AHashNeeded: Boolean;
      out ASuppliedUserName, ASuppliedPasswordHash: string;
      out AIsPassepartoutAuthentication: Boolean); virtual;

    /// <summary>Extracts from AAuthData the supplied password, in order to use
    /// it in an authentication attempt. If AHashNeeded is True, the password
    /// hash will be returned instead of the clear password.</summary>
    function GetSuppliedPasswordHash(const AAuthData: TEFNode;
      const AHashNeeded: Boolean): string; virtual;

    /// <summary>Extracts from AAuthData the supplied user name, in order to
    /// use it in an authentication attempt.</summary>
    function GetSuppliedUserName(const AAuthData: TEFNode): string; virtual;

    /// <summary>True if passepartout mode is enabled and the supplied password
    /// matches the passepartout password.</summary>
    function IsPassepartoutAuthentication(
      const ASuppliedPassword: string): Boolean; virtual;

    /// <summary>Returns True if AUserName is a valid user name. It is
    /// implemented using GetReadUserSQL to perform a query against the
    /// database to see if authentication data is available for this
    /// user.</summary>
    function IsValidUserName(const AUserName: string): Boolean; virtual;

    /// <summary>
    ///   <para>Reads data from the current record of the specified DB query
    ///   and stores it into AUser.</para>
    ///   <para>Override this method if your table of users has a non-default
    ///   structure or if you want to customize secret code generation
    ///   (for PIN-OTP authentication).</para>
    ///   <para>This method is usually overridden together with GetReadUserSQL,
    ///   and possibly also CreateUser.</para>
    /// </summary>
    procedure ReadUserFromRecord(const AUser: TKAuthUser;
      const ADBQuery: TEFDBQuery; const AAuthData: TEFNode); virtual;

    /// <summary>
    ///  Called by ResetPassword after generating the new random password
    ///  but before writing it to the database. Override this method to send
    ///  the generated password to the user so he can log in and change it.
    ///  The default implementation does nothing.
    /// </summary>
    /// <param name="AParams">
    ///  Contains all the params passed to ResetPassword plus the generated
    ///  password (in the "Password" node). This method is not supposed to
    ///  modify the params but can add custom ones if needed. They will be passed
    ///  back to the initiator of the password reset flow.
    /// </param>
    procedure BeforeResetPassword(const AParams: TEFNode); virtual;

    /// <summary>
    ///  Called by ResetPassword after writing the new random password
    ///  to the database but before committing the transaction. Override this method
    ///  if you need to perform additional database-related operations at this point
    ///  in time.
    ///  The default implementation does nothing.
    /// </summary>
    /// <param name="AParams">
    ///  Contains all the params passed to ResetPassword plus the generated
    ///  password (in the "Password" node). This method is not supposed to
    ///  modify the params but can add custom ones if needed. They will be passed
    ///  back to the initiator of the password reset flow.
    /// </param>
    procedure AfterResetPassword(const ADBConnection: TEFDBConnection; const AParams: TEFNode); virtual;

    /// <summary>
    ///  Called by QRGenerate after generating QR code for OTP authentication.
    ///  Override this method if you need to use this QR for any purpose, such
    ///  as sending it via email to a user. The default implementation does nothing.
    /// </summary>
    /// <param name="AParams">
    ///  Contains all the params passed to QRGenerate. This method is not supposed
    ///  to modify the params but can add custom ones if needed. They will be passed
    ///  back to the initiator of the QR generation flow.
    /// </param>
    procedure AfterQRGeneration(const AQRCode: TBitmap; const AParams: TEFNode); virtual;

  public
    /// <summary>Returns True if ASuppliedPasswordHash matches
    /// AStoredPasswordHash. By default this means that they are the same
    /// value. A descendant might use different matching rules or disable
    /// matching altogether by overriding this method.</summary>
    function IsPasswordMatching(const ASuppliedPasswordHash: string;
      const AStoredPasswordHash: string): Boolean; override;

    procedure ResetPassword(const AParams: TEFNode); override;
    procedure QRGenerate(const AParams: TEFNode); override;
  end;

  /// <summary>Same Authenticator as TKDBAuthenticator, it only manages hashed passwords
  ///  using BCrypt algorithm (in BCrypt unit).
  ///  It requires a field on the custom user table
  ///  named PASSWORD_HASH at least 60-CHARACTER LONG.
  ///  It shifts automatically from TKDBAuthenticator's hash method
  ///  to BCrypt (after the first successful login), without the need to do
  ///  a password reset.</summary>
  TKDBCryptAuthenticator = class(TKDBAuthenticator)

  strict private
    FBCryptCost: integer;
    function GetRandomSpecialChar: char;
    function GetBCryptedString(const AValue: string): string;
  protected
    /// <summary>Generates and returns a random password compatible with special rules defined in SetPassword.</summary>
    function GenerateRandomPassword: string; override;

    /// <summary>
    ///   <para>Reads data from the current record of the specified DB query
    ///   and stores it into AUser.</para>
    ///   <para>This method is usually overridden together with GetReadUserSQL,
    ///   and possibly also CreateUser.</para>
    /// </summary>
    procedure ReadUserFromRecord(const AUser: TKAuthUser;
      const ADBQuery: TEFDBQuery; const AAuthData: TEFNode); override;

    /// <summary>Extracts from AAuthData the supplied password, in order to use
    /// it in an authentication attempt.</summary>
    function GetSuppliedPasswordHash(const AAuthData: TEFNode; const AHashNeeded: Boolean): string; override;

    procedure SetPassword(const AValue: string); override;
    /// <summary>Raise an exception in auto-login fails.</summary>
    function InternalAuthenticate(const AAuthData: TEFNode): Boolean; override;

    /// <summary>Returns the SQL statement to be used to read the user data
    /// from the database. Override this method to change the name or the
    /// structure of the predefined table of users.</summary>
    function GetReadUserCommandText(const AUserName: string): string; override;

    /// <summary>Returns the SQL statement to be used to update the password
    /// (or password hash) in a user's record in the database. Override this
    /// method to change the name or the structure of the predefined table of
    /// users.</summary>
    /// <remarks>The statement should have two params named PASSWORD_HASH and
    /// USER_NAME that will be filled in with the data used to locate the
    /// record and update the password.</remarks>
    function GetSetPasswordCommandText: string;

    /// <summary>Returns the SQL statement to be used to reset the password
    /// (or password hash) in a user's record in the database. Override this
    /// method to change the name or the structure of the predefined table of
    /// users.</summary>
    /// <remarks>The statement should have two params named PASSWORD_HASH and
    /// EMAIL_ADDRESS that will be filled in with the data used to locate the
    /// record and update the password.</remarks>
    function GetResetPasswordCommandText: string;

    property BCryptCost: integer read FBCryptCost;

  public
    procedure AfterConstruction; override;
    function IsPasswordMatching(const ASuppliedPasswordHash: string;
      const AStoredPasswordHash: string): Boolean; override;
    procedure ResetPassword(const AParams: TEFNode); override;
  end;

implementation

uses
  SysUtils, Classes, Variants, DB,
  EF.Localization,  EF.Types, EF.StrUtils,
  Kitto.Types, Kitto.Config, Kitto.DatabaseRouter,
  BCrypt, Base32U, GoogleOTP, DelphiZXingQRCode;

{ TKDBAuthenticator }

procedure TKDBAuthenticator.AfterQRGeneration(const AQRCode: TBitmap;
  const AParams: TEFNode);
begin
end;

procedure TKDBAuthenticator.AfterResetPassword(const ADBConnection: TEFDBConnection; const AParams: TEFNode);
begin
end;

procedure TKDBAuthenticator.BeforeResetPassword(const AParams: TEFNode);
begin
end;

function TKDBAuthenticator.CreateAndReadUser(
  const AUserName: string; const AAuthData: TEFNode): TKAuthUser;
var
  LQuery: TEFDBQuery;
begin
  Result := nil;
  LQuery := TKConfig.Instance.DBConnections[GetDatabaseName].CreateDBQuery;
  try
    LQuery.CommandText := GetReadUserCommandText(AUserName);
    if LQuery.Params.Count <> 1 then
      raise EKError.CreateFmt(_('Wrong authentication query text: %s'), [LQuery.CommandText]);
    LQuery.Params[0].AsString := AUserName;
    LQuery.Open;
    try
      if not LQuery.DataSet.IsEmpty then
      begin
        Result := TKAuthUser.Create;
        try
          ReadUserFromRecord(Result, LQuery, AAuthData);
        except
          Result.Free;
          raise;
        end;
      end;
    finally
      LQuery.Close;
    end;
  finally
    FreeAndNil(LQuery);
  end;
end;

function TKDBAuthenticator.CreateUser: TKAuthUser;
begin
  Result := TKAuthUser.Create;
end;

function TKDBAuthenticator.IsPasswordMatching(const ASuppliedPasswordHash,
  AStoredPasswordHash: string): Boolean;
begin
  Result := ASuppliedPasswordHash = AStoredPasswordHash;
end;

function TKDBAuthenticator.GenerateRandomPassword: string;
begin
  Result := GetRandomString(8, '01');
end;

function TKDBAuthenticator.GetAfterAuthenticateCommandText: string;
begin
  Result := Config.GetExpandedString('AfterAuthenticateCommandText');
end;

function TKDBAuthenticator.GetDatabaseName: string;
var
  LDatabaseRouterNode: TEFNode;
begin
  LDatabaseRouterNode := Config.FindNode('DatabaseRouter');
  if Assigned(LDatabaseRouterNode) then
    Result := TKDatabaseRouterFactory.Instance.GetDatabaseName(
      LDatabaseRouterNode.AsString, Self, LDatabaseRouterNode)
  else
    Result := TKConfig.Instance.DatabaseName;
end;

function TKDBAuthenticator.GetIsClearPassword: Boolean;
begin
  Result := Config.GetBoolean('IsClearPassword');
end;

function TKDBAuthenticator.GetReadUserCommandText(const AUserName: string): string;
begin
  Result := Config.GetString('ReadUserCommandText',
    DEFAULT_READUSERCOMMANDTEXT);
end;

function TKDBAuthenticator.GetRegisterNewUserCommandText: string;
begin
  Result := Config.GetString('RegisterNewUserCommandText', DEFAULT_REGISTERNEWUSERCOMMANDTEXT);
end;

function TKDBAuthenticator.GetResetPasswordCommandText: string;
begin
  Result := Config.GetString('ResetPasswordCommandText', DEFAULT_RESETPASSWORDCOMMANDTEXT);
end;

function TKDBAuthenticator.GetSuppliedPasswordHash(
  const AAuthData: TEFNode; const AHashNeeded: Boolean): string;
begin
  Result := AAuthData.GetString('Password');
  TKConfig.Instance.MacroExpansionEngine.Expand(Result);
  if AHashNeeded then
    Result := GetStringHash(Result);
end;

function TKDBAuthenticator.GetSuppliedUserName(const AAuthData: TEFNode): string;
begin
  Result := AAuthData.GetString('UserName');
  TKConfig.Instance.MacroExpansionEngine.Expand(Result);
end;

procedure TKDBAuthenticator.InternalAfterAuthenticate(const AAuthData: TEFNode);

  function GetLocalDatabaseName: string;
  var
    LDatabaseRouterNode: TEFNode;
  begin
    LDatabaseRouterNode := Config.FindNode('AfterAuthenticateDatabaseRouter');
    if Assigned(LDatabaseRouterNode) then
      Result := TKDatabaseRouterFactory.Instance.GetDatabaseName(
        LDatabaseRouterNode.AsString, Self, LDatabaseRouterNode)
    else
      Result := TKConfig.Instance.DatabaseName;
  end;

var
  LCommand: TEFDBCommand;
  LAfterAuthenticateCommandText: string;
begin
  inherited;
  LAfterAuthenticateCommandText := GetAfterAuthenticateCommandText;

  if LAfterAuthenticateCommandText <> '' then
  begin
    LCommand := TKConfig.Instance.DBConnections[GetLocalDatabaseName].CreateDBCommand;
    try
      LCommand.CommandText := LAfterAuthenticateCommandText;
      LCommand.Execute;
    finally
      FreeAndNil(LCommand);
    end;
  end;
end;

procedure TKDBAuthenticator.GetSuppliedAuthData(
  const AAuthData: TEFNode; const AHashNeeded: Boolean;
  out ASuppliedUserName, ASuppliedPasswordHash: string;
  out AIsPassepartoutAuthentication: Boolean);
var
  LSuppliedPassword: string;
  LLoginTypeNode: TEFNode;
begin
  LLoginTypeNode := Config.FindNode('LoginType');
  ASuppliedUserName := GetSuppliedUserName(AAuthData);
  if (Assigned(LLoginTypeNode)) and (AnsiUpperCase(LLoginTypeNode.AsString) = 'PIN') then
    ASuppliedPasswordHash := GetSuppliedPasswordHash(AAuthData, False)
  else
    ASuppliedPasswordHash := GetSuppliedPasswordHash(AAuthData, AHashNeeded);
  LSuppliedPassword := GetSuppliedPasswordHash(AAuthData, False);
  AIsPassepartoutAuthentication := IsPassepartoutAuthentication(LSuppliedPassword);
end;

function TKDBAuthenticator.InternalAuthenticate(const AAuthData: TEFNode): Boolean;
var
  LSuppliedUserName: string;
  LSuppliedPasswordHash: string;
  LIsPassepartoutAuthentication: Boolean;
  LUser: TKAuthUser;
  LLoginTypeNode: TEFNode;
  LTokenValue: integer;
begin
  GetSuppliedAuthData(AAuthData, not IsClearPassword,
    LSuppliedUserName, LSuppliedPasswordHash, LIsPassepartoutAuthentication);

  if LSuppliedUserName <> '' then
  begin
    LUser := CreateAndReadUser(LSuppliedUserName, AAuthData);
    try
      if Assigned(LUser) then
      begin
        LLoginTypeNode := Config.FindNode('LoginType');
        if LIsPassepartoutAuthentication then
        begin
          AAuthData.SetBoolean('IsPassepartoutAuthentication', True);
          Result := True;
        end
        else if (Assigned(LLoginTypeNode)) and (AnsiUpperCase(LLoginTypeNode.AsString) = 'PIN') then
        begin
          if not TryStrToInt(LSuppliedPasswordHash,LTokenValue) then
            Result := False
          else
            Result := ValidateTOPT(AAuthData.GetString('SecretCode'),LTokenValue);
        end
        else
          Result := IsPasswordMatching(LSuppliedPasswordHash, LUser.PasswordHash);
      end
      else
        Result := False;
    finally
      FreeAndNil(LUser);
    end;
  end
  else
    Result := False;
end;

function TKDBAuthenticator.IsPassepartoutAuthentication(const ASuppliedPassword: string): Boolean;
var
  LIsPassepartoutEnabled: Boolean;
  LPassepartoutPassword: string;
begin
  LIsPassepartoutEnabled := Config.GetBoolean('IsPassepartoutEnabled', False);
  if LIsPassepartoutEnabled then
    LPassepartoutPassword := Config.GetString('PassepartoutPassword', '');
  Result := LIsPassepartoutEnabled and (ASuppliedPassword = LPassepartoutPassword);
end;

function TKDBAuthenticator.IsValidUserName(const AUserName: string): Boolean;
var
  LQuery: TEFDBQuery;
begin
  LQuery := TKConfig.Instance.DBConnections[GetDatabaseName].CreateDBQuery;
  try
    {$if compilerversion < 32}Result := False;{$ifend}
    LQuery.CommandText := GetReadUserCommandText(AUserName);
    if LQuery.Params.Count <> 1 then
      raise EKError.CreateFmt(_('Wrong authentication query text: %s'), [LQuery.CommandText]);
    LQuery.Params[0].AsString := AUserName;
    LQuery.Open;
    try
      if LQuery.DataSet.IsEmpty then
        Result := False
      else
        Result := True;
    finally
      LQuery.Close;
    end;
  finally
    FreeAndNil(LQuery);
  end;
end;

procedure TKDBAuthenticator.ReadUserFromRecord(const AUser: TKAuthUser;
  const ADBQuery: TEFDBQuery; const AAuthData: TEFNode);
begin
  Assert(Assigned(AUser));
  Assert(Assigned(ADBQuery));

  AUser.Name := ADBQuery.DataSet.FieldByName('USER_NAME').AsString;
  AUser.PasswordHash := ADBQuery.DataSet.FieldByName('PASSWORD_HASH').AsString;

  // All fields go to auth data under their names.
  AAuthData.AddFieldsAsChildren(ADBQuery.DataSet.Fields);
  // Plus, known fields go under known names (see InternalDefineAuthData).
  AAuthData.SetString('UserName', AUser.Name);
  AAuthData.SetString('Password', AUser.PasswordHash);

  // SecretCode (for PIN authentications) is filled with base32 encoded UserName.
  AAuthData.SetString('SecretCode',Base32.EncodeWithoutPadding(AnsiUpperCase(AUser.Name)));
end;

procedure TKDBAuthenticator.ResetPassword(const AParams: TEFNode);
var
  LUserName: string;
  LEmailAddress: string;
  LPassword: string;
  LPasswordHash: string;
  LCommandText: string;
  LCommand: TEFDBCommand;
begin
  Assert(Assigned(AParams));

  LUserName := AParams.GetString('UserName');
  if LUserName = '' then
    raise Exception.Create(_('UserName not specified.'));

  LEmailAddress := AParams.GetString('EmailAddress');
  if LEmailAddress = '' then
    raise Exception.Create(_('E-mail address not specified.'));

  LPassword := GenerateRandomPassword;
  AParams.SetString('Password', LPassword);

  BeforeResetPassword(AParams);
  if IsClearPassword then
    LPasswordHash := LPassword
  else
    LPasswordHash := GetStringHash(LPassword);

  LCommandText := GetResetPasswordCommandText;
  LCommand := TKConfig.Instance.DBConnections[GetDatabaseName].CreateDBCommand;
  try
    LCommand.Connection.StartTransaction;
    try
      LCommand.CommandText := LCommandText;
      LCommand.Params.ParamByName('USER_NAME').AsString := LUserName;
      LCommand.Params.ParamByName('EMAIL_ADDRESS').AsString := LEmailAddress;
      LCommand.Params.ParamByName('PASSWORD_HASH').AsString := LPasswordHash;
      if LCommand.Execute <> 1 then
        raise EKError.Create(_('Error: user name and email address not found.'));
      AfterResetPassword(LCommand.Connection, AParams);
      LCommand.Connection.CommitTransaction;
    except
      LCommand.Connection.RollbackTransaction;
      raise;
    end;
  finally
    FreeAndNil(LCommand);
  end;
end;

procedure TKDBAuthenticator.QRGenerate(const AParams: TEFNode);
var
  LUserName: string;
  LEmailAddress: string;
  LQuery: TEFDBQuery;
  LSecretCode, LQRString: string;
  LQRCode: TDelphiZXingQRCode;
  LQRCodeBitmap: TBitmap;
  LRow, LColumn: Integer;
  LSCaleFactor, LRowScale, LColumnScale: Integer;
begin
  Assert(Assigned(AParams));

  LUserName := AParams.GetString('UserName');
  if LUserName = '' then
    raise Exception.Create(_('UserName not specified.'));

  LEmailAddress := AParams.GetString('EmailAddress');
  if LEmailAddress = '' then
    raise Exception.Create(_('E-mail address not specified.'));

  LQuery := TKConfig.Instance.DBConnections[GetDatabaseName].CreateDBQuery;
  try
    LQuery.CommandText := GetReadUserCommandText(LUserName);
    if LQuery.Params.Count <> 1 then
      raise EKError.CreateFmt(_('Wrong authentication query text: %s'), [LQuery.CommandText]);
    LQuery.Params[0].AsString := LUserName;
    LQuery.Open;
    try
      if LQuery.DataSet.IsEmpty then
        raise EKError.Create(_('Error: user name and email address not found.'));
    finally
      LQuery.Close;
    end;
  finally
    FreeAndNil(LQuery);
  end;
  // Using Base32 encoded username as shared secret
  LSecretCode := Base32.EncodeWithoutPadding(AnsiUpperCase(LUserName));
  LQRString := 'otpauth://totp/'+TKConfig.Instance.Config.GetString('AppTitle')+'?secret='+LSecretCode;
  LQRCode := TDelphiZXingQRCode.Create;
  LQRCodeBitmap := TBitmap.Create;
  try
    LQRCode.Data := LQRString;
    LQRCode.Encoding := TQRCodeEncoding(3);
    LQRCode.QuietZone := StrToIntDef('4', 4);
    LScaleFactor := 10;
    LQRCodeBitmap.SetSize(LQRCode.Rows*LScaleFactor, LQRCode.Columns*LScaleFactor);
    for LRow := 0 to LQRCode.Rows - 1 do
    begin
      for LColumn := 0 to LQRCode.Columns - 1 do
      begin
        if (LQRCode.IsBlack[LRow, LColumn]) then
        begin
          for LColumnScale := 0 to LScaleFactor do
            for LRowScale := 0 to LScaleFactor do
              LQRCodeBitmap.Canvas.Pixels[LColumn*LScaleFactor-LColumnScale, LRow*LScaleFactor-LRowScale] := clBlack;
        end
        else
        begin
          for LColumnScale := 0 to LScaleFactor do
            for LRowScale := 0 to LScaleFactor do
              LQRCodeBitmap.Canvas.Pixels[LColumn*LScaleFactor-LColumnScale, LRow*LScaleFactor-LRowScale] := clWhite;
        end;
      end;
    end;
    AfterQRGeneration(LQRCodeBitmap,AParams);
  finally
    LQRCode.Free;
    LQRCodeBitmap.FreeImage;
  end;
end;

procedure TKDBAuthenticator.SetPassword(const AValue: string);
var
  LPasswordHash: string;
  LCommand: TEFDBCommand;
  LCommandText: string;
begin
  inherited;
  if IsClearPassword then
    LPasswordHash := AValue
  else
    LPasswordHash := GetStringHash(AValue);

  LCommandText := GetSetPasswordCommandText;
  LCommand := TKConfig.Instance.DBConnections[GetDatabaseName].CreateDBCommand;
  try
    LCommand.CommandText := LCommandText;
    LCommand.Params.ParamByName('USER_NAME').AsString := UserName;
    LCommand.Params.ParamByName('PASSWORD_HASH').AsString := LPasswordHash;
    LCommand.Connection.StartTransaction;
    try
      if LCommand.Execute <> 1 then
        raise EKError.Create(_('Error changing password.'));
      LCommand.Connection.CommitTransaction;
      AuthData.SetString('Password', LPasswordHash);
    except
      LCommand.Connection.RollbackTransaction;
      raise;
    end;
  finally
    FreeAndNil(LCommand);
  end;
end;

function TKDBAuthenticator.GetSetPasswordCommandText: string;
begin
  Result := Config.GetString('SetPasswordCommandText', DEFAULT_SETPASSWORDCOMMANDTEXT);
end;

{ TKDBCryptAuthenticator }

function TKDBCryptAuthenticator.GetRandomSpecialChar: char;
var
  LSpecialChars: string;
begin
  LSpecialChars := '\<>!£$%&/()=?^*°[]{}-+@#€';
  Result := LSpecialChars[Random(LSpecialChars.Length)+1];
end;

function TKDBCryptAuthenticator.GetBCryptedString(const AValue: string): string;
var
  LBCryptCostValue: integer;
begin
  // if BCryptCost is defined and <> 0 it means it has been invoked a password rehash: use BCryptCost value
  if ((BCryptCost <> 0)) then
    LBCryptCostValue := BCryptCost
  // if BCryptCost isn't defined (or = 0), it searches on the Config.yaml for a valid value
  else if Assigned(Config.FindNode('BCryptCostValue')) then
    LBCryptCostValue := StrToInt(Config.GetString('BCryptCostValue'))
  // if none of the above, it selects the default value 13
  else
    LBCryptCostValue := 13;

  // BCrypt works with values in range 4..31, if LBCryptCostValue is not in that range it's replaced by the default value 13
  if ((LBCryptCostValue <= 4) or (LBCryptCostValue >= 31)) then
    LBCryptCostValue := 13;
  // Stores actual BCryptCost and hashed password
  FBCryptCost := LBCryptCostValue;
  Result := TBCrypt.HashPassword(AValue,LBCryptCostValue);
end;

procedure TKDBCryptAuthenticator.AfterConstruction;
begin
  inherited;
  IsBCrypted := True;
end;

function TKDBCryptAuthenticator.GenerateRandomPassword: string;
var
  LValidatePasswordNode: TEFNode;
  LRegEx: string;
  LRegularExpression : TRegEx;
  LMatch: TMatch;
begin
  LValidatePasswordNode := Config.FindNode('ValidatePassword');
  LRegEx := LValidatePasswordNode.GetExpandedString('RegEx','^[ -~]{8,63}$');
  LRegularExpression.Create(LRegEx);
  Result := GetRandomStringEx(8)+GetRandomSpecialChar;
  LMatch := LRegularExpression.Match(Result);
  while (not LMatch.Success) do
  begin
    Result := GetRandomStringEx(8)+GetRandomSpecialChar;
    LMatch := LRegularExpression.Match(Result);
  end;
end;

function TKDBCryptAuthenticator.GetSuppliedPasswordHash(const AAuthData: TEFNode; const AHashNeeded: Boolean): string;
begin
  Result := AAuthData.GetString('Password');
  TKConfig.Instance.MacroExpansionEngine.Expand(Result);
  // No need to check AHashNeeded because hashing is done in IsPasswordMatching
end;

procedure TKDBCryptAuthenticator.SetPassword(const AValue: string);
var
  LValidatePasswordNode: TEFNode;
  LRegEx: string;
  LErrorMsg: string;
  LRegularExpression : TRegEx;
  LMatch: TMatch;
  LPasswordHash: string;
  LCommand: TEFDBCommand;
  LCommandText: string;
begin
  // Example of enforcement of password strength rules.
  LValidatePasswordNode := Config.FindNode('ValidatePassword');
  Assert(Assigned(LValidatePasswordNode));
  LErrorMsg := LValidatePasswordNode.GetExpandedString('Message','Minimun 8 characters');
  LRegEx := LValidatePasswordNode.GetExpandedString('RegEx','^[ -~]{8,63}$');
  LRegularExpression.Create(LRegEx);
  LMatch := LRegularExpression.Match(AValue);
  if not LMatch.Success then
    raise Exception.Create(LErrorMsg);

  if IsClearPassword then
    LPasswordHash := AValue
  else
    LPasswordHash := GetBCryptedString(AValue);

  LCommandText := GetSetPasswordCommandText;
  LCommand := TKConfig.Instance.DBConnections[GetDatabaseName].CreateDBCommand;
  try
    LCommand.CommandText := LCommandText;
    LCommand.Params.ParamByName('USER_NAME').AsString := UserName;
    LCommand.Params.ParamByName('PASSWORD_HASH').AsString := LPasswordHash;
    LCommand.Connection.StartTransaction;
    try
      if LCommand.Execute <> 1 then
        raise EKError.Create(_('Error changing password.'));
      LCommand.Connection.CommitTransaction;
      AuthData.SetString('Password', LPasswordHash);
    except
      LCommand.Connection.RollbackTransaction;
      raise;
    end;
  finally
    FreeAndNil(LCommand);
  end;
end;

function TKDBCryptAuthenticator.InternalAuthenticate(
  const AAuthData: TEFNode): Boolean;
var
  LSuppliedUserName: string;
  LSuppliedPasswordHash: string;
  LIsPassepartoutAuthentication: Boolean;
  LUser: TKAuthUser;
  LLoginTypeNode: TEFNode;
  LTokenValue: Integer;
begin
  GetSuppliedAuthData(AAuthData, not IsClearPassword,
    LSuppliedUserName, LSuppliedPasswordHash, LIsPassepartoutAuthentication);

  if LSuppliedUserName <> '' then
  begin
    LUser := CreateAndReadUser(LSuppliedUserName, AAuthData);
    try
      if Assigned(LUser) then
      begin
        LLoginTypeNode := Config.FindNode('LoginType');
        if LIsPassepartoutAuthentication then // this clause goes first not to trigger "Invalid base-64 hash string" BCrypt error
        begin
          AAuthData.SetBoolean('IsPassepartoutAuthentication', True);
          Result := True;
        end
        else if (Assigned(LLoginTypeNode)) and (AnsiUpperCase(LLoginTypeNode.AsString) = 'PIN') then
        begin
          if not TryStrToInt(LSuppliedPasswordHash,LTokenValue) then
            Result := False
          else
            Result := ValidateTOPT(AAuthData.GetString('SecretCode'),LTokenValue);
        end
        else if (AAuthData.GetString('Password') <> '') then
          Result := IsPasswordMatching(LSuppliedPasswordHash, AAuthData.GetString('Password'))
        else if IsClearPassword then
        begin
          if (inherited IsPasswordMatching(LSuppliedPasswordHash, LUser.PasswordHash)) then
          begin
            SetPassword(LSuppliedPasswordHash);
            Result := True;
          end
          else
            Result := False;
        end
        else
        begin
          if (inherited IsPasswordMatching(GetStringHash(LSuppliedPasswordHash), LUser.PasswordHash)) then
          begin
            SetPassword(LSuppliedPasswordHash);
            Result := True;
          end
          else
            Result := False;
        end;


      end
      else
        Result := False;
    finally
      FreeAndNil(LUser);
    end;
  end
  else
    Result := False;
end;

function TKDBCryptAuthenticator.IsPasswordMatching(const ASuppliedPasswordHash,
  AStoredPasswordHash: string): Boolean;
var
  LIsRehashNeeded: Boolean;
  LBCryptCostValue: string;
begin
  if IsClearPassword then
    Result := ASuppliedPasswordHash = AStoredPasswordHash
  else
  begin
    Result := TBCrypt.CheckPassword(ASuppliedPasswordHash,AStoredPasswordHash,LIsRehashNeeded);
    if Result and LIsRehashNeeded then
    begin
      // Increasing password's cost value (see BCrypt doc.) and rehashing when hash's strength is under a certain threshold
      LBCryptCostValue := StringReplace(AStoredPasswordHash.Substring(3,3), '$', '', [rfReplaceAll]);
      FBCryptCost := StrToInt(LBCryptCostValue)+1;
      SetPassword(ASuppliedPasswordHash);
    end;
  end;
end;

procedure TKDBCryptAuthenticator.ReadUserFromRecord(const AUser: TKAuthUser;
  const ADBQuery: TEFDBQuery; const AAuthData: TEFNode);
begin
  inherited;
  AAuthData.SetString('Password', ADBQuery.DataSet.FieldByName('PASSWORD_HASH').AsString);
  if (AAuthData.GetString('Password') = '') then
    AAuthData.SetString('Password',AAuthData.GetString('Password'));
end;

procedure TKDBCryptAuthenticator.ResetPassword(const AParams: TEFNode);
var
  LUserName: string;
  LEmailAddress: string;
  LPassword: string;
  LPasswordHash: string;
  LCommandText: string;
  LCommand: TEFDBCommand;
begin
  Assert(Assigned(AParams));

  LUserName := AParams.GetString('UserName');
  if LUserName = '' then
    raise Exception.Create(_('UserName not specified.'));

  LEmailAddress := AParams.GetString('EmailAddress');
  if LEmailAddress = '' then
    raise Exception.Create(_('E-mail address not specified.'));

  LPassword := GenerateRandomPassword;
  AParams.SetString('Password', LPassword);

  BeforeResetPassword(AParams);
  if IsClearPassword then
    LPasswordHash := LPassword
  else
    LPasswordHash := GetBCryptedString(LPassword);

  LCommandText := GetResetPasswordCommandText;
  LCommand := TKConfig.Instance.DBConnections[GetDatabaseName].CreateDBCommand;
  try
    LCommand.Connection.StartTransaction;
    try
      LCommand.CommandText := LCommandText;
      LCommand.Params.ParamByName('USER_NAME').AsString := LUserName;
      LCommand.Params.ParamByName('EMAIL_ADDRESS').AsString := LEmailAddress;
      LCommand.Params.ParamByName('PASSWORD_HASH').AsString := LPasswordHash;
      if LCommand.Execute <> 1 then
        raise EKError.Create(_('Error: user name and email address not found.'));
      AfterResetPassword(LCommand.Connection, AParams);
      LCommand.Connection.CommitTransaction;
    except
      LCommand.Connection.RollbackTransaction;
      raise;
    end;
  finally
    FreeAndNil(LCommand);
  end;
end;

function TKDBCryptAuthenticator.GetReadUserCommandText(const AUserName: string): string;
begin
  Result := Config.GetString('ReadUserCommandText',
    DEFAULT_BCRYPT_READUSERCOMMANDTEXT);
end;

function TKDBCryptAuthenticator.GetSetPasswordCommandText: string;
begin
  Result := Config.GetString('SetPasswordCommandText',
    DEFAULT_BCRYPT_SETPASSWORDCOMMANDTEXT);
end;

function TKDBCryptAuthenticator.GetResetPasswordCommandText: string;
begin
  Result := Config.GetString('ResetPasswordCommandText',
    DEFAULT_BCRYPT_RESETPASSWORDCOMMANDTEXT);
end;

initialization
  TKAuthenticatorRegistry.Instance.RegisterClass('DB', TKDBAuthenticator);
  TKAuthenticatorRegistry.Instance.RegisterClass('DBCrypt',TKDBCryptAuthenticator);

finalization
  TKAuthenticatorRegistry.Instance.UnregisterClass('DB');
  TKAuthenticatorRegistry.Instance.UnregisterClass('DBCrypt');

end.

