classdef online_filter < handle
    %ONLINE_FILTER Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        fs;        
        zf = []; % final state of filter

        selected_filer;
        selected_filer_a;
        selected_filer_b;
        do_filter;

    end
    
    methods
        function this = online_filter(fs)
            this.fs = fs;
        end
        
        
        function design_filters(this, fl, fh, order, en_bpFilt, en_notch_50hz)
            bpFilt = designfilt('bandpassiir', 'FilterOrder', order, ...
                'PassbandFrequency1', fl,'PassbandFrequency2', fh, ...
                'SampleRate', this.fs);

            notch_50hz = designfilt('bandstopiir','FilterOrder', 6, ...
                'StopbandFrequency1',48,'StopbandFrequency2',52, ...
                'SampleRate',this.fs);

            [b1, a1] = tf(bpFilt);
            [b2, a2] = tf(notch_50hz);
                        
            this.do_filter = true;
            if (en_bpFilt) && (en_notch_50hz)
                this.selected_filer_b = b1;
                this.selected_filer_a = a1;
            elseif (~en_bpFilt) && (en_notch_50hz)
                this.selected_filer_b = b2;
                this.selected_filer_a = a2;
            elseif (en_bpFilt) && (~en_notch_50hz)
                this.selected_filer_b = b1;
                this.selected_filer_a = a1;
            else
                this.do_filter = false;
            end

            this.zf = [];
        end

        function filtered_data = filter(this, data)
            if (this.do_filter)
                if (isempty(this.zf))
                    [filtered_data, this.zf] =...
                        filter(this.selected_filer_b, this.selected_filer_a, data);
                else
                    [filtered_data, this.zf] =...
                        filter(this.selected_filer_b, this.selected_filer_a, data, this.zf);
                end
            else
                filtered_data = data;
            end
        end
    end
end

