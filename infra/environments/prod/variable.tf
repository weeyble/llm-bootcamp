variable "region" {
  description = "メインで使う AWS リージョン"
  type        = string
  default     = "ap-northeast-1" #東京
}

variable "profile" {
  description = "AWS CLI のプロファイル名（SSOプロファイル）"
  type        = string
  default     = "llm-bootcamp"
}

variable "project" {
  description = "リソース名の接頭辞に使う識別子"
  type        = string
  default     = "llm-bootcamp"
}