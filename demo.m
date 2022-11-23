clear
%% add paths
addpath(genpath('classes'));
addpath(genpath('util'));
%% params
ours_mode = "full";      % choose from {"full", "w_0", "lambda_t_0", "wo_pp", "wo_tr"}. See our Ablation Study.
init_trans_est_method = "He";
max_disp = 63;
census_use_gray = true;
%% PAD dataset
scene = 1;
sample = 3;
visibility = "fog20";
crop = "tunnel";
mode = "real";
%% prepare data
data = DataPAD(scene, sample, visibility, crop, mode);
%% our method
[l_J, l_u] = ours(data.left_foggy, data.right_foggy, ...
                  data.visibility, ...
                  init_trans_est_method, ...
                  data.camera, ...
                  data.cropped_pixels, ...
                  ours_mode, ...
                  max_disp, ...
                  census_use_gray, ...
                  plot_disparity = false, ...
                  write_video = false);
%% create instances of evaluation metrics from the ground truth
eval_mask = data.left_disp > 0;
metric_disparity = MetricDisparity(data.left_disp, eval_mask);
metric_depth = MetricDepth(data.left_depth, eval_mask, class(data));
metric_intensity = MetricIntensity(data.left_clear);
%% evaluate results
l_z = data.camera.disp_to_depth(l_u);   % convert disparity to depth
metrics_disp = metric_disparity.calc_d1all(l_u);
metrics_depth = metric_depth.calcMetrics(l_z);
metrics_defogging = metric_intensity.calc_metrics(l_J);