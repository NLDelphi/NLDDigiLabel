{ *************************************************************************** }
{                                                                             }
{ NLDDigiLabel  -  www.nldelphi.com Open Source Delphi Component              }
{                                                                             }
{ Initiator: Albert de Weerd (aka NGLN)                                       }
{ License: Free to use, free to modify                                        }
{ Website: http://www.nldelphi.com/forum/showthread.php?t=26986               }
{ SVN path: http://svn.nldelphi.com/nldelphi/opensource/ngln/NLDDigiLabel     }
{                                                                             }
{ *************************************************************************** }
{                                                                             }
{ Date: May 13, 2011                                                          }
{ Version: 1.0.0.1                                                            }
{                                                                             }
{ *************************************************************************** }

unit NLDDigiLabel;

interface

uses
  Windows, Classes, Controls, Graphics, Messages, StdCtrls, SysUtils;

type
  TSegmentCoordIndex = 0..11;
  TSegmentCoords = array[TSegmentCoordIndex] of Word;

  TSegmentPointIndex = 0..5;
  TSegmentPoints = array[TSegmentPointIndex] of TPoint;

  TSegmentPos = (spTop, spCentre, spBottom, spTopLeft, spTopRight,
    spBottomLeft, spBottomRight);

  TFontData = record
    Width: Word;
    Height: Word;
    Spacing: Word;
    Thickness: Byte;
    Segments: array[TSegmentPos] of TSegmentCoords;
  end;

  TDigitCount = 1..32;
  TDigitScale = 1..100;

  TDigit = array[TSegmentPos] of TSegmentPoints;

  TNumeralSystem = (nsBinary, nsOctal, nsDecimal, nsHexadecimal);

  EDigiLabelError = class(EComponentError);

  TCustomDigiLabel = class(TGraphicControl)
  private
    FAlignment: TAlignment;
    FDigitColor: TColor;
    FDigitFont: TFontName;
    FDigitGrayColor: TColor;
    FDigits: array of TDigit;
    FDigitScale: TDigitScale;
    FDisplayNumeralSystem: TNumeralSystem;
    FFontData: TFontData;
    FLayout: TTextLayout;
    FOnMouseLeave: TNotifyEvent;
    FOnMouseEnter: TNotifyEvent;
    FRealignDigitsNeeded: Boolean;
    FValue: Int64;
    function GetDigitCount: TDigitCount;
    function GetTransparent: Boolean;
    procedure RealignDigits;
    procedure ReloadFontData;
    procedure SetAlignment(Value: TAlignment);
    procedure SetDigitColor(Value: TColor);
    procedure SetDigitCount(Value: TDigitCount);
    procedure SetDigitFont(const Value: TFontName);
    procedure SetDigitGrayColor(Value: TColor);
    procedure SetDigitScale(Value: TDigitScale);
    procedure SetDisplayNumeralSystem(Value: TNumeralSystem);
    procedure SetLayout(Value: TTextLayout);
    procedure SetTransparent(Value: Boolean);
    procedure SetValue(Value: Int64);
    procedure CMMouseEnter(var Message: TMessage); message CM_MOUSEENTER;
    procedure CMMouseLeave(var Message: TMessage); message CM_MOUSELEAVE;
  protected
    function GetTextHeight: Integer;
    function GetTextWidth: Integer;
    property Alignment: TAlignment read FAlignment write SetAlignment
      default taCenter;
    property DigitColor: TColor read FDigitColor write SetDigitColor
      default clYellow;
    property DigitCount: TDigitCount read GetDigitCount write SetDigitCount
      default 4;
    property DigitFont: TFontName read FDigitFont write SetDigitFont;
    property DigitGrayColor: TColor read FDigitGrayColor
      write SetDigitGrayColor default $00004040;
    property DigitScale: TDigitScale read FDigitScale write SetDigitScale
      default 1;
    property DisplayNumeralSystem: TNumeralSystem read FDisplayNumeralSystem
      write SetDisplayNumeralSystem default nsDecimal;
    property Layout: TTextLayout read FLayout write SetLayout default tlCenter;
    property OnMouseEnter: TNotifyEvent read FOnMouseEnter write FOnMouseEnter;
    property OnMouseLeave: TNotifyEvent read FOnMouseLeave write FOnMouseLeave;
    property Transparent: Boolean read GetTransparent write SetTransparent
      default False;
    property Value: Int64 read FValue write SetValue default 0;
  protected
    function CanAutoSize(var NewWidth, NewHeight: Integer): Boolean; override;
    function CanResize(var NewWidth, NewHeight: Integer): Boolean; override;
    procedure ChangeScale(M, D: Integer); override;
    procedure Paint; override;
    property Color default clBlack;
    property ParentColor default False;
  public
    procedure DecValue(DecBy: Integer = 1);
    class function GetDigitFontNames: TStrings;
    procedure IncValue(IncBy: Integer = 1);
  public
    constructor Create(AOwner: TComponent); override;
    function GetControlsAlignment: TAlignment; override;
    procedure Invalidate; override;
  end;

  TNLDDigiLabel = class(TCustomDigiLabel)
  published
    property Align;
    property Alignment;
    property Anchors;
    property AutoSize;
    property Color;
    property Constraints;
    property Cursor;
    property DigitColor;
    property DigitCount;
    property DigitFont;
    property DigitGrayColor;
    property DigitScale;
    property DisplayNumeralSystem;
    property DragCursor;
    property DragKind;
    property DragMode;
    property Height;
    property Hint;
    property Layout;
    property Left;
    property ParentColor;
    property ParentShowHint;
    property PopupMenu;
    property ShowHint;
    property Top;
    property Transparent;
    property Value;
    property Visible;
    property Width;
    property OnClick;
    property OnContextPopup;
    property OnDblClick;
    property OnDragDrop;
    property OnDragOver;
    property OnEndDock;
    property OnEndDrag;
    property OnMouseDown;
    property OnMouseEnter;
    property OnMouseMove;
    property OnMouseLeave;
    property OnMouseUp;
    property OnStartDock;
    property OnStartDrag;
  end;

implementation

{$R DigitFonts.res}

{ TCustomDigiLabel }

resourcestring
  SErrFontsMissing = 'Unable to create NLDDigiLabel control:' +
    #10#13#10#13'There are no digital font resources found.';
  SErrResCorruptF = 'Unable to load NLDDigiLabel font %s due to ' +
    'corrupt resource data.';

type
  //Each array-element represents combined boolean bits at the binary places
  //and in the numerical order of the digits -9876543210, each bit telling
  //whether the segment at the array-index lights up for that digit
  TSegmentShow = array[TSegmentPos] of Integer;

const
  DefResourceType = 'DIGITFONT';
  DefNumeralSystemBase: array[TNumeralSystem] of Integer = (2, 8, 10, 16);
  DefSegmentShow: TSegmentShow =
              //Digits:        -FEdCbA9876543210
    ( 55277,  //spTop:         01101011111101101
     126844,  //spCentre:      11110111101111100
      31597,  //spBottom:      00111101101101101
      57201,  //spTopLeft:     01101111101110001
      10143,  //spTopRight:    00010011110011111
      64837,  //spBottomLeft:  01111110101000101
      12283); //spBottomRight: 00010111111111011

var
  DigitFontNames: TStrings;

function TCustomDigiLabel.CanAutoSize(var NewWidth,
  NewHeight: Integer): Boolean;
begin
  NewWidth := GetTextWidth + (FDigitScale * 2 * FFontData.Thickness);
  NewHeight := GetTextHeight + (FDigitScale * 2 * FFontData.Thickness);
  if AutoSize and ((NewWidth <> Width) or (NewHeight <> Height)) then
    FRealignDigitsNeeded := True;
  Result := True;
end;

function TCustomDigiLabel.CanResize(var NewWidth, NewHeight: Integer): Boolean;
begin
  Result := inherited CanResize(NewWidth, NewHeight);
  if Result and ((NewWidth <> Width) or (NewHeight <> Height)) then
    FRealignDigitsNeeded := True;
end;

procedure TCustomDigiLabel.ChangeScale(M, D: Integer);
var
  NewScale: Integer;
begin
  inherited;
  NewScale := MulDiv(FDigitScale, M, D);
  if NewScale < Low(TDigitScale) then
    NewScale := Low(TDigitScale)
  else if NewScale > High(TDigitScale) then
    NewScale := High(TDigitScale);
  SetDigitScale(NewScale);
end;

procedure TCustomDigiLabel.CMMouseEnter(var Message: TMessage);
begin
  inherited;
  if Assigned(FOnMouseEnter) then
    FOnMouseEnter(Self);
end;

procedure TCustomDigiLabel.CMMouseLeave(var Message: TMessage);
begin
  inherited;
  if Assigned(FOnMouseLeave) then
    FOnMouseLeave(Self);
end;

constructor TCustomDigiLabel.Create(AOwner: TComponent);
begin
  if GetDigitFontNames.Count <= 0 then
    raise EDigiLabelError.Create(SErrFontsMissing);
  inherited;
  Color := clBlack;
  ControlStyle := ControlStyle + [csOpaque];
  FAlignment := taCenter;
  FDigitColor := clYellow;
  FDigitGrayColor := $00004040;
  FDigitScale := 1;
  FDisplayNumeralSystem := nsDecimal;
  FLayout := tlCenter;
  SetDigitFont(GetDigitFontNames[0]);
  SetDigitCount(4);
  Width := GetTextWidth + (2 * FFontData.Thickness);
  Height := GetTextHeight + (2 * FFontData.Thickness);
end;

procedure TCustomDigiLabel.DecValue(DecBy: Integer = 1);
begin
  Dec(FValue, DecBy);
  Invalidate;
end;

function TCustomDigiLabel.GetControlsAlignment: TAlignment;
begin
  Result := FAlignment;
end;

function TCustomDigiLabel.GetDigitCount: TDigitCount;
begin
  Result := Length(FDigits);
end;

class function TCustomDigiLabel.GetDigitFontNames: TStrings;
  function EnumResNamesProc(hModule: Cardinal; lpszType, lpszName: PChar;
    LParam: Integer): BOOL; stdcall;
  begin
    DigitFontNames.Add(lpszName);
    Result := True;
  end;
begin
  if DigitFontNames = nil then
  begin
    DigitFontNames := TStringList.Create;
    EnumResourceNames(HInstance, DefResourceType, @EnumResNamesProc, 0);
  end;
  Result := DigitFontNames;
end;

function TCustomDigiLabel.GetTextHeight: Integer;
begin
  Result := FDigitScale * FFontData.Height;
end;

function TCustomDigiLabel.GetTextWidth: Integer;
begin
  Result := ((DigitCount - 1) * FFontData.Spacing) + FFontData.Width;
  Result := FDigitScale * Result;
end;

function TCustomDigiLabel.GetTransparent: Boolean;
begin
  Result := not (csOpaque in ControlStyle);
end;

procedure TCustomDigiLabel.IncValue(IncBy: Integer = 1);
begin
  Inc(FValue, IncBy);
  Invalidate;
end;

procedure TCustomDigiLabel.Invalidate;
begin
  if FRealignDigitsNeeded then
  begin
    RealignDigits;
    FRealignDigitsNeeded := False;
  end;
  inherited Invalidate;
end;

procedure TCustomDigiLabel.Paint;
var
  NumeralSystemBase: Integer;
  MinusValue: Integer;
  Remain: Int64;
  iDigit: Integer;
  DigitValue: Integer;
  Combine: Integer;
  iPos: TSegmentPos;
begin
  inherited;
  if not Transparent then
  begin
    Canvas.Brush.Color := Color;
    Canvas.Brush.Style := bsSolid;
    Canvas.FillRect(ClientRect);
  end;
  Canvas.Pen.Style := psClear;
  NumeralSystemBase := DefNumeralSystemBase[FDisplayNumeralSystem];
  MinusValue := DefNumeralSystemBase[High(TNumeralSystem)];
  Remain := Abs(FValue);
  for iDigit := DigitCount - 1 downto 0 do
  begin
    if (iDigit = 0) and (FValue < 0) then
      DigitValue := MinusValue //minus character
    else
      DigitValue := Remain mod NumeralSystemBase; //last digit
    Combine := 1 shl DigitValue;
    for iPos := Low(TSegmentPos) to High(TSegmentPos) do
    begin
      if (Combine and DefSegmentShow[iPos]) <> 0 then
        Canvas.Brush.Color := FDigitColor
      else
        Canvas.Brush.Color := FDigitGrayColor;
      Polygon(Canvas.Handle, FDigits[iDigit][iPos],
        High(TSegmentPointIndex) + 1);
    end;
    Remain := Remain div NumeralSystemBase;
  end;
end;

procedure TCustomDigiLabel.RealignDigits;
var
  Origin: TPoint;
  iDigit: Integer;
  iPos: TSegmentPos;
  iPoint: TSegmentPointIndex;
begin
  case Alignment of
    taLeftJustify:
      Origin.X := FDigitScale * FFontData.Thickness;
    taCenter:
      Origin.X := (ClientWidth - GetTextWidth) div 2;
    taRightJustify:
      Origin.X := ClientWidth - GetTextWidth -
        (FDigitScale * FFontData.Thickness);
  end;
  case Layout of
    tlTop:
      Origin.Y := FDigitScale * FFontData.Thickness;
    tlCenter:
      Origin.Y := (ClientHeight - GetTextHeight) div 2;
    tlBottom:
      Origin.Y := ClientHeight - GetTextHeight -
        (FDigitScale * FFontData.Thickness);
  end;
  for iDigit := 0 to DigitCount - 1 do
    for iPos := Low(TSegmentPos) to High(TSegmentPos) do
      for iPoint := Low(TSegmentPointIndex) to High(TSegmentPointIndex) do
      begin
        FDigits[iDigit][iPos][iPoint].X :=
          Origin.X +
          iDigit * FDigitScale * FFontData.Spacing +
          FDigitScale * FFontData.Segments[iPos][2 * iPoint];
        FDigits[iDigit][iPos][iPoint].Y :=
          Origin.Y +
          FDigitScale * FFontData.Segments[iPos][2 * iPoint + 1];
      end;
end;

procedure TCustomDigiLabel.ReloadFontData;
var
  Stream: TStream;
  Strings: TStrings;
  Coords: TStrings;
  Data: TFontData;
  iPos: TSegmentPos;
  iCoord: TSegmentCoordIndex;
begin
  try
    Stream := TResourceStream.Create(HInstance, FDigitFont, DefResourceType);
    Strings := TStringList.Create;
    Coords := TStringList.Create;
    try
      Strings.LoadFromStream(Stream);
      Data.Width := StrToInt(Strings.Values['Width']);
      Data.Height := StrToInt(Strings.Values['Height']);
      Data.Spacing := StrToInt(Strings.Values['Spacing']);
      Data.Thickness := StrToInt(Strings.Values['Thickness']);
      for iPos := Low(TSegmentPos) to High(TSegmentPos) do
      begin
        Coords.Clear;
        Coords.CommaText :=
          Strings.Values['Pos' + IntToStr(Integer(iPos))];
        for iCoord := Low(TSegmentCoordIndex) to High(TSegmentCoordIndex) do
          Data.Segments[iPos][iCoord] := StrToInt(Coords[iCoord]);
      end;
    finally
      Coords.Free;
      Strings.Free;
      Stream.Free;
    end;
    FFontData := Data;
  except
    on EOutOfMemory do raise;
  else
    raise EDigiLabelError.CreateFmt(SErrResCorruptF, [FDigitFont]);
  end;
end;

procedure TCustomDigiLabel.SetAlignment(Value: TAlignment);
begin
  if FAlignment <> Value then
  begin
    FAlignment := Value;
    RealignDigits;
    Invalidate;
  end;
end;

procedure TCustomDigiLabel.SetDigitColor(Value: TColor);
begin
  if FDigitColor <> Value then
  begin
    FDigitColor := Value;
    Invalidate;
  end;
end;

procedure TCustomDigiLabel.SetDigitCount(Value: TDigitCount);
begin
  if (DigitCount <> Value) and (Value >= Low(TDigitCount)) and
    (Value <= High(TDigitCount)) then
  begin
    SetLength(FDigits, Value);
    FRealignDigitsNeeded := True;
    if AutoSize then
      AdjustSize
    else
      Invalidate;
  end;
end;

procedure TCustomDigiLabel.SetDigitFont(const Value: TFontName);
begin
  if FDigitFont <> Value then
    if GetDigitFontNames.IndexOf(Value) = -1 then
    begin
      if csDesigning in ComponentState then
        MessageBeep(MB_ICONEXCLAMATION);
    end
    else
    begin
      FDigitFont := Value;
      ReloadFontData;
      FRealignDigitsNeeded := True;
      if AutoSize then
        AdjustSize
      else
        Invalidate;
    end;
end;

procedure TCustomDigiLabel.SetDigitGrayColor(Value: TColor);
begin
  if FDigitGrayColor <> Value then
  begin
    FDigitGrayColor := Value;
    Invalidate;
  end;
end;

procedure TCustomDigiLabel.SetDigitScale(Value: TDigitScale);
begin
  if (FDigitScale <> Value) and (Value >= Low(TDigitScale)) and
    (Value <= High(TDigitScale)) then
  begin
    FDigitScale := Value;
    FRealignDigitsNeeded := True;
    if AutoSize then
      AdjustSize
    else
      Invalidate;
  end;
end;

procedure TCustomDigiLabel.SetDisplayNumeralSystem(Value: TNumeralSystem);
begin
  if FDisplayNumeralSystem <> Value then
  begin
    FDisplayNumeralSystem := Value;
    Invalidate;
  end;
end;

procedure TCustomDigiLabel.SetLayout(Value: TTextLayout);
begin
  if FLayout <> Value then
  begin
    FLayout := Value;
    RealignDigits;
    Invalidate;
  end;
end;

procedure TCustomDigiLabel.SetTransparent(Value: Boolean);
begin
  if GetTransparent <> Value then
  begin
    if Value then
      ControlStyle := ControlStyle - [csOpaque]
    else
      ControlStyle := ControlStyle + [csOpaque];
    Invalidate;
  end;
end;

procedure TCustomDigiLabel.SetValue(Value: Int64);
begin
  if FValue <> Value then
  begin
    FValue := Value;
    Invalidate;
  end;
end;

initialization

finalization
  if DigitFontNames <> nil then
    DigitFontNames.Free;

end.
