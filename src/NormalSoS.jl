module NormalSoS

using SumOfSquares, JuMP, PolyJuMP, DynamicPolynomials, MultivariatePolynomials, CSDP
using Plots
gr()
export normdecomp

# To do:
#  - Add plotting functions
#  - Add function to check normality

function normdecomp(f, x, SDPsolver=CSDPSolver(), nIters=1, o=2)

    n = length(f);

    m1 = SOSModel(solver=SDPsolver);
    @variable m1 ϵ

    # The Lyapunov function V(x):
    # Z = monomials(x,0:o);
    Z = minimalbasis(f,x);
    @polyvariable m1 V Z

    # Positive definiteness constraint
    @polyconstraint m1 V ≥ ϵ*sum(x.^o);

    # Apply matrix constraint, ∇U⋅g ≤ 0.
    I = NormalSoS.eye(x);
    Mv = [-dot(differentiate(V, x),f) differentiate(V,x)';
           differentiate(V,x)         I];
    @SDconstraint m1 Mv ⪰ 0 # Mv positive definite

    @objective m1 Max ϵ

    status = solve(m1);

    # Now iterate to improve
    for ii=1:nIters

        U = getvalue(V);

        m2 = SOSModel(solver=SDPsolver);
        @variable m2 ϵ
        @variable m2 α
        @polyvariable m2 V Z

        # Positive definiteness constraint
        @polyconstraint m2 V ≥ ϵ*sum(x.^o);

        # Apply matrix constraint, ∇U⋅g ≤ 0.
        Mv = [-dot(differentiate(V, x),f) differentiate(V,x)';
               differentiate(V,x)         I];
        @SDconstraint m2 Mv ⪰ 0 # Mv positive definite

        # Wynn inequality constraint
        @polyconstraint m2 dot(differentiate(V,x),f+2*differentiate(U,x)) ≥
            α*dot(differentiate(U,x),f) + (1+α)*sum(differentiate(U,x).^2)

        @constraint m2 α ≥ 0
        @constraint m2 ϵ ≥ 0
        @objective m2 Min α

        status = solve(m2);

    end

    return getvalue(V)

end

function minimalbasis(f,x)

    basis = 1.0;

    # Loop over the elements of f
    for (i,fi) in enumerate(f)
        basis = basis + fi*x[i];
    end
    basis = monomials(basis);
    print("Found minimal basis as:", "\n")
    print(basis, "\n")

    return basis

end

function eye(x)
    n = length(x);
    v = [1.0+0.0x[1]];
    for i = 1:n-1
        push!(v,1.0+0.0x[1]);
    end
    return diagm(v)
end

function plotlandscape(f, U, x, lims, scl=0.1)

    # Assemble the grid of points
    xv = collect(linspace(-2,2,30));
    yv = collect(linspace(-2,2,30));

    # Evaluate U using an array comprehension then plot
    Umat = [Float64(subs(U, x[1]=>xv[ii], x[2]=>yv[jj])) for ii=1:30, jj=1:30];
    plt = Plots.contour(xv,yv,Umat', xlabel="x1", ylabel="x2");

    # Evaluate f using an array comprehension then plot
    xm = vec([xv[ii] for jj=1:3:30, ii=1:3:30]);
    ym = vec([yv[ii] for ii=1:3:30, jj=1:3:30]);
    fMat = vec([(scl.*Float64(subs(f[1], x[1]=>xv[ii], x[2]=>yv[jj])),
                 scl.*Float64(subs(f[2], x[1]=>xv[ii], x[2]=>yv[jj])))
            for jj=1:3:30, ii=1:3:30]);
    Plots.quiver!(xm,ym, quiver=fMat);

    return plt

end

end
