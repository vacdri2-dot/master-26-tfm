locals {
  acr_name_raw  = "acr${var.name_prefix}${var.acr_name_suffix != null ? var.acr_name_suffix : ""}"
  acr_name_base = lower(replace(local.acr_name_raw, "-", ""))
  acr_name      = substr(local.acr_name_base, 0, 50)
  agent_apps = {
    orchestrator = {
      app_name         = "orchestrator-${var.name_prefix}"
      image            = coalesce(try(var.agent_images.orchestrator, null), "${azurerm_container_registry.this.login_server}/orchestrator:latest")
      external_ingress = true
    }
    rag = {
      app_name         = "rag-agent-${var.name_prefix}"
      image            = coalesce(try(var.agent_images.rag, null), "${azurerm_container_registry.this.login_server}/rag:latest")
      external_ingress = false
    }
    code = {
      app_name         = "code-agent-${var.name_prefix}"
      image            = coalesce(try(var.agent_images.code, null), "${azurerm_container_registry.this.login_server}/code-agent:latest")
      external_ingress = false
    }
  }
  # AZURE_CLIENT_ID lets DefaultAzureCredential pick the agent's own user-assigned identity in a multi-MI Container App.
  default_agent_env_vars = {
    for k, _ in local.agent_apps : k => {
      AZURE_CLIENT_ID = var.managed_identities[k].client_id
    }
  }
  merged_agent_env_vars = {
    for k, _ in local.agent_apps : k => merge(
      local.default_agent_env_vars[k],
      lookup(var.agent_env_vars, k, {}),
    )
  }
  merged_agent_key_vault_secrets = {
    for k, _ in local.agent_apps : k => lookup(var.agent_key_vault_env_secrets, k, {})
  }
  merged_agent_value_secrets = {
    for k, _ in local.agent_apps : k => lookup(var.agent_value_secrets, k, {})
  }
  merged_agent_value_secret_names = {
    for k, _ in local.agent_apps : k => toset(nonsensitive(keys(local.merged_agent_value_secrets[k])))
  }
}

resource "azurerm_container_registry" "this" {
  name                = local.acr_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Basic"
  admin_enabled       = var.acr_admin_enabled

  tags = var.tags
}

resource "azurerm_role_assignment" "acr_pull" {
  for_each = var.managed_identities

  scope                = azurerm_container_registry.this.id
  role_definition_name = "AcrPull"
  principal_id         = each.value.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_container_app_environment" "this" {
  name                = "cae-${var.name_prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name

  infrastructure_subnet_id   = var.container_apps_subnet_id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [
      infrastructure_resource_group_name,
      workload_profile,
    ]
  }
}

resource "azurerm_container_app" "agent" {
  for_each = local.agent_apps

  name                         = each.value.app_name
  resource_group_name          = var.resource_group_name
  container_app_environment_id = azurerm_container_app_environment.this.id
  revision_mode                = "Single"

  identity {
    type         = "UserAssigned"
    identity_ids = [var.managed_identities[each.key].id]
  }

  registry {
    server   = azurerm_container_registry.this.login_server
    identity = var.managed_identities[each.key].id
  }

  dynamic "secret" {
    for_each = local.merged_agent_key_vault_secrets[each.key]
    content {
      name                = lower(replace(secret.key, "_", "-"))
      identity            = var.managed_identities[each.key].id
      key_vault_secret_id = secret.value
    }
  }

  dynamic "secret" {
    for_each = local.merged_agent_value_secret_names[each.key]
    content {
      name  = lower(replace(secret.value, "_", "-"))
      value = local.merged_agent_value_secrets[each.key][secret.value]
    }
  }

  ingress {
    external_enabled = each.value.external_ingress
    target_port      = var.agent_container_port
    transport        = "auto"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  template {
    min_replicas = var.agent_min_replicas
    max_replicas = var.agent_max_replicas

    container {
      name   = each.key
      image  = each.value.image
      cpu    = var.agent_cpu
      memory = var.agent_memory

      dynamic "env" {
        for_each = local.merged_agent_env_vars[each.key]
        content {
          name  = env.key
          value = env.value
        }
      }

      dynamic "env" {
        for_each = local.merged_agent_key_vault_secrets[each.key]
        content {
          name        = env.key
          secret_name = lower(replace(env.key, "_", "-"))
        }
      }

      dynamic "env" {
        for_each = local.merged_agent_value_secret_names[each.key]
        content {
          name        = env.value
          secret_name = lower(replace(env.value, "_", "-"))
        }
      }

      liveness_probe {
        transport = "HTTP"
        port      = var.agent_container_port
        path      = "/health"
      }

      readiness_probe {
        transport = "HTTP"
        port      = var.agent_container_port
        path      = "/health"
      }
    }
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [workload_profile_name]
  }

  # azurerm does not infer depends_on from registry.identity; AcrPull must exist before the first revision pulls.
  depends_on = [azurerm_role_assignment.acr_pull]
}

resource "azurerm_monitor_diagnostic_setting" "container_app_metrics" {
  for_each = azurerm_container_app.agent

  name                       = "diag-metrics-${each.key}"
  target_resource_id         = each.value.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_metric {
    category = "AllMetrics"
  }
}
