classdef AdaptiveSupportWeight

    properties
        similarity_colour_space
        gamma_similarity
        gamma_proximity
        support_win_size
    end

    methods
        function obj = AdaptiveSupportWeight(similarity_colour_space,gamma_similarity,gamma_proximity,support_win_size)
            arguments
                similarity_colour_space     {mustBeMember(similarity_colour_space, ...
                                            {'LAB','gray_0_1','gray_0_255'})}
                gamma_similarity            (1,1) double {mustBePositive}
                gamma_proximity             (1,1) double {mustBePositive}
                support_win_size            (1,1) {mustBePositive}
            end
            
            obj.similarity_colour_space = similarity_colour_space;
            obj.gamma_similarity = gamma_similarity;
            obj.gamma_proximity = gamma_proximity;
            obj.support_win_size = support_win_size;
        end

        function similarity = calc_similarity(obj,img)
            % which colour space
            switch obj.similarity_colour_space
                case 'LAB'
                    img = rgb2lab(gather(img));
                case 'gray_0_1'
                    img = im2gray(img);
                case 'gray_0_255'
                    img = double(uint8(255*im2gray(img)));
            end

            centre_index = ceil(obj.support_win_size/2);                                      % center position
            delta_c = zeros([size(img,1),size(img,2),obj.support_win_size^2],'gpuArray');
            
            img_padded = padarray(img,[centre_index-1 centre_index-1],0,'both');
            
            page = 1;
            for hs = (centre_index-1):-1:(-(centre_index-1))
                for vs = (centre_index-1):-1:(-(centre_index-1))
                    img_padded_shifted = circshift(img_padded,[vs hs 0]);
                    delta_c(:,:,page) = sqrt(sum((img_padded_shifted(centre_index:end-(centre_index-1),centre_index:end-(centre_index-1),:) - img).^2,3));
                    page = page+1;
                end
            end

            similarity = exp(- delta_c / obj.gamma_similarity);     % eq. (4)
        end

        function proximity = calc_proximity(obj)
            centre_index = ceil(obj.support_win_size/2);
            [X,Y] = ndgrid(-(centre_index-1):centre_index-1,-(centre_index-1):centre_index-1);
            X = gpuArray(X);
            Y = gpuArray(Y);
            delta_g = reshape(sqrt(X.^2 + Y.^2),1,1,[]);
            proximity = exp(- delta_g / obj.gamma_proximity);       % eq. (5)
        end
    
        function support_weight = calc_support_weight(obj,img)
            support_weight = calc_similarity(obj,img) .* calc_proximity(obj);
        end
    end

    methods (Static)
        function cost_aggregated = aggregate_cost(support_weight_overall,cost_raw)
            support_win_size = sqrt(size(support_weight_overall,3));
            centre_index = ceil(support_win_size/2);

            cost_raw_padded = padarray(cost_raw,[centre_index-1 centre_index-1],0,'both');
            cost_in_3d = zeros(size(support_weight_overall),'gpuArray');

            page = 1;
            for hs = (centre_index-1):-1:(-(centre_index-1))
                for vs = (centre_index-1):-1:(-(centre_index-1))
                    cost_raw_padded_shifted = circshift(cost_raw_padded,[vs hs 0]);
                    cost_in_3d(:,:,page) = cost_raw_padded_shifted(centre_index:end-(centre_index-1),centre_index:end-(centre_index-1));
                    page = page+1;
                end
            end

            cost_aggregated = sum(support_weight_overall.*cost_in_3d,3) ./ sum(support_weight_overall,3);   % eq. (7)
        end
    end
end