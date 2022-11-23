classdef FoggyStereoMatching

    properties
        left_img
        right_img
        
        left_u_from_trans

        left_defogged_img
        right_defogged_img

        max_disparity

        lambda_d
        lambda_s
        lambda_a
        lambda_t
    
        use_weight

        guide_img
        tensor_magnitude
        tensor_sharpness
        use_lsd
        operator_G
        
        census_use_gradient
        census_win_size
        census_use_gray

        similarity_colour_space
        gamma_similarity
        gamma_proximity
        support_win_size

        max_outer_iter
        max_inner_iter
        beta

        plot_disparity
        write_video
    end
    
    methods
        function obj = FoggyStereoMatching(left_img, right_img, left_u_from_trans, options)
            arguments
                left_img    double {mustBeGreaterThanOrEqual(left_img,0), mustBeLessThanOrEqual(left_img,1)}
                right_img   double {mustBeGreaterThanOrEqual(right_img,0), mustBeLessThanOrEqual(right_img,1)}
                left_u_from_trans

                % dofogged image
                options.left_defogged_img = left_img;
                options.right_defogged_img = right_img;

                % maximum allowed disparity
                options.max_disparity = 63
                
                % cost balance parameters
                options.lambda_d = 4e-1
                options.lambda_s = 1e-0
                options.lambda_t = 1e-3
                
                % modified Kuschk method by allowing for different weights at different pixel locations
                options.use_weight  (1,1) logical = false

                % anisotropic diffusion tensor
                options.guide_img   double {mustBeGreaterThanOrEqual(options.guide_img,0), mustBeLessThanOrEqual(options.guide_img,1)} = left_img    
                options.tensor_magnitude = 9
                options.tensor_sharpness = 0.85
                options.use_lsd     (1,1) logical = false
        
                % census transform
                options.census_use_gradient     (1,1) logical = false
                options.census_win_size = 7
                options.census_use_gray         (1,1) logical = true

                % adpative support weights
                options.similarity_colour_space {mustBeMember(options.similarity_colour_space, ...
                                                {'LAB','gray_0_1','gray_0_255'})} = 'LAB'
                options.gamma_similarity = 5
                options.gamma_proximity = 7.5
                options.support_win_size = 15

                % iterative algorithm
                options.max_outer_iter = 80
                options.max_inner_iter = 150
                options.beta = 1e-3
                
                % visual output
                options.plot_disparity = false
                options.write_video = false
            end
            
            obj.left_img = left_img;
            obj.right_img = right_img;
            obj.left_u_from_trans = left_u_from_trans;

            obj.left_defogged_img = options.left_defogged_img;
            obj.right_defogged_img = options.right_defogged_img;

            obj.max_disparity = options.max_disparity;
            
            obj.lambda_d = options.lambda_d;
            obj.lambda_s = options.lambda_s;
            obj.lambda_a = 8 * obj.lambda_s;
            obj.lambda_t = options.lambda_t;
            
            obj.use_weight = options.use_weight;

            obj.guide_img = options.guide_img;
            obj.tensor_magnitude = options.tensor_magnitude;
            obj.tensor_sharpness = options.tensor_sharpness;
            obj.use_lsd = options.use_lsd;
            anisotropic_diffusion_tensor = AnisotropicDiffusionTensor(obj.guide_img,obj.tensor_magnitude,obj.tensor_sharpness,obj.use_lsd);
            obj.operator_G = anisotropic_diffusion_tensor.calc_operator();
            
            obj.census_use_gradient = options.census_use_gradient;
            obj.census_win_size = options.census_win_size;
            obj.census_use_gray = options.census_use_gray;

            obj.similarity_colour_space = options.similarity_colour_space;
            obj.gamma_similarity = options.gamma_similarity;
            obj.gamma_proximity = options.gamma_proximity;
            obj.support_win_size = options.support_win_size;
            
            obj.max_outer_iter = options.max_outer_iter;
            obj.max_inner_iter = options.max_inner_iter;
            obj.beta = options.beta;

            obj.plot_disparity = options.plot_disparity;
            obj.write_video = options.write_video;
        end
        
        function [u, a, weights] = calc_disparity(obj)
            %% winner-takes-all
            [a, cost, weights] = WTA_cost_aggregation(obj);
            %% initialisation
            u = a;
            L = zeros(size(u), 'gpuArray');
            theta = 1;
            %% create figure
            if obj.plot_disparity
                global tile

                tile = tiledlayout(2, 2, 'Padding', 'compact', 'TileSpacing', 'compact');
                tile.Parent.Position = [100 100 size(u, 2)*2 size(u, 1)*2];
                
                nexttile(1)
                imagesc(obj.left_img);
                title('The input left foggy image $I_l$', 'interpreter','latex', 'fontsize', 13)
                axis image
                axis off

                nexttile(2)
                imagesc(obj.right_img);
                title('The input right foggy image $I_r$', 'interpreter','latex', 'fontsize', 13)
                axis image
                axis off

                nexttile(3)
                im_u = imagesc(u,[0 1]);
                title('The disparity map $u$ after iteration 0', 'interpreter','latex', 'fontsize', 13)
                colormap('jet');
                axis image
                axis off
            end     
            %% save current frame
            if obj.write_video
                global Frames
                Frames = repmat(struct('cdata', NaN, 'colormap', NaN), 1, obj.max_outer_iter + 1);       % create a 1x(obj.max_outer_iter + 1) empty struct to save frames
                Frames(1) = getframe(tile.Parent);
            end
            %% the iterative algorithm
            for n = 1:obj.max_outer_iter
                %% 1. primal-dual to optimise u
                [u] = PDHG_fast(obj, u, L, a, theta, weights, obj.left_u_from_trans);
                %% 2. point-wise search to optimise a
                [a, ~] = pointwise_search(obj, weights, cost, L, u, theta);
                %% 3. update L
                L = L + weights.*(u-a)/theta/2;
                %% 4. update theta
                theta = theta*(1 - obj.beta*n);
                %% update figure
                if obj.plot_disparity
                    nexttile(3)
                    set(im_u,'CData',gather(u))
                    title(['The disparity map $u$ after iteration ' num2str(n)], 'interpreter','latex', 'fontsize', 13)

                    drawnow
                end
                %% save current frame
                if obj.write_video
                    Frames(n+1) = getframe(tile.Parent);
                end
            end
            %% denormalise to true disparities
            u = obj.max_disparity * u;
            a = obj.max_disparity * a;
        end

        function [a, cost, weights] = WTA_cost_aggregation(obj)
            %% census transform
            census_transform = CensusTransform(obj.census_use_gradient,obj.census_win_size);

            if obj.census_use_gray
                left_census_array = census_transform.transform(rgb2gray(obj.left_img));
                right_census_array = census_transform.transform(rgb2gray(obj.right_img));
            else
                left_census_array_r = census_transform.transform(obj.left_img(:, :, 1));
                left_census_array_g = census_transform.transform(obj.left_img(:, :, 2));
                left_census_array_b = census_transform.transform(obj.left_img(:, :, 3));
                left_census_array = cat(4, left_census_array_r, left_census_array_g, left_census_array_b);
                left_census_array = permute(left_census_array, [1,2,4,3]);

                right_census_array_r = census_transform.transform(obj.right_img(:, :, 1));
                right_census_array_g = census_transform.transform(obj.right_img(:, :, 2));
                right_census_array_b = census_transform.transform(obj.right_img(:, :, 3));
                right_census_array = cat(4, right_census_array_r, right_census_array_g, right_census_array_b);
                right_census_array = permute(right_census_array, [1,2,4,3]);
            end
            %% adaptive support weight
            adaptive_support_weight = AdaptiveSupportWeight(obj.similarity_colour_space,obj.gamma_similarity,obj.gamma_proximity,obj.support_win_size);
            left_weight_array = adaptive_support_weight.calc_support_weight(obj.left_defogged_img);
            right_weight_array = adaptive_support_weight.calc_support_weight(obj.right_defogged_img);
            %% aggregate Hamming distance with the support weights in both support windows
            [height,width,~] = size(obj.left_img);
            hamming_distance = zeros(height,width,obj.max_disparity+1,'uint8','gpuArray');
            cost = zeros(height,width,obj.max_disparity+1,'gpuArray');
            for k = 0:obj.max_disparity
                right_census_array_shifted = circshift(right_census_array,[0 k]);
                hamming_distance(:,:,k+1) = sum(right_census_array_shifted ~= left_census_array,[3,4]);
                overall_weight_array = left_weight_array .* circshift(right_weight_array,[0 k 0]);     % shift to the right by k pixels
                cost(:,:,k+1) = adaptive_support_weight.aggregate_cost(overall_weight_array,hamming_distance(:,:,k+1));
            end
            [~, min_cost_ind] = min(cost, [], 3);
            a = min_cost_ind - 1;
            %% normalise the output disparity and cost
            a = a / obj.max_disparity;
            if obj.census_use_gray
                cost = cost / obj.census_win_size.^2;
            else
                cost = cost / (obj.census_win_size.^2 * 3);
            end
            %% calculate weights
            if obj.use_weight
                weights = gpuArray(obj.calc_weights(cost));
            else
                weights = ones([height, width], 'gpuArray');
            end
        end
        
        function [u] = PDHG_fast(obj, u_init, L, a, theta, weights, u_tilde)
            %% initialisation
            z = u_init - u_tilde;
            v = zeros([size(u_init), 2], 'gpuArray');
            p = zeros([size(u_init), 2], 'gpuArray');
            q = zeros([size(u_init), 4], 'gpuArray');
            r = zeros([size(u_init), 2], 'gpuArray');
            %% pre-calculations
            Dz = operator_D(z);
            Jv = operator_J(v);
            Du_tilde = operator_D(u_tilde);
            %% step sizes
            lip = max(weights(:)/theta);
            L2_1 = 12;
            L2_2 = 8;
            L2_sum = L2_1 + L2_2;

            sigma = 10/L2_sum;                      % dual step size
            tau = 0.99 / ( lip/2 + sigma*L2_sum );  % primal step size
            %% main loop
            for iter = 1:obj.max_inner_iter
                v_old = v;
                Dz_old = Dz;
                Jv_old = Jv;
                Gp = obj.operator_G(p);

                % primal updates
                z = z - tau*(L + 1/theta*weights.*(z+u_tilde-a) + operator_Dadj(Gp) + operator_Dadj(r));
                z = project_box(z, -u_tilde, 1-u_tilde);

                v = v - tau*(-Gp + operator_Jadj(q));
                
                % reusable calculations
                Dz = operator_D(z);
                Jv = operator_J(v); 

                % dual updates
                p = p + sigma*(obj.operator_G((2*Dz - Dz_old) + Du_tilde - (2*v-v_old)));
                p = project_L2(p, obj.lambda_s, 3);

                q = q + sigma*(2*Jv - Jv_old);
                q = project_L2(q, obj.lambda_a, 3);
                
                r = r + sigma*(2*Dz - Dz_old);
%                 r = project_L2(r, obj.lambda_t, 3);                         % isotropic TV
                r = project_box(r, -obj.lambda_t, obj.lambda_t);            % anisotropic TV
                
            end
            u = z + u_tilde;
        end

        function [a, cost_sum] = pointwise_search(obj, weights, cost, L, u, theta)
            a_normed = reshape(gpuArray(0:obj.max_disparity)/obj.max_disparity, 1, 1, []);       % use broadcast, seems faster
            ua_diff = u - a_normed;
            %% the total cost at each pixel location (eq. (8))
            cost_no_L = obj.lambda_d * weights .* cost ...  % the 1st term in eq. (8)
                      + weights .* (ua_diff.^2)/2/theta;    % the 3rd term in eq. (8)
            cost_total = cost_no_L ...
                       + L .* ua_diff;
            [~, min_ind] = min(cost_total, [], 3);
            %% subpixel accuracy
            cost_total_padded = padarray(cost_total,[0 0 1],'replicate','both');
            [rows, cols] = ndgrid(1:size(cost_total_padded,1), 1:size(cost_total_padded,2));
            data_cube = cat(3, ...
                            cost_total_padded(sub2ind(size(cost_total_padded), rows, cols, min_ind)), ...
                            cost_total_padded(sub2ind(size(cost_total_padded), rows, cols, min_ind+1)), ...
                            cost_total_padded(sub2ind(size(cost_total_padded), rows, cols, min_ind+2)));
            
            size_cube = size(data_cube);
            x = [-1;0;1];
            z = 2;
            V = bsxfun(@power,x,0:z);
            M = pinv(V);
            poly_cube = M*reshape(permute(data_cube,[3 1 2]),size_cube(3),[]);
            poly_cube = reshape(poly_cube,[size_cube(3) size_cube(1) size_cube(2)]);
            poly_cube = permute(poly_cube,[2 3 1]);
            
            ind_subpix = -poly_cube(:,:,2)/2./poly_cube(:,:,3);
            
            ind_subpix = ind_subpix + min_ind;
            
            a = min(max(ind_subpix, 1), obj.max_disparity+1);
            a = a - 1;
            a = a / obj.max_disparity;      % normalise to [0,1]
            %% get the sum of the 1st and 3rd terms in eq. (8) at all pixels
            [rows, cols] = ndgrid(1:size(cost_no_L,1), 1:size(cost_no_L,2));
            cost_no_L_at_min_ind = cost_no_L(sub2ind(size(cost_no_L), rows, cols, min_ind));
            cost_sum = sum(cost_no_L_at_min_ind,'all');
        end
    end

    methods (Static)
        function weights = calc_weights(cost_in)
            %% the lowest cost and its index K
            [min_val, min_ind] = min(gather(cost_in),[],3); 
            %% the lowest cost excluding at K-1, K and K+1
            cost_in_padded = padarray(gather(cost_in),[0 0 2],Inf,'both');
            [rows, cols] = ndgrid(1:size(cost_in_padded,1), 1:size(cost_in_padded,2));
            
            cost_in_padded(sub2ind(size(cost_in_padded), rows, cols, min_ind)) = Inf;
            cost_in_padded(sub2ind(size(cost_in_padded), rows, cols, min_ind+1)) = Inf;
            cost_in_padded(sub2ind(size(cost_in_padded), rows, cols, min_ind+2)) = Inf;
            cost_in_padded(sub2ind(size(cost_in_padded), rows, cols, min_ind+3)) = Inf;
            cost_in_padded(sub2ind(size(cost_in_padded), rows, cols, min_ind+4)) = Inf;
            
            min_val_excluding = min(cost_in_padded,[],3);
            %% generating w
            weights = min(1, 1*max(0.003, min_val_excluding ./ min_val - 1.15));
        end

        function write_frames_to_video(frames, file_name, options)
            arguments
                frames
                file_name
                options.frame_rate = 10
            end

            % create the video writer
            writerObj = VideoWriter(file_name);
            writerObj.FrameRate = options.frame_rate;
            % open the video writer
            open(writerObj);
            % write the frames to the video
            for i=1:length(frames)
                % convert the image to a frame
                frame = frames(i) ;    
                writeVideo(writerObj, frame);
            end
            % close the writer object
            close(writerObj);
        end
    end
end