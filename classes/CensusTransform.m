classdef CensusTransform

    properties
        use_gradient
        win_size
    end

    methods
        function obj = CensusTransform(use_gradient,win_size)
            arguments
                use_gradient    (1,1) logical
                win_size        (1,1) {mustBePositive}
            end
            obj.use_gradient = use_gradient;
            obj.win_size = win_size;
        end

        function census_array = transform(obj,img)
%             img = im2gray(img);
            
            centre_index = ceil(obj.win_size/2);    % center position
            census_array = false([size(img), obj.win_size^2],'gpuArray');

            img_gray = im2gray(img);
            
            if obj.use_gradient
                [img_gradient,~] = imgradient(img_gray);
                img_padded = padarray(img_gradient,[centre_index-1 centre_index-1],0,'both');
            else
                img_padded = padarray(img,[centre_index-1 centre_index-1],0,'both');
            end
            
            page = 1;
            for hs = (centre_index-1):-1:(-(centre_index-1))
                for vs = (centre_index-1):-1:(-(centre_index-1))
                    img_padded_shifted = circshift(img_padded,[vs hs 0]);
                    census_array(:,:,page) = img_padded_shifted(centre_index:end-(centre_index-1),centre_index:end-(centre_index-1)) < img;
                    page = page+1;
                end
            end
        end
        
    end
end