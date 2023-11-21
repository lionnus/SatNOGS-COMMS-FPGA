function hexValue = binArrayToHex(binArray)
    % Convert array of binary data to string
    binString = num2str(binArray);
    binString = strrep(binString,' ','');

    % Ensure that the binary string length is a multiple of 4 by prepending zeros if necessary
    remainder = mod(length(binString), 4);
    if remainder ~= 0
        binString = [repmat('0', 1, 4 - remainder), binString];
    end

    % Convert each 4 binary digits to a hexadecimal digit
    hexValue = '';
    for i = 1:4:length(binString)
        binDigit = binString(i:i+3);
        decValue = bin2dec(binDigit);
        hexValue = [hexValue, dec2hex(decValue)];
    end
end
