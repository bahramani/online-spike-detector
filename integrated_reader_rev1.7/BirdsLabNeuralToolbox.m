% In the name of Allah

classdef BirdsLabNeuralToolbox < BirdsLabNeuralToolboxUI
    properties
        rev = 1.1
        
        redis_client;
        fs;
        packet_length;        
        closing = false;

        neural_filter;
    end
    methods
        %         Constructor
        function this = BirdsLabNeuralToolbox(redis_client, fs,...
                packet_length, evnt_key, start_rds)
            
            this@BirdsLabNeuralToolboxUI();
            this.neural_filter = birdslab.online_filter(fs);
            this.update_filters();
            this.redis_client = redis_client;
            this.fs = fs;
            this.packet_length = packet_length;
                         
            pos = get(this.BirdsLabNeuralToolboxUIUIFigure, 'Position');
                         %    x1,     y1, width,  height
            set(this.BirdsLabNeuralToolboxUIUIFigure, 'Position', [50, 50, pos(3), pos(4)]);
            
            time_offset = 373.1;

            this.init_timescope(packet_length, time_offset);
            
            % Audio Device Initialization
            audioWriter = audioDeviceWriter(fs, 'BitDepth','32-bit float',...
                'SupportVariableSizeInput', true, 'BufferSize', packet_length);
            setup(audioWriter, zeros(packet_length, 1));
            
            this.PSTH_Plotter = birdslab.psth_plotter(this.redis_client, fs, evnt_key, start_rds);
            this.SpikeDetector = birdslab.spike_detector(this, fs, 0, this.PSTH_Plotter);
            this.set_detector_props();
            this.AudioPlayer = audioWriter;            
        end

        function init_timescope(this, packet_length, time_offset)
            scope = timescope(...
                'SampleRate', this.fs,...
                'TimeSpan', 0.2,...
                'BufferLength', packet_length, ...  
                'YLimits', [-150, 150], ... 
                'TimeSpanSource', 'property',...
                'TimeSpanOverrunAction', "Scroll");
                                     %    x1,     y1, width,  height
            set(scope, 'Position', [50, 1080/2 - 100,   750,    400]);
            scope.TimeDisplayOffset = time_offset;

            this.TimeScope = scope;
            
            sscope = dsp.SpectrumAnalyzer;
            sscope.SampleRate = this.fs;
            sscope.SpectralAverages = 10;
            sscope.PlotAsTwoSidedSpectrum = false;
            sscope.RBWSource = 'Auto';
            sscope.PowerUnits = 'dBW';

            this.SpectrumAnalyzer = sscope;


        end
        
        function update_filters(this)
            this.neural_filter.design_filters(this.flEditField.Value,...
                this.fhEditField.Value, ...
                this.FilterOrderEditField.Value, ...
                this.FilterCheckBox.Value,...
                this.HzFilterCheckBox.Value)
        end
        
        function set_detector_props(this)
            disp('hi');
            this.SpikeDetector.threshold_sign = this.ThresholdSignButtonGroup.SelectedObject.Text;
            this.SpikeDetector.threshold = this.ThresholduVSlider.Value;
            this.SpikeDetector.shown_spikes = this.ShownSpikesEditField.Value;
        end
        
%         function scans_available(this, src, evt)
% %             [data, timestamps, ~] = read(src, src.ScansAvailableFcnCount, "OutputFormat", "Matrix");
%             [data, timestamps, ~] = read(src, this.packet_length, "OutputFormat", "Matrix");
%             data = data(:, 1);
%             this.step(data*10);
%         end

function continue_working = step(this, data, redis_ts)            
            continue_working = true;
            if (~this.closing)
%             fprintf('TimeScopeSwitch: %s, SpikeDetectorSwitch: %s, SoundCheckBox: %d\n',...
%                 this.TimeScopeSwitch.Value, this.SpikeDetectorSwitch.Value, this.SoundCheckBox.Value);

                data = data';
                data = this.neural_filter.filter(data);

                if (this.SoundCheckBox.Value)
                    numUnderrun = this.AudioPlayer(data/300);
                end
    
                if (strcmp(this.TimeScopeSwitch.Value, 'On'))
                    this.TimeScope(data);
                end

                if (strcmp(this.SpectrumAnalyzerSwitch.Value, 'On'))
                    this.SpectrumAnalyzer(data);
                end
    
                if (strcmp(this.SpikeDetectorSwitch.Value, 'On'))
                    this.SpikeDetector.step(data, redis_ts);
                end
                
                if (true)
                    this.PSTH_Plotter.update_trigger(redis_ts);
                end
    
                drawnow limitrate;
            else
                continue_working = false;
            end
        end

        function closeme(this)
            this.closing = true;
            this.AudioPlayer.release();            
            this.SpikeDetector.close();
            this.delete();
        end

        function reset(this)
            this.SpikeDetector.reset();
            this.PSTH_Plotter.reset();
        end
    end
end