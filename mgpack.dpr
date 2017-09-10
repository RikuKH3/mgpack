program Project1;

{$WEAKLINKRTTI ON}
{$RTTI EXPLICIT METHODS([]) PROPERTIES([]) FIELDS([])}

{$APPTYPE CONSOLE}

{$R *.res}

uses
  Windows, System.SysUtils, System.Classes, System.IOUtils, System.Types;

{$SETPEFLAGS IMAGE_FILE_RELOCS_STRIPPED}

var
  EncryptedFlag, CompressedFlag: Boolean;
  gamekey: TBytes;
  ArcVersion: LongWord;

function Pad(length: Cardinal; DataAlignment: Cardinal): Cardinal;
var
  m: Cardinal;
begin
  Result:=length;
  m:=length mod DataAlignment;
  if (m>0) then Result:=result+DataAlignment-m;
end;

function clzf2_compress(const input: TBytes; var output: TBytes): LongWord;
label
  Label_0326, Label_02A9;
const
  HLOG: LongWord=14;
  HSIZE: LongWord=16384; //1 shl 14
  MAX_LIT: Integer=32; //1 shl 5
  MAX_OFF: LongWord=8192; //1 shl 13
  MAX_REF: LongWord=264; //(1 shl 8) + (1 shl 3)
var
  HashTable: array of Int64;
  hslot, reference, off: Int64;
  lit: Integer;
  inputLength, iidx, oidx, hval, len, maxlen: LongWord;
begin
  inputLength := Length(input);
  SetLength(HashTable, HSIZE);
  iidx := 0;
  oidx := 0;
  hval := (input[iidx] shl 8) or input[iidx+1];
  lit := 0;
  goto Label_0326;

Label_02A9:
  inc(lit);
  inc(iidx);
  if (lit = MAX_LIT) then
  begin
    SetLength(output,oidx+1);
    output[oidx] := MAX_LIT-1; inc(oidx);
    lit := 0-lit;
    repeat
      SetLength(output,oidx+1);
      output[oidx] := input[Int64(iidx) + lit]; inc(oidx);
      inc(lit);
    until (lit = 0)
  end;

Label_0326:
  if iidx < (inputLength - 2) then
  begin
    hval := (hval shl 8) or input[iidx+2];
    hslot := ((hval xor (hval shl 5)) shr (($18 - HLOG) - hval*5)) and (HSIZE - 1);
    reference := HashTable[hslot];
    HashTable[hslot] := iidx;
    off := iidx - reference - 1;
    if (off >= MAX_OFF) or (iidx+4 >= inputLength) or (reference <= 0) or (input[reference] <> input[iidx]) or (input[reference+1] <> input[iidx+1]) or (input[reference+2] <> input[iidx+2]) then goto Label_02A9;
    len := 2;
    maxlen := inputLength - iidx - len;
    if maxlen > MAX_REF then maxlen := MAX_REF;
    repeat
      inc(len)
    until (len >= maxlen) or (input[reference+len] <> input[iidx+len]);
    if (lit <> 0) then
    begin
      SetLength(output,oidx+1);
      output[oidx] := lit-1; inc(oidx);
      lit := 0-lit;
      repeat
        SetLength(output,oidx+1);
        output[oidx] := input[Int64(iidx) + lit]; inc(oidx);
        inc(lit);
      until (lit = 0)
    end;
    dec(len, 2);
    inc(iidx);
    if (len < 7) then
      begin
        SetLength(output,oidx+1);
        output[oidx] := (off shr 8) + (len shl 5); inc(oidx);
      end
    else
      begin
        SetLength(output,oidx+1);
        output[oidx] := off shr 8 + $e0; inc(oidx);
        SetLength(output,oidx+1);
        output[oidx] := len-7; inc(oidx);
      end;
    SetLength(output,oidx+1);
    output[oidx] := off; inc(oidx);
    inc(iidx, len-1);
    hval := (input[iidx] shl 8) or input[iidx+1];
    hval := (hval shl 8) or input[iidx+2];
    HashTable[((hval xor (hval shl 5)) shr ($18 - HLOG - hval*5)) and (HSIZE - 1)] := iidx;
    inc(iidx);
    hval := (hval shl 8) or input[iidx+2];
    HashTable[((hval xor (hval shl 5)) shr ($18 - HLOG - hval*5)) and (HSIZE - 1)] := iidx;
    inc(iidx);
    goto Label_0326
  end;
  if (iidx = inputLength) then
  begin
    if (lit <> 0) then
    begin
      SetLength(output,oidx+1);
      output[oidx] := lit-1; inc(oidx);
      lit := 0-lit;
      repeat
        SetLength(output,oidx+1);
        output[oidx] := input[Int64(iidx) + lit]; inc(oidx);
        inc(lit);
      until (lit = 0)
    end;
    Result := oidx;
    exit
  end;
  goto Label_02A9
end;

function clzf2_decompress(const input: TBytes; var output: TBytes): LongWord;
var
  reference: Integer;
  inputLength, iidx, oidx, ctrl, len: LongWord;
begin
  inputLength := Length(input);
  iidx := 0;
  oidx := 0;
  repeat
    ctrl := input[iidx]; inc(iidx);
    if (ctrl < $20) then
    begin
      inc(ctrl);
      repeat
        SetLength(output, oidx+1);
        output[oidx] := input[iidx]; inc(oidx); inc(iidx);
        dec(ctrl);
      until (ctrl = 0);
    end
    else
    begin
      len := (ctrl shr 5);
      reference := ((oidx - ((ctrl and $1f) shl 8)) - 1);
      if (len = 7) then
        begin
          inc(len, input[iidx]); inc(iidx)
        end;
      dec(reference, input[iidx]); inc(iidx);
      if (reference < 0) then
        begin
          Result := 0;
          exit
        end;
      SetLength(output, oidx+2);
      output[oidx] := output[reference]; inc(oidx); inc(reference);
      output[oidx] := output[reference]; inc(oidx); inc(reference);
      repeat
        SetLength(output, oidx+1);
        output[oidx] := output[reference]; inc(oidx); inc(reference);
        dec(len);
      until (len = 0)
    end
  until (iidx >= inputLength);
  Result := oidx;
end;

procedure encodedata(var b: TBytes);
var
  buffer2: TBytes;
  i, index: Integer;
begin
  SetLength(buffer2, Length(gamekey));
  for i:=0 to Length(gamekey)-1 do buffer2[i]:=gamekey[i];

  i := 0;
  while i < Length(b) do
  begin
    index := i mod Length(buffer2);
    b[i] := b[i] xor buffer2[index];
    if ArcVersion=1 then buffer2[index] := buffer2[index] + $1B;  //may vary depending on gamekey
    inc(i)
  end
end;

procedure unpack;
var
  FileStream1, FileStream2: TFileStream;
  BytesStream1: TBytesStream;
  Bytes1, Bytes2, StringBytes: TBytes;
  DataCount, LongWord1: LongWord;
  DataPos, DataSize: array of LongWord;
  DataName: array of String;
  DataNameLength, Byte1: Byte;
  FileDirOut: String;
  i: Integer;
begin
  FileStream1:=TFileStream.Create(ParamStr(4), fmOpenRead or fmShareDenyWrite);
  try
    FileStream1.ReadBuffer(LongWord1,4);
    if not LongWord1=$4B50474D then begin Writeln('Error: Input file is not a valid MGPK archive file'); Readln; exit end;
    FileStream1.ReadBuffer(ArcVersion, 4);
    FileStream1.ReadBuffer(DataCount,4);
    if DataCount=0 then begin Writeln('Error: Input file is an empty MGPK archive file'); Readln; exit end;
    SetLength(DataPos, DataCount); SetLength(DataSize, DataCount); SetLength(DataName, DataCount);
    for i:=0 to DataCount-1 do
    begin
      if ArcVersion=1 then begin
        FileStream1.ReadBuffer(DataNameLength,1);
        SetLength(StringBytes, DataNameLength);
        FileStream1.ReadBuffer(PByte(StringBytes)^, DataNameLength);
        DataName[i]:=TEncoding.UTF8.GetString(StringBytes);
        FileStream1.Position:=FileStream1.Position-DataNameLength-1 + Pad(DataNameLength+2, $20);
        FileStream1.ReadBuffer(DataPos[i],4);
        FileStream1.ReadBuffer(DataSize[i],4);
        FileStream1.Position:=FileStream1.Position+8;
      end else begin
        LongWord1 := FileStream1.Position;
        SetLength(StringBytes, 0);
        repeat
          FileStream1.ReadBuffer(Byte1,1);
          if not (Byte1=0) then
          begin
            SetLength(StringBytes, Length(StringBytes)+1);
            StringBytes[Length(StringBytes)-1]:=Byte1;
          end;
        until (Byte1=0) or (FileStream1.Position=LongWord1+$20);
        DataName[i]:=TEncoding.UTF8.GetString(StringBytes);
        FileStream1.Position:=LongWord1+$20;
        FileStream1.ReadBuffer(DataPos[i],4);
        FileStream1.Position:=FileStream1.Position+8;
        FileStream1.ReadBuffer(DataSize[i],4);
      end;
    end;

    if ParamCount<5 then FileDirOut:=ExpandFileName(Copy(ParamStr(4),1,Length(ParamStr(4))-Length(ExtractFileExt(ParamStr(4))))) else FileDirOut:=ParamStr(5);
    if not (DirectoryExists(FileDirOut)) then CreateDir(FileDirOut);

    for i:=0 to DataCount-1 do
    begin
      FileStream1.Position:=DataPos[i];

      if (EncryptedFlag=False) and (CompressedFlag=False) then
      begin
        FileStream2:=TFileStream.Create(FileDirOut+'\'+DataName[i], fmCreate or fmOpenWrite or fmShareDenyWrite);
        try
          FileStream2.CopyFrom(FileStream1, DataSize[i]);
        finally FileStream2.Free end;
      end else
      begin
        SetLength(Bytes1, DataSize[i]);
        FileStream1.ReadBuffer(Bytes1[0], DataSize[i]);
        if EncryptedFlag=True then encodedata(Bytes1);
        if CompressedFlag=True then
        begin
          clzf2_decompress(Bytes1, Bytes2);
          BytesStream1:=TBytesStream.Create(Bytes2);
          try
            BytesStream1.SaveToFile(FileDirOut+'\'+DataName[i]);
          finally BytesStream1.Free end;
        end else
        begin
          BytesStream1:=TBytesStream.Create(Bytes1);
          try
            BytesStream1.SaveToFile(FileDirOut+'\'+DataName[i]);
          finally BytesStream1.Free end;
        end;
      end;
      Writeln('[',StringOfChar('0',Length(IntToStr(DataCount))-Length(IntToStr(i+1)))+IntToStr(i+1)+'/'+IntToStr(DataCount)+'] '+DataName[i]);
    end;
  finally FileStream1.Free end;
end;

procedure pack;
const
  ZeroByte: Byte=0;
var
  FileStream1, FileStream2: TFileStream;
  MemoryStream1: TMemoryStream;
  BytesStream1: TBytesStream;
  InputFiles: TStringDynArray;
  Bytes1, Bytes2: TBytes;
  DataLengthPos: array of LongWord;
  utfstring: UTF8String;
  LongWord1: LongWord;
  DataNameLength: Byte;
  InputDir, OutputFile: String;
  z,i: Integer;
begin
  InputDir:=ExpandFileName(ParamStr(4));
  repeat if InputDir[Length(InputDir)]='\' then SetLength(InputDir, Length(InputDir)-1) until not (InputDir[Length(InputDir)]='\');
  InputFiles:=TDirectory.GetFiles(InputDir, '*', TSearchOption.soTopDirectoryOnly);
  if Length(InputFiles)=0 then begin Writeln('Error: No files found in selected directory'); Readln; exit end;

  if (LowerCase(ParamStr(5))='-v1') or (LowerCase(ParamStr(6))='-v1') then ArcVersion := 0 else begin
    if ParamStr(1) = '250,49,151,173,1,93,121,238,101' then ArcVersion := 0 else ArcVersion := 1;
  end;

  MemoryStream1:=TMemoryStream.Create;
  try
    LongWord1:=$4B50474D;
    MemoryStream1.WriteBuffer(LongWord1,4);
    MemoryStream1.WriteBuffer(ArcVersion,4);
    LongWord1:=Length(InputFiles);
    MemoryStream1.WriteBuffer(LongWord1,4);
    SetLength(DataLengthPos, LongWord1);

    for z:=0 to Length(InputFiles)-1 do
    begin
      utfstring:=UTF8String(ExtractFileName(InputFiles[z]));
      DataNameLength:=Length(utfstring);
      if ArcVersion=1 then begin
        MemoryStream1.WriteBuffer(DataNameLength,1);
        MemoryStream1.WriteBuffer(utfstring[1], DataNameLength);
        for i:=1 to Pad(DataNameLength+2, $20)-DataNameLength-1 do MemoryStream1.WriteBuffer(ZeroByte,1);
      end else begin
        MemoryStream1.WriteBuffer(utfstring[1], DataNameLength);
        for i:=1 to Pad(DataNameLength+2, $20)-DataNameLength do MemoryStream1.WriteBuffer(ZeroByte,1);
      end;
      DataLengthPos[z]:=MemoryStream1.Size;
      for i:=1 to 16 do MemoryStream1.WriteBuffer(ZeroByte,1);
    end;

    if ParamCount<5 then OutputFile:=InputDir+'.pac' else begin
      if not (LowerCase(ParamStr(5))='-v1') then OutputFile:=ParamStr(5) else OutputFile:=InputDir+'.pac';
    end;
    FileStream1:=TFileStream.Create(OutputFile, fmCreate or fmOpenWrite or fmShareDenyWrite);
    try
      FileStream1.Size:=MemoryStream1.Size;
      for z:=0 to Length(InputFiles)-1 do
      begin
        FileStream2:=TFileStream.Create(InputFiles[z], fmOpenRead or fmShareDenyWrite);
        try
          if (EncryptedFlag=False) and (CompressedFlag=False) then
          begin
            MemoryStream1.Position:=DataLengthPos[z];
            LongWord1:=FileStream1.Size;
            MemoryStream1.WriteBuffer(LongWord1,4);
            LongWord1:=FileStream2.Size;
            if ArcVersion=0 then MemoryStream1.Position := MemoryStream1.Position + 8;
            MemoryStream1.WriteBuffer(LongWord1,4);
            FileStream1.CopyFrom(FileStream2, FileStream2.Size);
          end else
          begin
            SetLength(Bytes1, FileStream2.Size);
            FileStream2.ReadBuffer(Bytes1[0], FileStream2.Size);
            if CompressedFlag=True then
            begin
              clzf2_compress(Bytes1, Bytes2);
              if EncryptedFlag=True then encodedata(Bytes2);
              MemoryStream1.Position:=DataLengthPos[z];
              LongWord1:=FileStream1.Size;
              MemoryStream1.WriteBuffer(LongWord1,4);
              LongWord1:=Length(Bytes2);
              if ArcVersion=0 then MemoryStream1.Position := MemoryStream1.Position + 8;
              MemoryStream1.WriteBuffer(LongWord1,4);
              BytesStream1:=TBytesStream.Create(Bytes2);
              try
                FileStream1.CopyFrom(BytesStream1, BytesStream1.Size);
              finally BytesStream1.Free end;
            end else
            begin
              if EncryptedFlag=True then encodedata(Bytes1);
              MemoryStream1.Position:=DataLengthPos[z];
              LongWord1:=FileStream1.Size;
              MemoryStream1.WriteBuffer(LongWord1,4);
              LongWord1:=Length(Bytes1);
              if ArcVersion=0 then MemoryStream1.Position := MemoryStream1.Position + 8;
              MemoryStream1.WriteBuffer(LongWord1,4);
              BytesStream1:=TBytesStream.Create(Bytes1);
              try
                FileStream1.CopyFrom(BytesStream1, BytesStream1.Size);
              finally BytesStream1.Free end;
            end;
          end;
        finally FileStream2.Free end;
        Writeln('[',StringOfChar('0',Length(IntToStr(Length(InputFiles)))-Length(IntToStr(z+1)))+IntToStr(z+1)+'/'+IntToStr(Length(InputFiles))+'] '+ExtractFileName(InputFiles[z]));
      end;
      FileStream1.Position:=0;
      MemoryStream1.Position:=0;
      FileStream1.CopyFrom(MemoryStream1, MemoryStream1.Size);
    finally FileStream1.Free end;
  finally MemoryStream1.Free end;
end;

var
  s: String;
  i: Integer;
begin
  try
    Writeln('Mangagamer MGPK Archive Unpacker/Packer v1.1 by RikuKH3');
    Writeln('-------------------------------------------------------');
    if ParamCount<4 then begin Writeln('Usage:'+#13#10+'  mgpack.exe <gamekey> enc|dec comp|unc <input file or folder> [output file or folder] [-v1]'+#13#10#13#10+'Known gamekeys:'+#13#10+'  d2b VS Deardrops -Cross the Future-'+#9#9#9+'229,99,174,4,45,166,127,158,69'+#13#10'  Really? Really!'+#9#9#9#9#9+'250,49,151,173,1,93,121,238,101'+#13#10+'  Cartagra, Free Friends, Kara no Shojo 2 (Trial)'+#9+'229,101,186,26,61,198,127,158,70,21,137'+#13#10+'  Kara no Shojo 2'+#9#9#9#9#9+'162,101,186,26,45,198,127,147,70,21,132'+#13#10#13#10+'Example:'+#13#10+'  mgpack.exe 162,101,186,26,45,198,127,147,70,21,132 enc comp "D:\Games\KnS2\GameData\script.pac"'); Readln; exit end;

    if LowerCase(ParamStr(2))='enc' then EncryptedFlag:=True else
      if LowerCase(ParamStr(2))='dec' then EncryptedFlag:=False else
        begin Writeln('Error: Unknown parameter '+#39+ParamStr(2)+#39+'. Please use '+#39+'enc'+#39+' or '+#39+'dec'+#39+'.'); Readln; exit end;

    if LowerCase(ParamStr(3))='comp' then CompressedFlag:=True else
      if LowerCase(ParamStr(3))='unc' then CompressedFlag:=False else
        begin Writeln('Error: Unknown parameter '+#39+ParamStr(3)+#39+'. Please use '+#39+'comp'+#39+' or '+#39+'unc'+#39+'.'); Readln; exit end;

    s:=ParamStr(1);
    repeat
      i:=Pos(',',s);
      SetLength(gamekey, Length(gamekey)+1);
      if i>0 then
      begin
        gamekey[Length(gamekey)-1]:=StrToInt(Copy(s,1,i-1));
        s:=Copy(s,i+1);
      end else gamekey[Length(gamekey)-1]:=StrToInt(s);
    until i=0;

    if Pos('.', ExtractFileName(ParamStr(4)))=0 then pack else unpack;
  except on E: Exception do begin Writeln('Error: '+E.Message); Readln; exit end end;
end.
