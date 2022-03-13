object Form1: TForm1
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu, biMinimize]
  Caption = 'TextCollector'
  ClientHeight = 50
  ClientWidth = 606
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 15
  object GridPanel1: TGridPanel
    Left = 0
    Top = 0
    Width = 606
    Height = 50
    Align = alClient
    BevelOuter = bvNone
    ColumnCollection = <
      item
        Value = 33.501516046889130000
      end
      item
        Value = 33.332367431332320000
      end
      item
        Value = 33.166116521778550000
      end>
    ControlCollection = <
      item
        Column = 0
        Control = Button1
        Row = 0
      end
      item
        Column = 1
        Control = Button2
        Row = 0
      end
      item
        Column = 2
        Control = Panel1
        Row = 0
      end>
    RowCollection = <
      item
        Value = 100.000000000000000000
      end>
    TabOrder = 0
    object Button1: TButton
      Left = 0
      Top = 0
      Width = 203
      Height = 50
      Align = alClient
      Caption = 'Cache Folder Clear'
      TabOrder = 0
      OnClick = Button1Click
    end
    object Button2: TButton
      Left = 203
      Top = 0
      Width = 202
      Height = 50
      Align = alClient
      Caption = 'Layout Clear And Load'
      TabOrder = 1
      OnClick = Button2Click
    end
    object Panel1: TPanel
      Left = 405
      Top = 0
      Width = 201
      Height = 50
      Align = alClient
      BevelOuter = bvNone
      TabOrder = 2
      ExplicitLeft = 472
      ExplicitTop = 32
      ExplicitWidth = 185
      ExplicitHeight = 41
      object CheckBoxCompress: TCheckBox
        AlignWithMargins = True
        Left = 3
        Top = 3
        Width = 195
        Height = 44
        Align = alClient
        Caption = 'Compression "deflate"'
        Font.Charset = DEFAULT_CHARSET
        Font.Color = clWindowText
        Font.Height = -12
        Font.Name = 'Segoe UI'
        Font.Style = [fsBold]
        ParentFont = False
        TabOrder = 0
        ExplicitLeft = 17
        ExplicitTop = 9
        ExplicitWidth = 97
        ExplicitHeight = 17
      end
    end
  end
  object IdHTTPServer1: TIdHTTPServer
    Active = True
    Bindings = <>
    DefaultPort = 8080
    OnCommandGet = IdHTTPServer1CommandGet
    Left = 320
  end
end
