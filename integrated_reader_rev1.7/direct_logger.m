% In the name of Allah
% 1401-04-30
% raw-reader


clear all;
close all;

if (exist('blnt','var'))
    blnt.close();
end
warning('off', 'signal:findpeaks:largeMinPeakHeight');

fs = 20000;
packet_length = 30;


blnt = BirdsLabNeuralToolbox(fs, packet_length);


delete(instrfindall); % Reset Com Port
delete(timerfindall); % Delete Timers

Ref = 0.6;
analog_gain = 200;
digital_gain = 2;
gain = analog_gain*digital_gain;
resolution  = 12;
m = 1;
R = (resolution-m);
D2A = Ref/((2^(R))*gain);


COM_PORT = "COM4";
serial_port = serial(COM_PORT);
serial_port.InputBufferSize = 242*100;
fopen(serial_port);



raw_data = fread(serial_port, 242);
ble_cntr = raw_data(end);
last_usb_cntr = raw_data(1);
last_ble_cntr = raw_data(end);
cntr = 0;
data_chunk = zeros(4, 30); % four channels, 30 samples
while true
    raw_data = fread(serial_port, 242);
    usb_cntr = raw_data(1);
    ble_cntr = raw_data(end);
    if (ble_cntr == last_ble_cntr)
        if (mod(last_usb_cntr + 1, 256) == usb_cntr)
            for ch = 1:4
                ind1 = (2:8:241) + ch - 1;
                ind2 = (3:8:241) + ch - 1;
                data_chunk(ch, :) = raw_data(ind2)*256+raw_data(ind1);
                ind = raw_data(ind2) > 15;
                data_chunk(ch, ind) = data_chunk(ch, ind) - 65536;
            end
            data_chunk = data_chunk*D2A*1000;
            blnt.step(data_chunk(1, :)');
        else
            fprintf('USB loss %d %d\n', last_usb_cntr, usb_cntr);
        end
    else
        fprintf('BLE loss\n');
    end
%     fprintf('cntr: %d, length:%d \n', usb_cntr, length(raw_data));
    last_usb_cntr = usb_cntr;
    last_ble_cntr = ble_cntr;
end

fclose(serial_port);
delete(serial_port);