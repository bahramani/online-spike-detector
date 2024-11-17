% In the name of Allah
% 1401-09-09
% raw-reader

clear all;
clear java;
close all;


javaaddpath(fullfile(pwd, 'java_libs', 'BirdsLabTools_rev0.6.jar'));
redis = ir.ac.ipm.scs.birdslab.redis.RedisClient("192.168.130.126", int32(6379));
redis2 = ir.ac.ipm.scs.birdslab.redis.RedisClient("192.168.130.126", int32(6379));
st_key = "neural_1401_09_09";
evnt_key = "Exp_1401_09_09_010";


if (exist('blnt','var'))
    blnt.close();
end
warning('off', 'signal:findpeaks:largeMinPeakHeight');



single_entry = redis.XReadUpcommingSingleField(st_key, 1000);
if (isempty(single_entry))
    warning("redis_logger: stream is not active or does not exists: " + st_key);
    return;
end
start_rds = single_entry.id;
sc = single_entry.GetValueAsSignalChunk();
fs = sc.fs;
packet_length = size(sc.data, 2);

blnt = BirdsLabNeuralToolbox(redis2, sc.fs, packet_length, evnt_key, start_rds);

% set number of channels
if (sc.M < 4)
    for i = 1:length(blnt.ChannelSelectionButtonGroup.Children)
        rdo_button = blnt.ChannelSelectionButtonGroup.Children(i);
        ch_index = str2double(strrep(rdo_button.Text, 'Channel ', ''));
        if (ch_index > sc.M)
            rdo_button.Enable = 'off';
        end
    end
end

if (exist('brdr','var'))
    brdr.Stop();
end

brdr = ir.ac.ipm.scs.birdslab.redis.RingBufferedDataReader(redis,...
    int32(150));

flag = brdr.StartSubscription(st_key, single_entry.id);
if (flag)
    disp("Reading data asynchronously started ...");
else
    disp("Continue last subscription ...");
    flag = true;
end

while(brdr.stream_entries.size() > 0)
    brdr.stream_entries.poll();
end
old_seq = sc.seq;
while (flag) % blnt active flag
    if (brdr.stream_entries.size() > 0)
        stream_entry = brdr.stream_entries.poll();
        sc = stream_entry.GetValueAsSignalChunk();
        if (sc.seq ~= old_seq + 1)
            fprintf('cleaning buffer - old_seq = %d, new_seq = %d\n', old_seq, sc.seq);
%             brdr.stream_entries.clear();
            while(brdr.stream_entries.size() > 0)
                stream_entry = brdr.stream_entries.poll();
                sc = stream_entry.GetValueAsSignalChunk();
            end
        end
        old_seq = sc.seq;
        redis_ts = split(char(stream_entry.id), '-');
        redis_ts = str2double(redis_ts{1});
        cd = double(sc.data);
        slctd_chnl = str2double(strrep(...
            blnt.ChannelSelectionButtonGroup.SelectedObject.Text,...
            'Channel ', ''));
        flag = blnt.step(cd(slctd_chnl, :)*sc.coeff, redis_ts);
    end
end

% brdr.close();