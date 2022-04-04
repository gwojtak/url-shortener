variable "custom_domain" {
  description = "A custom domain name to associate with the API Gateway.  Use \"\" (the default) to not associate a domain name."
  type        = string
  default     = ""
}
