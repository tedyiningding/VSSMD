classdef AtmosScatteringModel

    properties
        visibility
        atmos
        beta
    end

    methods
        function obj = AtmosScatteringModel(visibility, atmos)
            obj.visibility = visibility;
            obj.atmos = reshape(atmos, [1, 1, 3]);
            obj.beta = Constant.VIS_BETA_PRODUCT / obj.visibility;
        end

        function transmission = dist_to_trans(obj, distance)
            transmission = exp(-obj.beta * distance);
        end

        function distance = trans_to_dist(obj, transmission)
            distance = - log(transmission) / obj.beta;
        end

        function foggy = clear_to_foggy(obj, clear, transmission, options)
            arguments
                obj
                clear
                transmission
                options.clamp = true
            end
            foggy = clear.*transmission + obj.atmos.*(1-transmission);
            if options.clamp
                foggy = max(min(foggy, 1), 0);
            end
        end

        function clear = foggy_to_clear(obj, foggy, transmission, options)
            arguments
                obj
                foggy
                transmission
                options.lower_bounded = false
                options.clamp = true
            end
            if options.lower_bounded
                transmission_lb = 1 - min(foggy./obj.atmos, [], 3);
                transmission = max(transmission, transmission_lb);
            end
            clear = (foggy - obj.atmos)./transmission + obj.atmos;
            if options.clamp
                clear = max(min(clear, 1), 0);
            end
        end
    end
end