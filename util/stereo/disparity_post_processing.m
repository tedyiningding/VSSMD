function [disp_out] = disparity_post_processing(disp_in, max_disp)

disp_out = disp_in;

[height, ~] = size(disp_out);

for h = 1:height
    [max_val, max_ind] = max(disp_out(h, 1:max_disp+1));
    if max_ind > 1
        disp_out(h, 1:max_ind-1) = max_val;
    end
end

end