classdef MetricDisparity
    
    properties (Constant)
       TAU_ABS = 3
       TAU_REL = 0.05

       HEADERS = {'D1All (%)'}
    end

    properties
        gt
        eval_mask
    end

    methods
        function obj = MetricDisparity(groundtruth, eval_mask)
            obj.gt = groundtruth;
            obj.eval_mask = eval_mask;
        end

        function d1all = calc_d1all(obj, est)           
            assert(all(size(est) == size(obj.gt)), 'estimation and groundtruth have to have the same size')
    
            abs_err = abs(est - obj.gt);
            rel_err = abs_err ./ obj.gt;
            
            err_too_big = abs_err > obj.TAU_ABS ...
                        & rel_err > obj.TAU_REL;
            num_err_pixels = sum(err_too_big & obj.eval_mask, 'all');
            num_total_pixels = sum(obj.eval_mask, 'all');
            d1all = num_err_pixels / num_total_pixels * 100;
        end
    end
end