
function integrate_scenario_radau(mech_scen::MechanismScenario, x::Vector{Float64}; t_final::Float64=1.0,
        max_steps::Int64=1000)

    n_dof = num_x(mech_scen)

    (t_final < 0.0) && error("t_final (set to $t_final) most be non-negative")
    (length(x) == n_dof) || error("The length of x ($(length(x))) is different from the number of variables in the scenario ($n_dof). Did you forget the state variables for bristle friction?")

    t_cumulative = 0.0
    rr = makeRadauIntegrator(n_dof, 1.0e-16, mech_scen)
    data_time = zeros(Float64, max_steps)
    data_state = zeros(Float64, max_steps, n_dof)
    verify_bristle_ids!(mech_scen, x)  # make sure than any bristle friction variables are used exactly once
    for k = 1:max_steps
        h, x = solveRadau(rr, x)
        principal_value!(mech_scen, x)
        t_cumulative += h
        data_time[k] = t_cumulative
        data_state[k, :] = x
        if t_final < t_cumulative
            return data_time[1:k], data_state[1:k, :], rr
        end
    end
    return data_time, data_state, rr
end
