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

unit Kitto.Ext.Form;

{$I Kitto.Defines.inc}

interface

uses
  Generics.Collections, SysUtils,
  Ext, ExtData, ExtForm, ExtPascalUtils,
  superobject,
  EF.ObserverIntf, EF.Tree,
  Kitto.Metadata.Views, Kitto.Metadata.DataView, Kitto.Store,
  Kitto.Ext.Controller, Kitto.Ext.Base, Kitto.Ext.DataPanel, Kitto.Ext.Editors,
  Kitto.Ext.GridPanel;

type
  ///	<summary>
  ///	  A button that opens a popup detail form.
  ///	</summary>
  TKExtDetailFormButton = class(TKExtButton)
  private
    FViewTable: TKViewTable;
    FDetailHostWindow: TKExtModalWindow;
    FServerStore: TKViewTableStore;
    procedure SetViewTable(const AValue: TKViewTable);
  public
    property ViewTable: TKViewTable read FViewTable write SetViewTable;
    property ServerStore: TKViewTableStore read FServerStore write FServerStore;
  published
    procedure ShowDetailWindow;
  end;

  ///	<summary>
  ///	  The Form controller.
  ///	</summary>
  TKExtFormPanelController = class(TKExtDataPanelController)
  strict private
    FTabPanel: TExtTabPanel;
    FFormPanel: TKExtEditPanel;
    FMainPagePanel: TKExtEditPage;
    FIsReadOnly: Boolean;
    FConfirmButton: TKExtButton;
    FEditButton: TKExtButton;
    FCancelButton: TKExtButton;
    FCloseButton: TKExtButton;
    FDetailToolbar: TKExtToolbar;
    FDetailButtons: TObjectList<TKExtDetailFormButton>;
    FDetailControllers: TObjectList<TObject>;
    FOperation: string;
    FFocusField: TExtFormField;
    FStoreRecord: TKViewTableRecord;
    FCloneValues: TEFNode;
    FCloneButton: TKExtButton;
    FLabelAlign: TExtFormFormPanelLabelAlign;
    procedure CreateEditors;
    procedure RecreateEditors;
    procedure CreateButtons;
    procedure ChangeEditorsState;
    procedure StartOperation;
    procedure FocusFirstField;
    procedure CreateDetailPanels;
    procedure CreateDetailToolbar;
    function GetDetailStyle: string;
    function GetExtraHeight: Integer;
    procedure AssignFieldChangeEvent(const AAssign: Boolean);
    procedure FieldChange(const AField: TKField; const AOldValue, ANewValue: Variant);
    procedure CreateFormPanel;
    function LayoutContainsPageBreaks: Boolean;
    function GetConfirmJSCode(const AMethod: TExtProcedure): string;
    procedure InitFlags;
    function FindLayout: TKLayout;
    function IsViewMode: Boolean;
    procedure RefreshEditorValues;
  strict protected
    procedure DoDisplay; override;
    procedure InitComponents; override;
    property StoreRecord: TKViewTableRecord read FStoreRecord;
    function AddActionButton(const AUniqueId: string; const AView: TKView;
      const AToolbar: TKExtToolbar): TKExtActionButton; override;
  public
    procedure LoadData; override;
    destructor Destroy; override;
  published
    procedure GetRecord;
    procedure SwitchToEditMode;
    procedure ConfirmChanges;
    procedure ConfirmChangesAndClone;
    procedure CancelChanges;
  end;

implementation

uses
  StrUtils, Classes, Variants, Types,
  ExtPascal,
  EF.Localization, EF.Types, EF.Intf, EF.DB, EF.JSON, EF.VariantUtils, EF.StrUtils,
  Kitto.Types, Kitto.AccessControl, Kitto.Rules, Kitto.SQL, Kitto.Config,
  Kitto.Ext.Session, Kitto.Ext.Utils;

{ TKExtFormPanelController }

procedure TKExtFormPanelController.ChangeEditorsState;
var
  LViewMode: Boolean;
  LInsertOperation: Boolean;
begin
  LViewMode := IsViewMode;
  LInsertOperation := FOperation = ADD_OPERATION;
  FEditItems.AllEditors(
    procedure (AEditor: IKExtEditor)
    var
      LFormField: TExtFormField;
      LViewField: TKViewField;
    begin
      LFormField := AEditor.AsExtFormField;
      if Assigned(LFormField) then
      begin
        LViewField := ViewTable.FieldByAliasedName(AEditor.FieldName);
        if Assigned(LViewField) then
          LFormField.ReadOnly := LViewMode or not LViewField.CanEditField(LInsertOperation)
        else
          LFormField.ReadOnly := LViewMode;

          if not LFormField.ReadOnly and (FFocusField = nil) then
            FFocusField := LFormField;
      end;
    end);
end;

destructor TKExtFormPanelController.Destroy;
begin
  FreeAndNil(FCloneValues);
  FreeAndNil(FEditItems);
  FreeAndNil(FDetailButtons);
  FreeAndNil(FDetailControllers);
  inherited;
end;

procedure TKExtFormPanelController.DoDisplay;
begin
  inherited;
  CreateEditors;
  LoadData;
  ChangeEditorsState;
end;

procedure TKExtFormPanelController.CreateDetailToolbar;
var
  I: Integer;
begin
  Assert(ViewTable <> nil);
  Assert(FDetailToolbar = nil);
  Assert(FDetailButtons = nil);
  Assert(Assigned(FStoreRecord));

  if ViewTable.DetailTableCount > 0 then
  begin
    FStoreRecord.EnsureDetailStores;
    Assert(FStoreRecord.DetailStoreCount = ViewTable.DetailTableCount);
    FDetailToolbar := TKExtToolbar.Create(Self);
    FDetailButtons := TObjectList<TKExtDetailFormButton>.Create(False);
    for I := 0 to ViewTable.DetailTableCount - 1 do
    begin
      FDetailButtons.Add(TKExtDetailFormButton.CreateAndAddTo(FDetailToolbar.Items));
      FDetailButtons[I].ServerStore := FStoreRecord.DetailStores[I];
      FDetailButtons[I].ViewTable := ViewTable.DetailTables[I];
    end;
    Tbar := FDetailToolbar;
  end;
end;

procedure TKExtFormPanelController.CreateDetailPanels;
var
  I: Integer;
  LController: IKExtController;
  LControllerType: string;
begin
  Assert(ViewTable <> nil);
  Assert(FDetailControllers = nil);
  Assert(Assigned(FStoreRecord));

  if ViewTable.DetailTableCount > 0 then
  begin
    Assert(FTabPanel <> nil);
    FStoreRecord.EnsureDetailStores;
    Assert(FStoreRecord.DetailStoreCount = ViewTable.DetailTableCount);
    FDetailControllers := TObjectList<TObject>.Create(False);
    for I := 0 to ViewTable.DetailTableCount - 1 do
    begin
      LControllerType := ViewTable.GetString('Controller', 'GridPanel');
      // The node may exist and be '', which does not return the default value.
      if LControllerType = '' then
        LControllerType := 'GridPanel';
      LController := TKExtControllerFactory.Instance.CreateController(FTabPanel,
        View, FTabPanel, ViewTable.FindNode('Controller'), Self, LControllerType);
      LController.Config.SetObject('Sys/ViewTable', ViewTable.DetailTables[I]);
      LController.Config.SetObject('Sys/ServerStore', FStoreRecord.DetailStores[I]);
      LController.Config.SetBoolean('AllowClose', False);
      if SameText(FOperation, VIEW_OPERATION) then
      begin
        //Cascading View mode
        LController.Config.SetBoolean('AllowViewing', True);
        LController.Config.SetBoolean('PreventEditing', True);
        LController.Config.SetBoolean('PreventAdding', True);
        LController.Config.SetBoolean('PreventDeleting', True);
        LController.Config.SetBoolean('AllowDuplicating', False);
      end;
      FDetailControllers.Add(LController.AsObject);
      LController.Display;
      if (LController.AsObject is TKExtDataPanelController) then
        TKExtDataPanelController(LController.AsObject).LoadData;
    end;
  end;
end;

procedure TKExtFormPanelController.RecreateEditors;
begin
  FFormPanel.Free(True);
  CreateFormPanel;
  CreateEditors;
end;

procedure TKExtFormPanelController.CreateEditors;
var
  LLayoutProcessor: TKExtLayoutProcessor;
begin
  Assert(Assigned(FStoreRecord));

  FreeAndNil(FEditItems);
  FEditItems := TKEditItemList.Create;
  LLayoutProcessor := TKExtLayoutProcessor.Create;
  try
    LLayoutProcessor.DataRecord := FStoreRecord;
    LLayoutProcessor.FormPanel := FFormPanel;
    LLayoutProcessor.MainEditPage := FMainPagePanel;
    LLayoutProcessor.TabPanel := FTabPanel;
    LLayoutProcessor.OnNewEditItem :=
      procedure (AEditItem: IKExtEditItem)
      var
        LSubject: IEFSubject;
      begin
        FEditItems.Add(AEditItem.AsObject);
        if Supports(AEditItem.AsObject, IEFSubject, LSubject) then
          LSubject.AttachObserver(Self);
      end;
    LLayoutProcessor.ForceReadOnly := FIsReadOnly;
    if MatchStr(FOperation, [ADD_OPERATION, DUPLICATE_OPERATION]) then
      LLayoutProcessor.Operation := eoInsert
    else
      LLayoutProcessor.Operation := eoUpdate;
    LLayoutProcessor.CreateEditors(FindLayout);
    FFocusField := LLayoutProcessor.FocusField;
  finally
    FreeAndNil(LLayoutProcessor);
  end;
  // Scroll back to top - can't do that until afterrender because body.dom is needed.
  FMainPagePanel.On('afterrender', JSFunction(FMainPagePanel.JSName + '.body.dom.scrollTop = 0;'));
  // Set button handlers (editors are needed by GetConfirmJSCode).
  if Assigned(FConfirmButton) then
    FConfirmButton.Handler := JSFunction(GetConfirmJSCode(ConfirmChanges));
  if Assigned(FEditButton) then
    FEditButton.Handler := JSFunction(GetConfirmJSCode(SwitchToEditMode));
  if Assigned(FCloneButton) then
    FCloneButton.Handler := JSFunction(GetConfirmJSCode(ConfirmChangesAndClone));
end;

function TKExtFormPanelController.GetDetailStyle: string;
begin
  Result := ViewTable.GetString('DetailTables/Controller/Style', 'Tabs');
end;

procedure TKExtFormPanelController.LoadData;
var
  LDetailStyle: string;
  LHostWindow: TExtWindow;
begin
  LDetailStyle := GetDetailStyle;
  if SameText(LDetailStyle, 'Tabs') then
    CreateDetailPanels
  else if SameText(LDetailStyle, 'Popup') then
    CreateDetailToolbar;
  // Resize the window after setting up toolbars and tabs, so that we
  // know the exact extra height needed.
  if Config.GetBoolean('Sys/HostWindow/AutoSize') then
  begin
    LHostWindow := GetHostWindow;
    if Assigned(LHostWindow) then
      LHostWindow.On('afterrender', JSFunction(Format(
        '%s.setOptimalSize(0, %d); %s.center();',
          [LHostWindow.JSName, GetExtraHeight, LHostWindow.JSName])));
  end;
  StartOperation;
end;

procedure TKExtFormPanelController.StartOperation;
var
  LDefaultValues: TEFNode;

  procedure MergeKeyDefaultValues;
  var
    LKeyDefaultValues: TEFNode;
  begin
    LKeyDefaultValues := ViewTable.GetDefaultValues(True);
    try
      LDefaultValues.Merge(LKeyDefaultValues);
    finally
      FreeAndNil(LKeyDefaultValues);
    end;
  end;

begin
  Assert(Assigned(FStoreRecord));

  AssignFieldChangeEvent(True);
  try
    if MatchStr(FOperation, [ADD_OPERATION, DUPLICATE_OPERATION]) then
    begin
      LDefaultValues := nil;
      try
        if Assigned(FCloneValues) then
        begin
          LDefaultValues := TEFNode.Clone(FCloneValues);
          MergeKeyDefaultValues;
        end
        else
          LDefaultValues := ViewTable.GetDefaultValues;
        if SameText(FOperation, DUPLICATE_OPERATION) then
          FStoreRecord.Store.DisableChangeNotifications;
        try
          FStoreRecord.ReadFromNode(LDefaultValues);
        finally
          if SameText(FOperation, DUPLICATE_OPERATION) then
            FStoreRecord.Store.EnableChangeNotifications;
        end;
        ViewTable.Model.BeforeNewRecord(FStoreRecord, Assigned(FCloneValues) and SameText(FOperation, ADD_OPERATION));
        FStoreRecord.ApplyNewRecordRules;
        ViewTable.Model.AfterNewRecord(FStoreRecord);
      finally
        FreeAndNil(LDefaultValues);
      end;
    end;

    RefreshEditorValues;

    FocusFirstField;
  except
    on E: EKValidationError do
    begin
      ExtMessageBox.Alert(_(Session.Config.AppTitle), E.Message);
      CancelChanges;
    end;
  end;
end;

procedure TKExtFormPanelController.RefreshEditorValues;
begin
  // Load data. Combo boxes can only have their raw value set after they're rendered.
  FEditItems.AllEditors(
    procedure (AEditor: IKExtEditor)
    var
      LFormField: TExtFormField;
    begin
      LFormField := AEditor.AsExtFormField;
      if Assigned(LFormField) then
      begin
        LFormField.RemoveAllListeners('afterrender');
        LFormField.On('afterrender', LFormField.JSFunction(
          procedure()
          begin
            AEditor.RefreshValue;
          end));
      end
      else
        AEditor.RefreshValue;
    end);
end;

procedure TKExtFormPanelController.SwitchToEditMode;
var
  LHostWindow: TExtWindow;
begin
  FEditButton.SetVisible(False);
  FConfirmButton.SetVisible(True);
  if Assigned(FCloneButton) then
    FCloneButton.SetVisible(True);
  FCloseButton.SetVisible(False);
  FCancelButton.SetVisible(True);
  FOperation := EDIT_OPERATION;
  InitFlags;
  ChangeEditorsState;
  LHostWindow := GetHostWindow;
  if Assigned(LHostWindow) then
    LHostWindow.Title := Format(_('Edit %s'), [_(ViewTable.DisplayLabel)]);
  StartOperation;
end;

procedure TKExtFormPanelController.FocusFirstField;
begin
  if Assigned (FFocusField) then
    FFocusField.Focus(False, 500);
end;

procedure TKExtFormPanelController.GetRecord;
begin
  Assert(Assigned(FStoreRecord));

  ExtSession.ResponseItems.AddJSON('{success:true,data:' + FStoreRecord.GetAsJSON(False) + '}');
end;

procedure TKExtFormPanelController.ConfirmChanges;
var
  LError: string;
begin
  AssignFieldChangeEvent(False);
  LError := UpdateRecord(FStoreRecord, SO(Session.RequestBody).O['new'], True);
  FreeAndNil(FCloneValues);
  if LError = '' then
  begin
    if Config.GetBoolean('KeepOpenAfterOperation') then
      StartOperation
    else
      CloseHostContainer;
  end;
end;

procedure TKExtFormPanelController.ConfirmChangesAndClone;
begin
  UpdateRecord(FStoreRecord, SO(Session.RequestBody).O['new'], True);
  FCloneValues := TEFNode.Clone(FStoreRecord);
  FStoreRecord := ServerStore.AppendRecord(nil);
  FOperation := ADD_OPERATION;
  // recupera dati record
  StartOperation;
end;

function TKExtFormPanelController.LayoutContainsPageBreaks: Boolean;
var
  LLayout: TKLayout;
begin
  Result := False;
  LLayout := FindLayout;
  if Assigned(LLayout) then
  begin
    Result := Assigned(LLayout.FindChildByPredicate(
      function (const ANode: TEFNode): Boolean
      begin
        Result := SameText(ANode.Name, 'PageBreak');
      end));
  end
end;

procedure TKExtFormPanelController.CreateButtons;
var
  LCloneButtonNode: TEFNode;
  LHostWindow: TExtWindow;
begin
  if not FIsReadOnly then
  begin
    LCloneButtonNode := Config.FindNode('CloneButton');
    if Assigned(LCloneButtonNode) then
    begin
      FCloneButton := TKExtButton.CreateAndAddTo(FFormPanel.Buttons);
      FCloneButton.SetIconAndScale('accept_clone', Config.GetString('ButtonScale', 'medium'));
      FCloneButton.FormBind := True;
      FCloneButton.Text := LCloneButtonNode.GetString('Caption', _('Save & Clone'));
      FCloneButton.Tooltip := LCloneButtonNode.GetString('Tooltip', _('Save changes and create a new clone record'));
      FCloneButton.Hidden := FIsReadOnly or IsViewMode;
    end
    else
      FCloneButton := nil;
  end;
  FConfirmButton := TKExtButton.CreateAndAddTo(FFormPanel.Buttons);
  FConfirmButton.SetIconAndScale('accept', Config.GetString('ButtonScale', 'medium'));
  FConfirmButton.FormBind := True;
  FConfirmButton.Text := Config.GetString('ConfirmButton/Caption', _('Save'));
  FConfirmButton.Tooltip := Config.GetString('ConfirmButton/Tooltip', _('Save changes and finish editing'));
  FConfirmButton.Hidden := FIsReadOnly or IsViewMode;

  if IsViewMode then
  begin
    FEditButton := TKExtButton.CreateAndAddTo(FFormPanel.Buttons);
    FEditButton.SetIconAndScale('edit_record', Config.GetString('ButtonScale', 'medium'));
    FEditButton.FormBind := True;
    FEditButton.Text := Config.GetString('ConfirmButton/Caption', _(EDIT_OPERATION));
    FEditButton.Tooltip := Config.GetString('ConfirmButton/Tooltip', _('Switch to edit mode'));
    FEditButton.Hidden := FIsReadOnly;
  end;

  FCancelButton := TKExtButton.CreateAndAddTo(FFormPanel.Buttons);
  FCancelButton.SetIconAndScale('cancel', Config.GetString('ButtonScale', 'medium'));
  FCancelButton.Text := _('Cancel');
  FCancelButton.Tooltip := _('Cancel changes');
  FCancelButton.Handler := Ajax(CancelChanges);
  FCancelButton.Hidden := FIsReadOnly or IsViewMode;

  FCloseButton := TKExtButton.CreateAndAddTo(FFormPanel.Buttons);
  FCloseButton.SetIconAndScale('close', Config.GetString('ButtonScale', 'medium'));
  FCloseButton.Text := _('Close');
  FCloseButton.Tooltip := _('Close this panel');
  // No need for an ajax call when we just close the client-side panel.
  LHostWindow := GetHostWindow;
  if Assigned(LHostWindow) then
    FCloseButton.Handler := JSFunction(LHostWindow.JSName + '.close();');
  FCloseButton.Hidden := not FIsReadOnly and not IsViewMode;
end;

procedure TKExtFormPanelController.InitComponents;
begin
  inherited;
  FOperation := Config.GetString('Sys/Operation');
  if FOperation = '' then
    FOperation := Config.GetString('Operation');
  InitFlags;
  CreateFormPanel;
  CreateButtons;
end;

procedure TKExtFormPanelController.InitFlags;
var
  LLabelAlignNode: TEFNode;
begin
  if Title = '' then
    Title := _(ViewTable.DisplayLabel);

  FStoreRecord := Config.GetObject('Sys/Record') as TKViewTableRecord;
  Assert((FOperation = ADD_OPERATION) or Assigned(FStoreRecord));
  if FOperation = ADD_OPERATION then
  begin
    Assert(not Assigned(FStoreRecord));
    FStoreRecord := ServerStore.AppendRecord(nil);
  end
  else if FOperation = DUPLICATE_OPERATION then
  begin
    FreeAndNil(FCloneValues);
    FCloneValues := TEFNode.Clone(FStoreRecord);
    FStoreRecord := ServerStore.AppendRecord(nil);
  end;
  AssignFieldChangeEvent(True);

  if MatchStr(FOperation, [ADD_OPERATION, DUPLICATE_OPERATION]) then
    FIsReadOnly := ViewTable.GetBoolean('Controller/PreventAdding')
      or View.GetBoolean('IsReadOnly')
      or ViewTable.IsReadOnly
      or Config.GetBoolean('PreventAdding')
      or not ViewTable.IsAccessGranted(ACM_ADD)
  else //Edit or View Mode
    FIsReadOnly := ViewTable.GetBoolean('Controller/PreventEditing')
      or View.GetBoolean('IsReadOnly')
      or ViewTable.IsReadOnly
      or Config.GetBoolean('PreventEditing')
      or not ViewTable.IsAccessGranted(ACM_MODIFY);

  if SameText(FOperation, ADD_OPERATION) and FIsReadOnly then
    raise EEFError.Create(_('Operation Add not supported on read-only data.'))
  else if SameText(FOperation, EDIT_OPERATION) and FIsReadOnly then
    raise EEFError.Create(_('Operation Edit not supported on read-only data.'))
  else if SameText(FOperation, DUPLICATE_OPERATION) and FIsReadOnly then
    raise EEFError.Create(_('Operation Duplicate not supported on read-only data.'));

  LLabelAlignNode := ViewTable.FindNode('Controller/FormController/LabelAlign');
  if FindLayout <> nil then
    FLabelAlign := laTop
  else if Assigned(LLabelAlignNode) then
    FLabelAlign := OptionAsLabelAlign(LLabelAlignNode.AsString)
  else
    FLabelAlign := laRight; //Default to right
end;

procedure TKExtFormPanelController.CreateFormPanel;
begin
  FFormPanel := TKExtEditPanel.CreateAndAddTo(Items);
  FFormPanel.Region := rgCenter;
  FFormPanel.Border := False;
  FFormPanel.Header := False;
  FFormPanel.Layout := lyFit; // Vital to avoid detail grids with zero height!
  FFormPanel.AutoScroll := False;
  FFormPanel.LabelWidth := 120;
  FFormPanel.MonitorValid := True;
  FFormPanel.Cls := 'x-panel-mc'; // Sets correct theme background color.
  FFormPanel.LabelAlign := FLabelAlign;
  if ((ViewTable.DetailTableCount > 0) and SameText(GetDetailStyle, 'Tabs')) or LayoutContainsPageBreaks then
  begin
    FTabPanel := TExtTabPanel.CreateAndAddTo(FFormPanel.Items);
    FTabPanel.Border := False;
    FTabPanel.AutoScroll := False;
    FTabPanel.BodyStyle := 'background:none'; // Respects parent's background color.
    FTabPanel.DeferredRender := False;
    FTabPanel.EnableTabScroll := True;
    FMainPagePanel := TKExtEditPage.CreateAndAddTo(FTabPanel.Items);
    FMainPagePanel.Title := _(ViewTable.DisplayLabel);
    if Config.GetBoolean('Sys/ShowIcon', True) then
      FMainPagePanel.IconCls := Session.SetViewIconStyle(ViewTable.View);
    FMainPagePanel.EditPanel := FFormPanel;
    FTabPanel.SetActiveTab(0);
    FTabPanel.On('tabchange', FTabPanel.JSFunction(FTabPanel.JSName + '.doLayout();'));
  end
  else
  begin
    FTabPanel := nil;
    FMainPagePanel := TKExtEditPage.CreateAndAddTo(FFormPanel.Items);
    FMainPagePanel.Region := rgCenter;
    FMainPagePanel.EditPanel := FFormPanel;
  end;
  //Session.ResponseItems.ExecuteJSCode(Format('%s.getForm().url = "%s";', [FFormPanel.JSName, MethodURI(ConfirmChanges)]));
end;

function TKExtFormPanelController.GetExtraHeight: Integer;
begin
  Result := 10; // 5px padding * 2.
  if Assigned(FDetailToolbar) then
    Result := Result + 30;
  if Assigned(TopToolbar) then
    Result := Result + 30;
end;

function TKExtFormPanelController.IsViewMode: Boolean;
begin
  Result := FOperation = VIEW_OPERATION;
end;

procedure TKExtFormPanelController.CancelChanges;
var
  LKeepOpen: Boolean;
begin
  LKeepOpen := Config.GetBoolean('KeepOpenAfterOperation');

  if MatchStr(FOperation, [ADD_OPERATION, DUPLICATE_OPERATION]) then
  begin
    ServerStore.RemoveRecord(FStoreRecord);
    FStoreRecord := nil;
  end;
  NotifyObservers('Canceled');
  if LKeepOpen then
  begin
    if FOperation = ADD_OPERATION then
    begin
      FStoreRecord := ServerStore.AppendRecord(nil);
      RecreateEditors;
    end
    else
    begin
      { TODO: implement Dup + KeepOpenAfterOperation }
      Assert(False, 'Dup + KeepOpenAfterOperation not implemented.');
    end;
    StartOperation;
  end
  else
  begin
    AssignFieldChangeEvent(False);
    CloseHostContainer;
  end;
end;

function TKExtFormPanelController.AddActionButton(const AUniqueId: string;
  const AView: TKView; const AToolbar: TKExtToolbar): TKExtActionButton;
begin
  Result := inherited AddActionButton(AUniqueId, AView, AToolbar);
  TKExtDataActionButton(Result).OnGetServerRecord :=
    function: TKViewTableRecord
    begin
      Result := StoreRecord;
    end;
end;

procedure TKExtFormPanelController.AssignFieldChangeEvent(const AAssign: Boolean);
begin
  if Assigned(FStoreRecord) then
    if AAssign then
      FStoreRecord.OnFieldChange := FieldChange
    else
      FStoreRecord.OnFieldChange := nil;
end;

procedure TKExtFormPanelController.FieldChange(const AField: TKField; const AOldValue, ANewValue: Variant);
var
  LField: TKViewTableField;
begin
  Assert(Assigned(AField));
  Assert(AField is TKViewTableField);

  LField := TKViewTableField(AField);
  { TODO :
  Refactor the way derived fields are determined.
  Reference fields should not have derived fields.
  Underlying key fields should.
  Meanwhile, we just ignore changes to reference fields
  that would not work due to having only the caption
  and not the key values here.
  After the refactoring, this test can be removed. }
  if LField.ViewField.IsReference and not LField.IsPhysicalPartOfReference then
    Exit;

  // Refresh editors linked to changed field.
  FEditItems.EditorsByViewField(LField.ViewField,
    procedure (AEditor: IKExtEditor)
    begin
      AEditor.RefreshValue;
    end);

  // Give all non-editors a chance to refresh (such as a FieldSet which might
  // need to refresh its title). This might be a performance bottleneck.
  FEditItems.AllNonEditors(
    procedure (AEditItem: IKExtEditItem)
    begin
      AEditItem.RefreshValue;
    end);
end;

function TKExtFormPanelController.FindLayout: TKLayout;
begin
  Result := FindViewLayout('Form');
end;

function TKExtFormPanelController.GetConfirmJSCode(const AMethod: TExtProcedure): string;
var
  LCode: string;
begin
  LCode :=
    'var json = new Object;' + sLineBreak +
    'json.new = new Object;' + sLineBreak;

  LCode := LCode + GetJSFunctionCode(
    procedure
    begin
      FEditItems.AllEditors(
        procedure (AEditor: IKExtEditor)
        begin
          AEditor.StoreValue('json.new');
        end);
    end,
    False) + sLineBreak;

  LCode := LCode + GetPOSTAjaxCode(AMethod, [], 'json') + sLineBreak;
  Result := LCode;
end;

{ TKExtDetailFormButton }

procedure TKExtDetailFormButton.SetViewTable(const AValue: TKViewTable);
begin
  FViewTable := AValue;
  if Assigned(FViewTable) then
  begin
    Text := _(FViewTable.PluralDisplayLabel);
    Icon := Session.Config.GetImageURL(FViewTable.ImageName);
    Handler := Ajax(ShowDetailWindow, []);
  end;
end;

procedure TKExtDetailFormButton.ShowDetailWindow;
var
  LController: IKExtController;
begin
  Assert(Assigned(FViewTable));

  if Assigned(FDetailHostWindow) then
    FDetailHostWindow.Free(True);
  FDetailHostWindow := TKExtModalWindow.Create(Self);

  FDetailHostWindow.Title := _(ViewTable.PluralDisplayLabel);
  FDetailHostWindow.Closable := True;

  LController := TKExtControllerFactory.Instance.CreateController(
    FDetailHostWindow, FViewTable.View, FDetailHostWindow);
  LController.Config.SetObject('Sys/ServerStore', ServerStore);
  LController.Config.SetObject('Sys/ViewTable', ViewTable);
  LController.Config.SetObject('Sys/HostWindow', FDetailHostWindow);
  LController.Display;
  FDetailHostWindow.Show;
end;

initialization
  TKExtControllerRegistry.Instance.RegisterClass('Form', TKExtFormPanelController);

finalization
  TKExtControllerRegistry.Instance.UnregisterClass('Form');

end.
