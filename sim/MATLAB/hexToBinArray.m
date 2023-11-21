% Define function to transform hex to binary
function binArray = hexToBinArray(hexValue)
    % Convert each hex digit to binary and concatenate
    binValue = '';
    for i = 1:length(hexValue)
        binValue = [binValue, dec2bin(hex2dec(hexValue(i)), 4)];
    end
    % Convert string of binary to array of binary data
    binArray = arrayfun(@(x) str2double(x), binValue);
end