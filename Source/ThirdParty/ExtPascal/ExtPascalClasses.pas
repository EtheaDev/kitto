unit ExtPascalClasses;

interface

uses
  SysUtils, Classes, IniFiles, EF.StrUtils, ExtPascalUtils;

{$WARN IMPLICIT_STRING_CAST OFF}
{$WARN IMPLICIT_STRING_CAST_LOSS OFF}

type
  TCustomWebApplication = class;

{$M+}
  TCustomWebSession = class;
{$M-}

  TObjectCatalog = class(TComponent)
  private
    FSession: TCustomWebSession;
  public
    function FindExtObject(const AJSName: string): TObject;

    procedure FreeAllExtObjects;

    property Session: TCustomWebSession read FSession;
  end;

{$M+}
  TCustomWebSession = class(TObject)
  private
    FUploadedFileTooBig: Boolean;
    FObjectCatalog: TObjectCatalog;
    FNameSpace: string;
    FScriptName : string;
    FSessionGUID: string;
    FAcceptedWildCards: string;
    function CheckPassword(const RealPassword : string) : Boolean;
    function GetCookie(const Name : string): string;
    function GetQuery(const ParamName : string) : string;
    function GetQueryAsBoolean(const ParamName : string) : Boolean;
    function GetQueryAsDouble(const ParamName : string) : Double;
    function GetQueryAsInteger(const ParamName : string) : Integer;
    function GetQueryAsTDateTime(const ParamName : string) : TDateTime;
    procedure SetCustomResponseHeaders(const Name, Value : string);
    function GetSessionCookie: string;
    procedure SetSessionCookie(const AValue: string);
    procedure SetScriptName(const Value: string);
    procedure SetNameSpace(const Value: string);
    procedure SetAcceptedWildCards(const Value: string);
    procedure SetMaxUploadSize(const Value: Integer);
  protected
    FApplication : TCustomWebApplication;
    FBrowser : TBrowser;
    FContentType : string;
    FCookies : TStrings;
    FCustomResponseHeaders : TStrings;
    FFileUploaded : string;
    FFileUploadedFullName : string;
    FGarbageCollector : TStrings; // Object list to free when the session ends
    FIsAjax : Boolean;
    FIsDownload : Boolean;
    FIsUpload : Boolean;
    FMaxUploadSize : Integer;
    FNewThread : Boolean;
    FOwner : TObject;
    FPathInfo : string;
    FQueries : TStrings;
    FUploadMark : AnsiString;
    FUploadPath : string;
    procedure AfterHandleRequest; virtual;
    procedure AfterNewSession; virtual;
    function BeforeHandleRequest : Boolean; virtual;
    function CanCallAfterHandleRequest : Boolean; virtual; abstract;
    function CanHandleUrlPath : Boolean; virtual; abstract;
    procedure DetectBrowser(const UserAgent : string);
    procedure DoLogout; virtual;
    procedure DoSetCookie(const Name, ValueRaw : string); virtual;
    procedure DownloadBuffer(const FileName: string; const Size: Longint;
      const Buffer : AnsiString; AContentType : string = '';
      const AEmbedded: Boolean = False);
    function DownloadContentType(const FileName, Default : string) : string;
    class function GetCurrentWebSession : TCustomWebSession; virtual; abstract;
    function GetDocumentRoot : string; virtual; abstract;
    function GarbageFixName(const Name : string) : string; virtual;
    function GetRequestHeader(const Name : string) : string; virtual; abstract;
    function GetRequestBody: string; virtual; abstract;
    function GetUrlHandlerObject : TObject; virtual;
    function GetWebServer : string; virtual; abstract;
    procedure HandleRequest(const ARequest : AnsiString);
    function HandleUrlPath : Boolean; virtual;
    procedure InitDefaultValues; virtual;
    procedure OnError(const Msg, Method, Params : string); virtual;
    procedure OnRedirectError(const AURLToRedirect: string); virtual;
    procedure OnNotFoundError; virtual;
    procedure SendResponse(const Msg : AnsiString); virtual; abstract;
    procedure SetCookie(const Name, Value : string; Expires : TDateTime = 0; const Domain : string = '';
                        const Path : string = ''; Secure : Boolean = False);
    procedure SetQueryText(const AQueryStr : string; NeedDecode, Append : Boolean);
    function TryToServeFile: Boolean; virtual;
    function UploadBlockType(const Buffer : AnsiString; var MarkPos : Integer) : TUploadBlockType; virtual; abstract;
    function UploadNeedUnknownBlock : Boolean; virtual; abstract;
    procedure UploadPrepare(const AContentType: string; const Buffer : AnsiString; var FileMark : Integer);
    procedure UploadResponse(Success : Boolean; const AMessage: string = '');
    procedure UploadWriteFile(const Buffer : AnsiString; InitPos : Integer = 1);
    property Application : TCustomWebApplication read FApplication;
    property DocumentRoot : string read GetDocumentRoot;
    property IsDownload : Boolean read FIsDownload write FIsDownload;
    property IsUpload : Boolean read FIsUpload write FIsUpload;
    property Owner : TObject read FOwner;
    property UploadMark : AnsiString read FUploadMark write FUploadMark;
    function GetUploadedFileFullName(const UploadedFileName: string): string; virtual;
    function GetSessionCookieName: string; virtual;
  public
    RequiresReload : boolean;
    Response: string;
    Charset: string; // Charset for html contenttype default utf-8, another option iso-8859-1
    constructor Create(AOwner: TObject); reintroduce; virtual;
    destructor Destroy; override;
    procedure Alert(const AMessage: string); virtual;
    procedure DownloadFile(const FileName : string; AContentType : string = '');
    procedure DownloadStream(const Stream : TStream; const FileName : string; AContentType : string = '';
      const AEmbedded: Boolean = False);
    procedure Refresh; virtual;
    function MethodURI(MethodName : string): string; overload;
    function MethodURI(Method : TExtProcedure): string; overload;
    function EncodeResponse: AnsiString;
    property Browser : TBrowser read FBrowser; // Browser in use in this session
    property ContentType : string read FContentType write FContentType; // HTTP response content-type header, default is 'text/html'
    property Cookie[const Name : string] : string read GetCookie; // Returns HTTP cookies read in the current request
    property CustomResponseHeaders[const Name : string]: string write SetCustomResponseHeaders;
    property FileUploaded : string read FFileUploaded; // Last uploaded file name
    property FileUploadedFullName : string read FFileUploadedFullName; // Last uploaded file fullname
    property IsAjax : Boolean read FIsAjax write FIsAjax; // Tests if execution is occurring in an AJAX request
    property MaxUploadSize : Integer read FMaxUploadSize write SetMaxUploadSize; // Max size of upload file. Default is MaxLongint(2GB)
    property AcceptedWildCards : string read FAcceptedWildCards write SetAcceptedWildCards; //optional file extensions to check for upload
    property NewThread : Boolean read FNewThread write FNewThread; // True if is the first request of a thread
    property PathInfo: string read FPathInfo; // Path info string for the current request
    property Query[const ParamName : string] : string read GetQuery; // Returns HTTP query info parameters read in the current request as a string
    property QueryAsBoolean[const ParamName : string] : Boolean read GetQueryAsBoolean;
    property QueryAsInteger[const ParamName : string] : Integer read GetQueryAsInteger;
    property QueryAsDouble[const ParamName : string] : Double read GetQueryAsDouble;
    property QueryAsTDateTime[const ParamName : string] : TDateTime read GetQueryAsTDateTime;
    property Queries : TStrings read FQueries; // Returns all HTTP queries as list to ease searching
    property RequestHeader[const Name : string]: string read GetRequestHeader; // Returns HTTP headers read in the current request
    property RequestBody: string read GetRequestBody; // returns request payload for POST requests.
    property ScriptName : string read FScriptName write SetScriptName;
    property UploadPath : string read FUploadPath write FUploadPath; // Upload path below document root. e.g. '/uploads'
    property WebServer : string read GetWebServer; // WebServer in use in this session

    property ObjectCatalog: TObjectCatalog read FObjectCatalog;

    procedure CopyContextFrom(const ASession: TCustomWebSession); virtual;

    // Optional namespace to allow more sessions of the same application
    // in the same web page. It is set as an additional $<namespace> path in the initial URL
    // and then it is a) added as part of the URL to all requests from the session and
    // b) used with the session GUID to locate a request's session.
    // A valid namespace must begin with $.
    property NameSpace: string read FNameSpace write SetNameSpace;

    property SessionCookie: string read GetSessionCookie write SetSessionCookie;
    property SessionGUID: string read FSessionGUID write FSessionGUID;

    function CreateNewSessionId: string;
  published
    procedure Home; virtual; abstract; // Default method to be called by <link TCustomWebSession.HandleRequest, HandleRequest>
    procedure Logout;
    procedure Shutdown;
  end;
{$M-}

  TCustomWebSessionClass = class of TCustomWebSession;

  TCustomWebApplication = class(TComponent)
  protected
    FConfig : TCustomIniFile;
    FIcon : string;
    FMaxConns : Integer;
    FMaxIdleMinutes : Word;
    FOwnerThread : TThread;
    FPassword : string;
    FPort : Word;
    FSessionClass : TCustomWebSessionClass;
    FTerminated : Boolean;
    FTitle : string;
    procedure DoRun; virtual; abstract;
    function GetTerminated : Boolean; virtual;
    property Terminated : Boolean read GetTerminated;
  public
    constructor Create(const AOwner: TComponent; const ATitle : string; ASessionClass : TCustomWebSessionClass; APort : Word;
                       AMaxIdleMinutes : Word = 30; AMaxConns : Integer = 1000); reintroduce; virtual;
    function Reconfig(AReload : Boolean = True) : Boolean; virtual;
    procedure Run(AOwnerThread : TThread = nil); // To enter the main loop
    procedure Terminate; // To terminate the application
    property Config : TCustomIniFile read FConfig;
    property Icon : string read FIcon write FIcon; // Icon to show in Browser
    property MaxConns : Integer read FMaxConns;
    property MaxIdleMinutes : Word read FMaxIdleMinutes;
    property OwnerThread : TThread read FOwnerThread; // Application will terminate if OwnerThread is not nil and OwnerThread.Terminated is True
    property Password : string read FPassword write FPassword; // Password to be informed in Browser URL, as a query parameter, to Shutdown and Reconfig methods
    property Port : Word read FPort;
    property SessionClass : TCustomWebSessionClass read FSessionClass;
    property Title : string read FTitle; // Application title
  end;

implementation

uses
  StrUtils,
  {$IF CompilerVersion > 27}
  NetEncoding,
  {$ELSE}
  HTTPApp,
  {$ENDIF}
  ExtPascal,
  gnugettext;

const
  CBrowserNames: array[TBrowser] of string = ('Unknown', 'MSIE', 'Firefox', 'Chrome', 'Safari', 'Opera', 'Konqueror', 'Safari');
  // todo: put this map into a config file
  CMIMEExtensions: array[1..176] of record Ext: string; MimeType: string; end = (
    (Ext: '.gif'; MimeType: 'image/gif'),
    (Ext: '.jpg'; MimeType: 'image/jpeg'),
    (Ext: '.jpeg'; MimeType: 'image/jpeg'),
    (Ext: '.html'; MimeType: 'text/html'),
    (Ext: '.htm'; MimeType: 'text/html'),
    (Ext: '.css'; MimeType: 'text/css'),
    (Ext: '.js'; MimeType: 'text/javascript'),
    (Ext: '.txt'; MimeType: 'text/plain'),
    (Ext: '.xls'; MimeType: 'application/excel'),
    (Ext: '.rtf'; MimeType: 'text/richtext'),
    (Ext: '.wq1'; MimeType: 'application/x-lotus'),
    (Ext: '.wk1'; MimeType: 'application/x-lotus'),
    (Ext: '.raf'; MimeType: 'application/raf'),
    (Ext: '.png'; MimeType: 'image/x-png'),
    (Ext: '.c'; MimeType: 'text/plain'),
    (Ext: '.c++'; MimeType: 'text/plain'),
    (Ext: '.pl'; MimeType: 'text/plain'),
    (Ext: '.cc'; MimeType: 'text/plain'),
    (Ext: '.h'; MimeType: 'text/plain'),
    (Ext: '.talk'; MimeType: 'text/x-speech'),
    (Ext: '.xbm'; MimeType: 'image/x-xbitmap'),
    (Ext: '.xpm'; MimeType: 'image/x-xpixmap'),
    (Ext: '.ief'; MimeType: 'image/ief'),
    (Ext: '.jpe'; MimeType: 'image/jpeg'),
    (Ext: '.tiff'; MimeType: 'image/tiff'),
    (Ext: '.tif'; MimeType: 'image/tiff'),
    (Ext: '.rgb'; MimeType: 'image/rgb'),
    (Ext: '.g3f'; MimeType: 'image/g3fax'),
    (Ext: '.xwd'; MimeType: 'image/x-xwindowdump'),
    (Ext: '.pict'; MimeType: 'image/x-pict'),
    (Ext: '.ppm'; MimeType: 'image/x-portable-pixmap'),
    (Ext: '.pgm'; MimeType: 'image/x-portable-graymap'),
    (Ext: '.pbm'; MimeType: 'image/x-portable-bitmap'),
    (Ext: '.pnm'; MimeType: 'image/x-portable-anymap'),
    (Ext: '.bmp'; MimeType: 'image/x-ms-bmp'),
    (Ext: '.ras'; MimeType: 'image/x-cmu-raster'),
    (Ext: '.pcd'; MimeType: 'image/x-photo-cd'),
    (Ext: '.cgm'; MimeType: 'image/cgm'),
    (Ext: '.mil'; MimeType: 'image/x-cals'),
    (Ext: '.cal'; MimeType: 'image/x-cals'),
    (Ext: '.fif'; MimeType: 'image/fif'),
    (Ext: '.dsf'; MimeType: 'image/x-mgx-dsf'),
    (Ext: '.cmx'; MimeType: 'image/x-cmx'),
    (Ext: '.wi'; MimeType: 'image/wavelet'),
    (Ext: '.dwg'; MimeType: 'image/vnd.dwg'),
    (Ext: '.dxf'; MimeType: 'image/vnd.dxf'),
    (Ext: '.svf'; MimeType: 'image/vnd.svf'),
    (Ext: '.au'; MimeType: 'audio/basic'),
    (Ext: '.snd'; MimeType: 'audio/basic'),
    (Ext: '.aif'; MimeType: 'audio/x-aiff'),
    (Ext: '.aiff'; MimeType: 'audio/x-aiff'),
    (Ext: '.aifc'; MimeType: 'audio/x-aiff'),
    (Ext: '.wav'; MimeType: 'audio/x-wav'),
    (Ext: '.mpa'; MimeType: 'audio/x-mpeg'),
    (Ext: '.abs'; MimeType: 'audio/x-mpeg'),
    (Ext: '.mpega'; MimeType: 'audio/x-mpeg'),
    (Ext: '.mp2a'; MimeType: 'audio/x-mpeg-2'),
    (Ext: '.mpa2'; MimeType: 'audio/x-mpeg-2'),
    (Ext: '.es'; MimeType: 'audio/echospeech'),
    (Ext: '.vox'; MimeType: 'audio/voxware'),
    (Ext: '.lcc'; MimeType: 'application/fastman'),
    (Ext: '.ra'; MimeType: 'application/x-pn-realaudio'),
    (Ext: '.ram'; MimeType: 'application/x-pn-realaudio'),
    (Ext: '.mmid'; MimeType: 'x-music/x-midi'),
    (Ext: '.skp'; MimeType: 'application/vnd.koan'),
    (Ext: '.talk'; MimeType: 'text/x-speech'),
    (Ext: '.mpeg'; MimeType: 'video/mpeg'),
    (Ext: '.mpg'; MimeType: 'video/mpeg'),
    (Ext: '.mpe'; MimeType: 'video/mpeg'),
    (Ext: '.mpv2'; MimeType: 'video/mpeg-2'),
    (Ext: '.mp2v'; MimeType: 'video/mpeg-2'),
    (Ext: '.qt'; MimeType: 'video/quicktime'),
    (Ext: '.mov'; MimeType: 'video/quicktime'),
    (Ext: '.avi'; MimeType: 'video/x-msvideo'),
    (Ext: '.movie'; MimeType: 'video/x-sgi-movie'),
    (Ext: '.vdo'; MimeType: 'video/vdo'),
    (Ext: '.viv'; MimeType: 'video/vnd.vivo'),
    (Ext: '.pac'; MimeType: 'application/x-ns-proxy-autoconfig'),
    (Ext: '.ai'; MimeType: 'application/postscript'),
    (Ext: '.eps'; MimeType: 'application/postscript'),
    (Ext: '.ps'; MimeType: 'application/postscript'),
    (Ext: '.rtf'; MimeType: 'application/rtf'),
    (Ext: '.pdf'; MimeType: 'application/pdf'),
    (Ext: '.mif'; MimeType: 'application/vnd.mif'),
    (Ext: '.t'; MimeType: 'application/x-troff'),
    (Ext: '.tr'; MimeType: 'application/x-troff'),
    (Ext: '.roff'; MimeType: 'application/x-troff'),
    (Ext: '.man'; MimeType: 'application/x-troff-man'),
    (Ext: '.me'; MimeType: 'application/x-troff-me'),
    (Ext: '.ms'; MimeType: 'application/x-troff-ms'),
    (Ext: '.latex'; MimeType: 'application/x-latex'),
    (Ext: '.tex'; MimeType: 'application/x-tex'),
    (Ext: '.texinfo'; MimeType: 'application/x-texinfo'),
    (Ext: '.texi'; MimeType: 'application/x-texinfo'),
    (Ext: '.dvi'; MimeType: 'application/x-dvi'),
    (Ext: '.doc'; MimeType: 'application/msword'),
    (Ext: '.oda'; MimeType: 'application/oda'),
    (Ext: '.evy'; MimeType: 'application/envoy'),
    (Ext: '.gtar'; MimeType: 'application/x-gtar'),
    (Ext: '.tar'; MimeType: 'application/x-tar'),
    (Ext: '.ustar'; MimeType: 'application/x-ustar'),
    (Ext: '.bcpio'; MimeType: 'application/x-bcpio'),
    (Ext: '.cpio'; MimeType: 'application/x-cpio'),
    (Ext: '.shar'; MimeType: 'application/x-shar'),
    (Ext: '.zip'; MimeType: 'application/zip'),
    (Ext: '.hqx'; MimeType: 'application/mac-binhex40'),
    (Ext: '.sit'; MimeType: 'application/x-stuffit'),
    (Ext: '.sea'; MimeType: 'application/x-stuffit'),
    (Ext: '.fif'; MimeType: 'application/fractals'),
    (Ext: '.bin'; MimeType: 'application/octet-stream'),
    (Ext: '.uu'; MimeType: 'application/octet-stream'),
    (Ext: '.exe'; MimeType: 'application/octet-stream'),
    (Ext: '.src'; MimeType: 'application/x-wais-source'),
    (Ext: '.wsrc'; MimeType: 'application/x-wais-source'),
    (Ext: '.hdf'; MimeType: 'application/hdf'),
    (Ext: '.ls'; MimeType: 'text/javascript'),
    (Ext: '.mocha'; MimeType: 'text/javascript'),
    (Ext: '.vbs'; MimeType: 'text/vbscript'),
    (Ext: '.sh'; MimeType: 'application/x-sh'),
    (Ext: '.csh'; MimeType: 'application/x-csh'),
    (Ext: '.pl'; MimeType: 'application/x-perl'),
    (Ext: '.tcl'; MimeType: 'application/x-tcl'),
    (Ext: '.spl'; MimeType: 'application/futuresplash'),
    (Ext: '.mbd'; MimeType: 'application/mbedlet'),
    (Ext: '.swf'; MimeType: 'application/x-director'),
    (Ext: '.pps'; MimeType: 'application/mspowerpoint'),
    (Ext: '.asp'; MimeType: 'application/x-asap'),
    (Ext: '.asn'; MimeType: 'application/astound'),
    (Ext: '.axs'; MimeType: 'application/x-olescript'),
    (Ext: '.ods'; MimeType: 'application/x-oleobject'),
    (Ext: '.opp'; MimeType: 'x-form/x-openscape'),
    (Ext: '.wba'; MimeType: 'application/x-webbasic'),
    (Ext: '.frm'; MimeType: 'application/x-alpha-form'),
    (Ext: '.wfx'; MimeType: 'x-script/x-wfxclient'),
    (Ext: '.pcn'; MimeType: 'application/x-pcn'),
    (Ext: '.ppt'; MimeType: 'application/vnd.ms-powerpoint'),
    (Ext: '.svd'; MimeType: 'application/vnd.svd'),
    (Ext: '.ins'; MimeType: 'application/x-net-install'),
    (Ext: '.ccv'; MimeType: 'application/ccv'),
    (Ext: '.vts'; MimeType: 'workbook/formulaone'),
    (Ext: '.wrl'; MimeType: 'x-world/x-vrml'),
    (Ext: '.vrml'; MimeType: 'x-world/x-vrml'),
    (Ext: '.vrw'; MimeType: 'x-world/x-vream'),
    (Ext: '.p3d'; MimeType: 'application/x-p3d'),
    (Ext: '.svr'; MimeType: 'x-world/x-svr'),
    (Ext: '.wvr'; MimeType: 'x-world/x-wvr'),
    (Ext: '.3dmf'; MimeType: 'x-world/x-3dmf'),
    (Ext: '.ma'; MimeType: 'application/mathematica'),
    (Ext: '.msh'; MimeType: 'x-model/x-mesh'),
    (Ext: '.v5d'; MimeType: 'application/vis5d'),
    (Ext: '.igs'; MimeType: 'application/iges'),
    (Ext: '.dwf'; MimeType: 'drawing/x-dwf'),
    (Ext: '.showcase'; MimeType: 'application/x-showcase'),
    (Ext: '.slides'; MimeType: 'application/x-showcase'),
    (Ext: '.sc'; MimeType: 'application/x-showcase'),
    (Ext: '.sho'; MimeType: 'application/x-showcase'),
    (Ext: '.show'; MimeType: 'application/x-showcase'),
    (Ext: '.ins'; MimeType: 'application/x-insight'),
    (Ext: '.insight'; MimeType: 'application/x-insight'),
    (Ext: '.ano'; MimeType: 'application/x-annotator'),
    (Ext: '.dir'; MimeType: 'application/x-dirview'),
    (Ext: '.lic'; MimeType: 'application/x-enterlicense'),
    (Ext: '.faxmgr'; MimeType: 'application/x-fax-manager'),
    (Ext: '.faxmgrjob'; MimeType: 'application/x-fax-manager-job'),
    (Ext: '.icnbk'; MimeType: 'application/x-iconbook'),
    (Ext: '.wb'; MimeType: 'application/x-inpview'),
    (Ext: '.inst'; MimeType: 'application/x-install'),
    (Ext: '.mail'; MimeType: 'application/x-mailfolder'),
    (Ext: '.pp'; MimeType: 'application/x-ppages'),
    (Ext: '.ppages'; MimeType: 'application/x-ppages'),
    (Ext: '.sgi-lpr'; MimeType: 'application/x-sgi-lpr'),
    (Ext: '.tardist'; MimeType: 'application/x-tardist'),
    (Ext: '.ztardist'; MimeType: 'application/x-ztardist'),
    (Ext: '.wkz'; MimeType: 'application/x-wingz'),
    (Ext: '.xml'; MimeType: 'application/xml'),
    (Ext: '.iv'; MimeType: 'graphics/x-inventor'));

type
  PGarbage = ^TGarbage;
  TGarbage = record
    Garbage    : TObject;
    Persistent : Boolean;
  end;

{ TCustomWebSession }

constructor TCustomWebSession.Create(AOwner: TObject);
begin
  inherited Create;
  FObjectCatalog := TObjectCatalog.Create(nil);
  FObjectCatalog.FSession := Self;
  FOwner := AOwner;
  FGarbageCollector := TStringList.Create;
  TStringList(FGarbageCollector).Sorted := True;
  FMaxUploadSize := MaxLongInt;
  FCookies := TStringList.Create;
  FCookies.StrictDelimiter := True;
  FCookies.Delimiter := ';';
  FCustomResponseHeaders := TStringList.Create;
  FCustomResponseHeaders.NameValueSeparator := ':';
  FQueries := TStringList.Create;
  FQueries.StrictDelimiter := True;
  FQueries.Delimiter := '&';
  InitDefaultValues;
end;

function TCustomWebSession.CreateNewSessionId: string;
var
  LGUID: TGUID;
begin
  CreateGUID(LGUID);
  Result := GUIDToString(LGUID);
  if NameSpace <> '' then
    Result := NameSpace + '/' + Result;
end;

destructor TCustomWebSession.Destroy;
begin
  FQueries.Free;
  FCustomResponseHeaders.Free;
  FCookies.Free;
  FGarbageCollector.Free;
  FreeAndNil(FObjectCatalog);
  inherited;
end;

procedure TCustomWebSession.AfterHandleRequest; begin end;

procedure TCustomWebSession.AfterNewSession; begin end;

procedure TCustomWebSession.Alert(const AMessage: string);
begin
  Response := Format('alert("%s");', [AMessage]);
end;

function TCustomWebSession.BeforeHandleRequest : Boolean;
begin
  Result := True;
end;

function TCustomWebSession.CheckPassword(const RealPassword : string) : Boolean;
begin
  Result := (RealPassword <> '') and (Query['password'] = RealPassword);
end;

procedure TCustomWebSession.CopyContextFrom(const ASession: TCustomWebSession);
begin
  FCookies.DelimitedText := ASession.FCookies.DelimitedText;
  NameSpace := ASession.NameSpace;
end;

procedure TCustomWebSession.DetectBrowser(const UserAgent : string);
var
  LBrowser: TBrowser;
begin
  for LBrowser := TBrowser(Ord(brUnknown) + 1) to High(TBrowser) do
    if Pos(CBrowserNames[LBrowser], UserAgent) <> 0 then begin
      FBrowser := LBrowser;
      if (FBrowser = brSafari) and // Which Safari?
        (Pos('Mobile', UserAgent) > 0) and
        (Pos('Apple', UserAgent) > 0) then
        FBrowser := brMobileSafari;
      Exit;
    end;
  FBrowser := brUnknown;
end;

procedure TCustomWebSession.DoLogout; begin end;

// send cookie to response
procedure TCustomWebSession.DoSetCookie(const Name, ValueRaw : string); begin end;

procedure TCustomWebSession.DownloadBuffer(const FileName: string; const Size: Longint;
  const Buffer : AnsiString; AContentType : string = '';
  const AEmbedded: Boolean = False);
begin
  if AContentType = '' then
    ContentType := DownloadContentType(FileName, 'application/octet-stream')
  else
    ContentType := AContentType;
  if not AEmbedded then
    CustomResponseHeaders['content-disposition'] := Format('attachment;filename="%s"', [ExtractFileName(FileName)]);
  CustomResponseHeaders['Content-Length'] := IntToStr(Size);
  Response := string(Buffer);
  IsDownload := True;
end;

function TCustomWebSession.DownloadContentType(const FileName, Default : string) : string;
var
  FileExt : string;
  I : Integer;
begin
  Result := Default;
  FileExt := LowerCase(ExtractFileExt(FileName));
  for I := Low(CMIMEExtensions) to High(CMIMEExtensions) do
    with CMIMEExtensions[I] do
      if Ext = FileExt then begin
        Result := MimeType;
        Break;
      end;
end;

procedure TCustomWebSession.DownloadFile(const FileName : string; AContentType : string = '');
var
  F : file;
  Buffer : AnsiString;
  Size: Longint;
begin
  if FileExists(FileName) then begin
    System.Assign(F, FileName);
    Reset(F, 1);
    Size := FileSize(F);
    SetLength(Buffer, Size);
    BlockRead(F, Buffer[1], Length(Buffer));
    Close(F);
    DownloadBuffer(FileName, Size, Buffer, AContentType);
  end;
end;

procedure TCustomWebSession.DownloadStream(const Stream: TStream;
  const FileName: string; AContentType: string;
  const AEmbedded: Boolean);
var
  Buffer : AnsiString;
  Size: Longint;
begin
  if Assigned(Stream) then begin
    Size := Stream.Size;
    SetLength(Buffer, Size);
    Stream.Position := 0;
    Stream.Read(Buffer[1], Length(Buffer));
    DownloadBuffer(FileName, Size, Buffer, AContentType, AEmbedded);
  end;
end;

{
Encodes the response according to the Charset and returns it
as a SBCS string. Please note that currently only utf-8 and
the system charset (iso-8859-1 in Western Europe) are supported.
}
function TCustomWebSession.EncodeResponse: AnsiString;
begin
  if SameText(Charset, 'utf-8') then
    Result := {$IFDEF MSWINDOWS}AnsiToUTF8{$ENDIF}(Response)
  else
    Result := AnsiString(Response);
end;

function TCustomWebSession.GarbageFixName(const Name : string) : string;
begin
  Result := Name;
end;

function TCustomWebSession.GetCookie(const Name : string) : string;
begin
  Result := FCookies.Values[Name];
end;

function TCustomWebSession.GetQuery(const ParamName : string) : string;
begin
  Result := FQueries.Values[ParamName];
end;

function TCustomWebSession.GetQueryAsBoolean(const ParamName : string) : Boolean;
begin
  Result := StrToBoolDef(Query[ParamName], False);
end;

function TCustomWebSession.GetQueryAsDouble(const ParamName : string) : Double;
begin
  Result := StrToFloatDef(Query[ParamName], 0);
end;

function TCustomWebSession.GetQueryAsInteger(const ParamName : string): Integer;
begin
  Result := StrToIntDef(Query[ParamName], 0);
end;

function TCustomWebSession.GetQueryAsTDateTime(const ParamName : string) : TDateTime;
begin
  Result := StrToFloatDef(Query[ParamName], 0);
end;

function TCustomWebSession.GetSessionCookie: string;
begin
  Result := Cookie[GetSessionCookieName];
end;

function TCustomWebSession.GetSessionCookieName: string;
begin
  Result := 'FCGIThread';
end;

function TCustomWebSession.GetUrlHandlerObject : TObject;
begin
  Result := Self;
end;

procedure TCustomWebSession.HandleRequest(const ARequest : AnsiString);
begin
  if Browser = brUnknown then DetectBrowser(RequestHeader['HTTP_USER_AGENT']);
  if BeforeHandleRequest then
    try
      if PathInfo = NameSpace then
        Home
      else
        if CanHandleUrlPath and not HandleUrlPath and not TryToServeFile then
          OnNotFoundError;
    except
      on E: ERedirectError do OnRedirectError(E.Message);
      {$IF CompilerVersion > 27}
      on E: Exception do OnError(E.Message, PathInfo, string(TNetEncoding.URL.Decode(ARequest)));
      {$ELSE}
      on E: Exception do OnError(E.Message, PathInfo, string(HTTPDecode(ARequest)));
      {$ENDIF}
    end;
  if CanCallAfterHandleRequest then AfterHandleRequest;
end;

function TCustomWebSession.HandleUrlPath : Boolean;
type
  MethodCall = procedure of object;
var
  PageMethod : TMethod;
  HandlerObj : TObject;
  LPathInfo: string;
  LPos: Integer;
begin
  HandlerObj := GetUrlHandlerObject;
  if Assigned(HandlerObj) then
  begin
    LPathInfo := PathInfo;
    LPos := Pos('/', LPathInfo);
    if LPos > 0 then
      Delete(LPathInfo, 1, LPos);
    PageMethod.Code := HandlerObj.MethodAddress(LPathInfo);
    Result := PageMethod.Code <> nil;
    if Result then
    begin
      PageMethod.Data := HandlerObj;
      MethodCall(PageMethod); // Call published method
    end;
  end
  else
  begin
{$IFDEF DEBUG}
    raise Exception.CreateFmt(dgettext('Kitto','Handler object for method %s not found in session.'), [PathInfo]);
{$ELSE}
    Result := False;
{$ENDIF}
  end;
end;

procedure TCustomWebSession.InitDefaultValues; begin end;

procedure TCustomWebSession.Logout;
begin
  Response := 'window.close();';
  DoLogout;
end;

function TCustomWebSession.MethodURI(MethodName : string): string;
begin
  Result := ScriptName;
  if NameSpace <> '' then
    Result := ScriptName + NameSpace + '/';
  Result := Result + MethodName;
end;

function TCustomWebSession.MethodURI(Method : TExtProcedure) : string;
begin
  Result := GetCurrentWebSession.MethodName(@Method);
  if Result <> '' then
    Result := MethodURI(Result)
  else
    raise Exception.Create(dgettext('Kitto','MethodURI: Method is not published'));
end;

procedure TCustomWebSession.OnError(const Msg, Method, Params : string);
var
  LMsg: string;
begin
  LMsg := Format(dgettext('Kitto','%s\non Method: %s\nParams: %s'),
    [Msg, Method, Params]);
  Alert(LMsg);
end;

procedure TCustomWebSession.OnNotFoundError;
var
  LMsg: string;
begin
  LMsg := Format(dgettext('Kitto','Method: ''%s'' not found'), [PathInfo]);
  Response := Format('alert("%s");', [LMsg]);
end;

procedure TCustomWebSession.OnRedirectError(const AURLToRedirect: string);
begin
  Alert(dgettext('Kitto','Redirect to: ')+ AURLToRedirect);
end;

{
Calls Garbage collector. Optionally used to Refresh the Home page, when user press F5 on browser
@example <code>
if not NewThread then begin
  Refresh;
  EditorGrid := nil;
  DataStore := nil;
end;</code>
}
procedure TCustomWebSession.Refresh;
begin
  ObjectCatalog.FreeAllExtObjects;
end;

{
Sets a cookie in HTTP response header
@param Name Cookie name
@param Value Cookie value
@param Expires Cookie expiration date. If zero or not specified, the cookie will expire when the user's session ends.
@param Domain Sets this cookie only if Domain parameter matches against the tail of the fully qualified domain name of the host.
If not specified assumes the current Domain request.
@param Path Sets this cookie only if Path parameter matches against the initial part of pathname component of the URL.
If not specified assumes the current pathname request.
@param Secure If true the cookie will only be transmitted if the communications channel with the host is a secure one (HTTPS only).
The default is false.
}
procedure TCustomWebSession.SetAcceptedWildCards(const Value: string);
begin
  FAcceptedWildCards := Value;
end;

procedure TCustomWebSession.SetCookie(const Name, Value : string; Expires : TDateTime; const Domain, Path : string; Secure : Boolean);
var
  ValueRaw : string;
begin
  ValueRaw := Value;
  if Expires <> 0 then
    ValueRaw := Format('%s; expires=%s GMT', [ValueRaw, FormatDateTime('ddd, dd-mmm-yyyy hh:nn:ss', Expires)]);
  if Domain <> '' then
    ValueRaw := Format('%s; domain=%s', [ValueRaw, Domain]);
  if Path <> '' then
    ValueRaw := Format('%s; path=%s', [ValueRaw, Path]);
  if Secure then
    ValueRaw := ValueRaw + '; secure';
  DoSetCookie(Name, ValueRaw);
  FCookies.Values[Name] := ValueRaw;
end;

procedure TCustomWebSession.SetCustomResponseHeaders(const Name, Value : string);
begin
  FCustomResponseHeaders.Values[Name] := Value;
end;

procedure TCustomWebSession.SetMaxUploadSize(const Value: Integer);
begin
  FMaxUploadSize := Value;
end;

procedure TCustomWebSession.SetNameSpace(const Value: string);
begin
  FNameSpace := Value;
  if (FNameSpace <> '') and (FNameSpace[1] = '/') then
    Delete(FNameSpace, 1, 1);
end;

procedure TCustomWebSession.SetQueryText(const AQueryStr : string; NeedDecode, Append : Boolean);
var
  I : Integer;
begin
  if Append then
    FQueries.DelimitedText := FQueries.DelimitedText + '&' + AQueryStr
  else
    FQueries.DelimitedText := AQueryStr;

  if NeedDecode then
    if SameText(Charset, 'utf-8') then
      for I := 0 to FQueries.Count - 1 do
        FQueries[I] := URLDecodeUTF8(FQueries[I])
    else
      for I := 0 to FQueries.Count - 1 do
        FQueries[I] := URLDecode(FQueries[I]);
end;

procedure TCustomWebSession.SetScriptName(const Value: string);
begin
  FScriptName := Value;
  if (FScriptName = '') or (FScriptName[length(FScriptName)] <> '/') then FScriptName := FScriptName + '/';
end;

procedure TCustomWebSession.SetSessionCookie(const AValue: string);
var
  LPath: string;
begin
  LPath := ScriptName;
  if NameSpace <> '' then
    LPath := LPath + NameSpace + '/';
  SetCookie(GetSessionCookieName, AValue, 0, '', LPath);
end;

procedure TCustomWebSession.Shutdown;
begin
  with Application do
    if CheckPassword(Password) then begin
      Logout;
      SendResponse(dgettext('Kitto','SHUTDOWN: Service is temporarily shutdown for maintenance. Please, try again after a few moments.'));
      Terminate;
    end;
end;

function TCustomWebSession.TryToServeFile : Boolean;
begin
  Result := False;
end;

procedure TCustomWebSession.UploadPrepare(const AContentType: string; const Buffer : AnsiString; var FileMark : Integer);
var
  I, J: Integer;
begin
  IsUpload := True;
  FUploadedFileTooBig := False;
  J := Pos('=', AContentType);
  UploadMark := '--' + AnsiString(Copy(AContentType, J + 1, Length(AContentType)));
  I := Pos(UploadMark, Buffer);
  I := PosEx('filename="', string(Buffer), I);
  FileMark := I;
  J := PosEx('"', string(Buffer), I + 10);
  FFileUploaded := ExtractFileName(Copy(string(Buffer), I + 10, J - I - 10));
  if FileUploaded <> '' then
    FFileUploadedFullName := GetUploadedFileFullName(FileUploaded)
  else
    UploadResponse(False);
end;

function TCustomWebSession.GetUploadedFileFullName(const UploadedFileName: string): string;
begin
  Result := ReplaceStr(DocumentRoot + UploadPath + '/' + UploadedFileName, '/', PathDelim);
end;

procedure TCustomWebSession.UploadResponse(Success : Boolean; const AMessage: string);
const
  CBools : array[Boolean] of string = ('false', 'true');

  function GetMessage: string;
  begin
    if AMessage <> '' then
      Result := AMessage
    else
      Result := 'File upload error.';
  end;

begin
  if FileUploaded <> '' then
    Response := Format('{success:%s,file:"%s",message:"%s"}', [CBools[Success], FileUploaded, GetMessage])
  else
    Response := Format('{success:false,message:"%s"}', [GetMessage]);
end;

procedure TCustomWebSession.UploadWriteFile(const Buffer : AnsiString; InitPos : Integer);
var
  F : file;
  I, J, Tam : Integer;
  BlockType : TUploadBlockType;
begin
  if FileUploaded = '' then Exit;
  if MaxUploadSize = 0 then
  begin
    UploadResponse(False, dgettext('Kitto','File upload disabled.'));
    Exit;
  end
  else if FUploadedFileTooBig then
  begin
    UploadResponse(False, Format(dgettext('Kitto','File too big. Maximum allowed size is %s.'),
      [FormatByteSize(MaxUploadSize)]));
    Exit;
  end
  else if not MatchWildCards(FileUploadedFullName, FAcceptedWildCards) then
  begin
    UploadResponse(False, Format(dgettext('Kitto',
      'Error: uploaded file don''t match Wildcard (%s)'),
      [FAcceptedWildcards]));
    Exit;
  end;
  ForceDirectories(ExtractFilePath(FileUploadedFullName));
  System.Assign(F, FileUploadedFullName);
  BlockType := UploadBlockType(Buffer, I);
  case BlockType of
    ubtBegin: begin
      if UploadNeedUnknownBlock then Rewrite(F, 1);
      I := PosEx(#13#10#13#10, string(Buffer), InitPos) + 4;
      J := PosEx(string(UploadMark), string(Buffer), I);
      if J = 0 then begin
        Tam := Length(Buffer) - I + 1;
        BlockType := ubtUnknown;
        UploadResponse(False);
      end
      else begin // unique block
        if not UploadNeedUnknownBlock then Rewrite(F, 1);
        Tam := J - I - 2;
        UploadResponse(True);
      end;
    end;
    ubtMiddle: begin
      Reset(F, 1);
      Seek(F, FileSize(F));
      I := 1;
      Tam := Length(Buffer);
      FUploadedFileTooBig := FileSize(F) + Tam > MaxUploadSize;
    end;
    ubtEnd: begin
      Reset(F, 1);
      Seek(F, FileSize(F));
      Tam := I - 3;
      I := 1;
      UploadResponse(True);
    end;
  else
    Tam := 0; // to make compiler happy
  end;
  if ((BlockType <> ubtUnknown) or UploadNeedUnknownBlock) and ((FileSize(F) + Tam) <= MaxUploadSize) and not FUploadedFileTooBig then
    BlockWrite(F, Buffer[I], Tam);
  Close(F);
end;

{ TCustomWebApplication }

constructor TCustomWebApplication.Create(
  const AOwner: TComponent; const ATitle : string; ASessionClass : TCustomWebSessionClass;
  APort, AMaxIdleMinutes : Word; AMaxConns : Integer);
begin
  inherited Create(AOwner);
  FTitle := ATitle;
  FSessionClass := ASessionClass;
  FPort := APort;
  FMaxIdleMinutes := AMaxIdleMinutes;
  FMaxConns := AMaxConns;
end;

type TThreadAccess = class(TThread);

function TCustomWebApplication.GetTerminated : Boolean;
begin
  Result := FTerminated or (Assigned(OwnerThread) and TThreadAccess(OwnerThread).Terminated);
end;

function TCustomWebApplication.Reconfig(AReload : Boolean = True) : Boolean;
begin
  Result := False;
end;

procedure TCustomWebApplication.Run(AOwnerThread : TThread = nil);
begin
  FOwnerThread := AOwnerThread;
  DoRun;
end;

procedure TCustomWebApplication.Terminate;
begin
  FTerminated := True;
end;

{ TObjectCatalog }

function TObjectCatalog.FindExtObject(const AJSName: string): TObject;
var
  I: Integer;
begin
  Assert(AJSName <> '');

  Result := FindComponent(AJSName);
  if not Assigned(Result) then
  begin
    for I := 0 to ComponentCount - 1 do
    begin
      if SameText(Components[I].Name, AJSName) then
        Result := Components[I]
      else if Components[I] is TExtObject then
        Result := TExtObject(Components[I]).FindExtObject(AJSName)
      else
        Result := Components[I].FindComponent(AJSName);
      if Assigned(Result) then
        Break;
    end;
  end;
end;

procedure TObjectCatalog.FreeAllExtObjects;
var
  I: Integer;
begin
  for I := ComponentCount - 1 downto 0 do
    Components[I].Free;
  Assert(ComponentCount = 0);
end;

end.

