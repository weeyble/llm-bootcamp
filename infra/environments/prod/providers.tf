# Terraform 本体の設定
terraform {
  required_version = ">= 1.9"

  # state を S3 に保存し、S3ネイティブロック(use_lockfile)で排他する（リモートバックエンド）
  # ※ backend ブロックは変数(var.*)を使えない（評価が早いため）。値は直書き。
  backend "s3" {
    bucket       = "llm-bootcamp-tfstate-855071901694"
    key          = "environments/prod/terraform.tfstate"
    region       = "ap-northeast-1"
    use_lockfile = true # S3ネイティブロック（DynamoDB不要）
    encrypt      = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# AWS プロバイダの設定：どのリージョン・どの認証で操作するか
provider "aws" {
  region  = var.region  # 東京（変数で指定）
  profile = var.profile # SSOプロファイル

}