classdef psth_plotter < handle
    %PSTH_PLOTTER Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        fig_hndle;
        axs_hndle;
        img_hndle;

        fig_hndle_psth;
        axs_hndle_psth;

        is_enable;
        
        redis_client;
        events_key;
        fs;

        recent_spike_count = 5000; % TODO
        spikes_history; % 3 by M matrix - where M is #spikes
                        % M is equal to recent_spike_count
                        % 1st column is redis time stamp
                        % 2nd column is spike id
                        % 3rd neuron id (in this version is always 0)
        spikes_ts
        spike_insertion_pointer = 1;

        
        fetch_events_from;
        recent_event_count = 100; % TODO        
%         events_history

        event_timer = uint64(0);
        event_fetch_interval = 1.2; % seconds

        time_zero_ind;
        max_unique_events = 8;
        event_map;
        raster_data; % M by T+2 matrix - where M is #event - T is # timebins
        raster_T;
%         last_processed_rds;
        % M is equal to recent_event_count
        time_before_event = 500; % ms
        time_after_event = 1500; % ms
        bin_timespan = 4; % ms
        raster_x_scale = 2;
        raster_y_scale = 4;
        bin_edges;

        color_map;
    end
    
    methods
        function this = psth_plotter(redis_client, fs, events_key, start_rds)
            this.redis_client = redis_client;
            this.fs = fs;
            this.events_key = events_key;
            this.fetch_events_from = start_rds;
            this.is_enable = true;
%             this.spikes_ts = zeros(this.recent_spike_count, 1, 'int64');
%             this.events_history = zeros(2, this.recent_event_count, 'int64');
            this.spikes_history = zeros(3, this.recent_spike_count, 'int64');
            
            this.bin_edges = (-this.time_before_event):this.bin_timespan:this.time_after_event;
            this.raster_T = length(this.bin_edges) - 1;
%             this.raster_T = (this.time_before_event+this.time_after_event)/this.bin_timespan;
            this.raster_data = zeros(this.recent_event_count, ...
                2 + this.raster_T, 'int64');

            [~, this.time_zero_ind] = min(abs(this.bin_edges - 0));
       
            
%             this.last_processed_rds = start_rds;
           % this.events_history(:, 2) = -1;
           this.Open();
        end

        function add_spike(this, spike)
            if (this.is_enable)
                this.spikes_history = circshift(this.spikes_history, [0, -1]);
                this.spikes_history(1, end) = spike.redis_ts;
                this.spikes_history(2, end) = spike.id;
                this.spikes_history(3, end) = 0;

%                 this.update_trigger();
            end
        end

        function update_trigger(this, current_rds)
            if (toc(this.event_timer) > this.event_fetch_interval)
                this.event_timer = tic;
                
                nof_new_events = this.check_for_new_events();
                if (nof_new_events > 0)
                    % updating this.raster_data
                    for i = 0:(nof_new_events + 3)
                        this.raster_data(end-i, 3:end) = 0;
                        event_ts = this.raster_data(end-i, 1);
                        ind1 = this.spikes_history(1, :) < event_ts + this.time_after_event;
                        ind2 = this.spikes_history(1, :) > event_ts - this.time_before_event;
                        ind = ind1 & ind2;

                        event_related_spikes = this.spikes_history(1, ind);
                        event_related_spikes = event_related_spikes - event_ts;

                        spike_counts = histcounts(event_related_spikes,...
                            this.bin_edges);
                        this.raster_data(end-i, 3:end) = spike_counts;
                    end

%                     last_rds = thirs.last_processed_rds;

                    
%                     this.last_processed_rds = current_rds;

                    % tODO: UPDATE PSTH PLOT
                    delete(this.img_hndle);
                    this.update_plots();
                end
            end
        end
        
        function nof_events = check_for_new_events(this)
            if this.is_enable
                events = this.redis_client.XRange2(this.events_key,...
                    this.fetch_events_from, "+", -1);
                nof_events = events.size();
                if (nof_events > 0)                    
                    % TODO must check order of events
                    for i = 1:nof_events
%                         disp(nof_events)
                        event = events.get(i-1);
                        if (strcmp(event.field, 'SimpleEvent'))
                            se = event.GetValueAsSimpleEvent();

                           rds = split(char(event.id), '-');
                           rds = str2double(rds{1});

                           this.raster_data = circshift(this.raster_data, [-1, 0]);
                           this.raster_data(end, 1) = rds;
                           this.raster_data(end, 2) = se.id; % simple event id
                           this.raster_data(end, 3:end) = 0;
                        end
                    end
                    this.fetch_events_from = [num2str(rds), '-2'];
                end
            end
        end

        function update_plots(this)
            I = uint8(this.raster_data(:, 3:end));
            [m ,n] = size(I);
            event_colored_image = double(this.raster_data(:, 2)) * ones(1, this.raster_T);
            ind = I > 0;
            I(ind) = event_colored_image(ind);
            I(:, this.time_zero_ind) = this.max_unique_events + 1;
            I = imresize(I, [m*this.raster_y_scale, n*this.raster_x_scale], 'box');
            this.img_hndle = imshow(I, this.color_map, 'Parent', this.axs_hndle);

           
%          psth plot update
            for i = 1:this.max_unique_events
                selected_event_ind = this.raster_data(:, 2) == i;
                if (any(selected_event_ind))
                    data = double(this.raster_data(selected_event_ind, 3:end));
                    plot(this.axs_hndle_psth,...
                        this.bin_edges(2:end),...
                        movmean(mean(data), 100)/(this.bin_timespan/1000),...
                        'Color', this.color_map(i+1, :), 'DisplayName',...
                        ['Event ' num2str(i)]);


                    xlim(this.axs_hndle_psth, [-this.time_before_event this.time_after_event])
                    title(this.axs_hndle_psth, 'Peri-Stimulus Time Histogram')
                    xlabel(this.axs_hndle_psth, 'time [ms]')
                    ylabel(this.axs_hndle_psth, 'Firing rate [Hz]')
                    grid(this.axs_hndle_psth,'minor')
                    

                    hold(this.axs_hndle_psth, 'on');
                end
            end
%             [] = max(get(this.axs_hndle_psth, 'YLim'));

%             stem(this.axs_hndle_psth, 0, max(max_mins(:, 1))*1.1, 'r',...
%                 'Marker', 'none', 'DisplayName', '');
            xline(this.axs_hndle_psth, 0, 'DisplayName', 'Onset');
            hold(this.axs_hndle_psth, 'off');
            grid(this.axs_hndle_psth, 'minor');
            legend(this.axs_hndle_psth, 'show');
            drawnow limitrate;
        end

%         function set_fetch_events_from(this)
%             [secs, micros] = redis.time(this.redis_client);
%             this.fetch_events_from = [secs,  micros(1:3)];
%         end

        function init_plots(this)
            % colors
%             this.color_map = colorcube(this.max_unique_events);
            this.color_map = hsv(this.max_unique_events + 1);
            this.color_map = circshift(this.color_map, [-1, 0]);
            this.color_map = [0.8, 0.8, 0.8;
                this.color_map];            
            
%             axis on;
%             xlabel('milliseconds');
%             
% %             ind = 1:((length(this.bin_edges) - 1)*this.raster_x_scale);
% %             ind = ind(1:floor(length(ind)/10):end);
% %             xticks(ind);
% %             xticklabels(this.bin_edges(ind));
% 
%             hold on;
% %             this.color_map = [0.8, 0.8, 0.8;
% %                 this.color_map;
% %                 1   .0  .0];
% 
%             set(this.fig_hndle, 'Name', 'Raster Plotter');
%             set(this.fig_hndle, 'NumberTitle', 'off');      



            %% psth plot
            this.fig_hndle_psth = figure;
                                            %    x1,     y1, width,  height
            set(this.fig_hndle_psth, 'Position', [860, 1080/2 - 100,   750,    400]);
            set(this.fig_hndle_psth, 'Name', ['PSTH']);
            set(this.fig_hndle_psth, 'NumberTitle', 'off');

            this.axs_hndle_psth = gca;
            xlim([-this.time_before_event this.time_after_event])
            title('Peri-Stimulus Time Histogram')
            xlabel('time [ms]')
            ylabel('Firing rate [Hz]')
            grid on
            grid minor


            this.update_plots();
        end

        function Open(this)
            this.is_enable = true;
            this.fig_hndle = figure;
%             imshow(this.raster_data, 'Parent', this.axs_hndle);
            this.axs_hndle = gca;
                                            %    x1,     y1, width,  height
%             set(this.fig_hndle, 'Position', [860, 1080/2 - 100,   750,    400]);
            

%             this.set_fetch_events_from();
            this.init_plots();
            %TODO - open figures and set handles
        end

        function Close(this)
            this.is_enable = false;
            %TODO - close figures and empty handles
        end

        function reset(this)
            this.spikes_history = zeros(3, this.recent_spike_count, 'int64');
            this.raster_data = zeros(this.recent_event_count, ...
                2 + this.raster_T, 'int64');
            this.update_plots();
            T = this.bin_edges(2:end);
            y = zeros(size(T));
            plot(this.axs_hndle_psth,T, y);
        end
    end
end

