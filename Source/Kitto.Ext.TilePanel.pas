{-------------------------------------------------------------------------------
   Copyright 2013 Ethea S.r.l.

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

unit Kitto.Ext.TilePanel;

{$I Kitto.Defines.inc}

interface

uses
  Types,
  EF.Tree,
  Kitto.Metadata.Views,
  Kitto.Ext.Base, Kitto.Ext.Controller, Kitto.Ext.Session, Kitto.Ext.TabPanel;

const
  DEFAULT_TILE_HEIGHT = '50';
  DEFAULT_TILE_WIDTH = '100';

type
  // A tile page to be added to a container.
  TKExtTilePanel = class(TKExtPanelBase)
  strict private
    FView: TKView;
    FConfig: TEFTree;
    FTileBoxHtml: string;
    FColors: TStringDynArray;
    FColorIndex: Integer;
    FRootNode: TKTreeViewNode;
    procedure AddBreak;
    procedure AddTitle(const ADisplayLabel: string);
    function GetTileHeight: string;
    function GetTileWidth: string;
    function GetShowImage: Boolean;
    function GetImagePosition: string;
    procedure BuildTileBoxHtml(const ARootNode: TKTreeViewNode = nil);
    procedure AddTile(const ANode: TKTreeViewNode; const ADisplayLabel: string;
      AIsBack: Boolean = False);
    procedure AddTiles(const ANode: TKTreeViewNode; const ADisplayLabel: string);
    procedure AddBackTile;
    function GetNextTileColor: string;
    function GetColors(const AColorSetName: string): TStringDynArray;
  public
    const DEFAULT_COLOR_SET = 'Metro';
    property Config: TEFTree read FConfig write FConfig;
    property View: TKView read FView write FView;
    procedure DoDisplay;
  published
    procedure DisplayView;
    procedure DisplayPage;
  end;

  // Hosted by the tile panel controller; manages the additional tile page.
  TKExtTileTabPanel = class(TKExtTabPanel)
  private
    FTilePanel: TKExtTilePanel;
    procedure AddTileSubPanel;
  strict protected
    function TabsVisible: Boolean; override;
  public
    procedure SetAsViewHost; override;
    procedure DisplaySubViewsAndControllers; override;
  end;

  // A tab panel controller with a tile menu on the first page.
  TKExtTilePanelController = class(TKExtTabPanelController)
  strict protected
    function GetTabPanelClass: TKExtTabPanelClass; override;
    function GetDefaultTabIconsVisible: Boolean; override;
  end;

implementation

uses
  SysUtils, StrUtils,
  Ext,
  EF.StrUtils, EF.Macros, EF.Localization,
  Kitto.Config, Kitto.Utils, Kitto.Ext.Utils;

{ TKExtTilePanelController }

function TKExtTilePanelController.GetDefaultTabIconsVisible: Boolean;
begin
  Result := False;
end;

function TKExtTilePanelController.GetTabPanelClass: TKExtTabPanelClass;
begin
  Result := TKExtTileTabPanel;
end;

{ TKExtTileTabPanel }

procedure TKExtTileTabPanel.DisplaySubViewsAndControllers;
begin
  AddTileSubPanel;
  inherited;
  if Items.Count > 0 then
    SetActiveTab(Config.GetInteger('ActiveTabNumber', 0));
end;

procedure TKExtTileTabPanel.SetAsViewHost;
begin
  // Don't act as view host on mobile - we want modal views there.
  if not Session.IsMobileBrowser then
    inherited;
end;

function TKExtTileTabPanel.TabsVisible: Boolean;
begin
  Result := Config.GetBoolean('TabsVisible', not Session.IsMobileBrowser);
end;

procedure TKExtTileTabPanel.AddTileSubPanel;
begin
  inherited;
  FTilePanel := TKExtTilePanel.CreateAndAddTo(Items);
  FTilePanel.View := View;
  FTilePanel.Config := Config;
  FTilePanel.DoDisplay;
end;

{ TKExtTilePanel }

procedure TKExtTilePanel.DoDisplay;
var
  LTitle: string;
begin
  LTitle := _(Config.GetExpandedString('Title', View.DisplayLabel));
  if LTitle <> '' then
    Title := LTitle
  else
    Title := _('Home');
  AutoScroll := True;

  FColors := GetColors(Config.GetExpandedString('ColorSet', DEFAULT_COLOR_SET));
  BuildTileBoxHtml;
end;

procedure TKExtTilePanel.DisplayPage;
begin
  BuildTileBoxHtml(TKTreeViewNode(Session.QueryAsInteger['PageId']));
end;

procedure TKExtTilePanel.DisplayView;
begin
  Session.DisplayView(TKView(Session.QueryAsInteger['View']));
end;

function TKExtTilePanel.GetColors(const AColorSetName: string): TStringDynArray;
begin
  if SameText(AColorSetName, 'Metro') then
  begin
    SetLength(Result, 10);
    Result[0] := '#00904A';
    Result[1] := '#FF0097';
    Result[2] := '#00ABA9';
    Result[3] := '#8CBF26';
    Result[4] := '#A05000';
    Result[5] := '#E671B8';
    Result[6] := '#F09609';
    Result[7] := '#1BA1E2';
    Result[8] := '#E51400';
    Result[9] := '#339933';
  end
  else if SameText(AColorSetName, 'Blue') then
  begin
    SetLength(Result, 5);
    Result[0] := '#1240AB';
    Result[1] := '#365BB0';
    Result[2] := '#5777C0';
    Result[3] := '#0D3184';
    Result[4] := '#082568';
  end
  else if SameText(AColorSetName, 'Red') then
  begin
    SetLength(Result, 5);
    Result[0] := '#FF0000';
    Result[1] := '#FF3939';
    Result[2] := '#FF6363';
    Result[3] := '#C50000';
    Result[4] := '#9B0000';
  end
  else if SameText(AColorSetName, 'Gold') then
  begin
    SetLength(Result, 5);
    Result[0] := '#FFD300';
    Result[1] := '#FFDD39';
    Result[2] := '#FFE463';
    Result[3] := '#C5A300';
    Result[4] := '#9B8000';
  end
  else if SameText(AColorSetName, 'Violet') then
  begin
    SetLength(Result, 5);
    Result[0] := '#3914AF';
    Result[1] := '#5538B4';
    Result[2] := '#735AC3';
    Result[3] := '#2B0E88';
    Result[4] := '#20096A';
  end
  else if SameText(AColorSetName, 'Green') then
  begin
    SetLength(Result, 5);
    Result[0] := '#97C93C';
    Result[1] := '#93DB70';
    Result[2] := '#00CD00';
    Result[3] := '#008000';
    Result[4] := '#003300';
  end
  else
  begin
    SetLength(Result, 1);
    Result[0] := '#000000';
  end;
end;

function TKExtTilePanel.GetImagePosition: string;
begin
  Result := Config.GetString('ShowImage/Position', '');
end;

function TKExtTilePanel.GetShowImage: Boolean;
begin
  Result := Config.GetBoolean('ShowImage', False);
end;

function TKExtTilePanel.GetNextTileColor: string;
begin
  Result := FColors[FColorIndex];
  Inc(FColorIndex);
  if FColorIndex > High(FColors) then
    FColorIndex := Low(FColors);
end;

function TKExtTilePanel.GetTileHeight: string;
var
  LChar: Char;
begin
  Result := Config.GetString('TileHeight', DEFAULT_TILE_HEIGHT);
  LChar := Result[length(Result)];
  if CharInSet(LChar, ['0'..'9']) then
    Result := Result+'px';
end;

function TKExtTilePanel.GetTileWidth: string;
var
  LChar: Char;
begin
  Result := Config.GetString('TileWidth', DEFAULT_TILE_WIDTH);
  LChar := Result[length(Result)];
  if CharInSet(LChar, ['0'..'9']) then
    Result := Result+'px';
end;

procedure TKExtTilePanel.AddTiles(const ANode: TKTreeViewNode; const ADisplayLabel: string);
var
  LOriginalNode: TKTreeViewNode;

  function IsNodeIncluded(const ACurrentNode: TEFNode): Boolean;
  begin
    Result := (FRootNode = nil) or FRootNode.HasChild(ACurrentNode, True);
  end;

  procedure ProcessChildren(const AParentNode: TKTreeViewNode);
  var
    LDisplayLabelNode: TEFNode;
    LDisplayLabel: string;
    I: Integer;
    LSubNode: TKTreeViewNode;
    LOriginalSubNode: TKTreeViewNode;
    LAddedTileCount: Integer;
  begin
    LAddedTileCount := 0;
    for I := 0 to AParentNode.TreeViewNodeCount - 1 do
    begin
      LSubNode := AParentNode.TreeViewNodes[I];
      LOriginalSubNode := TKTreeViewNode(LSubNode.GetObject('Sys/SourceNode'));
      if IsNodeIncluded(LOriginalSubNode) then
      begin
        LDisplayLabelNode := LOriginalSubNode.FindNode('DisplayLabel');
        if Assigned(LDisplayLabelNode) then
          LDisplayLabel := _(LDisplayLabelNode.AsString)
        else
          LDisplayLabel := GetDisplayLabelFromNode(LOriginalSubNode, Session.Config.Views);
        // Render folders as rows not tiles in second level.
        if not (LOriginalSubNode is TKTreeViewFolder) or not Assigned(FRootNode) then
        begin
          AddTile(LOriginalSubNode, LDisplayLabel);
          Inc(LAddedTileCount);
        end;
      end;
      // Only when not rendering the first level, look ahead for children.
      if (LSubNode is TKTreeViewFolder) and Assigned(FRootNode) then
        ProcessChildren(LSubNode);
    end;
    if LAddedTileCount > 0 then
      AddBreak;
  end;

begin
  LOriginalNode := TKTreeViewNode(ANode.GetObject('Sys/SourceNode'));
  FTileBoxHtml := FTileBoxHtml + '<div class="k-tile-row">';
  if ANode is TKTreeViewFolder then
  begin
    // Render folders as rows not tiles in second level.
    if IsNodeIncluded(LOriginalNode) and not Assigned(FRootNode) then
      AddTitle(ADisplayLabel)
    else if SameText(ANode.Name, 'Back') then
      AddBackTile;
    ProcessChildren(ANode);
  end
  else if IsNodeIncluded(LOriginalNode) then
    AddTile(LOriginalNode, ADisplayLabel);
  FTileBoxHtml := FTileBoxHtml + '</div>';
end;

procedure TKExtTilePanel.AddBackTile;
begin
  AddTile(FRootNode, FRootNode.GetString('Back/DisplayLabel',_('Back')), True);
end;

procedure TKExtTilePanel.AddBreak;
begin
  FTileBoxHtml := FTileBoxHtml + '<br style="clear:left;" />';
end;

procedure TKExtTilePanel.AddTitle(const ADisplayLabel: string);
begin
  if ADisplayLabel <> '' then
    FTileBoxHtml := FTileBoxHtml + Format(
      '<div class="k-tile-title-row">%s</div>',
      [HTMLEncode(ADisplayLabel)]);
end;

procedure TKExtTilePanel.AddTile(const ANode: TKTreeViewNode; const ADisplayLabel: string;
  AIsBack: Boolean = False);
var
  LClickCode: string;
  LCustomStyle: string;
  LTileBoxHTML: string;
  LImageName, LImageURL: string;
  LView: TKView;
  LShowImage: boolean;
  LPageId: Integer;
  LBackGroundColor: string;

  function GetCSS: string;
  var
    LCSS: string;
  begin
    LCSS := ANode.GetString('CSS');
    if LCSS <> '' then
      Result := ' ' + LCSS
    else
      Result := '';
  end;

  function GetDisplayLabel: string;
  begin
    if not ANode.GetBoolean('HideLabel') then
      Result := HTMLEncode(ADisplayLabel)
    else
      Result := '';
  end;

  procedure AddAttributeToStyle(var AStyle: string; const AStileAttributeName, AFormatStr: string;
    const ADefault: string = '');
  var
    LNode: TEFNode;
    LNodeStr: string;
  begin
    LNode := ANode.FindNode(AStileAttributeName);
    if Assigned(LNode) then
      LNodeStr := LNode.AsString
    else if ADefault <> '' then
      LNodeStr := ADefault
    else
      Exit;
    AStyle := Trim(AStyle + ' ' + Format(AFormatStr, [LNodeStr]));
  end;

begin
  if ANode is TKTreeViewFolder then
  begin
    LView := nil;
    if AIsBack then
      LPageId := 0
    else
      LPageId := Integer(ANode);

    LClickCode := JSMethod(Ajax(DisplayPage, ['PageId', LPageId]));
  end
  else
  begin
    LView := Session.Config.Views.ViewByNode(ANode);
    LClickCode := JSMethod(Ajax(DisplayView, ['View', Integer(LView)]));
  end;

  if AIsBack then
  begin
    LImageName := ANode.GetString('Back/ImageName');
    if (LImageName = '') and GetShowImage then
      LImageName := 'back';
    LBackGroundColor := ANode.GetString('Back/BackgroundColor', GetNextTileColor);
  end
  else
  begin
    LImageName := ANode.GetString('ImageName');
    LBackGroundColor := GetNextTileColor;
  end;

  //Build background css style
  LCustomStyle := 'background-repeat: no-repeat;';
  AddAttributeToStyle(LCustomStyle, 'BackgroundColor', 'background-color: %s;', LBackGroundColor);
  AddAttributeToStyle(LCustomStyle, 'Width', 'width:%s;', GetTileWidth);
  AddAttributeToStyle(LCustomStyle, 'Height', 'height:%s;', GetTileHeight);

  LShowImage := GetShowImage or (LImageName <> '');
  if LShowImage then
  begin
    if (LImageName = '') and Assigned(LView) then
    begin
      LImageName := CallViewControllerStringMethod(LView, 'GetDefaultImageName', LView.ImageName);
    end;
    if LImageName <> '' then
    begin
      AddAttributeToStyle(LCustomStyle, 'ImagePosition', 'background-position: %s;', GetImagePosition);
      LImageURL := Session.Config.FindImageURL(SmartConcat(LImageName, '_', 'large'));
      if LImageURL = '' then
        LImageURL := Session.Config.FindImageURL(LImageName);
      if LImageURL <> '' then
        LCustomStyle := LCustomStyle + Format('background-image: url(&quot;%s&quot);', [LImageURL]);
    end;
  end;
  AddAttributeToStyle(LCustomStyle, 'Style', '%s;');

  if GetCSS <> '' then
  begin
    LTileBoxHTML := Format(
      '<a href="#" onclick="%s"><div class="k-tile%s" style="%s">' +
      '<div class="k-tile-inner">%s</div></div></a>',
      [HTMLEncode(LClickCode), GetCSS, LCustomStyle, GetDisplayLabel]);
  end
  else
  begin
    LTileBoxHTML := Format(
      '<a href="#" onclick="%s"><div class="k-tile" style="%s">' +
      '<div class="k-tile-inner">%s</div></div></a>',
      [HTMLEncode(LClickCode), LCustomStyle, GetDisplayLabel]);
  end;

  FTileBoxHtml := FTileBoxHtml + LTileBoxHTML;
end;

procedure TKExtTilePanel.BuildTileBoxHtml(const ARootNode: TKTreeViewNode);
var
  LTreeViewRenderer: TKExtTreeViewRenderer;
  LNode: TEFNode;
  LTreeView: TKTreeView;
  LFileName: string;
begin
  FColorIndex :=  0;
  FTileBoxHtml := '<div class="k-tile-box">';
  FRootNode := ARootNode;
  if Assigned(FRootNode) then
  begin
    AddBackTile;
    if FRootNode.GetBoolean('Back/AddBreak',True) then
      AddBreak;
  end;

  LTreeViewRenderer := TKExtTreeViewRenderer.Create;
  try
    LTreeViewRenderer.Session := Session;
    LNode := Config.GetNode('TreeView');
    LTreeView := Session.Config.Views.ViewByNode(LNode) as TKTreeView;
    LTreeViewRenderer.Render(LTreeView,
      procedure (ANode: TKTreeViewNode; ADisplayLabel: string)
      begin
        AddTiles(ANode, ADisplayLabel);
      end,
      Self, DisplayView);
    FTileBoxHtml := FTileBoxHtml + '</div></div>';

    LFileName := ChangeFileExt(ExtractFileName(LTreeView.PersistentFileName), '.html');
    LoadHtml(LFileName,
      function (AHtml: string): string
      begin
        if AHtml <> '' then
          Result := ReplaceText(AHtml, '{content}', FTileBoxHtml)
        else
          Result := FTileBoxHtml;
      end);
  finally
    FreeAndNil(LTreeViewRenderer);
  end;
end;

initialization
  TKExtControllerRegistry.Instance.RegisterClass('TilePanel', TKExtTilePanelController);

finalization
  TKExtControllerRegistry.Instance.UnregisterClass('TilePanel');

end.
