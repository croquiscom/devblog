---
title: 젠킨스 작업을 정의하는 방식들
tags: ['Jenkins']
date: 2018-02-27
author: Sangmin Yoon
original: http://sixmen.com/ko/tech/2018-02-27-1-jenkins-job-styles/
---

오늘날의 소프트웨어 개발에 있어서 지속적 통합(continuous integration)은
필수라고 할 수 있습니다.
저도 당연히 동의하면서 오래전부터 도입하려고 했지만, 급한 일에 밀려 실제로 도입한 것은
지그재그 서비스를 오픈하고 나서도 2년이나 지난 작년 여름무렵입니다.

여러가지 고민한 끝에 CI에 [젠킨스](https://jenkins.io/)를 사용하기로 결정했습니다.
그런데 서비스에 적용하기 위해서 각종 문서를 찾아보는데
문서별로 작업을 정의하는 방식이 너무 달라서 굉장히 혼란스러웠습니다.

이번 글에서는 저와 같이 혼란을 겪으시는 분들을 위해 젠킨스의 작업 정의 방식들에 대해서 설명하려고 합니다.

<!--more-->

# UI를 통해 정의하기

젠킨스는 수많은 플러그인을 가지고 있습니다.
내가 젠킨스를 통해 하고 싶은 일을 수행해주는 플러그인을 찾았을 때 대부분은 UI에서 어떻게 설정하는지를 설명하고 있습니다.
또한 오래된 젠킨스 튜토리얼 문서들도 모두 이 방식으로 설명하고 있습니다.

예를 들어 다음은 코드 커버리지 리포트를 모아주는 [Cobertura Plugin의 위키 페이지](https://wiki.jenkins.io/display/JENKINS/Cobertura+Plugin)에 있는 설정 방법입니다.

1. Install the cobertura plugin (via Manage Jenkins -> Manage Plugins)
2. Configure your project's build script to generate cobertura XML reports (See below for examples with Ant and Maven2)
3. Enable the "Publish Cobertura Coverage Report" publisher
4. Specify the directory where the coverage.xml report is generated.
5. (Optional) Configure the coverage metric targets to reflect your goals.

다음은 위 설명에 따라 Freestyle project를 생성한 후 Cobertura Plugin을 설정하는 화면입니다.

![Cobertura Plugin 설정](/img/content/2018-02-27-1/2018-02-27-1-01.png)

# 코드를 통해 정의하기

그런데 막상 [젠킨스 공식 문서](https://jenkins.io/doc/)에서는 위와 같은 UI 화면을 전혀 찾아볼 수 없고, Jenkinsfile 라는 파일에 작업을 정의한다고 되어 있습니다.

작업을 코드로 정의해서 소스와 같이 관리하는 것이 바로 제가 원하는 것이였기 때문에,
이 방식을 적용하려고 했으나 아무리 찾아봐도 Freestyle project에서 Jenkinsfile을 연결하는 방법을 찾지 못했습니다.
한참을 삽질을 한 끝에 별도의 [파이프라인 플러그인](https://wiki.jenkins.io/display/JENKINS/Pipeline+Plugin)인을 설치해야 한다는 것을 알았습니다.

이는 2016년 4월에 릴리스된 [Jenkins 2.0과 함께 공식적으로 소개](https://jenkins.io/blog/2016/04/26/jenkins-20-is-here/)된 기능입니다.
오래된 튜토리얼이나 위키 문서에 해당 내용이 없는게 당연하겠죠.

다음은 Pipeline project를 생성한 후 작업 파이프라인을 정의하는 예입니다.

![Pipeline 작업 정의](/img/content/2018-02-27-1/2018-02-27-1-02.png)

# Declarative Pipeline? Scripted Pipeline?

그런데 [파이프라인 문법 문서](https://jenkins.io/doc/book/pipeline/syntax/)를 보면
두가지 스타일에 대한 얘기가 있습니다.
처음에는 Scripted 방식이였고 후에 [Declarative 방식이 추가](https://jenkins.io/blog/2017/02/03/declarative-pipeline-ga/)된 것으로 보입니다.

제가 원하는 기능을 파이프라인으로 정의하려고 하는데 생각한대로 동작하지 않아서 굉장히 혼란스러웠습니다.
문서는 Declarative 방식 위주로 되어 있는데, 그게 제가 원하는 동작을 정의하기에 맞지 않았던 것이 문제였습니다.

여러가지 시도 끝에 지금은 Scripted 방식으로 파이프라인을 정의해서 사용하고 있습니다.

# Blue Ocean

제가 원하는 것은 GitHub 저장소와 연동되어 젠킨스 빌드가 이루어지는 것이였는데
이때 젠킨스의 새로운 UI 프로젝트인 [Blue Ocean](https://jenkins.io/doc/book/blueocean/)를 알게됐고 이를 통해 쉽게 GitHub 저장소와 연동되는 프로젝트를 만들 수 있었습니다.

그런데 이 Blue Ocean에는 파이프라인을 정의할 수 있는 UI가 포함되어 있습니다.

다음은 Blue Ocean에서 파이프라인을 정의하는 예입니다.

![Blue Ocean에서 파이프라인 정의](/img/content/2018-02-27-1/2018-02-27-1-03.png)

UI에서 정의한 내용은 다음과 같이 Declarative 방식의 Jenkinsfile로 만들어집니다.

{{< highlight groovy >}}
pipeline {
  agent any
  stages {
    stage('Build') {
      parallel {
        stage('Build 1') {
          steps {
            sh 'echo Build 1'
          }
        }
        stage('Build 2') {
          steps {
            sh 'echo Build 2'
          }
        }
      }
    }
    stage('Deploy') {
      steps {
        sh 'echo Deploy'
      }
    }
  }
}
{{< /highlight >}}

# 결론

젠킨스가 오래된 프로젝트이고 기존 방식을 버리지 못하는 상황에서 새로운 방식을 추가하다보니 혼란스러운 점이 있었습니다.

새로운 프로젝트는 무조건 Jenkinsfile로 만들어서 소스에 추가한다고 생각하시는 것이 좋습니다.
초기 방식은 설정 파일이 소스와 별도로 존재해서 관리하기가 어렵습니다.

파이프라인 문법 중에서도 대부분의 경우 Declarative 방식을 사용하시는 것을 추천합니다.
초보를 위해 편집 UI도 제공하기 때문에 정의하기가 편리합니다.

이 글이 젠킨스 CI 구축에 도움이 되었으면 합니다.
