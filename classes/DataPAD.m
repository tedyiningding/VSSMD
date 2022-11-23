classdef DataPAD
    
    properties (Constant)
        DATA_ROOT = 'data/pad'
    end

    properties
        scene
        sample
        visibility
        cropped_pixels
        mode
        camera
        
        left_clear
        right_clear
        left_foggy
        right_foggy
        
        left_depth
        left_disp
    end

    methods
        function obj = DataPAD(scene, sample, visibility, crop_method, mode)
            arguments
                scene           {mustBeMember(scene, 1:3)}
                sample          {mustBeMember(sample, 0:9)}
                visibility      {mustBeMember(visibility, {'fog20', 'fog25', 'fog30', 'fog35', 'fog40'})}
                crop_method     {mustBeMember(crop_method, {'gruber', 'tunnel', 'stereo', 'stereo evaluate', 'none'})} = 'stereo'
                mode            {mustBeMember(mode, {'real', 'synth'})} = 'real'
            end
            obj.scene = scene;
            obj.sample = sample;
            obj.visibility = char(visibility);
            obj.mode = mode;
            
            switch crop_method
                case 'gruber'
                    obj.cropped_pixels = Constant.ORIGINAL_TO_GRUBER;                    
                case 'tunnel'
                    obj.cropped_pixels = Constant.ORIGINAL_TO_TUNNEL;
                case 'stereo'
                    obj.cropped_pixels = Constant.ORIGINAL_TO_STEREO;                
                case 'stereo evaluate'
                    obj.cropped_pixels = Constant.STEREO_TO_TUNNEL;
                case 'none'
                    obj.cropped_pixels = [0, 0, 0, 0];
            end

            obj.camera = Camera('pad');
            
            % always read clear intensity images and depth
            obj.left_clear = Camera.crop_image(obj.read_intensity('left', 'clear'), obj.cropped_pixels);
            obj.right_clear = Camera.crop_image(obj.read_intensity('right', 'clear'), obj.cropped_pixels);
            obj.left_depth = Camera.crop_image(obj.read_depth, obj.cropped_pixels);
            obj.left_disp = obj.camera.depth_to_disp(obj.left_depth);

            % read foggy intensity images if required
            if ~strcmp(obj.visibility, 'clear')
                visibility_char = obj.visibility;
                obj.visibility = str2double(obj.visibility(4:end));    % only extract the number (e.g. 'fog20' -> 20.0)
                if strcmp(obj.mode, 'real')
                   obj.left_foggy = Camera.crop_image(obj.read_intensity('left', visibility_char), obj.cropped_pixels);
                   obj.right_foggy = Camera.crop_image(obj.read_intensity('right', visibility_char), obj.cropped_pixels);
                end
            else
                obj.visibility = Inf;
            end
        end

        function img = read_intensity(obj, left_or_right, clear_or_foggy)
            full_file = fullfile(DataPAD.DATA_ROOT, ...
                                 strjoin({'rgb', left_or_right, '8bit'}, '_'), ...
                                 strjoin({['scene', num2str(obj.scene)], 'day', clear_or_foggy, [num2str(obj.sample), '.png']}, '_'));
            img = im2double(imread(full_file));
        end

        function img = read_depth(obj)
            full_file = fullfile(DataPAD.DATA_ROOT, ...
                                'intermetric_rgb_left', ...
                                ['scene', num2str(obj.scene), '.mat']);
            img = load(full_file);
            img = double(img.arr_0);
        end
    end
end