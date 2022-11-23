function disp_out = interpolate_background(disp_in)
% simple background interpolation to fill invalid disparity values (NaN or <=0)
% http://www.cvlibs.net/datasets/kitti/eval_scene_flow.php?benchmark=stereo

[h, w] = size(disp_in);

disp_out = disp_in;

for v = 0:h-1                                       % for each row do
    count = 0;
    for u = 0:w-1                                   % for each pixel do
        if disp_out(v+1, u+1) > 0                   % if disparity is valid
            if count >= 1                           % at least one pixel requires interpolation
                u1 = u - count;
                u2 = u - 1;
                if u1 > 0 && u2 < w-1
                    disp_val = min(disp_out(v+1, u1), disp_out(v+1, u2+2)); % the valid disparity value used for interpolation
                    disp_out(v+1, u1+1:u2+1) = disp_val;
                end
            end
            count = 0;
        else
            count = count + 1;
        end
    end

    % extrapolate to the left
    for u = 0:w-1
        if disp_out(v+1, u+1) > 0
            disp_out(v+1, 1:u) = disp_out(v+1, u+1);
            break
        end
    end
    
    % extrapolate to the right
    for u = w-1:-1:0
        if disp_out(v+1, u+1) > 0
            disp_out(v+1, u+2:w) = disp_out(v+1, u+1);
            break
        end
    end
end

for u = 0:w-1                           % for each column do
    % extrapolate to the top
    for v = 0:h-1
        if disp_out(v+1, u+1) > 0
            disp_out(1:v, u+1) = disp_out(v+1, u+1);
            break
        end
    end

    % extrapolate to the bottom
    for v = h-1:-1:0
        if disp_out(v+1, u+1) > 0
            disp_out(v+2:h, u+1) = disp_out(v+1, u+1);
            break
        end
    end
end

end