classdef DataVkitti

    properties (Constant)
        DATA_ROOT = 'data/vkitti_2.0.3'
    end

    properties
        scene
        sample
        condition
        visibility
        atmos
        cropped_pixels
        camera

        left_clear
        right_clear
        left_foggy
        right_foggy
        left_depth
        right_depth
        left_disp
        right_disp

        asm
    end

    methods
        function obj = DataVkitti(scene, sample, condition, visibility, atmos, crop_method)
            arguments
                scene           {mustBeMember(scene, [1, 2, 6, 18, 20])}
                sample          {mustBeMember(sample, 0:836)}
                condition       {mustBeMember(condition, {'sunny', 'overcast', 'morning', 'sunset'})}
                visibility      (1, 1)
                atmos           (1, 3)
                crop_method     {mustBeMember(crop_method, {'none'})} = 'none'
            end
            obj.scene = scene;
            obj.sample = sample;
            obj.condition = condition;
            obj.visibility = visibility;
            obj.atmos = atmos;

            switch crop_method
                case 'none'
                    obj.cropped_pixels = [0, 0, 0, 0];
            end
            
            obj.camera = Camera('vkitti');

            obj.left_clear = obj.read_data('rgb', 'left');
            obj.right_clear = obj.read_data('rgb', 'right');
            obj.left_depth = obj.read_data('depth', 'left');
            obj.right_depth = obj.read_data('depth', 'right');

            obj.left_disp = obj.camera.depth_to_disp(obj.left_depth);
            obj.right_disp = obj.camera.depth_to_disp(obj.right_depth);

            % set disparity values at inf depth as -1
            obj.left_disp(obj.left_depth == 655.35) = -1;
            obj.right_disp(obj.right_depth == 655.35) = -1;
            
            obj = obj.synth_foggy;
        end

        function img = read_data(obj, rgb_or_depth, left_or_right)
            if strcmp(obj.condition, 'sunny'), condition_str = 'clone'; else, condition_str = obj.condition; end
            if strcmp(left_or_right, 'left'), zero_or_one = '0'; else, zero_or_one = '1'; end
            if strcmp(rgb_or_depth, 'rgb'), ext = '.jpg'; else, ext = '.png'; end
            
            full_file = fullfile(DataVkitti.DATA_ROOT, ...
                                 strcat('vkitti_2.0.3_', rgb_or_depth), ...
                                 sprintf('Scene%02d', obj.scene), ...
                                 condition_str, ...
                                 'frames', ...
                                 rgb_or_depth, ...
                                 strcat('Camera_', zero_or_one), ...
                                 strcat(rgb_or_depth, sprintf('_%05d', obj.sample), ext));
            if strcmp(rgb_or_depth, 'rgb')
                img = im2double(imread(full_file));
            else
                img = double(imread(full_file)) / 100;  % from cm to m
            end
        end

        function obj = synth_foggy(obj)
            obj.asm = AtmosScatteringModel(obj.visibility, obj.atmos);

            left_dist = obj.camera.depth_to_dist(obj.left_depth);
            left_trans = obj.asm.dist_to_trans(left_dist);
            obj.left_foggy = obj.asm.clear_to_foggy(obj.left_clear, left_trans);

            right_dist = obj.camera.depth_to_dist(obj.right_depth);
            right_trans = obj.asm.dist_to_trans(right_dist);
            obj.right_foggy = obj.asm.clear_to_foggy(obj.right_clear, right_trans);
        end
    end
end