% In the name of Allah
% 1401-05-22
% raw-reader

clear all;
clear java;
close all;


javaaddpath(fullfile(pwd, 'java_libs', 'BirdsLabTools_rev0.6.jar'));
redis = ir.ac.ipm.scs.birdslab.redis.RedisClient("192.168.131.73", int32(6379));
st_key = "Exp_1401_08_04_002";


events = redis.XRange2(st_key, "-", "+", -1);
events.size()
for i = 1:events.size()
    event = events.get(i-1);
    if (strcmp(event.field, 'SimpleEvent'))
        se = event.GetValueAsSimpleEvent();
        disp(char(event.id) + ", " + num2str(se.id));
    end
end