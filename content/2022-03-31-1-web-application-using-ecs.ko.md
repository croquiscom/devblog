---
title: ECS를 사용해서 어플리케이션 서비스 하기
tags: ['AWS', 'Tutorial']
date: 2022-03-31T00:00:00
original: http://sixmen.com/ko/tech/2022-03-31-1-web-application-using-ecs/
---

카카오스타일에서는 한동한 ECS를 사용해서 어플리케이션을 서비스했습니다. 현재는 EKS로 전환하고 있지만, ECS가 상대적으로 단순하기 때문에 서비스 구축 개념을 익히는데 좋은 것 같습니다. (간단한 서비스는 굳이 쿠버네티스를 쓸 필요가 없다고 생각합니다) 그런 의미에서 이번 글에서는 ECS를 이용해 단순한 서비스를 오픈하는 과정을 단계별로 설명해보려고 합니다.

<!--more-->

## Docker 도입 과정

[도커](https://www.docker.com/)에 대한 얘기는 2014~2015년 무렵 들려오기 시작했던 것 같습니다. 혁신적인 솔루션이라는 얘기가 오가고 있었지만, 카카오스타일에서는 [AWS Elastic Beanstalk](https://aws.amazon.com/ko/elasticbeanstalk/)를 거쳐, 독자적인 배포 시스템을 갖추고 있었기 때문에 도커의 이득에 대해서 크게 와 닿지 않아 도커로 넘어가는게 상대적으로 늦었던 것 같습니다.

그러던 와중에 처음 필요성을 느꼈던 것은 로컬 개발환경을 갖추는 부분이였던 것 같습니다. 유닛 테스트등을 위해서 로컬에 DB 프로세스 구동이 필요했습니다. 신규 직원에게 [brew](https://brew.sh/)로 설치하는 것을 가이드하고 있었는데, [Docker Compose](https://docs.docker.com/compose/)로 구성해두었더니 도커에 익숙한 사람은 쉽게 개발 환경을 갖출 수 있었습니다.

![2022-03-31-1-01.png](/img/content/2022-03-31-1/2022-03-31-1-01.png)

이후 지토가 하나의 마이크로서비스에 대해서 [ECS](https://aws.amazon.com/ko/ecs/) 셋업을 했는데, 세팅된 것을 보고 나니 유용성이 느껴진 것 같습니다. 그래서 빠르게 이후에 빠르게 ECS 전환을 했습니다.

![2022-03-31-1-02.png](/img/content/2022-03-31-1/2022-03-31-1-02.png)

ECS 전환전보다 배포 시간이 늘어나긴 했습니다. (이전에는 이미 존재하는 EC2 인스턴스에 새로운 소스를 전송한 후 프로세스만 새로 띄우면 됐습니다) 하지만 점점 마이크로서비스로 나눠지고, 트래픽이 늘어나는 상황에 대응하기에는 ECS가 훨씬 수월했습니다.

## Docker로 서비스 만들기

도커로 구동할 Node.js 어플리케이션을 만들어봅시다. HTTP 요청에 보낸 온 데이터를 그대로 반환하는 간단한 서버입니다.

```javascript
// echo.js
const http = require('http');
const server = http.createServer((req, res) => {
  req.pipe(res);
});
server.listen(3000);
```

이 서버를 도커 이미지로 만들기 위해 다음과 같이 Dockerfile을 만들면 됩니다.

```docker
FROM node:16
WORKDIR /opt/app
COPY echo.js .
EXPOSE 3000
CMD ["node", "echo.js"]
```

[docker build](https://docs.docker.com/engine/reference/commandline/build/)로 도커 이미지를 만들 수 있습니다.

```bash
$ docker build . -t simon-sample
```

> Apple Silicon을 사용한 컴퓨터에서는 platform을 지정해 빌드해야 ECS에서 정상동작합니다. `docker build . -t simon-sample --platform=linux/amd64`

[docker run](https://docs.docker.com/engine/reference/commandline/run/)을 이용해 이미지로 부터 프로세스를 실행할 수 있습니다. 외부에서 서버에 접근하기 위해 3000번 포트를 열어야 하고, 데몬 모드로 실행합니다.

```bash
$ docker run -p 3000 -d simon-sample
```

[curl](https://curl.se/)을 사용해 잘 동작하는지 확인 가능합니다.

```bash
$ curl http://localhost:3000 --data 'hello world'    
hello world
```

이렇게 만들어진 이미지는 어떠한 환경에서든 동일하게 동작하고, 배포도 단순해집니다.

## VPC 셋업

ECS 클러스터 생성에 앞서, 클러스터가 놓일 VPC를 만듭니다.

우리가 원하는 서비스 구조를 위해서는 VPC에 최소한 다음과 같은 것들이 필요합니다. ([퍼블릭 및 프라이빗 서브넷이 있는 VPC(NAT) 문서](https://docs.aws.amazon.com/ko_kr/vpc/latest/userguide/VPC_Scenario2.html)에서 설명하는 구조와 같습니다.)

- VPC
- 인터넷에 노출되는 서버가 놓일 퍼플릭 서브넷 (최소 두개 이상의 AZ)
- 안전하게 외부로 부터 접근을 차단된, 실제 서비스가 배치될 프라이빗 서브넷 (최소 두개 이상의 AZ)
- 퍼플릭 서브넷에서 외부 통신을 할 때 사용하는 인터넷 게이트웨이
- 프라이빗 서브넷에서 외부 통신이 필요할 때(아웃바운드 전용) 사용하는 NAT 게이트웨이
- 퍼플릭 서브넷에 연결할 라우팅 테이블. 서브넷에서 다른 서브넷에 접근할 때 규칙과, 외부(0.0.0.0/0)에 접근할 때의 규칙(인터넷 게이트웨이를 거치게 함)을 정의합니다.
- 프라이빗 서브넷에 연결할 라우팅 테이블. 퍼플릭 라우팅 테이블과 비슷한 규칙이지만, 외부에 접근시 NAT 게이트웨이를 거칩니다.

![Sample VPC](/img/content/2022-03-31-1/2022-03-31-1-03.png)

카카오스타일은 인프라 정의시 [Terraform](https://www.terraform.io/)을 사용합니다. 여기서는 세부 사항을 이해하기 위해 개별 리소스를 정의하고 있지만, [terraform-aws-modules/vpc/aws](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest) 같은 모듈을 써서 편하게 정의하는 것도 가능합니다.

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
  tags                    = { Name = "${local.vpc_name}-public-${count.index + 1}" }
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
  tags              = { Name = "${local.vpc_name}-private-${count.index + 1}" }
}

## 프라이빗 서브넷을 라우팅 테이블에 연결합니다
resource "aws_route_table_association" "private" {
  count = length(local.private_subnets)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
```

## ECS 클러스터

우리 서비스가 동작할 ECS 클러스터가 필요합니다. 도커 컨테이너가 구동될 EC2 인스턴스를 직접 관리한다면 복잡하지만 Fargate를 쓴다면 크게 신경쓸게 없습니다.

```hcl
## ECS 클러스터를 생성합니다
resource "aws_ecs_cluster" "this" {
  name = "simon-test"
}
```

## 서비스 구동

이제 우리가 만든 어플리케이션을 ECS 클러스터에 올릴 차례입니다.

우선 도커 이미지를 업로드할 저장소([ECR](https://aws.amazon.com/ko/ecr/))를 정의합니다.

```hcl
locals {
  app_name = "simon-sample"
}

## simon-sample 앱을 위한 저장소를 만듭니다
resource "aws_ecr_repository" "simon_sample" {
  name = local.app_name
}
```

첫단계에서 만든 도커 이미지를 다음과 같이 업로드할 수 있습니다.

```bash
## ECR 저장소에 로그인합니다
$ aws ecr get-login-password --region ap-northeast-2 | docker login --username AWS --password-stdin <aws-account-id>.dkr.ecr.ap-northeast-2.amazonaws.com
## 앞서 만든 이미지에 ECR 이름을 붙여줍니다
$ docker tag simon-sample:latest <aws-account-id>.dkr.ecr.ap-northeast-2.amazonaws.com/simon-sample:latest
## 이미지를 올립니다
$ docker push <aws-account-id>.dkr.ecr.ap-northeast-2.amazonaws.com/simon-sample:latest
```

작업 정의를 다음과 같이 정의합니다.

```hcl
## 태스크 정의시 AmazonECSTaskExecutionRolePolicy 정책을 포함한
## IAM 역할을 실행 역할(execution role)로 설정해줘야 합니다
resource "aws_iam_role" "execution" {
  name = "${local.app_name}-exec-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      },
      Effect = "Allow",
    }]
  })
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

## ECS 위에서 띄울 태스크에 대한 정의입니다
resource "aws_ecs_task_definition" "this" {
  family                   = local.app_name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256 # CPU, 메모리는 가장 작은 값을 사용합니다
  memory                   = 512
  execution_role_arn       = aws_iam_role.execution.arn
  container_definitions = jsonencode([{
    name  = "app"
    image = "${aws_ecr_repository.simon_sample.repository_url}:latest", # ECR에 올라온 이미지를 사용합니다
    cpu   = 0
    portMappings = [{ # 3000번 포트를 외부에 엽니다
      hostPort      = 3000
      protocol      = "tcp"
      containerPort = 3000
    }]
  }])
}
```

이제 컨테이너를 띄울 준비가 끝났습니다. 서비스를 정의하면 설정된 것에 맞춰 작업(태스크)가 뜹니다

```hcl
## ECR에서 데이터를 가져오려면 태스크에 인터넷에 접근할 수 있는 권한을 주어야 합니다
resource "aws_security_group" "this" {
  name   = "${local.app_name}-sg"
  vpc_id = aws_vpc.this.id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

## ECS 서비스를 정의합니다
resource "aws_ecs_service" "this" {
  desired_count   = 1 # 태스크를 하나만 띄웁니다
  name            = local.app_name
  cluster         = aws_ecs_cluster.this.arn
  task_definition = aws_ecs_task_definition.this.arn
  launch_type     = "FARGATE"
  network_configuration {
    subnets         = aws_subnet.private[*].id # 프라이빗 서브넷에 배치합니다
    security_groups = [aws_security_group.this.id]
  }
}
```

## 서비스를 외부에 노출하기

이렇게 만들어진 서비스는 외부에서 접속이 불가능하기 때문에 사실 아무 쓸모가 없습니다. (로그도 없어서 잘 떴는지 확인하기도 어렵습니다.)

ECS 태스크를 직접 외부에 노출할 수도 있겠지만, 보통 여러개의 태스크를 실행하기 때문에 앞에 트래픽을 분산해주는 서버가 필요합니다. 이는 로드 밸런서를 이용해 달성할 수 있습니다. 이 로드 밸런서를 퍼블릭 서브넷에 배치함으로써 외부에서 트래픽도 받을 수 있습니다.

3000번 포트로 트래픽을 전송하는 로드밸런서 타겟 그룹을 만들어 로드 밸런서 80포트(HTTP)로 트래픽이 들어오면 전송하도록 설정합니다.

```hcl
locals {
  lb_name = "simon-test-lb"
}

## 외부에 80번 포트를 여는 보안 그룹을 생성합니다
resource "aws_security_group" "lb" {
  name   = "${local.lb_name}-sg"
  vpc_id = aws_vpc.this.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

## HTTP 요청을 분산하는 어플리케이션 로드 밸런서를 정의합니다
resource "aws_lb" "this" {
  name               = local.lb_name
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb.id]
  subnets            = aws_subnet.public[*].id # 퍼블릭 서브넷에 배치합니다
}

## 로드 밸런서로 온 요청을 받아 처리할 목표 그룹을 정의합니다
resource "aws_lb_target_group" "this" {
  name        = local.app_name
  port        = 3000 # 우리가 만든 컨테이너는 3000번 포트에서 입력을 받습니다
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.this.id
}

## HTTP(80)에 대한 리스너를 생성합니다.
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = "80"
  protocol          = "HTTP"
  # 앞서 정의한 타겟 그룹으로 모든 트래픽을 보냅니다
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}
```

이렇게 생성된 로드 밸런서는 `simon-test-lb-135798642.ap-northeast-2.elb.amazonaws.com`와 같은 주소를 할당받게 됩니다. 아직 이전에 만든 ECS 태스크가 타겟 그룹에 등록되지 않았기 때문에, 이 주소에 접속해보면 503 에러가 발생합니다. 두가지 추가 작업이 필요합니다.

우선 ECS 태스크가 3000번 포트에서의 입력을 처리할 수 있도록 해야 합니다.

```hcl
## ECS는 로드 밸런서에서 3000번 포트로 온 요청을 받을 수 있습니다.
resource "aws_security_group_rule" "ecs_from_lb" {
  security_group_id        = aws_security_group.this.id
  type                     = "ingress"
  from_port                = 3000
  to_port                  = 3000
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.lb.id
}
```

또 로드 밸런서에서 ECS 태스크로 요청도 가능해야 합니다.

```hcl
## 로드 밸런서에서 ECS의 3000번 포트로 요청을 보낼 수 있습니다.
resource "aws_security_group_rule" "lb_to_ecs" {
  security_group_id        = aws_security_group.lb.id
  type                     = "egress"
  from_port                = 3000
  to_port                  = 3000
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.this.id
}
```

다음으로는 ECS 서비스 정의를 변경해 태스크가 만들어지면 타겟 그룹에 등록하게 하게 하면 됩니다.

```hcl
resource "aws_ecs_service" "this" {
  desired_count   = 1
  name            = local.app_name
  cluster         = aws_ecs_cluster.this.arn
  task_definition = aws_ecs_task_definition.this.arn
  launch_type     = "FARGATE"
  network_configuration {
    subnets         = aws_subnet.private[*].id
    security_groups = [aws_security_group.this.id]
  }
  # 다음을 추가합니다.
  load_balancer {
    target_group_arn = aws_lb_target_group.this.arn
    container_name   = "app"
    container_port   = 3000
  }
}
```

이제 로드 밸런서 주소로 요청을 보내면 로컬과 마찬가지로 응답을 보내옵니다.

```bash
$ curl simon-test-lb-135798642.ap-northeast-2.elb.amazonaws.com --data 'hello world'
hello world
```

## 남은 작업

실제 서비스에 더 가까우려면 추가로 해줘야 할 것들이 많이 있습니다. 다만 이번글에서는 따로 설명하지 않겠습니다.

- 로드 밸런서 주소는 랜덤하게 생성됩니다. 이를 실제 서비스에서 쓰기는 어렵고 서비스만의 도메인을 설정해주는게 좋습니다. Route53에 별칭 A 레코드를 생성하면 됩니다.
- 여기서는 HTTP 트래픽을 받고 있지만, 안전한 통신을 위해 HTTPS를 사용하면 좋습니다. AWS Certificate Manager로 인증서를 생성해 로드 밸런서에 설정하면 로드 밸런서에서 TLS 종료를 처리해줍니다. 그 뒷단에 있는 우리의 어플리케이션에서는 HTTP만 처리하면 됩니다.
- 현재 트래픽을 받을 수 있는 서버가 하나 뿐입니다. 서버만 늘리면 로드 밸런서가 알아서 트래픽을 분산해줍니다. desired_count를 조절해 수동으로 서버를 늘릴 수도 있고, 오토 스케일링 정책을 설정해 트래픽에 따라 서버를 늘이고 줄일 수도 있습니다.
- 현재는 컨테이너에서 발생한 로그를 볼 수 없습니다. CloudWatch Logs를 연결해 로그를 기록할 수 있습니다.
- CloudFront를 연결하면 전세계에서 접근할 때 지연 시간을 줄이는 등 추가 이득을 얻을 수 있습니다.

## Appendix

- 예제 파일: [simon-sample.zip](/file/2022-03-31-1-simon-sample.zip)
    > 전체 Terraform 파일에서 한번에 스택을 생성할 때는 먼저 ECR만 생성해(`terraform apply --target aws_ecr_repository.simon_sample`) 이미지를 올린 후 나머지를 생성해주는게 깔끔합니다.
- [퍼블릭 및 프라이빗 서브넷이 있는 VPC(NAT)](https://docs.aws.amazon.com/ko_kr/vpc/latest/userguide/VPC_Scenario2.html)
- [Amazon Elastic Container Service 설명서](https://docs.aws.amazon.com/ko_kr/ecs/index.html)
- [ELB 로드 밸런서로 트래픽 라우팅](https://docs.aws.amazon.com/ko_kr/Route53/latest/DeveloperGuide/routing-to-elb-load-balancer.html)
- [Application Load Balancer용 HTTPS 리스너 생성](https://docs.aws.amazon.com/ko_kr/elasticloadbalancing/latest/application/create-https-listener.html)
