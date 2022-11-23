classdef Constant

    properties (Constant)
        VIS_BETA_PRODUCT = -log(0.05)

        % number of pixels to crop, always [top, bottom, left, right] 
        ORIGINAL_TO_GRUBER = [270, 20, 170, 20];               % original size -> input size to evaluate depth error metrics in Gruber's paper
        ORIGINAL_TO_TUNNEL = [270, 260, 514, 374];             % original size -> input size to evaluate depth error metrics
        ORIGINAL_TO_STEREO = [270, 260, 450, 310];             % original size -> input size to stereo algorithms
        STEREO_TO_TUNNEL = Constant.ORIGINAL_TO_TUNNEL ...
                         - Constant.ORIGINAL_TO_STEREO;       % input size to stereo algorithms -> input size to evaluate depth error metrics

    end

end