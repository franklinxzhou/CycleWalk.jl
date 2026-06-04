
""""""
function interpret_constraints(constraints)
    mfr_constraints = mfr_initialize_constraints()
	mfr_add_constraint!(mfr_constraints, constraints.population_constraint)
	# for check in constraints.checks
	# 	constraint = constraints.constraints[check]
	# 	# if constraint isa WHATEVER
	# end
    return mfr_constraints
end
