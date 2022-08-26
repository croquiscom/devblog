---
title: AWS Abuse Report
tags: ['AWS']
date: 2018-08-23
author: Sangmin Yoon
---

28일 오전, 한참 작업을 하다가 11시가 조금 넘은 시간에 문득 핸드폰을 들여다봤습니다.
평상시 메일은 몰아서 처리하는 편인데(시급한 일이 메일로 오는 경우는 드물어서) 이날은 왠지 메일에 눈이 갔습니다.
AWS에서 보낸 메일이 보였는데, 자주 오던 광고성 메일은 아니었고 Maintenance 알림 메일인가 하고 넘어가려는 순간
불안한 단어 **Abuse**가 눈에 들어왔습니다.

<!--more-->

메일을 봤을 때 시작 부분에 EC2 Instance Id가 보여서 처음에는 계정이 노출되어 누군가 인스턴스를 생성해서 쓴 것으로 생각했습니다.
급하게 AWS Console에 들어가서 해당 인스턴스를 찾아봤는데 우리가 생성한 인스턴스로 보였습니다.
다시 찬찬히 메일을 읽어보니 특정 인스턴스에서 트래픽이 많이 발생하고 있다는 리포트였습니다.

해당 인스턴스는 데이터 팀이 분석을 위해 띄어놓은 EMR 작업 노드였습니다.
데이터 팀이 EMR 로그를 확인한 결과 알 수 없는 사용자가 YARN 애플리케이션을 실행한 이력이 보였습니다.
일단 급하게 EMR 클러스터를 종료하고 어떤 상황인지 분석을 시작했습니다.

우선 이메일 내용은 다음과 같습니다.

> AWS ID: xxxxx Region: ap-northeast-2 EC2 Instance Id: i-0dd5cb3b390f83f56 [52.79.xxx.xxx]
>
> has been implicated in activity that resembles a Denial of Service attack against remote hosts; please review the information provided below about the activity.
>
> Please investigate your instance(s) and reply detailing the corrective measures you have taken to address this activity. To assist you, we have taken the following actions:
> Region: ap-northeast-2
> Instances:
> Instance Id Remote IP Port Protocol Action Taken
> i-0dd5cb3b390f83f56 68.201.32.219 80 17 Outgoing Port 80 Blocked
>
> Details of the abusive activity:
>
> Instance Id: i-0dd5cb3b390f83f56
> Report begin time: 2018-11-28 02:04:18 UTC
> Report end time: 2018-11-28 02:05:18 UTC
>
> Protocol: UDP
> Remote IP: 68.201.32.219
> Remote port(s): 80
>
> Total bytes sent: 6941183220
> Total packets sent: 12854043
> Total bytes received: 0
> Total packets received: 0

총 3개의 인스턴스에 대해 메일을 받았습니다.

EMR 로그를 확인한 결과 dr.who라고 기록된 익명 사용자가 5:39부터 EMR 클러스터에 접근해서
10:00까지 수천 개의 작업을 실행했습니다.

![EMR 로그](/img/content/2018-11-30-1/2018-11-30-1-01.png)

EMR에 작업 노드가 여러 개 있었지만, 그 중 리포트 받은 3개 인스턴스의 경우
CPU가 100%를 유지하고 있었고, 11:00 이후 순간적으로 트래픽이 발생한 것을 볼 수 있었습니다.

![CPU 사용률](/img/content/2018-11-30-1/2018-11-30-1-02.png)

![네트워크 출력](/img/content/2018-11-30-1/2018-11-30-1-03.png)

여기까지의 과정은 다음과 같습니다.

1. [05:30] 데이터 팀 내부에서 사용하기 위해 EMR 클러스터의 마스터 노드의 포트를 전 세계에 염
2. [05:39] dr.who라는 사용자가 클러스터에 접근 시작
3. [~10:00] 수초에서 10여 분 짜리 hadoop 작업 수천 개를 실행
4. [11:04] 한 개의 인스턴스에서 첫 대량 트래픽 발생
5. [11:06] AWS Abuse 이메일 발송
6. [11:09] 이메일 확인
7. [11:24] EMR 인스턴스 종료
8. [11:53] AWS 팀에 해결 메일 발송

    > We were using AWS EMR, and changed SecurityGroupIngress open to world at 11-27 20:00 (UTC) by mistake.
    > And someone seems to use this cluster for illegal thing.
    > We stopped this AWS EMR immediately(11-28 2:25 (UTC)), and will check conditions for some while.

9. [12:55] 해결됨 메일 받음

    > Hello,
    > This case has been investigated and resolved by the AWS Abuse Team.
    > Thank you for your attention to this matter.
    > Best regards,
    > AWS Abuse Team

일단 해결은 됐지만 dr.who가 무슨 짓을 한 것인지 궁금했습니다.
처음에는 DDoS 공격에 사용된 건가 싶었습니다. 그리고 hadoop 애플리케이션은 10:00에 종료됐는데, 11:00에 트래픽이 발생한 것도 조금 의문이었습니다.
이에 대해 데이터 팀이 분석을 계속한 결과
[Hadoop YARN: An Assessment of the Attack Surface and Its Exploits](https://hk.saowen.com/a/b115602e878aeae35db26c6f82c4be7969477b90d363b0d36fed895dd202c25e)의 내용과 유사한 로그를 발견해
암호화폐 채굴에 이용된 것으로 잠정 결론을 내렸습니다.

22일 오전에는 AWS 서울 리전을 이용하는 서비스들에 문제가 발생했습니다. 지그재그는 구조상 전면적인 서비스 불가는 피했지만, 꽤 영향을 받았습니다.
25일 KT 아현지사 화재에는 해당 건물 IDC에 있던 서버들이 피해를 받았다는 소식을 들었습니다.
이번 사고에서는 다행히 트래픽 비용이 조금 발생하는 것으로 끝났습니다만 가슴이 꽤 철렁했습니다.
사고를 완전히 방지하는 것은 쉬운 일은 아니지만, 최악의 상황에도 데이터는 보존할 수 있도록 더 노력해야겠다는 생각이 들었습니다.
그리고 점점 개발팀이 커지고 작업 범위가 늘어나면서 보안 사고 가능성도 점점 커져 더 큰 노력이 필요하다는 것을 절실히 느꼈습니다.

오랜만의 글이 조금은 부정적인 내용이었습니다.
크로키닷컴의 개발팀에 대해 하고 싶은 얘기는 많은데 시간이 부족하네요.
빠른 시간 안에 다시 재밌는 얘기로 찾아뵙겠습니다.
