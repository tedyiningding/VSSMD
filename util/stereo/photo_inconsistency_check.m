function b = photo_inconsistency_check(left_image,...
    right_image, left_disparity, epsilon)
%PHOTO_INCONSISTENCY_CHECK  Check consistency of disparity map for the left
%image of a stereo pair with respect to the photometric distance between
%corresponding pixels from left and right image under this disparity map.
%
%   INPUTS:
%
%   -|left_image|: |height|-by-|width|-by-3 left RGB image of the stereo pair.
%
%   -|right_image|: |height|-by-|width|-by-3 right RGB image of the stereo pair.
%
%   -|left_disparity|: |height|-by-|width| disparity map for |left_image|, where
%   disparity is measured in pixels.
%
%   -|epsilon|: positive scalar, acting as a threshold for photometric
%   discrepancy between corresponding pixels.
%
%   OUTPUTS:
%
%   -|b|: |height|-by-|width| boolean matrix, where
%   true indicates that the corresponding pixel in |left_disparity| contains a
%   value that is not photoconsistent.

[height, width, ~] = size(left_image);

% Create a pixel-wise map from the left to the right image, based on the
% disparity map of the left image. Enforce mapping of every pixel inside the
% image border, but remember all exceptions to mark them as inconsistent
% subsequently.
[X, Y] = meshgrid(1:width, 1:height);
X_aligned = round(X - left_disparity);
mapped_inside_border = X_aligned >= 1 & X_aligned <= width;
X_aligned = min(max(X_aligned, 1), width);

% Form warped version of right image, which is used in the photoconsistency
% check with the left image.
indices_reshaped = reshape(sub2ind([height, width], Y(:), X_aligned(:)),...
    height, width);
right_image_warped = cat(3, right_image(indices_reshaped),...
    right_image(indices_reshaped + height * width),...
    right_image(indices_reshaped + 2 * height * width));

% Inconsistent disparity values are equivalent to large photometric discrepancies
% between corresponding pixels OR mapping outside the border of the right
% image.
colour_dist_squared = sum((left_image - right_image_warped) .^ 2, 3) ;
b = colour_dist_squared;
b(colour_dist_squared > epsilon^2) = epsilon^2;
b = b / max(b(:));
b(~mapped_inside_border) = 1;

end

