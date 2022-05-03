---
title: Terraform으로 EKS 구축하기
tags: ['AWS', 'Kubernetes', 'Tutorial']
date: 2022-03-31T00:02:00
author: Simon(윤상민)
summary:
  이전 글에서는 ECS / EKS에서 서비스 하는 것에 대한 개념을 풀어 써봤습니다. 이번 글에서는 잘 만들어진 모듈을 이용해 빠르게 구성해보겠습니다.
original: http://sixmen.com/ko/tech/2022-03-31-3-build-eks-cluster-with-terraform/
---

[이전 글](/ko/2022-03-31-2-web-application-using-eks/)에서는 ECS / EKS에서 서비스 하는 것에 대한 개념을 풀어 써봤습니다. 이번 글에서는 잘 만들어진 모듈을 이용해 빠르게 구성해보겠습니다.

> 모듈을 이용하면 편하긴 하지만 내부 개념을 정확히 이해하지 못한 채 사용하면 문제가 발생했을 때 해결이 어려운 것 같습니다. 결국 기본이 중요하다고 생각합니다.

## VPC 셋업

[VPC 모듈](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest)을 사용하면 이전에 길게 썼던 것을 짧게 기술할 수 있습니다. 이전에 만든 VPC 구조와 같지만 NAT 게이트웨이가 AZ 별로 따로 존재합니다.

```hcl
provider "aws" {
  region = "ap-northeast-2"
}

locals {
  cluster_name = "simon-test"
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "simon-test"
  cidr = "10.194.0.0/16"

  azs             = ["ap-northeast-2a", "ap-northeast-2c"]
  public_subnets  = ["10.194.0.0/24", "10.194.1.0/24"]
  private_subnets = ["10.194.100.0/24", "10.194.101.0/24"]

  enable_nat_gateway     = true
  one_nat_gateway_per_az = true

  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
  }
}
```

## EKS 클러스터 생성

[AWS EKS 모듈](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest)을 사용하면 EKS 클러스터도 쉽게 생성가능합니다.

```hcl
module "eks" {
  source = "terraform-aws-modules/eks/aws"

  cluster_name                    = local.cluster_name
  cluster_version                 = "1.21"
  cluster_endpoint_private_access = false
  cluster_endpoint_public_access  = true

  cluster_addons = {
    coredns = {
      resolve_conflicts = "OVERWRITE"
    }
    kube-proxy = {}
    vpc-cni = {
      resolve_conflicts = "OVERWRITE"
    }
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cloudwatch_log_group_retention_in_days = 1

  fargate_profiles = {
    default = {
      name = "default"
      selectors = [
        {
          namespace = "kube-system"
        },
        {
          namespace = "default"
        }
      ]
    }
  }
}
```

coredns 모듈 생성에서 계속 멈춰 있는 것을 볼 수 있습니다. Fargate만 있어서인데, [CoreDNS 패치를 해 주면](https://docs.aws.amazon.com/eks/latest/userguide/fargate-getting-started.html#fargate-gs-coredns)
 잠시 후 완료됩니다.

```bash
$ aws eks update-kubeconfig --region ap-northeast-2 --name simon-test --alias simon-test
$ kubectl patch deployment coredns -n kube-system --type json -p='[{"op": "remove", "path": "/spec/template/metadata/annotations/eks.amazonaws.com~1compute-type"}]'
```

## AWS Load Balancer Controller 설치

[AWS Load Balancer Controller](https://docs.aws.amazon.com/ko_kr/eks/latest/userguide/aws-load-balancer-controller.html)도 Terraform으로 설치가능합니다. 관련된 모듈이 여러 개 있는데 미묘하게 다 동작을 하지 않아서 결국은 자체적으로 구현해봤습니다. 이전에 쉘에서 실행한 명령을 Terraform으로 구성했다고 보시면 됩니다.

```hcl
locals {
  lb_controller_iam_role_name        = "inhouse-eks-aws-lb-ctrl"
  lb_controller_service_account_name = "aws-load-balancer-controller"
}

data "aws_eks_cluster_auth" "this" {
  name = local.cluster_name
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    token                  = data.aws_eks_cluster_auth.this.token
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  }
}

module "lb_controller_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"

  create_role = true

  role_name        = local.lb_controller_iam_role_name
  role_path        = "/"
  role_description = "Used by AWS Load Balancer Controller for EKS"

  role_permissions_boundary_arn = ""

  provider_url = replace(module.eks.cluster_oidc_issuer_url, "https://", "")
  oidc_fully_qualified_subjects = [
    "system:serviceaccount:kube-system:${local.lb_controller_service_account_name}"
  ]
  oidc_fully_qualified_audiences = [
    "sts.amazonaws.com"
  ]
}

data "http" "iam_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.4.0/docs/install/iam_policy.json"
}

resource "aws_iam_role_policy" "controller" {
  name_prefix = "AWSLoadBalancerControllerIAMPolicy"
  policy      = data.http.iam_policy.body
  role        = module.lb_controller_role.iam_role_name
}

resource "helm_release" "release" {
  name       = "aws-load-balancer-controller"
  chart      = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  namespace  = "kube-system"

  dynamic "set" {
    for_each = {
      "clusterName"           = module.eks.cluster_id
      "serviceAccount.create" = "true"
      "serviceAccount.name"   = local.lb_controller_service_account_name
      "region"                = "ap-northeast-2"
      "vpcId"                 = module.vpc.vpc_id
      "image.repository"      = "602401143452.dkr.ecr.ap-northeast-2.amazonaws.com/amazon/aws-load-balancer-controller"

      "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn" = module.lb_controller_role.iam_role_arn
    }
    content {
      name  = set.key
      value = set.value
    }
  }
}
```

## 어플리케이션 구동

간단한 서버(이번에는 공개 서버 - `k8s.gcr.io/echoserver` -를 이용합니다)를 Terraform으로 구성하겠습니다.

```hcl
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  token                  = data.aws_eks_cluster_auth.this.token
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
}

resource "kubernetes_deployment" "echo" {
  metadata {
    name = "echo"
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        "app.kubernetes.io/name" = "echo"
      }
    }
    template {
      metadata {
        labels = {
          "app.kubernetes.io/name" = "echo"
        }
      }
      spec {
        container {
          image = "k8s.gcr.io/echoserver:1.10"
          name  = "echo"
        }
      }
    }
  }
}

resource "kubernetes_service" "echo" {
  metadata {
    name = "echo"
  }
  spec {
    selector = {
      "app.kubernetes.io/name" = "echo"
    }
    port {
      port        = 8080
      target_port = 8080
    }
    type = "NodePort"
  }
}

resource "kubernetes_ingress_v1" "alb" {
  metadata {
    name = "alb"
    annotations = {
      "alb.ingress.kubernetes.io/scheme"      = "internet-facing",
      "alb.ingress.kubernetes.io/target-type" = "ip",
    }
  }
  spec {
    ingress_class_name = "alb"
    rule {
      http {
        path {
          backend {
            service {
              name = "echo"
              port {
                number = 8080
              }
            }
          }
          path = "/*"
        }
      }
    }
  }
}
```

이제 로드 밸런서 주소로 요청을 보내면 응답을 보내옵니다.

```bash
# k8s-default-alb-622014ceba-1089817135.ap-northeast-2.elb.amazonaws.com 같은 주소를 가집니다
$ LB_HOST=$(kubectl get ingress/alb -ojson | jq -r ".status.loadBalancer.ingress[0].hostname")
$ curl $LB_HOST

Hostname: echo-5499565745-tk7dm

Pod Information:
	-no pod information available-

Server values:
	server_version=nginx: 1.13.3 - lua: 10008

Request Information:
	client_address=10.194.1.162
	method=GET
	real path=/
	query=
	request_version=1.1
	request_scheme=http
	request_uri=http://k8s-default-alb-622014ceba-1089817135.ap-northeast-2.elb.amazonaws.com:8080/

Request Headers:
	accept=*/*
	host=k8s-default-alb-622014ceba-1089817135.ap-northeast-2.elb.amazonaws.com
	user-agent=curl/7.77.0
	x-amzn-trace-id=Root=1-6244434a-56cbdde1124166e4168d1cf4
	x-forwarded-for=1.2.3.4
	x-forwarded-port=80
	x-forwarded-proto=http

Request Body:
	-no body in request-
```

위 예에서는 같은 Terraform 파일에서 정의를 했기 때문에 module.eks의 출력을 이용했습니다. 만약 별도 스택으로 정의를 할 예정이고, kubeconfig가 설정된 상태면 다음과 같이 provider를 설정할 수 있습니다.

```hcl
provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "simon-test"
}
```

## 후기

EKS 시리즈 글을 작성하면서 클러스터 생성을 여러 번 반복했습니다. 반복할 때마다 하나씩 빼먹어서 문제점을 찾는데 한참 걸렸습니다. 그에 비해 잘 구성된 Terraform 모듈을 활용하니 확실히 편했습니다.

하지만 각 단계를 한번씩 해봐서 전체적인 이해가 된 상황(서브넷 태깅이 왜 필요한지, CoreDNS는 왜 생성되지 않는지등)이여서 모듈 활용도 가능했다고 봅니다.

이번 예에서는 예제 파일을 단순하게 하기 위해서, 쿠버네티스에서 동작하는 어플리케이션까지 Terraform으로 구성해봤습니다. Terraform으로 인프라를 통일하면 좋다고 생각하지만, 쿠버네티스는 별개의 정의 스펙이 있다보니 애매한 점이 있는 것 같습니다. 실제로 저희 실 서비스의 경우는 Terraform이 아니라 [Helm Charts](https://helm.sh/)를 사용해 어플리케이션을 정의했습니다.

이번 글이 쿠버네티스와 EKS를 이해하는데 도움이 되었기를 바랍니다.

## Appendix

- 예제 파일: [simon-sample.zip](/file/2022-03-31-3-simon-sample.zip)
- [terraform-aws-modules/vpc/aws | Terraform Registry](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest)
- [terraform-aws-modules/eks/aws | Terraform Registry](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest)
- AWS Load Balancer Controller 모듈
    - [Young-ook/eks/aws | Terraform Registry](https://registry.terraform.io/modules/Young-ook/eks/aws/latest/examples/lb)
    - [DNXLabs/eks-lb-controller/aws | Terraform Registry](https://registry.terraform.io/modules/DNXLabs/eks-lb-controller/aws/latest)
    - [basisai/lb-controller/aws | Terraform Registry](https://registry.terraform.io/modules/basisai/lb-controller/aws/latest)
- [Helm vs Terraform: What Are the Differences](https://phoenixnap.com/blog/helm-vs-terraform)
- [Kubernetes Provider](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs)
