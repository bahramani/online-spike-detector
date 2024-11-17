% In the name of Allah

clear all;
close all;

if (exist('blnt','var'))
    blnt.close();
end
warning('off', 'signal:findpeaks:largeMinPeakHeight');

fs = 30000;
packet_length = fs/10;




blnt = BirdsLabNeuralToolbox(fs, packet_length);

dq = daq("ni");
range = [-0.2, 0.2];
inp1 = addinput(dq, "Dev2", "ai0", "Voltage");
inp1.Range = range;
inp1.TerminalConfig = "Differential";
sub = inp1.Device.Subsystems;

inp2 = addinput(dq, "Dev2", "ai1", "Voltage");
inp2.Range = range;
inp3 = addinput(dq, "Dev2", "ai2", "Voltage");
inp3.Range = range;
% SingleEnded,SingleEndedNonReferenced,Differential
% -0.20 to +0.20 Volts,-1.0 to +1.0 Volts,-5.0 to +5.0 Volts,-10 to +10 Volts
inp4 = addinput(dq, "Dev2", "ai3", "Voltage");
inp4.Range = range;
dq.Rate = fs;
dq.ReadTimeout = 0.01;
dq.ScansAvailableFcn = @(src, evt) blnt.scans_available(src, evt);
% dq.ScansAvailableFcnCount = floor(fs/packet_length) + 1;
% start(dq, 'continuous');
start(dq, 'Duration', seconds(30));


while dq.Running
    pause(0.2)
    fprintf("While loop: Scans acquired = %d, Scans Available = %d\n", dq.NumScansAcquired, dq.NumScansAvailable)
end

% 
% 
% try
%     tic; i = 0;
%     while true 
%         i = i + 1;
%         [data, timestamps, triggertime] = read(dq, packet_length,...
%             'OutputFormat', 'Matrix');
%         data = data*100;
%         if (dq.NumScansAvailable > 3000)
%             [~, ~, ~] = read(dq, dq.NumScansAvailable - packet_length,...
%                 'OutputFormat', 'Matrix');
%             fprintf('clear buffer\n');
%         end        
%         if mod(i, 1) == 0
%             fprintf('Elapsed Time: %2.1fs, Writed Samples: %2.1fs, NumScansAvailable: %d\n',...
%                 toc, i*packet_length/fs, dq.NumScansAvailable);
%         end        
%         if (length(data) == packet_length)
%             blnt.step(data);
%         end
%     end
% catch ex
%     if (strcmp(ex.identifier, 'MATLAB:class:InvalidHandle'))
%         clear blnt;
%     else
%         disp(ex.stack(1));
%         throw(ex);        
%     end
% end
% stop(dq);

