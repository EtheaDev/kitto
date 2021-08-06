{###############################################################################
                      https://github.com/wendelb/DelphiOTP
###############################################################################}
unit Base32U;

{

================================================================================
If you found this Unit as your were looking for a delphi Base32 Implementation,
that is also unicode ready, please see the Readme!
================================================================================

}

interface

uses
  System.SysUtils;  // For UpperCase (Base32Decode)

type
  Base32 = class
  public
    /// <param name="inString">
    ///   Base32-String (Attention: No validity checks)
    /// </param>
    /// <summary>
    ///   Decodes a Base32-String
    /// </summary>
    /// <returns>
    ///   Unicode String containing the ANSI-Data from that Base32-Input
    /// </returns>
    class function Decode(const inString: String): String;

    /// <param name="inString">
    ///   UTF8-String (Attention: No validity checks)
    /// </param>
    /// <summary>
    ///   Encodes a UTF-8String into a Base32-String
    /// </summary>
    /// <returns>
    ///   Unicode string containing the Base32 string encoded from that UTF8-Input
    /// </returns>
    class function Encode(const InString: UTF8String): string;

    /// <summary>
    ///   Same as Encode but cleans up the trailing "=" at the end of the string.
    /// </summary>
    class function EncodeWithoutPadding(const InString: UTF8String): string;
  end;

// As the FromBase32String Function doesn't has the result I'm looking for, here
// is my version of that function. This is converted from a PHP function, which
// can be found here: https://www.idontplaydarts.com/2011/07/google-totp-two-factor-authentication-for-php/
const
  ValidChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

implementation

uses
  System.Math;

{$REGION 'Base32Functions'}


function Base32Decode(const source: String): String;
var
  UpperSource: String;
  p, i, l, n, j: Integer;
begin
  UpperSource := UpperCase(source);

  l := Length(source);
  n := 0; j := 0;
  Result := '';

  for i := 1 to l do
  begin
    n := n shl 5; 				// Move buffer left by 5 to make room

    p := Pos(UpperSource[i], ValidChars);
    if p >= 0 then
      n := n + (p - 1);         // Add value into buffer

		j := j + 5;				// Keep track of number of bits in buffer

    if (j >= 8) then
    begin
      j := j - 8;
      Result := Result + chr((n AND ($FF shl j)) shr j);
    end;
  end;
end;


function Base32Encode(str: UTF8String): string;
var
  B: Int64;
  i, j, len: Integer;
begin
  Result := '';
     // Every 5 characters are encoded in groups (5 characters x8 = 40 bits, 5 * 8 characters = 40 bits, and each character of BASE32 is represented by 5 bits)
  len := length(str);
  while len > 0 do
  begin
    if len >= 5 then
      len := 5;
         // Store the ASCII codes of these 5 characters in order into Int64 (8 bytes in total) integer
    B := 0;
    for i := 1 to len do
      B := B shl 8 + Ord (str [i]); // Store a character, shift one byte to the left (8 bits)
    B := B shl ((8-len) * 8); // Finally shift left 3 bytes (3 * 8)
    j := system.Math.ceil(len * 8 / 5);
         // Encoding, every 5 digits represent a character, 8 characters are exactly 40 digits
    for i := 1 to 8 do
    begin
      if i <= j then
      begin
                 Result := Result + ValidChars [B shr 59 + 1]; // shift right 7 * 8 digits +3 digits, take characters from BASE32 table
                 B := B shl 5; // Shift 5 bits to the left each time
      end
      else
        Result := Result + '=';
    end;
         // Remove the processed 5 characters
    delete(str, 1, len);
    len := length(str);
  end;
end;

{$ENDREGION}

{ Base32 }

class function Base32.Decode(const inString: String): String;
begin
  Result := Base32Decode(inString);
end;

class function Base32.Encode(const inString: UTF8String): string;
begin
  Result := Base32Encode(inString);
end;

class function Base32.EncodeWithoutPadding(const InString: UTF8String): string;
begin
  Result := StringReplace(Base32Encode(inString),'=','',[rfReplaceAll]);
end;

end.
