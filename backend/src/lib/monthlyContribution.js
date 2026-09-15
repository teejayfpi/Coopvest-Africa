/**
 * Resolution of a member's current monthly savings contribution.
 *
 * Two stores hold this figure:
 *   - `contribution_plans.current_monthly_amount` — the live plan. Registration
 *     onboarding seeds it and the member's increase/reduction requests update
 *     it, so it is the source of truth.
 *   - `savings.monthly_savings` — a denormalised mirror. It can lag behind the
 *     plan and is absent for members whose plan predates the sync, so it is
 *     only a fallback.
 *
 * A member raising their contribution must see the new amount reflected in
 * "Your obligations this month", hence the plan always wins when present.
 */
function resolveMonthlyContribution({ planAmount, savingsAmount } = {}) {
  const plan = Number(planAmount);
  if (Number.isFinite(plan) && plan > 0) return plan;

  const savings = Number(savingsAmount);
  if (Number.isFinite(savings) && savings > 0) return savings;

  return 0;
}

module.exports = { resolveMonthlyContribution };
