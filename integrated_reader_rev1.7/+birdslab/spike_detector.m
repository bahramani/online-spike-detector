% In the name of Allah

classdef spike_detector < handle
    %SPIKE_PLOTTER Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        parent

        last_spike_id
        
        spike_detection_interval % ms - MUST GREATER THAN signal chunks
        spike_interval_overlap % ms - MUST GREATER THAN signal chunks
        fs
        PSTH_Plotter
        T
        
        threshold
        threshold_sign
        min_spike_distance
        
        % visualization
        shown_spikes
        time_before_spike
        time_after_spike
        fig_hndle_spike
        axs_hndle_spike
        fig_hndle_isi
        axs_hndle_isi

        isi_density_hndle

        % internal_buffer is a three column matrix
        % its first column contains samples timestamps
        % its second column saves whole packet redis_ts(rds)
        % its third column holds samples
        internal_buffer
        remained_samples_for_spike_detection
        remained_steps_to_draw
        
        recent_spike_count = 1000;
        detected_spikes = birdslab.spike(0, 0, 0, 0);
    end
    
    methods
        function this = spike_detector(parent, fs, first_sample_ts, PSTH_Plotter)
            this.parent = parent;
            this.last_spike_id = 0;
            this.fs = fs;
            this.PSTH_Plotter = PSTH_Plotter;
            this.T = 1/fs;
            this.spike_detection_interval = 150; % ms
            this.spike_interval_overlap = 10; % ms
            this.time_before_spike = 2.5; % ms
            this.time_after_spike = 3.5; % ms
            
            if ((this.time_before_spike + this.time_after_spike) >=...
                    this.spike_detection_interval)
                throw("spike_plotter.spike_plotter: time_before_spike + time_before_spike >= spike_detection_interval");
            end

            % #samples in one interval
            this.internal_buffer = zeros(this.spike_detection_interval/1000*this.fs, 3);
            this.internal_buffer(end, 1) = first_sample_ts;
            this.remained_steps_to_draw = inf;
            this.reset_remained_samples_for_spike_detection();
%             this.detected_spikes(1) = birdslab.spike(0, 0, 0);
            this.init_plots();

%             this.threshold = 0.3;
            this.min_spike_distance = 100;
            
            
            for i = 2:this.recent_spike_count
                this.detected_spikes(end+1) = birdslab.spike(0, 0, 0, 0);
            end
        end

        function init_plots(this)
            %% spikes plot
            this.fig_hndle_spike = figure;
                                            %    x1,     y1, width,  height
            set(this.fig_hndle_spike, 'Position', [860, 1080/2 - 100,   750,    400]);
            set(this.fig_hndle_spike, 'Name', ['Spike Detector - rev', num2str(this.parent.rev)]);
            set(this.fig_hndle_spike, 'NumberTitle', 'off');
            hold on;
            this.axs_hndle_spike = gca;
            xlim([1 this.time_before_spike/1000*this.fs+this.time_after_spike/1000*this.fs])
%             ylim([-1 1])
            title('Detected Spikes')
            xlabel('Samples')
            ylabel('Voltage')
            grid on
            grid minor
            

            %% ISI plot
            this.fig_hndle_isi = figure;
                                            %    x1,     y1, width,  height
            set(this.fig_hndle_isi, 'Position', [860, 50,   750,    300]);
            set(this.fig_hndle_isi, 'Name', ['ISI Plot - rev', num2str(this.parent.rev)]);
            set(this.fig_hndle_isi, 'NumberTitle', 'off');
            
            this.axs_hndle_isi = gca;
            xlim([0 200])
%             ylim([-1 1])
            title('Interspike Interval Histogram')
            xlabel('ISI [ms]')
            ylabel('PDF')
            grid on
            hold on;
%             grid minor


        end

        function reset_remained_samples_for_spike_detection(this)
            this.remained_samples_for_spike_detection =...
                length(this.internal_buffer)*(1 -...
                this.spike_interval_overlap/this.spike_detection_interval);
        end
%         data is 1xN matrix - contains N samples of ones channel data
        function step(this, data, redis_ts)
            if (isvector(data))
                this.remained_steps_to_draw = this.remained_steps_to_draw - 1;
                if (this.remained_steps_to_draw == 0)
                    this.draw();
                    this.remained_steps_to_draw = inf;
                end
                
                N = length(data);
                if (this.remained_samples_for_spike_detection - N <= 0)
                    this.detect_spikes();
                    this.remained_steps_to_draw = 15; % TODO
                end
                
                this.remained_samples_for_spike_detection =...
                    this.remained_samples_for_spike_detection - N;                
                
                % TODO: efficient ring buffer
                last_ts = this.get_last_timestamp();
                this.internal_buffer = circshift(this.internal_buffer, -N);
                this.internal_buffer((end-N+1):end, 3) = data;
                this.internal_buffer((end-N+1):end, 2) = redis_ts;
                this.internal_buffer((end-N+1):end, 1) =...
                    (last_ts + this.T):this.T:...
                    (this.internal_buffer(end-N, 1)+N*this.T);
            else
                throw("spike_plotter.step: data is not vector");
            end
        end
        
        function last_ts = get_last_timestamp(this)
            last_ts = this.internal_buffer(end, 1);
        end

        function draw(this)
            % spike history adjustment


%             for i = length(this.detected_spikes):-1:(1)
%                 if (this.detected_spikes(i).id ~= 0)
%                     this.detected_spikes(i).update(this.axs_hndle_spike,...
%                         this.last_spike_id, this.get_last_timestamp(), this.shown_spikes);
%                 end
%             end



            for i = 1:(length(this.detected_spikes))
                if (this.detected_spikes(i).id ~= 0)
                    this.detected_spikes(i).update(this.axs_hndle_spike,...
                        this.last_spike_id, this.get_last_timestamp(), this.shown_spikes);
                end
            end
% % % % %             this.plot_isi();

%             for i = length(this.detected_spikes):-1:(length(this.detected_spikes) - 20)
%                 this.detected_spikes(i).draw(this.fig_hndle);
%             end
%             if (length(this.detected_spikes)> 1)
%                 this.detected_spikes(end).draw(this.axs_hndle);
%             end
%             set(h, 'Color', [1, 0, 0]);
            drawnow limitrate;
        end
        
        function plot_isi(this)
            ids = [this.detected_spikes.id];
            if (sum(ids ~= 0) > 50)
                spike_times = [this.detected_spikes(ids ~= 0).timestamp];
                spike_isis = diff(spike_times);

                
                if (~isempty(this.isi_density_hndle))
                    delete(this.isi_density_hndle);
                end
                
                this.isi_density_hndle = histfit(this.axs_hndle_isi,...
                    spike_isis, [], 'gamma');
                this.isi_density_hndle(1).FaceColor = [.8 .8  1];
            end
        end

        function detect_spikes(this)
            this.reset_remained_samples_for_spike_detection();
            % fill overlap_history
            % use circshift with spike_interval_overlap
            
            % use findpeaks
            switch this.threshold_sign
                case 'Negative'
                    [amps, indices] = findpeaks(-1*(this.internal_buffer(...
                        (this.spike_interval_overlap/1000*this.fs):end, 3)),...
                        'MinPeakHeight', this.threshold,...
                        'MinPeakDistance', 1/1000*this.fs); %this.min_spike_distance/1000*this.fs
                case 'Positive'
                    [amps, indices] = findpeaks(1*(this.internal_buffer(...
                        (this.spike_interval_overlap/1000*this.fs):end, 3)),...
                        'MinPeakHeight', this.threshold,...
                        'MinPeakDistance', 1/1000*this.fs); %this.min_spike_distance/1000*this.fs
                case 'Both'
                    [amps, indices] = findpeaks(abs(this.internal_buffer(...
                        (this.spike_interval_overlap/1000*this.fs):end, 3)),...
                        'MinPeakHeight', this.threshold,...
                        'MinPeakDistance', 1.5/1000*this.fs); %this.min_spike_distance/1000*this.fs
            end

            indices = indices + this.spike_interval_overlap/1000*this.fs;
            for i=1:length(amps)
                ind1 = (indices(i) - this.time_before_spike/1000*this.fs):indices(i);
                ind2 = (indices(i)+1):(indices(i) + this.time_after_spike/1000*this.fs);
                ind = [ind1, ind2];
                if ((max(ind) <= size(this.internal_buffer, 1)) &&...
                        (min(ind) >= 1))
                    this.last_spike_id = this.last_spike_id + 1;
                    
                    % TODO: efficient ring buffer                    
                    this.detected_spikes(1).dispose();                    
                    this.detected_spikes = circshift(this.detected_spikes, -1);
                    this.detected_spikes(end) = birdslab.spike(this.last_spike_id,...
                        this.internal_buffer(indices(i), 1),...
                        this.internal_buffer(indices(i), 2), amps(i)); %%%

                    this.detected_spikes(end).samples =...
                        this.internal_buffer(ind, 3);

                    % pass spike to the PSTH_Plotter
                    this.PSTH_Plotter.add_spike(this.detected_spikes(end));
                end
            end

            % extra check - this for can be deleted later
            ids = [this.detected_spikes.id];
            time_stamps = zeros(sum(ids ~= 0), 1);
            ind = find(ids ~= 0);
            for i = 1:length(ind)
                time_stamps(i) = this.detected_spikes(ind(i)).timestamp;
            end
            if (length(unique(time_stamps)) ~= length(time_stamps))
                error('duplicated spikes detected!');
            end
        end
        
        function close(this)
            close(this.fig_hndle_spike);
            close(this.fig_hndle_isi);
        end

        function reset(this)
            last_ts = this.internal_buffer(end , 1);
            this.internal_buffer = zeros(this.spike_detection_interval/1000*this.fs, 3);
            this.internal_buffer(end, 1) = last_ts;
            this.remained_steps_to_draw = inf;
            this.reset_remained_samples_for_spike_detection();
            
            for i = 1:this.recent_spike_count
                this.detected_spikes(i).dispose();
                this.detected_spikes(i) = birdslab.spike(0, 0, 0, 0);
            end
        end
    end
end

