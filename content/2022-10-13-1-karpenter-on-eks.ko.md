---
title: EKS클러스터 Karpenter 적용기
tags: ['AWS', 'Kubernetes']
date: 2022-10-13T00:00:00
author: Nessa(조이정)
---

안녕하세요! 카카오스타일 SRE팀 네사입니다. 오늘은 카카오스타일 SRE팀에서 올해 EKS 클러스터 이전을 하며 새롭게 도입 했던 **AWS Karpenter** 에 대해 공유를 해보려 합니다.

<!--more-->

## 카카오스타일의 고민

EKS 클러스터를 운영하는 엔지니어라면 누구나 확장성에 대한 고민을 한 번쯤 하게 됩니다. agility 가 생명인 마이크로 서비스 환경에서 Pod 나 Node 의 확장이 빠르게 되지 않는다면 서비스 속도뿐만 아니라 비용이나 관리 효율에도 영향을 미치게 됩니다. 확장성에 관한 우리의 요구사항은 늘 간단명료합니다. 빠르게 확장하고, 편하게 관리하며, 거기에 유연성까지 갖췄다면 금상첨화겠죠! 

카카오스타일 역시 대부분의 주요 마이크로서비스가 EKS 상에서 운영되고 있고, 유저들이 많이 사용하는 시간대 패턴이 있다 보니 하루에도 몇 번씩 Node 가 늘어났다 줄어드는 경험을 하게 됩니다. 카카오스타일도 처음에는 Kubernetes 의 기본 **Cluster Autoscaler(CA)** 를 사용했습니다. **Cloud Service Provider(CSP)** 에 따라 다르겠지만 AWS 의 경우는 **AutoScaling Group(ASG)** 을 통해 **CA** 기능을 구현하기 때문에 클러스터의 확장 시나리오는 다음과 같아집니다.

<Cluster Autoscaler 동작 원리>

![cluster_autoscaler](/img/content/2022-10-13-1/cluster_autoscaler.png)

1. **Horizontal Pod AutoScaler(HPA)** 에 의한 pod의 수평적 확장이 한계에 다다르면, pod는 적절한 Node 를 배정받지 못하고 pending 상태에 빠집니다.
2. 이때 **CA** 는 Pod 의 상태를 관찰하다가 지속해서 할당에 실패하면 **Node Group** 의 **ASG** Desired Capacity 값을 수정하여 Worker Node 개수를 증가하도록 설정합니다.
3. 이를 인지한 **ASG** 가 새로운 Node를 추가합니다.
4. 여유 공간이 생기면 **kube-scheduler** 가 Pod를 새 Node에 할당합니다.

하지만 **CA** 방식은 AWS 리소스인 **ASG** 에 의존도가 높기 때문에 Node 추가에 생각보다 오랜 시간이 걸립니다. 카카오스타일에서도 기존 Node 의 EBS 타입을 gp2 에서 gp3 로 업데이트 하기 위해 약 10여 대의 Node 를 재배포한 적이 있는데, 한 대씩 rolling 이 되는 데다 엔지니어가 작업에 개입하기 어려워 약 1시간 정도 지켜만 볼 수밖에 없었던 경험이 있습니다. 여기에 만약 Node 에 custom userdata 를 추가해야 한다면 **Launch template** 을 따로 관리해야하고, 워크로드별 인스턴스 요구사항이 달라 여러 **관리형 Node Group** 을 도입해야 한다면 여러 벌의 **ASG** 을 운영해야 하는 등 운영 부담이 늘어납니다.

별다른 대안이 없어 아쉬운 대로 운영해야만 했는데, 마침 2021년 11월 [AWS 새소식 블로그](https://aws.amazon.com/ko/blogs/aws/introducing-karpenter-an-open-source-high-performance-kubernetes-cluster-autoscaler/)에 올라온 글을 보고 **AWS Karpenter** 의 존재를 알게 되었습니다.

## Karpenter(카펜터) 란?

![karpenter_logo](/img/content/2022-10-13-1/karpenter_logo.png)

**[Karpenter](https://karpenter.sh/)** 는 AWS 가 개발한 Kubernetes 의 Worker Node 자동 확장 기능을 수행하는 오픈소스 프로젝트입니다. 앞서 말한 **Cluster Autoscaler (CA)** 와 비슷한 역할을 수행하지만, AWS 리소스에 의존성이 없어 **JIT(Just In-Time)** 배포가 가능하다는 점에서 다른 확장 시나리오를 가지고 있습니다.

<Karpenter 동작 원리>

![karpenter_logic](/img/content/2022-10-13-1/karpenter_logic.png)

1. **Horizontal Pod AutoScaler(HPA)** 에 의한 Pod의 수평적 확장이 한계에 다다르면, Pod 는 적절한 Node 를 배정받지 못하고 pending 상태에 빠집니다.
2. 이때 **Karpenter** 는 지속해서 unscheduled Pod 를 관찰하고 있다가, 새로운 Node 추가를 결정하고 직접 배포합니다.
3. 추가된 Node가 Ready 상태가 되면 **Karpenter** 는 **kube-scheduler** 를 대신하여 pod 의 **Node binding** 요청도 수행합니다.

위와 같이 **Karpenter** 는 기존 **CA** 에 비해 훨씬 단순한 구조를 가지고 있으며 클러스터 확장 시 일어나는 많은 부분을 **Karpenter** 에서 직접 처리해서 빠르게 확장을 처리할 수 있도록 설계되었습니다. 모든 Worker Node 는 **Karpenter** 에 의해 lifecycle 이 결정됩니다.

이에 따라 카카오스타일에서 **Karpenter** 를 도입했을 때 얻을 수 있는 장점을 정리해보면 다음과 같았습니다. 

## Karpenter 의 장점

**1) 운영 부담 절감**

**CA** 를 사용하면 Node 의 운영 요구사항을 반영하기 위해 **ASG** 나 **Launch Template** 와 같은 AWS 자원들을 추가로 관리해야 했습니다. 반면에 **Karpenter** 는 설치 후 **Provisioner** 라는 CRD 만 구성해주면, **ASG** 나 **Launch Template** 을 관리할 필요 없이 인스턴스 타입이나 스토리지 크기, IAM 역할 등을 정의하여 사용할 수 있습니다. 또한 **Provisioner** 를 용도별로 구성하면 별도로 관리형 **Node Group** 을 생성하고 운영할 필요가 없어 Node 운영 부담이 절감됩니다. **Provisioner** 에 대해서는 아래에서 조금 더 자세히 설명하겠습니다.

**2) 신속한 Node 추가와 제거**

**Karpenter** 를 사용하면 위에 설명한 설계 구조에 따라 Node 의 추가 속도가 빨라집니다. Pod 를 할당할 수 있는 용량이 모자라면 즉시 추가가 되기 때문에 기존 CA 방식에 비해 훨씬 빠른 속도(약 ~1.5분)를 체감할 수 있습니다. 또 반대로 불필요한 Empty Node 가 있는 경우 정리되는 속도도 빠른데, Node 제거에 대해서는 **Provisioner** 에 정의할 수 있는 `ttlSecondsAfterEmpty` 파라미터값을 정의하여 사용자 정의할 수도 있습니다. (카카오스타일은 30초로 설정하여 쓰고 있습니다.)

**3) 자동 Node 롤링**

EKS 클러스터 운영을 하다 보면 특정 Node 사용이 장기화되어 보안 패치등에 대한 우려가 생길 수 있습니다. 이때  **Karpenter Provisioner** 에 `ttlSecondsUntilExpired` 파라미터를 정의하여 Node 를 주기적으로 rolling update 할 수 있는데요, Node 가 수명이 다하면 Node drain 과 delete 를 차례대로 수행하여 최신 버전의 `amazon-eks-node` 이미지로 신규 Node 를 띄우게 됩니다. 카카오스타일의 경우 Node 베이스 이미지의 보안 패치가 상당히 잦다는 사실을 고려하여 이 값을 `1209600`로 정의하고 14일마다 롤링이 되도록 하고 있습니다. 한꺼번에 생성되었던 Node가 아니라면 ttl 에 맞춰 개별적으로 롤링이 되기 때문에 HA 가 구현된 클러스터 환경에서는 서비스에 영향을 끼치지 않습니다.

**4) 다양한 인스턴스 타입을 쉽게 적용**

앞서 **Karpenter** 를 사용하면 이전에 관리형 **Node Group** 이나 **Launch Template** 으로 정의해야 했던 인스턴스 타입을 **Provisioner** 로 관리하게 된다고 언급했습니다. **Launch template** 에서는 하나의 인스턴스 타입만 선정할 수 있고, **Node Group** 에서 정의하게 되면 다음과 같은 안내가 뜹니다.

![instance_types](/img/content/2022-10-13-1/instance_types.png)

하지만 **Provisioner** 에서는 다음과 같이 다양한 인스턴스 타입을 정의할 수 있습니다. 이렇게 되면 사용 리전 내 인스턴스 가용성을 걱정해야 할 일도 줄어들고, 신규 Node 추가 시 **Karpenter** 가 요청 Pod 에 가장 적절한 인스턴스 타입을 골라 기동하므로 Kubernetes 클러스터 운영 효율을 논할 때 늘 나오는 [bin packing](https://kubernetes.io/ko/docs/concepts/scheduling-eviction/resource-bin-packing/) 문제도 개선할 수 있습니다.

```yaml
  requirements:
    - key: "node.kubernetes.io/instance-type"
      operator: In
      values: ["m6i.2xlarge","m6i.4xlarge","m6i.8xlarge","c6i.2xlarge","c6i.4xlarge","c6i.8xlarge"]
    - key: "topology.kubernetes.io/zone"
      operator: In
      values: [ "ap-northeast-2a", "ap-northeast-2c" ]
    - key: "karpenter.sh/capacity-type"
      operator: In
      values: ["on-demand"]
```

**5) 빠른 버전 업그레이드에 따른 기대**

**Karpenter** 는 2021년 11월 처음 GA되어 2022년 09월까지 60여 번의 버전 릴리즈가 있었을 만큼 빠르게 업데이트되고 있습니다. 그사이 **podAffinity** 나 userdata 를 지원하는 등 다양한 필요 기능들이 추가되어 왔는데요. 예를 들어 카카오스타일에서도 Node에 추가 모듈을 설치하기 위해 처음에는 **Launch Template** 을 따로 정의하여 사용했지만, 얼마 안 가 userdata 를 정의할 수 있도록 **AWSNodeTemplate** CRD 가 나와 최신 AMI 를 유지하면서도 userdata 를 정의할 수 있게 되었습니다.

처음 **Karpenter** 가 나왔을 때, 운영 환경에 적용이 가능한 서비스라고 소개가 되었지만 아직 `v0.x` 으로 베타 버전에 가깝다는 점, 그리고 아직 국내 레퍼런스가 없다는 점 등에 대한 우려가 있었지만 이러한 **Karpenter** 의 특징이 카카오스타일의 클러스터 확장 요구사항에 잘 맞는다는 사실에 착안하여 신중한 PoC 를 거쳐 최종적으로 2022년 운영 환경에 까지 적용을 하게 되었습니다.

## Karpenter 적용 과정

**Karpenter** 는 helm chart 를 통해 설치할 수 있습니다. 카카오스타일은 **Terraform** 을 이용해 인프라를 관리하므로 EKS 클러스터를 생성할 때 **Karpenter** 도 **Terraform** 코드로 정의하여 함께 생성했습니다.

```terraform
resource "helm_release" "karpenter" {
  depends_on       = [module.eks.kubeconfig]
  namespace        = "karpenter"
  create_namespace = true

  name       = "karpenter"
  repository = "https://charts.karpenter.sh"
  chart      = "karpenter"
  version    = "v0.16.0"

  set {
    name  = "replicas"
    value = 2
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.iam_assumable_role_karpenter.iam_role_arn
  }

  set {
    name  = "clusterName"
    value = local.cluster_name
  }

  set {
    name  = "clusterEndpoint"
    value = module.eks.cluster_endpoint
  }

  set {
    name  = "aws.defaultInstanceProfile"
    value = aws_iam_instance_profile.karpenter.name
  }
}
```

**Karpenter** 를 설치하면 Kubernetes 클러스터에서는 다음과 같은 Pod 설정을 확인할 수 있습니다.

![karpenter_pods](/img/content/2022-10-13-1/karpenter_pods.png)

![karpenter_pod_detail](/img/content/2022-10-13-1/karpenter_pod_detail.png)

**Karpenter** Pod 는 **Controller** 와 **Webhook** 컨테이너로 이루어져 있습니다. **Controller** 는 Kubernetes Controller 의 일종으로 pod 상태를 감시하고 Node 를 확장 및 축소하는 주요 역할을 하는데, **Node selector**등이 일치하지 않아 할당할 수 있는 Node 가 없는 경우, 여기에서 에러로그를 확인할 수 있습니다. **Webhook** 은 **Provisioner** CRD 에 대한 유효성 검사 및 기본값을 지정하는 역할을 합니다.

그 다음엔 여러 번 언급했던 **Provisioner** CRD 을 생성합니다. **Provisioner** 는 **Karpenter** 에 의해 생성되는 Node 와 Pod 에 대한 제약조건을 지정하기 위해 **Karpenter** 에서 제공되는 Custom Resource 입니다. 카카오스타일에서는 용도에 따라 여러 **Provisioner** 를 운영하는데, 그중 높은 네트워크 요구사항을 가진 Pod 를 할당하기 위한 `test-network` **Provisioner** 를 예시로 들어보겠습니다.

```yaml
apiVersion: karpenter.sh/v1alpha5
kind: Provisioner
metadata:
  name: test-network
spec:
  taints:
    - key: networkNode
      value: "true"
      effect: NoSchedule
  labels:
    phase: test
    nodeType: network-node
  requirements:
    - key: "node.kubernetes.io/instance-type"
      operator: In
      values: ["c5n.4xlarge"]
    - key: "topology.kubernetes.io/zone"
      operator: In
      values: [ "ap-northeast-2a", "ap-northeast-2c" ]
    - key: "karpenter.sh/capacity-type"
      operator: In
      values: ["on-demand"]
  providerRef:
    name: enable-ipvs-test
  ttlSecondsAfterEmpty: 30
```

그리고 해당 Node의 경우 **kubeproxy** 의 `ipvs` 모드를 테스트 하기 위해 userdata 정의가 필요했으므로 **AWSNodeTemplate** 도 정의했습니다. **Provisioner** 와 **AWSNodeTemplate** 는 `providerRef` 파라미터에 의해 상호 연결됩니다.

```yaml
apiVersion: karpenter.k8s.aws/v1alpha1
kind: AWSNodeTemplate
metadata:
  name: enable-ipvs-test
spec:
  subnetSelector:
    karpenter.sh/discovery/test-cluster: '*'
  securityGroupSelector:
    aws:eks:cluster-name: "test-cluster"
  instanceProfile: KarpenterNodeInstanceProfile-test-cluster
  blockDeviceMappings:
    - deviceName: /dev/xvda
      ebs:
        volumeSize: 20Gi
        volumeType: gp3
        iops: 3000
        deleteOnTermination: true
        throughput: 125
  tags:
    service: network
  userData: |
    MIME-Version: 1.0
    Content-Type: multipart/mixed; boundary="BOUNDARY"

    --BOUNDARY
    Content-Type: text/x-shellscript; charset="us-ascii"

    #!/bin/bash
    sudo yum install -y ipvsadm
    sudo ipvsadm -l
    sudo modprobe ip_vs
    sudo modprobe ip_vs_rr
    sudo modprobe ip_vs_wrr
    sudo modprobe ip_vs_sh
    sudo modprobe nf_conntrack_ipv4

    --BOUNDARY--
```

**Provisioner** 와 **AWSNodeTemplate** 을 적용하고 나면 다음과 같이 확인할 수 있습니다.

```bash
$ kubectl get provisioner
NAME                          AGE
test-network                  10s

$ kubectl get awsnodetemplate
NAME                     AGE
enable-ipvs-test              15s
```

자, 이제 간단하게 **Karpenter** 구성이 끝났으니 확인만 하면 됩니다. 주의할 점은 **deployment** 를 정의할 때 적절한 `tolerations`와 `nodeSelector`(혹은 `nodeAffinity` )를 가지고 있는지만 확인하면 됩니다. 테스트로 nginx 를 띄워보았습니다.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
  namespace: nginx
spec:
  ...(생략)
  template:
    spec:
      containers:
      - name: nginx
        image: nginx
        imagePullPolicy: IfNotPresent
      nodeSelector:
        nodeType: network-node
      tolerations:
      - effect: NoSchedule
        key: node-role.kubernetes.io/master
      - key: CriticalAddonsOnly
        operator: Exists
      - effect: "NoSchedule"
        key: "networkNode"
        operator: "Equal"
        value: "true"
```

이제 Pod 를 기동하면 빠르게 원하는 **Provisioner** 가 추가한 Node 에 할당되는 것을 확인할 수 있습니다! 제가 애용하는 [k9s](https://k9scli.io/) 도구를 통해 살펴보겠습니다.

제일 처음, Pod 는 Node 정보가 n/a 로 뜨면서 `pending` 상태가 되었습니다.

![progress1](/img/content/2022-10-13-1/progress1.png)

그리고 이와 거의 동시에 Node 추가가 시작되었습니다.

![progress2](/img/content/2022-10-13-1/progress2.png)

불과 **55초**만에 `NodeReady` 상태가 되었습니다.

![progress3](/img/content/2022-10-13-1/progress3.png)

이후 Pod 는 바로 Node 에 binding 되어 약 **78초 내**에 정상 구동을 시작했습니다.

![progress4](/img/content/2022-10-13-1/progress4.png)

이때, Karpenter controller pod 의 로그에서는 다음과 같은 로그가 생성되었습니다.

```
INFO    controller.provisioning    Found 1 provisionable pod(s)    {"commit": "639756a"}
INFO    controller.provisioning    Computed 1 new node(s) will fit 1 pod(s)    {"commit": "639756a"}
INFO    controller.provisioning    Launching node with 1 pods requesting {"cpu":"125m","pods":"3"} from types c5n.2xlarge    {"commit": "639756a", "provisioner": "test-network"}
```

또, 만약 해당 deployment 를 삭제하여 Node 가 비면, 다음과 같은 로그가 찍힙니다.

```
INFO controller.node Added TTL to empty node {"commit": "639756a", "node": "ip-xx-x-xxx-xxx.ap-northeast-2.compute.internal"}
```

**Provisioner** 의 `ttlSecondsAfterEmpty`에서 지정한 TTL이 지나면 Node 는 삭제가 됩니다.

## ‼️ 잠깐, 이건 주의합시다

**Karpenter** 를 사용하면 대부분의 주요 서비스들이 사용하는 Node 를  **Provisioner** 로 관리하게 되기 때문에 처음  EKS 클러스터를 생성할 때 기본적으로 생성되는 default Node 에 대해 간과하기가 쉽습니다. 하지만 이 Node 들에는 모든 DNS 요청을 처리하는 **CoreDNS** Pod 가 있으므로 너무 작은 인스턴스 타입을 설정하는 경우 클러스터 동작에 문제가 될 수 있습니다. (이걸 왜 알고 있냐하면 저희도 알고 싶지 않았습니다 ..^^)

그리고 **Provisioner** 설정 시 Security Group 지정에 주의해야합니다. **Provisioner** 에서는 `securityGroupSelector` 파라미터를 이용해 Security Group 을 지정할 수 있고, **Karpenter** 는 이 selector 와 일치하는 Tag 를 가진 모든 Security Group 을 가져와 Node 에 할당합니다. 이 때 동일한 태그를 가진 Security Group(예 : `kubernetes.io/cluster/MyClusterName: owned` )이 2개 이상 있는 경우, **AWS Load Balancer controller** 동작에 문제가 생겨 **Ingress** 가 정상적으로 생성이 되지 않을 수 있습니다. 그 이유는 **AWS Load Balancer controller** 가 해당 Tag 를 가진 Security Group 을 하나만 지원하기 때문인데, 자세한 내용은 [여기](https://github.com/kubernetes-sigs/aws-load-balancer-controller/issues/2367)에서 확인할 수 있습니다. 카카오스타일은 `aws:eks:cluster-name` 태그로 지정하여 이슈를 피했습니다. 만약 이 이슈 때문에 AWS ELB **ingress** 가 생성되지 않는다면 연관성 찾기가 만만치 않습니다…^^ 동일 태그를 지닌 Security Group 이 있는지 확인하기 위해서는 다음과 같은 AWS cli 를 사용할 수 있습니다.

```bash
$ CLUSTER_VPC_ID="$(aws eks describe-cluster --name $CLUSTER_NAME --query cluster.resourcesVpcConfig.vpcId --output text)"

$ aws ec2 describe-security-groups --filters Name=vpc-id,Values=$CLUSTER_VPC_ID Name=tag-key,Values=kubernetes.io/cluster/$CLUSTER_NAME --query SecurityGroups[].[GroupName] --output text
```

참고로 **Karpenter** **Provisioner** yaml 수정 후 다시 apply 했을 때, 이전 **Provisioner** 설정에 의해 생성된 Node 가 자동으로 교체되지 않기 때문에 바로 반영이 필요하다면 별도로 롤링 업데이트를 해주어야합니다.

마지막으로, **Karpenter** 는 비교적 신규 서비스인만큼 초기 버전에서는 잘 동작하지 않는 기능이 많습니다. 예를 들어, 카카오스타일에서는 Node 에 특정 Pod 를 격리하기 위해 `podAffinity` 와 `podAntiAffinity` 를 지정하려고 했는데, 의도한 대로 동작하지 않아 헤매다가 `v0.9.0`에서 새롭게 추가된 기능인 것을 확인하고 버전을 업데이트 했던 경험이 있습니다. 따라서 **Karpenter** 를 사용할 땐 가능한 최신 버전을 사용하는 것을 추천합니다.

## 끝으로,

얼마 전 AWS에서 Enterprise Support 고객들을 상대로 진행했던 HighLander 행사에서 다들 아직 **Karpenter** 에 대한 신뢰가 부족하다는 인상을 받았는데요, 도입을 고민하시는 분들께 이 글이 도움이 되었으면 합니다. 감사합니다!
