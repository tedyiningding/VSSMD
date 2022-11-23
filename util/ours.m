function [l_J, l_u] = ours(l_I, r_I, visibility, init_trans_est_method, camera, cropped_pixels, ours_mode, max_disp, census_use_gray, options)
    arguments
        l_I
        r_I
        visibility
        init_trans_est_method
        camera
        cropped_pixels
        ours_mode
        max_disp
        census_use_gray
        options.plot_disparity = false
        options.write_video = false
        options.frame_rate = 8
    end
    %% preparation
    % choose mode (see our ablation study Sec. 4.3 of the paper)
    switch ours_mode
        case "full"
            use_weight = true;
            lambda_t = 1e-2;
            apply_pp = true;
            apply_tr = true;
        case "w_0"
            use_weight = false;
            lambda_t = 1e-2;
            apply_pp = true;
            apply_tr = true;
        case "lambda_t_0"
            use_weight = true;
            lambda_t = 0;
            apply_pp = true;
            apply_tr = true;
        case "wo_pp"
            use_weight = true;
            lambda_t = 1e-2;
            apply_pp = false;
            apply_tr = true;
        case "wo_tr"
            use_weight = true;
            lambda_t = 1e-2;
            apply_pp = true;
            apply_tr = false;
        otherwise
            error("Invalid mode!")
    end

    % parameters in defogging
    epsilon = 5;        % the distance cap in photo-inconsistency check
    mu = 0.003;         % the tuning parameter in transmission refinement (see Eq. (7))
    %% initial transmission estimation (Sec. 3.1 of the paper)
    switch init_trans_est_method
        case "He"
            [~, ~, l_t_tilde, ~] = He_defogging(l_I);
        otherwise
            error("Invalid initial transmission estimation method!")
    end
    % convert transmission to disparity with known visibility
    l_d_tilde = - log(l_t_tilde) / (Constant.VIS_BETA_PRODUCT / visibility);
    l_z_tilde = camera.dist_to_depth(l_d_tilde, cropped_pixels=cropped_pixels);
    l_u_tilde = camera.depth_to_disp(l_z_tilde);
    l_u_tilde = l_u_tilde / max(l_u_tilde(:));
    %% foggy stereo matching (Sec. 3.2 of the paper)
    tic;

    % create foggy stereo matching instance
    fsm = FoggyStereoMatching(l_I, r_I, l_u_tilde,...
                              use_weight=use_weight,...
                              lambda_t=lambda_t,...
                              use_lsd=false,...
                              max_disparity=max_disp,...
                              census_use_gray=census_use_gray,...
                              similarity_colour_space="gray_0_1",...
                              plot_disparity=options.plot_disparity,...
                              write_video=options.write_video);
    
    % calculate disparity and the weight
    [l_u, ~, w] = fsm.calc_disparity();

    % gpu to cpu
    l_u = gather(l_u);
    w = gather(w);
    
    % disparity post-processing
    if apply_pp
        l_u = disparity_post_processing(l_u, max_disp);
    end
    
    % interpolate invalid disparities as per the KITTI 2015 stereo benchmark
    if ~all(l_u > 0, 'all')
        l_u = interpolate_background(l_u);
    end

    elapsed_time = toc;
    fprintf('Foggy Stereo Matching took %.3f seconds\n', elapsed_time)
    %% defogging (Sec. 3.3 of the paper)
    tic;

    % photo-inconsistency check
    l_I_lab = rgb2lab(l_I);
    r_I_lab = rgb2lab(r_I);
    b = photo_inconsistency_check(l_I_lab, r_I_lab, l_u, epsilon);
    
    % atmospheric light estimation
    l_u_cropped = l_u(:, 1+max_disp:end);
    top_num_pixels = 0.001*numel(l_u_cropped);
    smallest_disps_count = floor(top_num_pixels) + mod(floor(top_num_pixels+1), 2);
    l_u_cropped_vec = l_u_cropped(:);
    [~, indices] = sort(l_u_cropped_vec, 'ascend');
    smallest_disps_indices = indices(1:smallest_disps_count);
    ind = smallest_disps_indices(ceil(length(smallest_disps_indices)/2));
    [row, col] = ind2sub(size(l_u_cropped), ind);
    l_A = l_I(row, col+max_disp, :);

    % create the asm instances and convert disparity to transmission
    asm = AtmosScatteringModel(visibility, reshape(l_A, [1, 3]));
    l_z = camera.disp_to_depth(l_u);
    l_d_bar = camera.depth_to_dist(l_z, cropped_pixels=cropped_pixels);
    l_t_bar = asm.dist_to_trans(l_d_bar);
    
    % transmission refinement
    if apply_tr
        l_t = wls_optimization_two_data_terms(l_t_tilde, (1-w).*b,...
                                                    l_t_bar, w.*(1-b),...
                                                    l_I, mu);
    else
        l_t = l_t_bar;
    end
    
    % invert the fog model (Eq. (1))
    l_J = asm.foggy_to_clear(l_I, ...
                            min(max(l_t, 0), 1), ...
                            lower_bounded=true, ...
                            clamp=true);

    elapsed_time = toc;
    fprintf('Defogging took %.3f seconds\n', elapsed_time)
    %% plot defogged image and write video
    if isa(fsm, 'FoggyStereoMatching')     % only do this when generating demo videos (not debug videos)
        if options.plot_disparity
            global tile
            nexttile(4)
            imagesc(l_J);
            title('The defogged image $J$', 'interpreter','latex', 'fontsize', 13)
            axis image
            axis off
        end
    
        if options.write_video
            global Frames
            Frames(end+1:end+2*options.frame_rate) = getframe(tile.Parent);
            fsm.write_frames_to_video(Frames, 'teaser.avi', frame_rate=options.frame_rate)
        end
    end
end