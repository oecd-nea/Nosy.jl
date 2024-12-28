"""
Single unit commitment.
"""

struct SingleUnitCommitmentBehavior{T} <: AbstractUnitCommitmentBehavior{T} end

SingleUnitCommitmentBehavior(c, b, cap) = error("not implemented")