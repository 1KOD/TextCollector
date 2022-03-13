unit TextCollectorU;


interface

uses
  Dialogs, System.Classes, SysUtils, Generics.Collections, System.JSON, IdZLib,
  dateutils, Winapi.Windows, System.RegularExpressions, System.SyncObjs, IdZLibHeaders,
  System.IOUtils;


type
  TTextCollector= class;

  TSecParamsItem = record
    GroupName: String;
    Key: String;
    Value: String;
  end;
  TSecParams = TList<TSecParamsItem>;


  TDynamicData = Class
  public
    Match : TMatch;
    Data: String;
    ReplaceData: String;
  end;
  TDynamicDatas = TList<TDynamicData>;


  TExecutePickerEvent = procedure(ATextPicker: TTextCollector; ATextData: TStringList) of object;

  TDynamicDataReplaceEvent =  procedure(ATextPicker: TTextCollector; const Matchs : TMatchCollection; const ADataText: TStringList;
    ADynamicDatas: TDynamicDatas) of object;


  TTextCollector = class
  private
    FReplaceCacheFilePath: String;
    FMemoryCache: Boolean;
    FEventExecutePicker: TExecutePickerEvent;
    FDynamicDataReplace: TDynamicDataReplaceEvent;
    function GetRexEx(const ARegEx, AValue: String; const AOptions: TRegExOptions): TMatch;
    function GetRexExs(const ARegEx, AValue: String; const AOptions: TRegExOptions): TMatchCollection;
    function CreateParams(const AGroupName, AKey, AValue: String): TSecParamsItem;
    function GetPart(AData: String; const AFind: String): String;
    function ExistsParamsItem(const AParamsColl: TSecParams; const AGroupName, AKey: String): Boolean;
    function FindParamsItem(const AParamsColl: TSecParams; const AGroupName, AKey: String): TSecParamsItem;
    procedure DeleteStrPart(AData: TStringList; const AStartIndex, ALength: Integer; const AInsertData: String);
    procedure SetReplaceCacheFilePath(const Value: String);
    procedure BaseExecutePicker(ATextData: TStringList);
    function CreateDynamicData(const AMatch: TMatch;  const AData: String): TDynamicData;
    function StringLisCompressiontStream(ATextData: TStringList): TMemoryStream;
    procedure DynamicDataReplace(out ATextData: TStringList);
  public
    Data: TObject;
    constructor Create(const AMemoryCache: Boolean; const AReplaceCacheFilePath: TFileName);
    destructor Destroy; override;

    procedure ExecutePicker(ATextData: TStringList);
    procedure ExecutePickerFile(const AFileName: TFileName; Out ATextData: TStringList; const AStaticDataText: Boolean);
    function ExecutePickerStream(const AFileName: TFileName; const AStaticDataText, ACompression: Boolean): TMemoryStream;

    procedure ClearCacheFiles(const ASearchPattern: string; const ASearchOption: TSearchOption=TSearchOption.soTopDirectoryOnly);
    class function CompressStream(const AFileName: String): TMemoryStream; static;
  published
    property OnAfterExecutePicker: TExecutePickerEvent read FEventExecutePicker write FEventExecutePicker;
    property OnDynamicDataReplace: TDynamicDataReplaceEvent read FDynamicDataReplace write FDynamicDataReplace;
    property ReplaceCacheFilePath: String read FReplaceCacheFilePath write SetReplaceCacheFilePath;
    property MemoryCache: Boolean read FMemoryCache write FMemoryCache default True;
  end;



var
  //Default Laravel Blade Syntax
  rexExtends    : String = '@extends\((.*[.].*)\)';
  rexSection    : String = '@section\((.*[:].*)\)';
  rexSecionStop : String = '(@section\([\s\S][^:]+?\))([\s\S]*?)(@stop)';
  rexSecionShow : String = '(@section\([\s\S][^:]+?\))([\s\S]*?)(@show)';
  reYield       : String = '@yield\((..*)\)';
  rexInclude    : String = '@include\((.*[.].*)\)';
  rexDynamic    : String = '({{)(.*?)(}})';


  //Layouts Cache
  GlobalLayouts_CS : TCriticalSection;
  GlobalLayouts    : TDictionary<String, String>;

  //Global File Cache
  GlobalFileCaches_CS  : TCriticalSection;
  GlobalFileCaches     : TDictionary<String, String>;

  //Layouts
  procedure GLB_Layouts_Load(const AFolderPath: TFileName; const ASearchPattern: string;
    const ASearchOption: TSearchOption=TSearchOption.soTopDirectoryOnly);
  function  GLB_GetLayoutData(const ALayoutName: String): String;
  procedure GLB_Layouts_Clear;


  //Cache Files
  procedure GLB_FileCacheData_Clear(const AFolderPath: TFileName; const ASearchPattern: string;
    const ASearchOption: TSearchOption=TSearchOption.soTopDirectoryOnly);
  procedure GLB_FileCacheData_Add(const AFileName: TFileName; const AData: String);
  function GLB_FileCache_Exists(const AFileName: String): Boolean;
  procedure GLB_FileCacheData_Assigned(const AFileName: String; out ATextData: TStringList);


implementation



{$REGION 'GlobalFileCaches'}
procedure GLB_FileCacheData_Assigned(const AFileName: String; out ATextData: TStringList);
begin
  GlobalFileCaches_CS.Enter;
  try
    if GlobalFileCaches.ContainsKey(AFileName) then
      ATextData.Text:= GlobalFileCaches.Items[AFileName];
  finally
    GlobalFileCaches_CS.Leave;
  end;
end;

function GLB_FileCache_Exists(const AFileName: String): Boolean;
begin
  GlobalFileCaches_CS.Enter;
  try
    result:= GlobalFileCaches.ContainsKey(AFileName);
  finally
    GlobalFileCaches_CS.Leave;
  end;
end;

procedure GLB_FileCacheData_Clear(const AFolderPath: TFileName; const ASearchPattern: string;
  const ASearchOption: TSearchOption=TSearchOption.soTopDirectoryOnly);
begin
  GlobalFileCaches_CS.Enter;
  try
    GlobalFileCaches.Clear;

    for var Item in System.IOUtils.TDirectory.GetFiles(AFolderPath,ASearchPattern,ASearchOption) do
     DeleteFile(Pchar(Item));

  finally
    GlobalFileCaches_CS.Leave;
  end;
end;

procedure GLB_FileCacheData_Add(const AFileName: TFileName; const AData: String);
begin
  GlobalFileCaches_CS.Enter;
  try
    GlobalFileCaches.Add(AFileName,AData);
  finally
    GlobalFileCaches_CS.Leave;
  end;
end;
{$ENDREGION}


{$REGION 'GlobalLayouts'}
function GLB_GetLayoutData(const ALayoutName: String): String;
begin
  GlobalLayouts_CS.Enter;
  try
    if GlobalLayouts.ContainsKey(ALayoutName) then
      result:= GlobalLayouts.Items[ALayoutName];
  finally
    GlobalLayouts_CS.Leave;
  end;
end;

procedure GLB_Layouts_Clear;
begin
  GlobalLayouts_CS.Enter;
  try
    GlobalLayouts.Clear;
  finally
    GlobalLayouts_CS.Leave;
  end;
end;


procedure GLB_Layouts_Load(const AFolderPath: TFileName; const ASearchPattern: string;
  const ASearchOption: TSearchOption=TSearchOption.soTopDirectoryOnly);
var
  Ind: Integer;
  Item: String;
  SList, FileList: TStringList;
  Encoding: TUTF8Encoding;
begin
  GlobalLayouts_CS.Enter;

  try
    FileList:= TStringList.Create;
    SList:= TStringList.Create;
    Encoding:= TUTF8Encoding.Create;

    try
      for Item in System.IOUtils.TDirectory.GetFiles(AFolderPath,ASearchPattern,ASearchOption) do
      begin
        SList.LoadFromFile(Item,Encoding);
        GlobalLayouts.Add(ExtractFileName(Item),SList.Text);
      end;
    finally
      Encoding.Free;
      SList.Free;
      FileList.Free;
    end;

  finally
    GlobalLayouts_CS.Leave;
  end;
end;
{$ENDREGION}


{$REGION 'TTextPicker'}
procedure TTextCollector.ClearCacheFiles(const ASearchPattern: string; const ASearchOption: TSearchOption=TSearchOption.soTopDirectoryOnly);
var
  Item: String;
begin
  for Item in System.IOUtils.TDirectory.GetFiles(FReplaceCacheFilePath,ASearchPattern,ASearchOption) do
  begin
    if FileExists(Item) then
      DeleteFile(Pchar(Item));
  end;
end;

class function TTextCollector.CompressStream(const AFileName: String): TMemoryStream;
var
  AFileStream: TFileStream;
begin
  AFileStream:= TFileStream.Create(AFileName,fmOpenRead);
  try
    Result:= TMemoryStream.Create;
    IndyCompressStream(AFileStream,Result);
  finally
    AFileStream.Free;
  end;
end;

function TTextCollector.GetRexEx(const ARegEx, AValue: String; const AOptions: TRegExOptions): TMatch;
var
  RegEx: TRegEx;
  Match : TMatch;
begin
  RegEx.Create(ARegEx,AOptions);
  result := RegEx.Match(AValue);
end;


function TTextCollector.GetRexExs(const ARegEx, AValue: String; const AOptions: TRegExOptions): TMatchCollection;
var
  RegEx: TRegEx;
  Match : TMatch;
begin
  RegEx.Create(ARegEx,AOptions);
  result := RegEx.Matches(AValue);
end;


procedure TTextCollector.SetReplaceCacheFilePath(const Value: String);
begin
  FReplaceCacheFilePath := Value;

  if Not DirectoryExists(FReplaceCacheFilePath) Then
    ForceDirectories(FReplaceCacheFilePath)
end;

function TTextCollector.ExistsParamsItem(const AParamsColl: TSecParams; const AGroupName, AKey: String): Boolean;
var
  Ind: Integer;
begin
  Result:= False;

  for Ind := 0 to AParamsColl.Count-1 do
  begin
    if (UpperCase(AParamsColl[Ind].GroupName)=UpperCase(AGroupName)) And
       (UpperCase(AParamsColl[Ind].Key)=UpperCase(AKey))  then
    begin
      Result:= True;
      Exit;
    end;

  end;
end;


function TTextCollector.CreateParams(const AGroupName, AKey,AValue: String): TSecParamsItem;
begin
  Result.GroupName := AGroupName;
  Result.Key:= Trim(AKey);
  Result.Value:= AValue;
end;


function TTextCollector.GetPart(AData: String; const AFind: String): String;
var
  Index: Integer;
begin
  Index:= Pos(AFind,AData);

  if (Index>0) then
  begin
    AData:= Copy(AData,Index+1);
    Index:= Pos(AFind,AData);

    if Index>0 then
      result:= Trim(Copy(AData,0,Index-1));
  end;
end;


function TTextCollector.FindParamsItem(const AParamsColl: TSecParams; const AGroupName, AKey: String): TSecParamsItem;
var
  Ind: Integer;
begin
  for Ind := 0 to AParamsColl.Count-1 do
  begin
    if (UpperCase(AParamsColl[Ind].GroupName)=UpperCase(AGroupName)) And
       (UpperCase(AParamsColl[Ind].Key)=UpperCase(AKey))  then
    begin
      Result:= AParamsColl[Ind];
      Exit;
    end;

  end;
end;

procedure TTextCollector.DeleteStrPart(AData: TStringList; const AStartIndex, ALength: Integer; const AInsertData: String);
begin
  AData.Text:= Copy(AData.Text,1,AStartIndex-1) +AInsertData+ Copy(AData.Text,AStartIndex+ALength);
end;

constructor TTextCollector.Create(const AMemoryCache: Boolean; const AReplaceCacheFilePath: TFileName);
begin
  inherited Create;
  FMemoryCache:= AMemoryCache;
  FReplaceCacheFilePath:= IncludeTrailingPathDelimiter(AReplaceCacheFilePath);
end;


destructor TTextCollector.Destroy;
begin
  inherited;
end;

procedure TTextCollector.BaseExecutePicker(ATextData: TStringList);
var
  Match : TMatch;
  Matchs: TMatchCollection;
  ResultList: TStringList;
  JData: TJSONObject;
  ExtendsSuccess: Boolean;
  Params: TSecParams;
begin
  ResultList:= TStringList.Create;
  Params:= TList<TSecParamsItem>.Create;

  try
    {$REGION '@extends Ayarlanýyor'}
    ExtendsSuccess:= False;
    Matchs := GetRexExs(rexExtends,ATextData.Text,[roIgnoreCase]);

    ExtendsSuccess:= Matchs.Count>0;

    for var I := 0 to Matchs.Count-1 do
    begin
      Match:= Matchs.Item[I];
      ResultList.Text:= ResultList.Text + sLineBreak+ GLB_GetLayoutData(Match.Groups.Item[1].Value);
    end;

    if not ExtendsSuccess then
      ResultList.Text:=  ATextData.Text;
    {$ENDREGION}


    {$REGION '@sectionlar Alýnýyor'}
    if ExtendsSuccess then
    begin
      Matchs := GetRexExs(rexSecionStop,ATextData.Text,[roIgnoreCase]);

      for var I := 0 to Matchs.Count-1 do
      begin
        Match:= Matchs.Item[I];
        Params.Add(CreateParams('SECTION',GetPart(Match.Groups.Item[1].Value,''''),Match.Groups.Item[2].Value));
      end;
    end;
    {$ENDREGION}


    {$REGION '@section Tek Veri gönderme ayarlanýyor'}
    if ExtendsSuccess then
    begin
      Match := GetRexEx(rexSection,ATextData.Text,[roIgnoreCase]);

      if Match.Success then
      begin
        JData := TJSONObject(TJSonObject.ParseJSONValue(Match.Groups.Item[1].Value));

        try
          try
            for var I:=0 to JData.Count-1 do
            begin
              Params.Add(CreateParams('JSON_DATA',JData.Pairs[I].JsonString.Value,JData.Pairs[I].JsonValue.Value));
            end;
          finally
            JData.Free;
          end;
        except
          raise Exception.Create('@section json syntax error sample: @section({"title": "TTextCollector"})');
        end;

      end;
    end;
    {$ENDREGION}


    {$REGION '@yield lar Ayarlanýyor'}
    if ExtendsSuccess then
    begin
      for var Item in Params do
      begin
        ResultList.Text:= StringReplace(ResultList.Text,Format('@yield(''%s'')',[Item.Key]),Item.Value,[rfReplaceAll,rfIgnoreCase]);
      end;

      {$REGION 'Kullanýlmayanlar Temizleniyor'}
      Matchs := GetRexExs(reYield,ResultList.Text,[roIgnoreCase]);

      for var I := 0 to Matchs.Count-1 do
      begin
        ResultList.Text:= StringReplace(ResultList.Text,Matchs.Item[I].Groups.Item[0].Value,'',[rfReplaceAll,rfIgnoreCase]);
      end;

      {$ENDREGION}
    end;
    {$ENDREGION}


    {$REGION '@sectionlar Ayarlanýyor'}
    if ExtendsSuccess then
    begin
      Matchs := GetRexExs(rexSecionShow,ResultList.Text,[roIgnoreCase]);

      for var I := 0 to Matchs.Count-1 do
      begin
        Match:= Matchs.Item[I];
        var SecName := GetPart(Match.Groups.Item[1].Value,'''');
        var SecHTML := Match.Groups.Item[2].Value;

        if ExistsParamsItem(Params,'SECTION',SecName) then
        begin
          var SecItem := FindParamsItem(Params,'SECTION',SecName);
          var InsertHTML:= SecItem.Value;

          if Pos('@@parent',SecItem.Value)>0 then
            InsertHTML:= StringReplace(InsertHTML,'@@parent',SecHTML,[rfReplaceAll,rfIgnoreCase]);

          DeleteStrPart(ResultList,Match.Index,Match.Length,InsertHTML);
        end;
      end;
    end;
    {$ENDREGION}


    {$REGION '@rexInclude Ayarlanýyor'}
    Matchs := GetRexExs(rexInclude,ResultList.Text,[roIgnoreCase]);

    for var I := 0 to Matchs.Count-1 do
    begin
      Match:= Matchs.Item[I];
      ResultList.Text:= StringReplace(ResultList.Text,Match.Groups.Item[0].Value,GLB_GetLayoutData(Match.Groups.Item[1].Value),[rfReplaceAll,rfIgnoreCase]);
    end;
    {$ENDREGION}

    if Assigned(OnAfterExecutePicker) then
      OnAfterExecutePicker(Self,ResultList);

    {$REGION 'Result'}
    ATextData.Text:= ResultList.Text;
    {$ENDREGION}

  finally
    ResultList.Free;
    Params.Free;
  end;
end;



function TTextCollector.CreateDynamicData(const AMatch: TMatch; const AData: String): TDynamicData;
begin
  Result:= TDynamicData.Create;
  Result.Match := AMatch;
  Result.Data:= AData;
end;


function TTextCollector.StringLisCompressiontStream(ATextData: TStringList): TMemoryStream;
var
  InStrStream: TStringStream;
begin
  InStrStream:= TStringStream.Create(ATextData.Text,TUTF8Encoding.Create);
  Result:= TMemoryStream.Create;

  try
    InStrStream.Position:= 0;
    IndyCompressStream(InStrStream,Result);
  finally
    InStrStream.Free;
  end;
end;


procedure TTextCollector.DynamicDataReplace(Out ATextData: TStringList);
var
  Match : TMatch;
  Matchs: TMatchCollection;
  DynamicDatas: TDynamicDatas;
begin
  {$REGION 'Dynamic Data Replacer'}
  if Assigned(FDynamicDataReplace) then
  begin
    var Difference: Integer;
    Difference := 0;

    var DataText: String;
    DataText:= ATextData.Text;

    Matchs := GetRexExs(rexDynamic,DataText,[roIgnoreCase,roSingleLine]);

    if (Matchs.Count>0) then
    begin
      DynamicDatas:= TDynamicDatas.Create;
      try

        for var Ind :=  0 to  Matchs.Count-1 do
        begin
          Match:= Matchs[Ind];
          DynamicDatas.Add(CreateDynamicData(Match,Match.Groups.Item[2].Value));
        end;

        FDynamicDataReplace(Self,Matchs,ATextData,DynamicDatas);

        for var Item in  DynamicDatas do
        begin
          if Item.ReplaceData<>'' then
          begin
            Insert(Item.ReplaceData,DataText,Item.Match.Index + Difference);
            Difference:=  Difference +  Length(Item.ReplaceData);
          end;

          Delete(DataText,Item.Match.Index+Difference,Item.Match.Length);
          Difference:=  Difference - Item.Match.Length;
        end;

        for var Ind :=  DynamicDatas.Count-1 downto 0  do
          DynamicDatas[Ind].Free;
      finally
        DynamicDatas.Free;
      end;

     ATextData.Text:=  DataText;
    end;
  end;
  {$ENDREGION}
end;


procedure TTextCollector.ExecutePicker(ATextData: TStringList);
begin
  BaseExecutePicker(ATextData);
  DynamicDataReplace(ATextData);
end;

procedure TTextCollector.ExecutePickerFile(const AFileName: TFileName; Out ATextData: TStringList; const AStaticDataText: Boolean);
var
  CacheFileName: String;
  Encoding: TUTF8Encoding;
  SList: TStringList;
begin
  {$REGION 'MemorCache açýk ise hafýzadan okuyor'}
  if ((MemoryCache) And (GLB_FileCache_Exists(AFileName))) then
  begin
    GLB_FileCacheData_Assigned(AFileName,ATextData);

    if Not AStaticDataText then
      DynamicDataReplace(ATextData);

    EXit;
  end;
  {$ENDREGION}


  if ReplaceCacheFilePath.Trim<>'' then
    CacheFileName:= ReplaceCacheFilePath+ExtractFileName(AFileName)
  else
    CacheFileName:= AFileName;

  if (FileExists(CacheFileName)) then
  begin
    Encoding:= TUTF8Encoding.Create;
    SList:= TStringList.Create;

    try
      SList.LoadFromFile(CacheFileName,Encoding);

      if (ReplaceCacheFilePath.Trim='') then
        BaseExecutePicker(SList);

      ATextData.Text:= SList.Text;
    finally
      Encoding.Free;
      SList.Free;
    end;
  end else
  if (ReplaceCacheFilePath.Trim<>'') And (FileExists(AFileName)) then
  begin
    Encoding:= TUTF8Encoding.Create;
    SList:= TStringList.Create;

    try
      SList.LoadFromFile(AFileName,Encoding);
      BaseExecutePicker(SList);
      ATextData.Text:= SList.Text;
      SList.Savetofile(CacheFileName,Encoding);
    finally
      Encoding.Free;
      SList.Free;
    end;
  end else
    Exit;

  if  (MemoryCache) And (ATextData.Text.Trim<>'') then
    GLB_FileCacheData_Add(AFileName,ATextData.Text);

  if Not AStaticDataText then
    DynamicDataReplace(ATextData);
end;


function TTextCollector.ExecutePickerStream(const AFileName: TFileName; const AStaticDataText, ACompression: Boolean): TMemoryStream;
var
  SList: TStringList;
begin
  SList:= TStringList.Create;

  try
    ExecutePickerFile(AFileName,SList,AStaticDataText);

    if (ACompression) And Not (AStaticDataText) then
      result:= StringLisCompressiontStream(SList)
    else begin
      Result:= TMemoryStream.Create;
      SList.SaveToStream(Result);
    end;

    Result.Position:= 0;
  finally
    SList.Free;
  end;
end;
{$ENDREGION}



initialization
  GlobalLayouts_CS := TCriticalSection.create;
  GlobalFileCaches_CS := TCriticalSection.create;

  GlobalLayouts    := TDictionary<String, String>.Create;
  GlobalFileCaches := TDictionary<String, String>.Create;



finalization
  GlobalLayouts_CS.Free;
  GlobalFileCaches_CS.Free;

  GlobalLayouts.Free;
  GlobalFileCaches.Free;


end.

