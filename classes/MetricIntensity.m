classdef MetricIntensity
    
    properties (Constant)
       HEADERS = {'SSIM', 'PSNR (dB)', 'RSNR (dB)'}
    end

    properties
        gt
    end

    methods
        function obj = MetricIntensity(groundtruth)
            obj.gt = groundtruth;
        end
        
        function ssim_ = calc_ssim(obj, est)
            [~, ~, ch] = size(est);
            if ch == 1
                ssim_ = ssim(est, obj.gt);
            else
                ssim_ = (ssim(est(:, :, 1), obj.gt(:, :, 1)) ...
                       + ssim(est(:, :, 2), obj.gt(:, :, 2)) ...
                       + ssim(est(:, :, 3), obj.gt(:, :, 3))) / 3;
            end
        end

        function psnr_val = calc_psnr(obj, est)           
            psnr_val = psnr(est, obj.gt);
        end

        function rsnr = calc_rsnr(obj, est)           
            rsnr = 20 * log10(norm(obj.gt(:)) / norm(obj.gt(:) - est(:)));
        end

        function metric_values = calc_metrics(obj, est)           
            assert(all(size(est) == size(obj.gt)), 'estimation and groundtruth have to have the same size')
            
            metric_values = [obj.calc_ssim(est), ...
                             obj.calc_psnr(est), ...
                             obj.calc_rsnr(est) ...
                            ];
        end
    end
end