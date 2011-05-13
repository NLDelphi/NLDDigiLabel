unit NLDDigiLabelReg;

interface

uses
  Classes, NLDDigiLabel, DesignIntf, Graphics, NLDDigiLabelEdit;

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('NLDelphi', [TNLDDigiLabel]);
  RegisterPropertyEditor(TypeInfo(TFontName), TNLDDigiLabel, 'DigitFont',
    TDigitFontProperty);
end;

end.
