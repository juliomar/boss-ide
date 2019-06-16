unit Boss.Modules.PackageProcessor;

interface

uses
  System.IniFiles, System.Classes, System.SysUtils, System.Types;

type
  TBossPackageProcessor = class
  private
    FDataFile: TStringList;

    function GetBplList(ARootPath: string): TStringDynArray;
    function GetBinList(ARootPath: string): TStringDynArray;

    function GetDataCachePath: string;

    procedure LoadTools(AProjectPath: string);
    procedure SetBossPath(AProjectPath: string);

    constructor Create;
  public
    procedure LoadBpls(AProjectPath: string);
    procedure UnloadOlds;

    class Procedure OnActiveProjectChanged(AProject: string);
    class function GetInstance: TBossPackageProcessor;
  end;


const
  PATH = 'PATH';
  BOSS_VAR = 'BOSS_PROJECT';
  BPLS = 'BPLS';
  DELIMITER = ';';

implementation

uses
  System.IOUtils, Providers.Consts, Boss.IDE.Installer, Providers.Message, Vcl.Dialogs, ToolsAPI,
  Boss.IDE.OpenToolApi.Tools, Winapi.ShellAPI, Winapi.Windows, Vcl.Menus, Boss.EventWrapper;

{ TBossPackageProcessor }

var
  _Instance: TBossPackageProcessor;

procedure TBossPackageProcessor.SetBossPath(AProjectPath: string);
begin
  SetEnvironmentVariable(PChar(BOSS_VAR), PChar(AProjectPath +  TPath.DirectorySeparatorChar + C_BPL_FOLDER));
end;

constructor TBossPackageProcessor.Create;
begin
  FDataFile := TStringList.Create();

  if FileExists(GetDataCachePath) then
    FDataFile.LoadFromFile(GetDataCachePath);

  UnloadOlds;
end;

function TBossPackageProcessor.GetBinList(ARootPath: string): TStringDynArray;
begin
  if not DirectoryExists(ARootPath + C_BIN_FOLDER) then
    Exit();

  Result := TDirectory.GetFiles(ARootPath + C_BIN_FOLDER, '*.exe')
end;

function TBossPackageProcessor.GetBplList(ARootPath: string): TStringDynArray;
begin
  if not DirectoryExists(ARootPath + C_BPL_FOLDER) then
    Exit();

  Result := TDirectory.GetFiles(ARootPath + C_BPL_FOLDER, '*.bpl')
end;

function TBossPackageProcessor.GetDataCachePath: string;
begin
  Result := GetEnvironmentVariable('HOMEDRIVE') + GetEnvironmentVariable('HOMEPATH') + TPath.DirectorySeparatorChar +
    C_BOSS_CACHE_FOLDER + TPath.DirectorySeparatorChar + C_DATA_FILE;
end;

class function TBossPackageProcessor.GetInstance: TBossPackageProcessor;
begin
  if not Assigned(_Instance) then
    _Instance := TBossPackageProcessor.Create;
  Result := _Instance;
end;

procedure PackageInfoProc(const Name: string; NameType: TNameType; Flags: Byte; Param: Pointer);
begin

end;

procedure TBossPackageProcessor.LoadBpls(AProjectPath: string);
var
  LBpls: TStringDynArray;
  LBpl: string;
  LFlag: Integer;
  LHnd: NativeUInt;
begin
  SetBossPath(AProjectPath);
  LBpls := GetBplList(AProjectPath);
  for LBpl in LBpls do
  begin
    try
      LHnd := LoadPackage(LBpl);
      GetPackageInfo(LHnd, nil, LFlag, PackageInfoProc);
      UnloadPackage(LHnd);
    except
      TProviderMessage.GetInstance.WriteLn('Failed to get info of ' + LBpl);
      Continue;
    end;

    if not(LFlag and pfRunOnly = pfRunOnly) and TBossIDEInstaller.InstallBpl(LBpl) then
    begin
      FDataFile.Values[BPLS] := FDataFile.Values[BPLS] + DELIMITER + LBpl;
      TProviderMessage.GetInstance.WriteLn('Instaled: ' + LBpl);
    end;
  end;
  FDataFile.SaveToFile(GetDataCachePath);
end;

procedure TBossPackageProcessor.LoadTools(AProjectPath: string);
var
  LBins: TStringDynArray;
  LBin, LBinName: string;
  LMenu: TMenuItem;
  LMenuItem: TMenuItem;
begin
  LMenu := NativeServices.MainMenu.Items.Find('Tools');
  LBins := GetBinList(AProjectPath);

  NativeServices.MenuBeginUpdate;
  try
    for LBin in LBins do
    begin
      LBinName := ExtractFileName(LBin);
      LMenuItem := TMenuItem.Create(NativeServices.MainMenu);
      LMenuItem.Caption := Providers.Consts.C_BOSS_TAG + ' ' + LBinName;
      LMenuItem.OnClick := GetOpenEvent(LBin);
      LMenuItem.Name := 'boss_' + LBinName.Replace('.', '_');
      LMenuItem.Hint := LBin;
      LMenu.Add(LMenuItem);
    end;
  finally
    NativeServices.MenuEndUpdate;
  end;
  FDataFile.SaveToFile(GetDataCachePath);
end;

class procedure TBossPackageProcessor.OnActiveProjectChanged(AProject: string);
begin
  TProviderMessage.GetInstance.Clear;
  TProviderMessage.GetInstance.WriteLn('Loading packages from project ' + AProject);

  GetInstance.UnloadOlds;
  GetInstance.LoadBpls(ExtractFilePath(AProject) + C_MODULES_FOLDER);
  GetInstance.LoadTools(ExtractFilePath(AProject) + C_MODULES_FOLDER);
end;

procedure TBossPackageProcessor.UnloadOlds;
var
  LBpl: string;
  LMenu: TMenuItem;
  LMenuItem: TMenuItem;
  LIndex: Integer;
begin
  for LBpl in FDataFile.Values[BPLS].Split([DELIMITER]) do
  begin
    TBossIDEInstaller.RemoveBpl(LBpl);
    TProviderMessage.GetInstance.WriteLn('Removed: ' + LBpl);
  end;

  LMenu := NativeServices.MainMenu.Items.Find('Tools');

  NativeServices.MenuBeginUpdate;
  try
    for LIndex := 0 to LMenu.Count - 1 do
    begin
      LMenuItem := LMenu.Items[LIndex];
      if LMenuItem.Caption.StartsWith(C_BOSS_TAG) then
      begin
        LMenu.Remove(LMenuItem);
        LMenuItem.Free;
      end;
    end;
  finally
    NativeServices.MenuEndUpdate;
  end;

  FDataFile.Values[BPLS] := EmptyStr;
  FDataFile.SaveToFile(GetDataCachePath);
end;

initialization

finalization

_Instance.Free;

end.
