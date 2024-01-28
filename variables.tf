variable "aca_name" {
  default     = "cmsdev002"
  type        = string
  description = "Name for Azure Container App"
}
variable "location" {
  default     = "uksouth"
  type        = string
  description = "Location of Azure resources"
}

## TAGS
variable "tags" {
  type = object({
    ApplicationService : string
    BusinessOwner : string
    BusinessUnit : string
    DataClassification : string
    Environment : string
    IRCode : string
    OU : string
    ProjectCodeOrCostCentre : string
    ServiceTier : string
    SupportInfoAppTeam : string
    SupportInfoInfTeam : string
    TaskOrGLCode : string
    TechnicalOwner : string
  })
  description = "Tags to apply"
  default = {
    ApplicationService : "airtricitycmsdev"
    BusinessOwner : "Robbie.Holden@sse.com"
    BusinessUnit : "ECS"
    DataClassification : "Public"
    Environment : "DEV"
    IRCode : "N/A"
    OU : "N/A"
    ProjectCodeOrCostCentre : "2486"
    ServiceTier : "Not Defined"
    SupportInfoAppTeam : "HCL_Cloud_&_Infrastructure_Delivery_Support"
    SupportInfoInfTeam : "HCL_Cloud_&_Infrastructure_Delivery_Support"
    TaskOrGLCode : "RITM2043111"
    TechnicalOwner : "Naadir.Akhtar@sse.com"
  }
}