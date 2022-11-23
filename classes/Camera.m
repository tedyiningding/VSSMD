classdef Camera

    properties (Constant)
        NAMES =     {'pad',         'vkitti',   'frida3'}
        BASELINES = [0.202993,      0.532725,   0.5]
        FXS =       [2355.722801,   725.0087,   700]
        FYS =       [2355.722801,   725.0087,   700]
        CXS =       [988.138054,    620.5,      320]
        CYS =       [508.051838,    187.0,      240]
        HEIGHTS =   [1024,          375,        480]
        WIDTHS =    [1920,          1242,       640]
    end

    properties
        name
        baseline
        fx
        fy
        cx
        cy
        height
        width
    end

    methods
        function obj = Camera(name)
            ind = find(strcmp(name, Camera.NAMES));
            assert(~isempty(ind), 'invalid camera name!')
            
            obj.name = name;
            obj.baseline = Camera.BASELINES(ind);
            obj.fx = Camera.FXS(ind);
            obj.fy = Camera.FYS(ind);
            obj.cx = Camera.CXS(ind);
            obj.cy = Camera.CYS(ind);
            obj.height = Camera.HEIGHTS(ind);
            obj.width = Camera.WIDTHS(ind);
        end
        
        function disparity = depth_to_disp(obj, depth)
            disparity = obj.baseline * obj.fx ./ depth;
        end

        function depth = disp_to_depth(obj, disparity)
            depth = obj.baseline * obj.fx ./ disparity;
        end

        function distance = depth_to_dist(obj, depth, options)
            arguments
                obj
                depth
                options.cropped_pixels = [0, 0, 0, 0]
            end
            top = options.cropped_pixels(1);
            bottom = options.cropped_pixels(2);
            left = options.cropped_pixels(3);
            right = options.cropped_pixels(4);
            assert(size(depth, 1) + top + bottom == obj.height ...
                && size(depth, 2) + left + right == obj.width, ...
                'input depth map size together with croped pixels has to be consistent with the original image size');
            depth_padded = zeros(obj.height, obj.width);
            depth_padded(top+1:end-bottom, left+1:end-right) = depth;
            [X, Y] = meshgrid(1:obj.width, 1:obj.height);
            distance_padded = depth_padded .* (sqrt((obj.fx^2 + (X - obj.cx).^2 + (Y - obj.cy).^2)) / obj.fx);
            distance = distance_padded(top+1:end-bottom, left+1:end-right);
        end

        function depth = dist_to_depth(obj, distance, options)
            arguments
                obj
                distance
                options.cropped_pixels = [0, 0, 0, 0]
            end
            top = options.cropped_pixels(1);
            bottom = options.cropped_pixels(2);
            left = options.cropped_pixels(3);
            right = options.cropped_pixels(4);
            assert(size(distance, 1) + top + bottom == obj.height ...
                && size(distance, 2) + left + right == obj.width, ...
                'input distance map size together with croped pixels has to be consistent with the original image size');
            distance_padded = zeros(obj.height, obj.width);
            distance_padded(top+1:end-bottom, left+1:end-right) = distance;
            [X, Y] = meshgrid(1:obj.width, 1:obj.height);
            depth_padded = distance_padded ./ (sqrt((obj.fx^2 + (X - obj.cx).^2 + (Y - obj.cy).^2)) / obj.fx);
            depth = depth_padded(top+1:end-bottom, left+1:end-right);
        end
    end


    methods (Static)
        function img_cropped = crop_image(img, pixels_to_crop)
          
            top = pixels_to_crop(1);
            bottom = pixels_to_crop(2);
            left = pixels_to_crop(3);
            right = pixels_to_crop(4);

            img_cropped = img(1+top:end-bottom, ...
                              1+left:end-right, ...
                              :);
        end
    end
end