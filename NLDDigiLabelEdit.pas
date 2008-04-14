unit NLDDigiLabelEdit;

interface

uses
  Classes, DesignEditors, DesignIntf;

type
  TDigitFontProperty = class(TStringProperty)
  public
    function GetAttributes: TPropertyAttributes; override;
    procedure GetValues(Proc: TGetStrProc); override;
  end;

procedure Register;

implementation

uses
  NLDDigiLabel, Graphics;

procedure Register;
begin
  RegisterPropertyEditor(TypeInfo(TFontName), TNLDDigiLabel, 'DigitFont',
    TDigitFontProperty);
end;

{ TDigitFontProperty }

function TDigitFontProperty.GetAttributes: TPropertyAttributes;
begin
  Result := [paValueList, paSortList, paMultiSelect, paRevertable];
end;

procedure TDigitFontProperty.GetValues(Proc: TGetStrProc);
var
  i: Integer;
  FontNames: TStrings;
begin
  inherited;
  FontNames := TNLDDigiLabel.GetDigitFontNames;
  for i := 0 to FontNames.Count - 1 do
    Proc(FontNames[i]);
end;

end.
