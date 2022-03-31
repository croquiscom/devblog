---
title: EKS를 사용해서 어플리케이션 서비스 하기
tags: ['AWS', 'Kubernetes', 'Tutorial']
date: 2022-03-31T00:01:00
summary:
  ECS 아티클에 이어 이번 글에서는 같은 서비스를 EKS로 구축해보도록 하겠습니다.
  간단하게 구축하는 것은 eksctl을 쓰면 되지만, 내부 이해를 위해 여기서는 기본부터 구현하도록 하겠습니다.
original: http://sixmen.com/ko/tech/2022-03-31-2-web-application-using-eks/
---

[ECS 아티클](/ko/2022-03-31-1-web-application-using-ecs/)에 이어 이번 글에서는 같은 서비스를 EKS로 구축해보도록 하겠습니다.

간단하게 구축하는 것은 [eksctl](https://eksctl.io/)을 쓰면 되지만, 내부 이해를 위해 여기서는 기본부터 구현하도록 하겠습니다.

## VPC 셋업

VPC는 이전과 마찬가지로 두 개의 AZ에 퍼블릭 서브넷과 프리이빗 서브넷이 필요합니다. 다만 로드 밸런서가 정상적으로 배치되려며 특정한 태그를 서브넷에 부여해야합니다.

![Sample VPC](/img/content/2022-03-31-2/2022-03-31-2-01.png)

서비스 컨테이너만 정의하는 ECS와 달리 쿠버네티스는 클러스터 내에서 로드 밸런서, 영구 볼륨등도 정의할 수 있습니다. 이때 정의는 쿠버네티스안에서 하지만 실제 만들어지는 것은 쿠버네티스와 무관한 AWS 리소스(ALB, EBS등)입니다. 쿠버네티스 자체는 AWS 구조와 독립적이고, 태그등 다른 방법을 통해 쿠버네티스 리소스가 위치할 AWS 리소스를 찾게 됩니다.

[EKS에서 애플리케이션 로드 밸런싱 문서](https://docs.aws.amazon.com/ko_kr/eks/latest/userguide/alb-ingress.html)에 따라 다음 태그를 설정해줍니다.

- `kubernetes.io/cluster/<name>`: `shared`
- `kubernetes.io/role/internal-elb`: 프라이빗 서브넷에 대해 `1`로 설정합니다.
- `kubernetes.io/role/elb`: 퍼블릭 서브넷에 대해 `1`로 설정합니다.

```hcl
provider "aws" {
  region = "ap-northeast-2"
}

locals {
  vpc_name        = "simon-test"
  cidr            = "10.194.0.0/16"
  public_subnets  = ["10.194.0.0/24", "10.194.1.0/24"]
  private_subnets = ["10.194.100.0/24", "10.194.101.0/24"]
  azs             = ["ap-northeast-2a", "ap-northeast-2c"]
  cluster_name    = "simon-test"
}

## VPC를 생성합니다
resource "aws_vpc" "this" {
  cidr_block = local.cidr
  tags       = { Name = local.vpc_name }
}

## VPC 생성시 기본으로 생성되는 라우트 테이블에 이름을 붙입니다
## 이걸 서브넷에 연결해 써도 되지만, 여기서는 사용하지 않습니다
resource "aws_default_route_table" "this" {
  default_route_table_id = aws_vpc.this.default_route_table_id
  tags                   = { Name = "${local.vpc_name}-default" }
}

## VPC 생성시 기본으로 생성되는 보안 그룹에 이름을 붙입니다
resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${local.vpc_name}-default" }
}

## 퍼플릭 서브넷에 연결할 인터넷 게이트웨이를 정의합니다
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${local.vpc_name}-igw" }
}

## 퍼플릭 서브넷에 적용할 라우팅 테이블
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${local.vpc_name}-public" }
}

## 퍼플릭 서브넷에서 인터넷에 트래픽 요청시 앞서 정의한 인터넷 게이트웨이로 보냅니다
resource "aws_route" "public_worldwide" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

## 퍼플릭 서브넷을 정의합니다
resource "aws_subnet" "public" {
  count = length(local.public_subnets) # 여러개를 정의합니다

  vpc_id                  = aws_vpc.this.id
  cidr_block              = local.public_subnets[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true # 퍼플릭 서브넷에 배치되는 서비스는 자동으로 공개 IP를 부여합니다
  tags = {
    Name = "${local.vpc_name}-public-${count.index + 1}",
    "kubernetes.io/cluster/${local.cluster_name}" = "shared", # 다른 부분
    "kubernetes.io/role/elb"                      = "1" # 다른 부분
  }
}

## 퍼플릭 서브넷을 라우팅 테이블에 연결합니다
resource "aws_route_table_association" "public" {
  count = length(local.public_subnets)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

## NAT 게이트웨이는 고정 IP를 필요로 합니다
resource "aws_eip" "nat_gateway" {
  vpc  = true
  tags = { Name = "${local.vpc_name}-natgw" }
}

## 프라이빗 서브넷에서 인터넷 접속시 사용할 NAT 게이트웨이
resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat_gateway.id
  subnet_id     = aws_subnet.public[0].id # NAT 게이트웨이 자체는 퍼플릭 서브넷에 위치해야 합니다
  tags          = { Name = "${local.vpc_name}-natgw" }
}

## 프라이빗 서브넷에 적용할 라우팅 테이블
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${local.vpc_name}-private" }
}

## 프라이빗 서브넷에서 인터넷에 트래픽 요청시 앞서 정의한 NAT 게이트웨이로 보냅니다
resource "aws_route" "private_worldwide" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this.id
}

## 프라이빗 서브넷을 정의합니다
resource "aws_subnet" "private" {
  count = length(local.private_subnets) # 여러개를 정의합니다

  vpc_id            = aws_vpc.this.id
  cidr_block        = local.private_subnets[count.index]
  availability_zone = local.azs[count.index]
  tags = {
    Name = "${local.vpc_name}-private-${count.index + 1}",
    "kubernetes.io/cluster/${local.cluster_name}" = "shared", # 다른 부분
    "kubernetes.io/role/internal-elb"             = "1" # 다른 부분
  }
}

## 프라이빗 서브넷을 라우팅 테이블에 연결합니다
resource "aws_route_table_association" "private" {
  count = length(local.private_subnets)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
```

## EKS 클러스터 생성

ECS가 하나의 리소스로 끝난 것에 비해 EKS는 조금 복잡합니다.

```hcl
## 클러스터가 사용할 역할을 정의합니다.
## AmazonEKSClusterPolicy와 AmazonEKSVPCResourceController를 포함합니다.
resource "aws_iam_role" "cluster" {
  name = "${local.cluster_name}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "eks.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}
resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}
resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSVPCResourceController" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.cluster.name
}

## EKS 클러스터를 정의합니다
resource "aws_eks_cluster" "this" {
  name     = local.cluster_name
  role_arn = aws_iam_role.cluster.arn
  vpc_config {
    subnet_ids = aws_subnet.private[*].id
  }
  depends_on = [ # see https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_cluster#example-usage
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.cluster_AmazonEKSVPCResourceController,
  ]
}

## Fargate에서 팟 배치시 사용하는 실행 역할을 정의합니다.
## AmazonEKSFargatePodExecutionRolePolicy를 포함합니다.
resource "aws_iam_role" "pod_execution" {
  name = "${local.cluster_name}-eks-pod-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "eks-fargate-pods.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}
resource "aws_iam_role_policy_attachment" "pod_execution_AmazonEKSFargatePodExecutionRolePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSFargatePodExecutionRolePolicy"
  role       = aws_iam_role.pod_execution.name
}

## EKS 클러스터에 노드를 Fargate로 공급합니다.
## default/kube-system 네임스페이스를 가진 팟에 대해 적용됩니다.
resource "aws_eks_fargate_profile" "default" {
  cluster_name           = aws_eks_cluster.this.name
  fargate_profile_name   = "fp-default"
  pod_execution_role_arn = aws_iam_role.pod_execution.arn
  subnet_ids             = aws_subnet.private[*].id # 프라이빗 서브넷만 줄 수 있습니다.
  selector {
    namespace = "default"
  }
  selector {
    namespace = "kube-system"
  }
}
```

쿠버네티스 클러스터에 접근할 수 있도록 [kubeconfig를 생성](https://docs.aws.amazon.com/ko_kr/eks/latest/userguide/create-kubeconfig.html)합니다. 

```bash
$ aws eks update-kubeconfig --region ap-northeast-2 --name simon-test --alias simon-test
```

이제 쿠버네티스 클러스터의 상태를 볼 수 있습니다.

```bash
$ kubectl get svc
NAME         TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
kubernetes   ClusterIP   172.20.0.1   <none>        443/TCP   23m
```

그런데 팟 목록을 보면 기본적으로 실행되어야 할 coredns 팟이 뜨지 않는 것이 보입니다.

```bash
$ kubectl get pods -n kube-system
NAME                       READY   STATUS    RESTARTS   AGE
coredns-6dbb778559-clx8r   0/1     Pending   0          13m
coredns-6dbb778559-zpx2h   0/1     Pending   0          13m
```

Fargate 노드만 사용하려면 [CoreDNS 내용을 수정 해줘야](https://docs.aws.amazon.com/eks/latest/userguide/fargate-getting-started.html#fargate-gs-coredns) 합니다.

```bash
$ kubectl patch deployment coredns \
    -n kube-system \
    --type json \
    -p='[{"op": "remove", "path": "/spec/template/metadata/annotations/eks.amazonaws.com~1compute-type"}]'
deployment.apps/coredns patched
$ kubectl get pods -n kube-system                          
NAME                       READY   STATUS    RESTARTS   AGE
coredns-6f99dbb876-hp667   1/1     Running   0          4m
coredns-6f99dbb876-skrgn   1/1     Running   0          4m
```

컨테이너에 IAM 권한을 부여하려면 [OIDC 공급자 생성](https://docs.aws.amazon.com/ko_kr/eks/latest/userguide/enable-iam-roles-for-service-accounts.html)이 필요합니다

```bash
$ eksctl utils associate-iam-oidc-provider --cluster simon-test --approve
```

## 서비스 구동

이제 우리가 만든 어플리케이션을 EKS 클러스터에 올릴 차례입니다.

이전과 마찬가지로 ECR 저장소를 만들고 이미지를 올려둡니다.

```hcl
locals {
  app_name = "simon-sample"
}

## simon-sample 앱을 위한 저장소를 만듭니다
resource "aws_ecr_repository" "simon_sample" {
  name = local.app_name
}
```

이 이미지를 띄우는 것은 쿠버네티스가 처리합니다.

쿠버네티스에 띄우는 가장 작은 단위는 [파드](https://kubernetes.io/ko/docs/concepts/workloads/pods/)입니다. 다만 파드로 띄우면 서버를 확장하는 것이 어렵습니다. [레플리카셋](https://kubernetes.io/ko/docs/concepts/workloads/controllers/replicaset/)이라는 리소스를 사용하면 파드를 여러개 띄울 수 있습니다. 여기에 더해 [디플로이먼트](https://kubernetes.io/ko/docs/concepts/workloads/controllers/deployment/)를 리소스를 사용하면 어플리케이션 갱신시 레플리카셋 교체를 해줍니다.

다음과 같이 쿠버네티스 리소스를 정의합니다.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: simon-sample
spec:
  replicas: 1
  selector:
    matchLabels:
      app: simon-sample
  template:
    metadata:
      labels:
        app: simon-sample
    spec:
      containers:
        - name: app
          image: <aws-account-id>.dkr.ecr.ap-northeast-2.amazonaws.com/simon-sample:latest
          ports:
            - containerPort: 3000
```

다음 명령으로 적용합니다.

```bash
$ kubectl apply -f simon-sample.yaml
deployment.apps/simon-sample created
```

보통 5분 안에(빠르면 1분 안에) 다음과 같이 Running 상태로 바뀝니다.

```bash
$ kubectl get pods -o wide                 
NAME                           READY   STATUS    RESTARTS   AGE     IP              NODE                    NOMINATED NODE   READINESS GATES
simon-sample-dd88b97bc-svtd6   1/1     Running   0          3m45s   10.194.101.15   fargate-10.194.101.15   <none>           <none>
```

포트 포워딩으로 세팅하고, HTTP 요청을 하면 응답이 오는 것을 볼 수 있습니다.

```bash
$ kubectl port-forward simon-sample-dd88b97bc-svtd6 3000:3000
Forwarding from 127.0.0.1:3000 -> 3000
Handling connection for 3000

## from other terminal
$ curl localhost:3000 --data 'hello world'
hello world
```

## 서비스를 외부에 노출하기

ECS와 마찬가지로 실제 서비스가 되려면 외부에 노출된 로드 밸런서에 우리의 서비스를 붙여줘야 합니다. ECS와 달리 쿠버네티스에서는 로드 밸런서 정의도 쿠버네티스 리소스로 정의합니다. 하지만 실제로는 EKS가 알아서 AWS 로드 밸런서를 생성하게 됩니다.

어플리케이션 계층(L7)에서 동작하는 Application Load Balancer(ALB)를 생성하기 위한 리소스 타입은 [Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/) 입니다.

우선 [AWS Load Balancer Controller 추가 기능 설치](https://docs.aws.amazon.com/ko_kr/eks/latest/userguide/aws-load-balancer-controller.html)가 필요합니다.

```bash
## ALB를 컨트롤 할 수 있는 정책을 생성합니다.
$ curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.4.0/docs/install/iam_policy.json
$ aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy-simon-test \
    --policy-document file://iam_policy.json

## 위 정책을 포함한 IAM 역할을 생성합니다.
$ ACCOUNT_ID=$(aws sts get-caller-identity | jq -r .Account)
$ OIDC_URL=$(aws eks describe-cluster --name simon-test --query "cluster.identity.oidc.issuer" --output text | sed "s|https://||")
$ cat > load-balancer-role-trust-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Federated": "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/$OIDC_URL"
            },
            "Action": "sts:AssumeRoleWithWebIdentity",
            "Condition": {
                "StringEquals": {
                    "${OIDC_URL}:aud": "sts.amazonaws.com",
                    "${OIDC_URL}:sub": "system:serviceaccount:kube-system:aws-load-balancer-controller"
                }
            }
        }
    ]
}
EOF
$ aws iam create-role \
    --role-name AmazonEKSLoadBalancerControllerRole-simon-test \
    --assume-role-policy-document file://"load-balancer-role-trust-policy.json"
$ aws iam attach-role-policy \
    --policy-arn arn:aws:iam::${ACCOUNT_ID}:policy/AWSLoadBalancerControllerIAMPolicy-simon-test \
    --role-name AmazonEKSLoadBalancerControllerRole-simon-test

## IAM 역할에 연결된 쿠베네티스 서비스 계정을 생성합니다.
$ cat > aws-load-balancer-controller-service-account.yaml << EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    app.kubernetes.io/component: controller
    app.kubernetes.io/name: aws-load-balancer-controller
  name: aws-load-balancer-controller
  namespace: kube-system
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::${ACCOUNT_ID}:role/AmazonEKSLoadBalancerControllerRole-simon-test
EOF
$ kubectl apply -f aws-load-balancer-controller-service-account.yaml

## AWS Load Balancer Controller를 설치합니다
$ VPC_ID=$(aws ec2 describe-vpcs --filters Name=cidr,Values=10.194.0.0/16 | jq -r .Vpcs[0].VpcId)
$ helm repo add eks https://aws.github.io/eks-charts
$ helm repo update
$ helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
    -n kube-system \
    --set clusterName=simon-test \
    --set serviceAccount.create=false \
    --set serviceAccount.name=aws-load-balancer-controller \
    --set region=ap-northeast-2 \
    --set vpcId=$VPC_ID \
    --set image.repository=602401143452.dkr.ecr.ap-northeast-2.amazonaws.com/amazon/aws-load-balancer-controller
NAME: aws-load-balancer-controller
LAST DEPLOYED: Sat Mar 26 10:02:19 2022
NAMESPACE: kube-system
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
AWS Load Balancer controller installed!
$ kubectl get deployment -n kube-system aws-load-balancer-controller
NAME                           READY   UP-TO-DATE   AVAILABLE   AGE
aws-load-balancer-controller   2/2     2            2           5m51s
```

이제 쿠버네티스를 통해 ALB를 생성하고, 아까 만든 앱을 등록합니다.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: simon-sample-service
spec:
  ports:
    - port: 3000
      targetPort: 3000
      protocol: TCP
  type: NodePort
  selector:
    app: simon-sample
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: simon-test-alb
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
spec:
  ingressClassName: alb
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: simon-sample-service
                port:
                  number: 3000
```

이제 로드 밸런서 주소로 요청을 보내면 응답을 보내옵니다.

```bash
## k8s-default-simontes-ea5ab2759b-771587743.ap-northeast-2.elb.amazonaws.com 같은 주소를 가집니다
$ LB_HOST=$(kubectl get ingress/simon-test-alb -ojson | jq -r .status.loadBalancer.ingress[0].hostname)
$ curl $LB_HOST --data 'hello world'
hello world
```

## 후기

확실히 EKS는 ECS에 비해 훨씬 복잡합니다. 그만큼 세세한 컨트롤이 가능하고, AWS에 특화된 개념이 아니라는 것은 장점이라고 봅니다.

이번 글에서는 수동으로 처리해주는 부분이 꽤 있는데 다음에는 더 자동화(Terraform) 해보도록 하겠습니다.

## Appendix

- 예제 파일: [simon-sample.zip](/file/2022-03-31-2-simon-sample.zip)
- [Amazon EKS의 애플리케이션 로드 밸런싱](https://docs.aws.amazon.com/ko_kr/eks/latest/userguide/alb-ingress.html)
- [Amazon EKS 클러스터 생성](https://docs.aws.amazon.com/ko_kr/eks/latest/userguide/create-cluster.html)
- [Amazon EKS를 사용하여 AWS Fargate 시작하기](https://docs.aws.amazon.com/ko_kr/eks/latest/userguide/fargate-getting-started.html)
    - [CoreDNS 업데이트](https://docs.aws.amazon.com/ko_kr/eks/latest/userguide/fargate-getting-started.html#fargate-gs-coredns)
- [Amazon EKS용 kubeconfig 생성](https://docs.aws.amazon.com/ko_kr/eks/latest/userguide/create-kubeconfig.html)
- [클러스터에 대한 IAM OIDC 공급자 생성](https://docs.aws.amazon.com/ko_kr/eks/latest/userguide/enable-iam-roles-for-service-accounts.html)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
    - [Ingress annotations](https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.4/guide/ingress/annotations/)
- [쿠버네티스](https://kubernetes.io/ko/docs/home/)
    - [파드](https://kubernetes.io/ko/docs/concepts/workloads/pods/)
    - [레플리카셋](https://kubernetes.io/ko/docs/concepts/workloads/controllers/replicaset/)
    - [디플로이먼트](https://kubernetes.io/ko/docs/concepts/workloads/controllers/deployment/)
    - [Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)
