function Dadj_u = operator_Dadj(u)
% applies the negative divegence operator (i.e. the adjoint of the gradient operator) with Dirichlet boundary condition
% a mapping from (H-by-W-by-2) to (H-by-W)

    h = -[u(:, 1, 1), diff(u(:, 1:end-1, 1), 1, 2), -u(:, end-1, 1)];
    v = -[u(1, :, 2); diff(u(1:end-1, :, 2), 1, 1); -u(end-1, :, 2)];

    Dadj_u = h + v;
end