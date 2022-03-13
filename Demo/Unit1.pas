unit Unit1;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, IdBaseComponent, IdComponent, TextCollectorU,
  IdCustomTCPServer, IdCustomHTTPServer, IdHTTPServer, IdContext, Vcl.StdCtrls,
  Vcl.ExtCtrls, IdGlobalProtocols, System.RegularExpressions;

type
  TForm1 = class(TForm)
    IdHTTPServer1: TIdHTTPServer;
    GridPanel1: TGridPanel;
    Button1: TButton;
    Button2: TButton;
    Panel1: TPanel;
    CheckBoxCompress: TCheckBox;
    procedure FormCreate(Sender: TObject);
    procedure IdHTTPServer1CommandGet(AContext: TIdContext;
      ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
  private
    procedure OnAfterExecutePicker(ATextPicker: TTextCollector;  ATextData: TStringList);
    procedure OnDynamicDataReplace(ATextPicker: TTextCollector;
      const Matchs: TMatchCollection; const ADataText: TStringList;
      ADynamicDatas: TDynamicDatas);
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form1: TForm1;
  WWW: String;

const
    Version = '1.1.1';

implementation

{$R *.dfm}



procedure TForm1.Button1Click(Sender: TObject);
begin
  GLB_FileCacheData_Clear(WWW+'cache','*.html');
end;

procedure TForm1.Button2Click(Sender: TObject);
begin
  GLB_Layouts_Clear;
  GLB_Layouts_Load(WWW+'layouts','*.html');
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  WWW:= ExtractFilePath(Application.ExeName)+'www\';

  Button1Click(self);
  Button2Click(self);

  IdHTTPServer1.StartListening;
end;

procedure TForm1.OnAfterExecutePicker(ATextPicker: TTextCollector; ATextData: TStringList);
begin
  ATextData.Text:= StringReplace(ATextData.Text,'@vers',Version,[rfReplaceAll]);
end;

procedure TForm1.OnDynamicDataReplace(ATextPicker: TTextCollector; const Matchs : TMatchCollection; const ADataText: TStringList;
    ADynamicDatas: TDynamicDatas);
begin
  // Server Side JS or PascalScrip vs vs Engine Code

  for var Item in ADynamicDatas do
    Item.ReplaceData:= 'var pageData = {"firstName":"Mehmet Akif", "lastName":"BASPINAR"}'
end;



procedure TForm1.IdHTTPServer1CommandGet(AContext: TIdContext;
  ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
var
  TextCollector: TTextCollector;
  FileMime: string;
  FileName: string;
  FileNameBase: string;
  SataticPage: Boolean;
begin
  if ARequestInfo.URI='/' then
  begin
     AResponseInfo.Redirect('index.html');
     exit;
  end;

  FileName:= WWW+StringReplace(ARequestInfo.URI,'/','\',[rfReplaceAll]);
  FileNameBase:= ExtractFileName(FileName);
  FileMime:= GetMIMETypeFromFile(FileName);

  AResponseInfo.ContentType := FileMime;
  AResponseInfo.ContentEncoding:='utf-8';

  if FileMime='text/html' then
  begin
    SataticPage := LowerCase(FileNameBase)='about.html';
    TextCollector:= TTextCollector.Create(True,WWW+'cache');

    try
      TextCollector.OnAfterExecutePicker:= OnAfterExecutePicker;
      TextCollector.OnDynamicDataReplace:= OnDynamicDataReplace;

      AResponseInfo.ContentStream:= TextCollector.ExecutePickerStream(FileName,SataticPage,CheckBoxCompress.Checked);
    finally
      TextCollector.Free;
    end;
  end else
  if FileExists(FileName) then
  begin
    if CheckBoxCompress.Checked then
      AResponseInfo.ContentStream:= TextCollector.CompressStream(FileName)
    else
      AResponseInfo.ContentStream:= TFileStream.Create(FileName,fmOpenRead);
  end;

  if CheckBoxCompress.Checked then
    AResponseInfo.ContentEncoding:= 'deflate';

end;

end.
