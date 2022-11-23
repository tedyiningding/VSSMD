function p = project_box(x, low, high)
% The procedure computes the projection onto the constraint set:
% low <= x <= high
    p = max(min(x, high), low);
end