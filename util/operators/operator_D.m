function D_x = operator_D(x)
% applies the gradient operator with Neumann boundary condition
% a mapping from (H-by-W) to (H-by-W-by-2)
try
    D_x = cat(3, ...
              [diff(x, 1, 1); zeros(1, size(x, 2))], ... % vertical gradient
              [diff(x, 1, 2), zeros(size(x, 1), 1)]);    % horizontal gradient
catch
    warning('t')
end
end