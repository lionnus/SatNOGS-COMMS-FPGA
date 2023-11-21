% Import the necessary library
import com.mathworks.toolbox.comm.*

% Input hexadecimal value
hexValue = '3FA598708734fe00ba349826400edfe6';

% Convert string of binary to array of binary data
inputBits = hexToBinArray(hexValue)

% Generator polynomials (in octal)
g = [171 133];

% Constraint length
constraint_length = 7;

% Create a trellis structure 
trellis = poly2trellis(constraint_length, g);

% Perform Convolutional Encoding
encodedBits = convenc(inputBits, trellis);
% Negate every second output bit
for i = 2:2:length(encodedBits)
    encodedBits(i) = ~encodedBits(i);
end
% Display the encoded bits as hexadecimal
disp(binArrayToHex(encodedBits));
 %% Short Binary Sequence
clc;
% Input binary value
inputBits = [ 1 1 1 0 1 1 1]

% Generator polynomials (in octal)
g = [171 133];

% Constraint length
constraint_length = 7;

% Create a trellis structure 
trellis = poly2trellis(constraint_length, g);


% Perform Convolutional Encoding
encodedBits = convenc(inputBits, trellis)

% Negate every second output bit
for i = 2:2:length(encodedBits)
    encodedBits(i) = ~encodedBits(i);
end
disp(encodedBits)
%% Text sequence: "HELLO,ITS-SAGE!"
clc;

% Input hexadecimal value
hexValue = '1ACFFC1D48454c4c4f2c4954532d534147452100';

% Convert string of binary to array of binary data
inputBits = hexToBinArray(hexValue);

% Generator polynomials (in octal)
g = [171 133];

% Constraint length
constraint_length = 7;

% Create a trellis structure 
trellis = poly2trellis(constraint_length, g);

% Perform Convolutional Encoding
encodedBits = convenc(inputBits, trellis);
% Negate every second output bit
for i = 2:2:length(encodedBits)
    encodedBits(i) = ~encodedBits(i);
end
% Display the encoded bits as hexadecimal
disp(encodedBits)
disp(binArrayToHex(encodedBits));