classdef MetricDepth
    
    properties
        depth_groundtruth
        eval_mask
        data_class
        MAX_DEPTH
    end
    
    properties (Constant)
        DEPTH_ERROR_THRESHOLD = 5
        DEPTH_DELTA_THRESHOLD = 1.25
        MIN_DEPTH = 0.001

        TABLE_HEADERS = {'RMSE (m)', 'tRMSE (m)', 'MAE (m)', 'tMAE (m)', ...
                         'logRMSE', 'SRD', 'ARD (%)', ...
                         'SIlog', 'delta1 (%)', 'delta2 (%)', 'delta3 (%)', ...
                        }
    end
    
    methods
        function obj = MetricDepth(groundtruth, eval_mask, data_class)
            arguments
                groundtruth
                eval_mask
                data_class      {mustBeMember(data_class, {'DataVkitti', 'DataPAD', 'DataFrida3'})}
            end
            obj.depth_groundtruth = groundtruth;
            obj.eval_mask = eval_mask;
            obj.data_class = data_class;
            if strcmp(obj.data_class, 'DataVkitti') || strcmp(obj.data_class, 'DataFrida3')
                obj.MAX_DEPTH = 80;
            else
                obj.MAX_DEPTH = 25;
            end
        end
        
        function metric_values = calcMetrics(obj, depth)           
            y_eval = depth(obj.eval_mask);
            y_eval_clipped = obj.clip(y_eval, obj.MIN_DEPTH, obj.MAX_DEPTH);

            y0_eval = obj.depth_groundtruth(obj.eval_mask);
            
            metric_values = [obj.calc_RMSE(y_eval_clipped, y0_eval), ...
                       obj.calc_thresholded_RMSE(y_eval_clipped, y0_eval, obj.DEPTH_ERROR_THRESHOLD), ...
                       obj.calc_MAE(y_eval_clipped, y0_eval), ...
                       obj.calc_thresholded_MAE(y_eval_clipped, y0_eval, obj.DEPTH_ERROR_THRESHOLD), ...
                       obj.calc_log_RMSE(y_eval_clipped, y0_eval), ...
                       obj.calc_SRD(y_eval_clipped, y0_eval), ...
                       obj.calc_ARD(y_eval_clipped, y0_eval), ...
                       obj.calc_scale_invariant_log(y_eval_clipped, y0_eval), ...
                       obj.calc_delta_threshold(y_eval_clipped, y0_eval, obj.DEPTH_DELTA_THRESHOLD), ...
                       obj.calc_delta_threshold(y_eval_clipped, y0_eval, obj.DEPTH_DELTA_THRESHOLD^2), ...
                       obj.calc_delta_threshold(y_eval_clipped, y0_eval, obj.DEPTH_DELTA_THRESHOLD^3), ...
                       ];
        end
        
        function metric_table = generate_metric_table(obj, depths)
            if ~isempty(depths)
                number_of_pages = size(depths,3);
                metric_values = NaN(number_of_pages,length(obj.TABLE_HEADERS));
                for page = 1:number_of_pages
                    metric_values(page,:) = obj.calcMetrics(depths(:,:,page));
                end
                metric_table = array2table(metric_values,'VariableNames',obj.TABLE_HEADERS);
            end
        end

    end
    
    methods (Static)
        function result = calc_RMSE(y, y_ref)
            result = sqrt(mean((y-y_ref).^2, 'all'));
        end
        
        function result = calc_thresholded_RMSE(y, y_ref, thr_depth)
            result = sqrt(mean(min((y-y_ref).^2, thr_depth^2), 'all'));
        end
        
        function result = calc_MAE(y, y_ref)
            result = mean(abs(y-y_ref), 'all');
        end
        
        function result = calc_thresholded_MAE(y, y_ref, thr_depth)
            result = mean(min(abs(y-y_ref), thr_depth), 'all');
        end
        
        function result = calc_log_RMSE(y, y_ref)
            result = MetricDepth.calc_RMSE(log(y), log(y_ref));
        end
        
        function result = calc_SRD(y, y_ref)  % squared relative distance
            result = mean((y-y_ref).^2 ./ y_ref, 'all');
        end
        
        function result = calc_ARD(y, y_ref)  % absolute relative distance
            result = mean(abs(y-y_ref) ./ y_ref, 'all') * 100;
        end
        
        function result = calc_scale_invariant_log(y, y_ref)
            d = log(y) - log(y_ref);
            result = 100 * sqrt(mean(d.^2, 'all') - (mean(d, 'all'))^2);
        end
        
        function result = calc_delta_threshold(y, y_ref, thr_delta)
            max_ratio = max(y./y_ref, y_ref./y);
            result = mean(max_ratio < thr_delta, 'all') * 100;
        end
        
        function clipped_result = clip(y, min_depth, max_depth)
            clipped_result = max(min(y, max_depth), min_depth);
        end

    end
end

