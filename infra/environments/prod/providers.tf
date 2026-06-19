# Terraform 本体の設定
terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
        source = "hashicorp/aws"
        version = "~> 5.0"
    }
  }
}

# AWS プロバイダの設定：どのリージョン・どの認証で操作するか
provider "aws" {
    region = var.region # 東京（変数で指定）
    profile = var.profile # SSOプロファイル
  
}