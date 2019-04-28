 ---
title: 크로키의 스택 - Thrift
tags: ['Croquis','Stack','Thrift','마이크로서비스','Microservice']
date: 2019-04-28
author: Sangmin Yoon
original: http://sixmen.com/ko/tech/2019-04-28-1-croquis-stack-thrift/
---

2016년 중반 마이크로서비스로의 전환을 결정했습니다.
마이크로서비스는 이론상 다른 서비스에 영향을 주지 않고 내부 기술을 바꿀 수 있습니다.
하지만 마이크로서비스 간의 통신 방법은 한번 결정하면 쉽게 바뀌기 어려울 것 같아서 가장 많이 고민했습니다.
그리고 Thrift를 선택했습니다.
이번 글에서는 그 이유와 이후의 상황에 관해 설명하겠습니다.

<!--more-->

마이크로서비스에 대한 글들을 찾아보면 대부분은 통신 방법도 REST API를 많이 얘기하고 있습니다.
(예. [Introduction to Microservices | NGINX](https://www.nginx.com/blog/introduction-to-microservices/))
그러나 <a href='{{< relref "/2018-05-30-1-croquis-stack-rest-api.ko.md" >}}'>이전 글</a>에서
썼듯이 REST API에 불편함을 느끼고 있었습니다. 특히 마이크로서비스 간에는 REST로 표현하기 어려운 더 다양한 API가 필요해질 것 같았습니다.
그래서 대안을 찾아봤습니다.

그 당시 고려했던 대안은 [Thrift](https://thrift.apache.org/), [Avro](https://avro.apache.org/), [Protocol Buffers](https://developers.google.com/protocol-buffers/)였던 것으로 기억합니다.
지금 시점에 괜찮아 보이는 [gRPC](https://grpc.io/)는 이상하게 당시 고려대상에서 벗어나 있었던 것 같습니다.
아마 RPC 보다는 데이터 직렬화 쪽을 더 중점적으로 생각했던 것 같습니다.
데이터- 특히 배열 -를 JSON으로 만들면 크기가 매우 크기 때문에 데이터 크기가 줄어드는 게 매력적으로 다가왔습니다.

그중에서 Thrift를 선택한 건 다음과 같은 이유가 있었던 것 같습니다.

1. Avro 방식보다는 Thrift / Protocol Buffers 방식이 더 작은 사이즈를 만들 것 같았습니다.
2. Protocol Buffers는 JavaScript를 잘 지원하는 듯이 보이지 않았습니다. (공식 문서의 튜토리얼에 없음)
3. VCNC에서 Thrift를 쓰고 있다는 글을 봐서 어느 정도 검증이 됐으리라 봤습니다.

그렇게 Thrift를 마이크로서비스 간의 통신에 적용하는 작업을 시작했는데 생각만큼 잘 동작하지는 않았습니다.

1. JavaScript를 지원하지만, 막상 해보니 클리어언트 JavaScript 용이었고, Node.js에 어울리는 코드를 만들어주지 않았습니다. TypeScript 지원을 포함해 몇 가지 수정을 가해서 사용하고 있습니다. (https://github.com/croquiscom/thrift/tree/croquis-171130)
2. TCP 소켓 통신을 통해 요청마다 연결을 만들어야 하는 낭비를 없애기를 기대했는데, 오토 스케일링과 어울리지 않아서 결국 HTTP 통신을 했습니다.

몇 가지 문제가 있긴 하지만, 오랜 시간에 걸쳐 안정화되어 현재 수백개의 Thrift API가 존재하고 있습니다.

크로키닷컴만의 특이한 규칙이 하나 있다면 Read API에서 모든 필드 요청을 피하기 위해서 받기를 원하는 필드를 지정할 수 있도록 구성되어 있다는 것입니다.
Update API도 하나로 여러 요구 사항에 대응하기 위해 업데이트를 할 필드를 같이 주도록 했습니다.

{{< highlight thrift >}}
/// 지그재그 공지사항
struct ZigzagNotice {
  /// 레코드 ID
  1: optional i32 id
  /// 공지사항 내용
  2: optional string contents
  /// 공지 날짜
  3: optional i32 date
  /// 배포 대상 OS 타입 (0:common,1:none,2:iOS,3:Android)
  4: optional i32 os
  /// 공지사항에 필요한 링크 URL
  5: optional string link
}

service ZigzagNoticeService {
  /**
   * 해당 레코드 ID의 공지사항을 반환한다.
   *
   * fields는 ZigzagNotice의 구조체 필드 ID로 빈 경우 레코드 ID만 반환한다.
   */
  ZigzagNotice getZigzagNotice(1: i32 notice_id, 2: list<i32> fields)

  /**
   * 해당 레코드 ID의 공지사항을 업데이트 한다.
   *
   * fields는 ZigzagNotice의 구조체 필드 ID로 정의된 필드의 값만 업데이트 된다.
   */
  void updateZigzagNotice(1: i32 notice_id, 2: ZigzagNotice notice, 3: list<i32> fields)
}
{{< /highlight >}}

이렇게 1년 이상 Thrift를 사용해왔지만 여러 가지 불편함이 발생했습니다.

1. 라이브러리가 활발하게 개발되지 않고 있습니다. 특히 JavaScript/Node.js 쪽은 큰 변화가 없습니다.
2. TypeScript와 잘 어울리지 않았습니다.
3. API 추가/변경 시마다 코드를 생성해야 하는 것이 생각보다 불편했습니다.

그래서 2017년 말에 GraphQL을 살펴보기 시작해서 현재는 새로 작성하는 모든 API를 GraphQL로 만들고 있습니다.
다음번에는 크로키닷컴에서 GraphQL을 적용하는 과정에 관해서 설명하겠습니다.
