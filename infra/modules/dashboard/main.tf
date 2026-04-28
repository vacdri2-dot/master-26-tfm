data "azurerm_resource_group" "this" {
  name = var.resource_group_name
}

locals {
  agent_app_names_json = jsonencode(values(var.container_app_names))
  # Azure Monitor normalizes _ResourceId to lowercase; the IDs from azurerm_container_app preserve casing.
  agent_app_ids_json = jsonencode([for id in values(var.container_app_ids) : lower(id)])
  # Azure Monitor workbooks require the resource name to be a GUID; uuidv5 gives a deterministic UUID per workspace.
  workbook_name = uuidv5("dns", var.log_analytics_workspace_id)

  workbook_data = {
    version = "Notebook/1.0"
    items = [
      {
        type = 1
        name = "intro"
        content = {
          json = <<-MARKDOWN
            ## Azure Monitor Demo Dashboard
            Live telemetry for the deployed TFM agents.

            Data sources:
            - Application Insights request telemetry via workspace-based tables
            - Azure Container Apps metrics exported to Log Analytics
            - Container Apps platform logs for scale-related events
          MARKDOWN
        }
      },
      {
        type = 3
        name = "latency-summary"
        content = {
          version      = "KqlItem/1.0"
          title        = "Latency P50/P95 by agent (last 30 minutes)"
          queryType    = 0
          resourceType = "microsoft.operationalinsights/workspaces"
          size         = 0
          query        = <<-KQL
            let agentRoles = dynamic(["orchestrator", "rag", "code"]);
            AppRequests
            | where TimeGenerated > ago(30m)
            | where set_has_element(agentRoles, AppRoleName)
            | summarize
                Requests = sum(ItemCount),
                P50_ms = percentile(DurationMs, 50),
                P95_ms = percentile(DurationMs, 95),
                ErrorRate_pct = 100.0 * todouble(sumif(ItemCount, Success == false)) / todouble(sum(ItemCount))
              by Agent = AppRoleName
            | order by Agent asc
          KQL
        }
      },
      {
        type = 3
        name = "requests-trend"
        content = {
          version      = "KqlItem/1.0"
          title        = "Requests by agent (last 6 hours)"
          queryType    = 0
          resourceType = "microsoft.operationalinsights/workspaces"
          size         = 0
          query        = <<-KQL
            let agentRoles = dynamic(["orchestrator", "rag", "code"]);
            AppRequests
            | where TimeGenerated > ago(6h)
            | where set_has_element(agentRoles, AppRoleName)
            | summarize Requests = sum(ItemCount) by bin(TimeGenerated, 5m), Agent = AppRoleName
            | render timechart
          KQL
        }
      },
      {
        type = 3
        name = "errors-trend"
        content = {
          version      = "KqlItem/1.0"
          title        = "Errors by agent (last 6 hours)"
          queryType    = 0
          resourceType = "microsoft.operationalinsights/workspaces"
          size         = 0
          query        = <<-KQL
            let agentRoles = dynamic(["orchestrator", "rag", "code"]);
            AppRequests
            | where TimeGenerated > ago(6h)
            | where set_has_element(agentRoles, AppRoleName)
            | where Success == false
            | summarize Errors = sum(ItemCount) by bin(TimeGenerated, 5m), Agent = AppRoleName
            | render timechart
          KQL
        }
      },
      {
        type = 3
        name = "cpu-trend"
        content = {
          version      = "KqlItem/1.0"
          title        = "Container Apps CPU percentage (last 6 hours)"
          queryType    = 0
          resourceType = "microsoft.operationalinsights/workspaces"
          size         = 0
          query        = <<-KQL
            let apps = dynamic(${local.agent_app_ids_json});
            AzureMetrics
            | where TimeGenerated > ago(6h)
            | where MetricName == "CpuPercentage"
            | where set_has_element(apps, _ResourceId)
            | summarize CPU_pct = avg(Average) by bin(TimeGenerated, 5m), App = Resource
            | render timechart
          KQL
        }
      },
      {
        type = 3
        name = "memory-trend"
        content = {
          version      = "KqlItem/1.0"
          title        = "Container Apps memory percentage (last 6 hours)"
          queryType    = 0
          resourceType = "microsoft.operationalinsights/workspaces"
          size         = 0
          query        = <<-KQL
            let apps = dynamic(${local.agent_app_ids_json});
            AzureMetrics
            | where TimeGenerated > ago(6h)
            | where MetricName == "MemoryPercentage"
            | where set_has_element(apps, _ResourceId)
            | summarize Memory_pct = avg(Average) by bin(TimeGenerated, 5m), App = Resource
            | render timechart
          KQL
        }
      },
      {
        type = 3
        name = "replicas-trend"
        content = {
          version      = "KqlItem/1.0"
          title        = "Active replicas by agent (last 6 hours)"
          queryType    = 0
          resourceType = "microsoft.operationalinsights/workspaces"
          size         = 0
          query        = <<-KQL
            let apps = dynamic(${local.agent_app_ids_json});
            AzureMetrics
            | where TimeGenerated > ago(6h)
            | where MetricName == "Replicas"
            | where set_has_element(apps, _ResourceId)
            | summarize ActiveReplicas = max(Maximum) by bin(TimeGenerated, 5m), App = Resource
            | render timechart
          KQL
        }
      },
      {
        type = 3
        name = "scaling-events"
        content = {
          version      = "KqlItem/1.0"
          title        = "Recent scaling events"
          queryType    = 0
          resourceType = "microsoft.operationalinsights/workspaces"
          size         = 0
          query        = <<-KQL
            let apps = dynamic(${local.agent_app_names_json});
            ContainerAppSystemLogs
            | where TimeGenerated > ago(6h)
            | where set_has_element(apps, ContainerAppName)
            | where EventSource has_any ("KEDA", "Revision", "Replica")
                or Reason has_any ("Scale", "Scaling")
                or Log has_any ("scale", "scaled", "replica")
            | project TimeGenerated, ContainerAppName, EventSource, Reason, Log
            | order by TimeGenerated desc
          KQL
        }
      },
    ]
    isLocked            = false
    fallbackResourceIds = [var.log_analytics_workspace_id]
  }
}

resource "azapi_resource" "workbook" {
  type      = "Microsoft.Insights/workbooks@2023-06-01"
  name      = local.workbook_name
  parent_id = data.azurerm_resource_group.this.id
  location  = var.location

  tags = merge(
    var.tags,
    {
      "hidden-title" = "Azure Monitor Demo Dashboard"
    },
  )

  body = {
    kind = "shared"
    properties = {
      category       = "workbook"
      description    = "Live Azure Monitor dashboard for the TFM agent demo."
      displayName    = "Azure Monitor Demo Dashboard"
      serializedData = jsonencode(local.workbook_data)
      sourceId       = var.log_analytics_workspace_id
      version        = "Notebook/1.0"
    }
  }

  schema_validation_enabled = false
  response_export_values    = ["*"]
}
