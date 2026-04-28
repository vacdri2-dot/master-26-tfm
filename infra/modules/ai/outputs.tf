output "openai_id" {
  description = "ID of the Azure OpenAI account."
  value       = azurerm_cognitive_account.openai.id
}

output "openai_name" {
  description = "Name of the Azure OpenAI account."
  value       = azurerm_cognitive_account.openai.name
}

output "openai_endpoint" {
  description = "Endpoint URL of the Azure OpenAI account."
  value       = azurerm_cognitive_account.openai.endpoint
}

output "gpt4o_deployment_name" {
  description = "Name of the GPT-4o deployment."
  value       = azurerm_cognitive_deployment.gpt4o.name
}

output "embedding_deployment_name" {
  description = "Name of the text-embedding-3-small deployment."
  value       = azurerm_cognitive_deployment.embedding.name
}
