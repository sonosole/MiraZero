export checkgrad


"""
    checkgrad(block::Block,            # a block contains params
              x::Variable;             # input of block
              dw::AbstractFloat=1e-7,  # increment of each params to check gradient
              tol::AbstractFloat=0.1,  # tolerance of error
              onlyone::Bool=false)     # true for only one param shall be checked

if all gradients were true, then it returns true.
"""
function checkgrad(block::B,
                   x::Variable;
                   dw::AbstractFloat=1e-7,
                   tol::AbstractFloat=0.1,
                   onlyone::Bool=false) where B <: Block
    istrue = true
    params = paramsof(block)
    for w in params
        # [1] forward 1st time
        y₁ = forward(block, x)
        C₁ = loss(y₁)
        backward(C₁)
        dw₁ = δ(w)[1]
        zerograds!(params)

        # [2] with a small change
        ᵛ(w)[1] += dw

        # [3] forward 2nd time
        y₂ = forward(block, x)
        C₂ = loss(y₂)
        backward(C₂)
        dw₂ = δ(w)[1]
        zerograds!(params)

        # [4] backward gradient vs numerical gradient
        ∂L∂w = (dw₂ + dw₁) / 2
        dLdw = (cost(C₂) - cost(C₁)) / dw

        # abnormal cases
        ∂L∂w==0 && dLdw==0 && return true
        ∂L∂w==0 && abs(dLdw)<=1e-5 && return true
        abs(∂L∂w)<=1e-5 && dLdw==0 && return true

        # [5] check if the auto-grad is true or not
        err = abs( (∂L∂w-dLdw) / ∂L∂w ) * 100
        istrue = (err ≤ tol) && istrue
        if !istrue
            println(yellow!("backward  gradient: $∂L∂w"))
            println(yellow!("numerical gradient: $dLdw"))
        end
        onlyone ? break : continue
    end
    return istrue
end


"""
checkgrad(fn::Function,
          x::Variable;
          dx::AbstractFloat=1e-8,
          tol::AbstractFloat=0.1)

if gradients were true, then it returns true. Attention, functions with ! ending
can NOT used here.
"""
function checkgrad(fn::Function,
                   x::Variable;
                   dx::AbstractFloat=1e-8,
                   tol::AbstractFloat=0.1)
    x.keepsgrad = true
    # [1] forward 1st time
    y₁ = fn(x)
    C₁ = loss(y₁)
    backward(C₁)
    dx₁ = δ(x)[1]
    zerograds!(x)

    # [2] with a small change
    ᵛ(x)[1] += dx

    # [3] forward 2nd time
    y₂ = fn(x)
    C₂ = loss(y₂)
    backward(C₂)
    dx₂ = δ(x)[1]
    zerograds!(x)

    # [4] backward gradient vs numerical gradient
    ∂L∂x = (dx₂ + dx₁) / 2
    dLdx = (cost(C₂) - cost(C₁)) / dx

    # [5] check if the auto-grad is true or not
    ∂L∂x==0 && dLdx==0 && return true
    ∂L∂x==0 && abs(dLdx)<=1e-5 && return true
    abs(∂L∂x)<=1e-5 && dLdx==0 && return true

    err = abs( 1 - ∂L∂x / dLdx ) * 100
    istrue = (err ≤ tol)
    if !istrue
        println(yellow!("backward  gradient: $∂L∂x"))
        println(yellow!("numerical gradient: $dLdx"))
    end
    return istrue
end