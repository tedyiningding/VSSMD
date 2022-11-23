classdef AnisotropicDiffusionTensor

    properties
        guide_img
        magnitude
        sharpness
        use_lsd
    end

    methods
        function obj = AnisotropicDiffusionTensor(guide_img,magnitude,sharpness,use_lsd)
            arguments
                guide_img   (:,:,3) double {mustBeGreaterThanOrEqual(guide_img,0), mustBeLessThanOrEqual(guide_img,1)}
                magnitude   (1,1) double
                sharpness   (1,1) double
                use_lsd     (1,1) logical
            end
        
            obj.guide_img = guide_img;
            obj.magnitude = magnitude;
            obj.sharpness = sharpness;
            obj.use_lsd = use_lsd;
        end
        
        function operator = calc_operator(obj)
            if isempty(obj.guide_img)           % guide image is empty
                operator = @(p) p;        % use identity mapping
            else                            % guide image is not empty
                % calculate the tensor from the guide image
                [tensor_G, ~, ~] = calcTensor(gpuArray(im2gray(obj.guide_img)), [obj.magnitude, obj.sharpness], 2);
                aa_G = tensor_G{1};
                bb_G = tensor_G{2};
                cc_G = tensor_G{3};
                
                if obj.use_lsd        % use the Line Segment Detector (for doing so you will need to install mexopencv and add it to the path - see http://amroamroamro.github.io/mexopencv/)
                    % detect line segments
                    lsd = cv.LineSegmentDetector('Refine','Standard');
                    guide_img_gray_uint8 = im2gray(uint8(255 * obj.guide_img));
                    lines = lsd.detect(guide_img_gray_uint8);
                    drawnLines = lsd.drawSegments(guide_img_gray_uint8, lines);
            
                    % check at which pixel locations in drawnLines is pure blue (i.e. [0,0,255])
                    blue_colour = reshape(uint8([0,0,255]),1,1,[]);
                    binary_mask = all(drawnLines == blue_colour,3);
                    
                    % calculate the tensor from the binary mask
                    [tensor_G_prime, ~, ~] = calcTensor(gpuArray(double(binary_mask)), [obj.magnitude, obj.sharpness], 2);
                    aa_G_prime = tensor_G_prime{1};
                    bb_G_prime = tensor_G_prime{2};
                    cc_G_prime = tensor_G_prime{3};
                    
                    % update tensor G with tensor G_prime at the posision of the detected lines
                    aa_G(binary_mask) = aa_G_prime(binary_mask);
                    bb_G(binary_mask) = bb_G_prime(binary_mask);
                    cc_G(binary_mask) = cc_G_prime(binary_mask);
                end
            
                operator = @(p) cat(3, aa_G.*p(:,:,1)+cc_G.*p(:,:,2), cc_G.*p(:,:,1)+bb_G.*p(:,:,2));
            end
        end

    end
end