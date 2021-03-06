unit frm_main;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, IBConnection, sqldb, db, FileUtil, Forms, Controls,
  Graphics, Dialogs, EditBtn, StdCtrls, ExtCtrls, ComCtrls, Buttons;

const
  _LogFile = 'scmFirebird.log';
  _FieldSeparator = ';';

  MSG_NO_EXIT_FILE = 'Exit filename empty';
  MSG_NO_DATA = 'Query retrieve 0 records';

(*
 Object Type managed:
       - TABLE
*)


type

  FormatMSG = (ERROR, DATA);

  { TfrmMain }

  TfrmMain = class(TForm)
    btnExit: TBitBtn;
    btnRun: TBitBtn;
    dbFile: TFileNameEdit;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    Panel1: TPanel;
    PB: TProgressBar;
    edUser: TEdit;
    edPassword: TEdit;
    GroupBox1: TGroupBox;
    Label1: TLabel;
    Label2: TLabel;
    outputFile: TFileNameEdit;
    IBConn: TIBConnection;
    qSQL: TSQLQuery;
    qSQLFIELD_LENGTH: TSmallintField;
    qSQLFIELD_NAME: TStringField;
    qSQLFIELD_PRECISION: TSmallintField;
    qSQLFIELD_TYPE: TStringField;
    qSQLOBJECT_NAME: TStringField;
    qSQLOBJECT_TYPE: TStringField;
    SQLTrans: TSQLTransaction;
    edHost: TEdit;
    procedure btnExitClick(Sender: TObject);
    procedure btnRunClick(Sender: TObject);
  private
    logFile: TextFile;
    outFile: TextFile;
    function ConnectDB (fileDB, userDB, passDB, hostDB: string): boolean;

    procedure LogStr (fmsg: FormatMSG; msg: string);

    procedure ProcessQuery (oFile: string);
    function ProcessRow (objType, objName, fieldName, fieldType: string;
                         fieldlength, fieldpresicion:integer): string;

  public
    { public declarations }
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.lfm}

{ TfrmMain }

procedure TfrmMain.btnExitClick(Sender: TObject);
begin
  Application.Terminate;
end;

procedure TfrmMain.btnRunClick(Sender: TObject);
begin
  if TRIM(outputFile.Text) = EmptyStr then
  begin
    LogStr(ERROR, MSG_NO_EXIT_FILE);
  end;

  if ConnectDB( TRIM(dbFile.Text)
              , TRIM(edUser.Text)
              , TRIM(edPassword.Text)
              , TRIM(edHost.Text)
              ) then
  begin
    try
      qSQL.Open;
      if (qSQL.RecordCount > 0) then
      begin
        ProcessQuery (outputFile.Text);
      end
      else
        LogStr(ERROR, MSG_NO_DATA);
    except
      on E: Exception do ( LogStr(ERROR, E.Message) );
    end;
  end;
end;

function TfrmMain.ConnectDB(fileDB, userDB, passDB, hostDB: string): boolean;
begin
  Result:= false;
  try
    with ibConn do
    begin
      DatabaseName:= fileDB;
      UserName:= userDB;
      Password:= passDB;
      HostName:= hostDB;
      Open;
      Result:= True;
    end;
  except
    on E: Exception do ( LogStr(ERROR, E.Message) );
  end;
end;

procedure TfrmMain.LogStr(fmsg: FormatMSG; msg: string);
begin
  AssignFile(logFile, ExtractFilePath(Application.ExeName)+ _LOGFILE);
  Append(logFile);
  case fmsg of
   ERROR: WriteLn(logFile, DateToStr(Now) + ' +++ ERROR +++ ' + msg);
   DATA: WriteLn(logFile,  DateToStr(Now) + ' - ' + msg);
  end;
  CloseFile(logFile);
end;

procedure TfrmMain.ProcessQuery(oFile: string);
var
 tmplength, tmpPrecision: integer; //Quick (and bad) check for nulls
 retRow: string;
begin
  try
    AssignFile(outFile, oFile);
    Rewrite(outFile);
    with qSQL do
    begin
      First;
      Pb.Max:= qSQL.RecordCount; //Set the progress bar
      While not EOF do
      begin
        if (qSQLFIELD_LENGTH.IsNull) then
          tmplength:= 0
        else
          tmplength:= qSQLFIELD_LENGTH.AsInteger;

        if (qSQLFIELD_PRECISION.IsNull) then
          tmpPrecision:= 0
        else
          tmpPrecision:= qSQLFIELD_PRECISION.AsInteger;

        retRow:= ProcessRow(qSQLOBJECT_TYPE.AsString
                  ,qSQLOBJECT_NAME.AsString
                  ,qSQLFIELD_NAME.AsString
                  ,qSQLFIELD_TYPE.AsString
                  ,tmplength
                  ,tmpPrecision
                  );

        if (retRow <> EmptyStr) then
          WriteLn(outFile, retRow);

        Next;
        Pb.StepIt;
      end;
    end;
    CloseFile(outFile);
  except
    on E: Exception do ( LogStr(ERROR, E.Message) );
  end;
end;

function TfrmMain.ProcessRow(objType, objName, fieldName, fieldType: string;
  fieldlength, fieldpresicion: integer): string;
const
  _MONTB = 'MON$'; //System Monitor tables
  _SYSTB = 'RDB$'; //System tables
var
 tempStr: string;
 isSysRow: boolean;
begin

  // Check for system tables. If I find one, return EmptyStr;
  tempStr:= Copy(UpperCase(Trim(objName)),1, 4);

  isSysRow := ((tempStr = _MONTB) or (tempStr = _SYSTB));


  if (not isSysRow) then
    Result:=  UpperCase(TRIM(objType))
           + _FieldSeparator
           + UpperCase(TRIM(objName))
           + _FieldSeparator
           + UpperCase(TRIM(fieldName))
           + _FieldSeparator
           + UpperCase(TRIM(fieldType))
           + _FieldSeparator
           + IntToStr(fieldlength)
           + _FieldSeparator
           + IntToStr(fieldpresicion)
    else
      Result:= EmptyStr;
end;

end.

