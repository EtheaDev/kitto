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

unit Kitto.Ext.Graphics;

{$I Kitto.Defines.inc}

interface

uses
  System.SysUtils, System.Classes,
  Ext, ExtPascal;

procedure DownloadThumbnailedStream(const AStream: TStream; const AFileName: string;
  const AThumbnailWidth, AThumbnailHeight: Integer);

implementation

uses
  System.Types, System.StrUtils,
  Vcl.Graphics, Vcl.Imaging.jpeg, Vcl.Imaging.pngimage,
  EF.SysUtils;

procedure DownloadThumbnailedStream(const AStream: TStream; const AFileName: string;
  const AThumbnailWidth, AThumbnailHeight: Integer);

{ Paradox graphic BLOB header }
type
  TPDoxGraphicHeader = record
    Count: Word;                { Fixed at 1 }
    HType: Word;                { Fixed at $0100 }
    Size: Integer              { Size not including header }
  end;

var
  LFileExt: string;
  Size: Longint;
  Header: TBytes;
  GraphicHeader: TPDoxGraphicHeader;

  LTempFileName: string;
  LStream: TFileStream;

  procedure WriteTempFile;
  var
    LFileStream: TFileStream;
  begin
    LFileStream := TFileStream.Create(LTempFileName, fmCreate);
    try
      AStream.Position := 0;
      Size := AStream.Size;
      if Size >= SizeOf(TPDoxGraphicHeader) then
      begin
        SetLength(Header, SizeOf(TPDoxGraphicHeader));
        AStream.Read(Header, 0, Length(Header));
        Move(Header[0], GraphicHeader, SizeOf(TPDoxGraphicHeader));
        if (GraphicHeader.Count <> 1) or (GraphicHeader.HType <> $0100) or
          (GraphicHeader.Size <> Size - SizeOf(GraphicHeader)) then
          AStream.Position := 0;
      end;
      LFileStream.CopyFrom(AStream, Size - AStream.Position);
      AStream.Position := 0;
    finally
      FreeAndNil(LFileStream);
    end;
  end;

  procedure TransformTempFileToThumbnail(const AMaxWidth, AMaxHeight: Integer;
    const AImageClass: TGraphicClass);
  var
    LImage: TGraphic;
    LScale: Extended;
    LBitmap: TBitmap;
  begin
    LImage := AImageClass.Create;
    try
      LImage.LoadFromFile(LTempFileName);
      if (LImage.Height <= AMaxHeight) and (LImage.Width <= AMaxWidth) then
        Exit;
      if LImage.Height > LImage.Width then
        LScale := AMaxHeight / LImage.Height
      else
        LScale := AMaxWidth / LImage.Width;
      LBitmap := TBitmap.Create;
      try
        LBitmap.Width := Round(LImage.Width * LScale);
        LBitmap.Height := Round(LImage.Height * LScale);
        LBitmap.Canvas.StretchDraw(LBitmap.Canvas.ClipRect, LImage);

        LImage.Assign(LBitmap);
        LImage.SaveToFile(LTempFileName);
      finally
        LBitmap.Free;
      end;
    finally
      LImage.Free;
    end;
  end;

begin
  Assert(Assigned(AStream));

  LFileExt := ExtractFileExt(AFileName);
  LTempFileName := GetTempFileName(LFileExt);
  try
    if MatchText(LFileExt, ['.jpg', '.jpeg', '.png']) then
    begin
      WriteTempFile;
      if MatchText(LFileExt, ['.jpg', '.jpeg']) then
        TransformTempFileToThumbnail(AThumbnailWidth, AThumbnailHeight, TJPEGImage)
      else
        TransformTempFileToThumbnail(AThumbnailWidth, AThumbnailHeight, TPngImage);

      LStream := TFileStream.Create(LTempFileName, fmOpenRead + fmShareDenyWrite);
      try
        Session.DownloadStream(LStream, AFileName);
      finally
        FreeAndNil(LStream);
      end;
    end
    else if MatchText(LFileExt, ['.bmp']) then
    begin
      WriteTempFile;
      TransformTempFileToThumbnail(AThumbnailWidth, AThumbnailHeight, TBitmap);
      LStream := TFileStream.Create(LTempFileName, fmOpenRead + fmShareDenyWrite);
      try
        Session.DownloadStream(LStream, AFileName);
      finally
        FreeAndNil(LStream);
      end;
    end
    else
      Session.DownloadStream(AStream, AFileName);
  finally
    if FileExists(LTempFileName) then
      DeleteFile(LTempFileName);
  end;
end;

end.