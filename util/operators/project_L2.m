function p = project_L2(x, lambda, dir)
% This procedure computes the projection onto the constraint set:
% ||x||_2 <= lambda
    p = x ./ max(sqrt(sum(x.^2, dir))/lambda, 1);
end