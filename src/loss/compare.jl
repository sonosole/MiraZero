export require_great_than_zero
export require_great_equal_than_zero

export require_less_than_zero
export require_less_equal_than_zero


"""
    require_great_than_zero(x::Variable) -> y::Variable

Suppose `xₖ` is an element in `x`. `xₖ` > 0 is a constraint.
+ If `xₖ` > 0 then `cost` is 0.
+ If `xₖ` ≤ 0 then `cost` is 1, to futher satisfy `xₖ` > 0, `xₖ` must be lager, so Δxₖ = -lr * δxₖ > 0 ⇒ δxₖ < 0
"""
function require_great_than_zero(x::Variable{T}) where T
    o = eltype(T)(0)  # typed zero
    m = ᵛ(x) .≤ o     # unsatisfied is marked 1, satisfied is marked 0
    y = Variable{T}(m, x.backprop)
    if y.backprop
        y.backward = function ∇require_great_than_zero()
            if needgrad(x)
                x ← δ(y) .* (-m)
            end
        end
        addchild(y, x)
    end
    return y
end


"""
    require_great_equal_than_zero(x::Variable) -> y::Variable

Suppose `xₖ` is an element in `x`. `xₖ` ≥ 0 is a constraint.
+ If `xₖ` ≥ 0 then `cost` is 0.
+ If `xₖ` < 0 then `cost` is 1, to futher satisfy `xₖ` ≥ 0, `xₖ` must be lager, so Δx = -lr * δx > 0 ⇒ δx < 0
"""
function require_great_equal_than_zero(x::Variable{T}) where T
    o = eltype(T)(0)  # typed zero
    m = ᵛ(x) .< o     # unsatisfied is marked 1, satisfied is marked 0
    y = Variable{T}(m, x.backprop)
    if y.backprop
        y.backward = function ∇require_great_equal_than_zero()
            if needgrad(x)
                x ← δ(y) .* (-m)
            end
        end
        addchild(y, x)
    end
    return y
end




"""
    require_less_than_zero(x::Variable) -> y::Variable

Suppose `xₖ` is an element in `x`. `xₖ` < 0 is a constraint.
+ If `xₖ` < 0 then `cost` is 0.
+ If `xₖ` ≥ 0 then `cost` is 1, to futher satisfy `xₖ` < 0, `xₖ` must be smaller, so Δx = -lr * δx < 0 ⇒ δx > 0
"""
function require_less_than_zero(x::Variable{T}) where T
    o = eltype(T)(0)  # typed zero
    m = ᵛ(x) .≥ o     # unsatisfied is marked 1, satisfied is marked 0
    y = Variable{T}(m, x.backprop)
    if y.backprop
        y.backward = function ∇require_less_than_zero()
            if needgrad(x)
                x ← δ(y) .* m
            end
        end
        addchild(y, x)
    end
    return y
end


"""
    require_less_equal_than_zero(x::Variable) -> y::Variable

Suppose `xₖ` is an element in `x`. `xₖ` ≤ 0 is a constraint.
+ If `xₖ` ≤ 0 then `cost` is 0.
+ If `xₖ` > 0 then `cost` is 1, to futher satisfy `xₖ` ≤ 0, `xₖ` must be smaller, so Δx = -lr * δx < 0 ⇒ δx > 0
"""
function require_less_equal_than_zero(x::Variable{T}) where T
    o = eltype(T)(0)  # typed zero
    m = ᵛ(x) .> o     # unsatisfied is marked 1, satisfied is marked 0
    y = Variable{T}(m, x.backprop)
    if y.backprop
        y.backward = function ∇require_less_equal_than_zero()
            if needgrad(x)
                x ← δ(y) .* m
            end
        end
        addchild(y, x)
    end
    return y
end

# Variable vs Variable
Base.:>(x::Variable, y::Variable) = require_great_than_zero(x - y)
Base.:≥(x::Variable, y::Variable) = require_great_equal_than_zero(x - y)
Base.:<(x::Variable, y::Variable) = require_less_than_zero(x - y)
Base.:≤(x::Variable, y::Variable) = require_less_equal_than_zero(x - y)
# Variable vs TensorOrReal
Base.:>(x::Variable, y::TensorOrReal) = require_great_than_zero(x - y)
Base.:≥(x::Variable, y::TensorOrReal) = require_great_equal_than_zero(x - y)
Base.:<(x::Variable, y::TensorOrReal) = require_less_than_zero(x - y)
Base.:≤(x::Variable, y::TensorOrReal) = require_less_equal_than_zero(x - y)
# TensorOrReal vs Variable
Base.:>(x::TensorOrReal, y::Variable) = require_great_than_zero(x - y)
Base.:≥(x::TensorOrReal, y::Variable) = require_great_equal_than_zero(x - y)
Base.:<(x::TensorOrReal, y::Variable) = require_less_than_zero(x - y)
Base.:≤(x::TensorOrReal, y::Variable) = require_less_equal_than_zero(x - y)
