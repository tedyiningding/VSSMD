function Dadj_u = operator_Dadj(u)
% applies the negative diverence operator (i.e. the adjoint of the gradient operator) with Dirichlet boundary condition
% a mapping from (H-by-W-by-2) to (H-by-W)
    Dadj_u = [-u(1, :, 1); -diff(u(1:end-1, :, 1), 1, 1); u(end-1, :, 1)] ...
           + [-u(:, 1, 2), -diff(u(:, 1:end-1, 2), 1, 2), u(:, end-1, 2)];
end