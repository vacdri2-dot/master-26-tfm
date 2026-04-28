output "workbook_id" {
  description = "Resource ID of the Azure Monitor workbook."
  value       = azapi_resource.workbook.id
}

output "workbook_name" {
  description = "Workbook resource name."
  value       = azapi_resource.workbook.name
}
