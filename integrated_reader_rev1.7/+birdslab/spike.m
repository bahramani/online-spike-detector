% In the name of Allah

classdef spike < handle
    properties
        id
        timestamp
        amplitude
        samples
        redis_ts
        
        plot_handle
    end
    methods
        function obj = spike(id, timestamp, redis_ts, amplitude)
            obj.id = id;
            obj.timestamp = timestamp;
            obj.redis_ts = redis_ts;
            obj.amplitude = amplitude;
        end      


        function update(this, axs_hndle, last_spike_id, last_time_stamp, shown_spikes)
            if (isempty(this.plot_handle))
                if ((last_spike_id - this.id) < shown_spikes)
%                     this.plot_handle = plot(axs_hndle, this.samples, 'Color', [1, 0, 1, 1]);
                    this.plot_handle = plot(axs_hndle, this.samples, 'Color', [1, 0, 1]);
                end                
            else
                if ((last_spike_id - this.id) > shown_spikes)
                    delete(this.plot_handle);
                    this.plot_handle = [];
                else
                    % spike_age: [0, 1], 0 new born, 1 oldest spike (limited to shown_spikes)
                    spike_age = (last_spike_id - this.id)/shown_spikes;
%                     set(this.plot_handle, 'Color', [1, 0, 1, 1 - spike_age]);
                    set(this.plot_handle, 'Color', [1, 0, 1, 1 - spike_age]*(1-spike_age));
                end                
            end
        end

        function dispose(this)
            if (~isempty(this.plot_handle))
                delete(this.plot_handle);
%                 this.plot_handle = [];
                this.samples = [];
            end
        end
    end
end