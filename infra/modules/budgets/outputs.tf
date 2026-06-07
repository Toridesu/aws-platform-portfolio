output "budget_name" {
  description = "AWS Budget name."
  value       = try(aws_budgets_budget.monthly_cost[0].name, null)
}
