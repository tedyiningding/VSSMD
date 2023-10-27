function J_x = operator_J(x)
% applies the gradient operator with Neumann boundary condition
% a mapping from (H-by-W-by-2) to (H-by-W-by-4)
    J_x = cat(3, ...
              [diff(x(:, : ,1), 1, 2), zeros(size(x, 1), 1)], ...   % page 1 horizontal gradient
		      [diff(x(:, :, 1), 1, 1); zeros(1, size(x, 2))], ...   % page 1 vertical gradient
              [diff(x(:, :, 2), 1, 2), zeros(size(x, 1), 1)], ...   % page 2 horizontal gradient
		      [diff(x(:, :, 2), 1, 1); zeros(1, size(x, 2))]);      % page 2 vertical gradient
              
end