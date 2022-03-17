MaxEnt
================

-   Introduction
    -   Presence vs. Presence-Absence
    -   Statistical Explanation
-   MaxEnt and TidyModels

# Introduction and Theory

<https://onlinelibrary.wiley.com/doi/epdf/10.1111/j.1472-4642.2010.00725.x>

MaxEnt is a modeling technique for presence-only datasets.

**NOTE**: If presence-absence data is available, MaxEnt is probably not
your best course of action.

**Terms**:

-   *L*: landscape of interest
-   **z**: vector of environmental covariates
-   *f*(**z**) : probability desnity of covariates across *L*
    -   *f*₁(**z**) : density in locations w/in L where species is
        present
    -   *f*₀(**z**) : density in locations w/in L where species is
        absent
        -   cannot be estimated from presence-only data
-   Pr(y = 1 \| **z**): probability of presence of the species based on
    env

Baye’s Theorem: Pr(y = 1 \| **z**) = *f*₁(**z**)Pr(y = 1) / *f*(**z**)

### Presence vs. Presence-Absence

-   Absence data is often unreliable - species are not perfectly
    detectable and may not occupy all suitable habitat.
    -   this unreliability still carries over to presence data (lack of
        presence in that area)
-   Presence-only data cannot yield **prevalence**: Pr(y=1), the
    proportion of occupied sites in the landscape
-   **sample selection bias** (when some areas are sampled more than
    others) has greatly affects presence-only models
    -   if *f*₁(**z**) is contaminated by ss bias *s*(**z**), model will
        give estimate of *f*₁(**z**)*s*(**z**), not *f*₁(**z**)
    -   in presence-absence data, ss bias affects both presence and
        absence and will cancel out
-   Presence data often doesn’t have an associated temporal or spatial
    scale needed to properly define the response variable.

### Statistical Explanation

-   MaxEnt finds a nonlinear fitted function defined over many
    **features**
    -   features have six classes: linear, product, quadratic, hinge,
        threshold, and categorical
    -   there will be more features than covariates
    -   features are selected by the model in a similar way to
        regression (choosing the most impactful feature)
