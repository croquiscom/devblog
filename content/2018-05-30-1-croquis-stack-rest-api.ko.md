---
title: 크로키의 스택 - REST API
tags: ['Croquis','Stack','REST API']
date: 2018-05-30
author: Sangmin Yoon
original: http://sixmen.com/ko/tech/2018-05-30-1-croquis-stack-rest-api/
---

크로키가 클라이언트-서버 아키텍처를 가진 첫 번째 서비스 개발을 시작한 것은 2012년이었습니다.
클라이언트에서 서버와 통신할 방법이 필요했는데 당시의 대세는 REST API였습니다.
저도 거기에 공감했기 때문에 REST API를 만들어 클라이언트를 구현했습니다.
그 후로 모든 서비스는 기본적으로 REST API로 클라이언트와 서버가 통신하고 있습니다.

<!--more-->

다만 여기서 말하는 REST API는 REST API라는 것에 대한 일반적인 인식 - 리소스 URI 명명법 및 HTTP 상태 코드 - 을
따른 API를 말하는 것으로, [Roy Fielding](https://en.wikipedia.org/wiki/Roy_Fielding)이
얘기하는 [REST 아키텍처](https://www.ics.uci.edu/~fielding/pubs/dissertation/rest_arch_style.htm)와는 거리가 있습니다.
Stateless 조건을 만족하는 대신 쿠키를 사용하고 있고,
[HATEOAS](https://en.wikipedia.org/wiki/HATEOAS)는 지금도 어떻게 사용하면 좋을지 감을 잡지 못하고 있습니다.
Accept 헤더도 인식하지 않고 무조건 JSON을 가정하고 있습니다.

지금도 REST 스타일로 리소스 URI를 명명하는 것은 옳다고 생각하고, 웹 서비스의 각 페이지 주소는 최대한 REST 스타일로 이름 짓고 있습니다.
다만 API를 REST API로 하는 것이 맞는지는 계속 의문을 품고 있습니다.
다음은 수년간 서비스를 개발하면서 REST API 스타일이 적합하지 않는다고 생각한 예를 적어보겠습니다.

### HTTP 동사로 처리하기 어려운 API
가장 처음에 맞닥뜨린 고민은 로그인, 로그아웃 API였습니다.
HTTP 동사에 딱 맞지 않는 경우 적당한 리소스 뒤에 동사를 붙이는 것으로 처리하는 경우를 많이 봤습니다.
예를 들어 로그인은 `/users/me/login`과 같이 처리하는 것이죠.
그런데 저는 동사를 피해야 한다고 하면서 마지막에 동사가 있는 것이 맘에 들지 않았습니다.

로그인/로그아웃의 경우 세션이라는 리소스를 다루는 것으로 간주하는 [API 디자인](https://stackoverflow.com/a/7252311)도 봤습니다.
`로그인 = POST /sessions`, `로그아웃 = DELETE /sessions`와 같이 대응시키는 것입니다.
하지만 너무 어색하게 느껴졌고, 이런 식으로 처리하기 어려운 예도 많았습니다.

그래서 이런 경우는 REST API가 아닌 API를 만들고 문서도 다르게 기술했습니다.

* REST API: `GET /users`, `POST /events`
* non-REST API: `/login (POST)`

다음은 non-REST API로 만들었던 API들의 예입니다.

* 로그인: `/login`
* 사용자 A가 B에게 팀에 가입 요청(join\_request)을 한 후 B가 해당 요청을 승인/거절: `/acceptJoinRequest`, `/ignoreJoinRequest`
* 특정 경기에 참여: `/joinMatch`
* 서비스 계정과 페이스북 계정의 연결/연결 끊기: `/linkWithFacebook`, `/unlinkWithFacebook`

### 여러 리소스를 한 번에 가져오기
몇 개의 리소스에서 데이터를 한 번에 가져오고 싶은 경우에 API를 정의하기 어려웠습니다.

예를 들어 지그재그에서 사용자가 담아둔 상품의 가격을 갱신하기 위해서 서버에 데이터를 요청하는데 REST API로는 기술하기가 어려웠습니다.
굳이 하자면 `GET /products/1,6,29,35/price` 같은 형태를 생각해볼 수 있지만, 상품이 많은 경우 URL 길이의 제한에 걸릴 수 있습니다.

결국, 이런 경우 RPC 스타일로 API를 정의했습니다. `/getProductPrices`

### 요청자마다 원하는 데이터가 다른 경우
같은 리소스지만 모든 데이터가 필요하지 않은 경우 네트워크 사용량을 줄이기 위해 특정 필드만 반환하도록 fields 인자를 지정하는 REST API를 종종 보셨을 것입니다.

저의 경우 네트워크 사용량은 무시해서 fields 인자를 사용하지는 않았지만, 일부 필드는 추가적인 DB 접근이 필요한 경우가 있어서 필요한 경우만 요청하도록 하는 규칙을 정했었습니다.
예를 들어 이벤트 정보를 받을 때 이벤트가 열리는 장소와 참석자는 별도 테이블(Place, EventAttendance)에 있다 보니 다음과 같이 요청했습니다.

`GET /events/123?add=attendances,place`

### 같은 리소스지만 인자에 따라 처리 코드가 다른 경우

비슷한 상품 목록이지만 검색어 검색과 카테고리 검색의 코드가 다릅니다.
그런데 라우트는 `GET /products` 하나로 구성해야 합니다.
이런 경우가 있을 때마다 제대로 URL을 정한 것인지 고민이 됩니다.

특히 인자에 따라 결괏값이 달라야 하는 경우 같은 리소스가 맞나 싶을 때가 있습니다.

### 결정하기 어려운 이름

보통 리소스 목록은 `/resources`, 개별 리소스는 `/resources/:id`로 구성을 하지만,
가끔 리소스 목록에 후자를 쓰고 싶을 때가 있습니다.
상태(`/resources/valid`)나 검색(`/resources/my-query`) 같은 경우인데요,
페이지 URL이 REST 형태로 잘 구성되어 있다고 생각하는 GitHub에서도
https://github.com/nodejs/node/pulls/10000 같은 주소를 보면 쉽지 않다고 느낍니다.

# 결론

현재 크로키닷컴의 API는 REST API가 기본이지만 위에 적힌 이유로 마이크로서비스 간의 통신에는 Thrift를 사용해서 RPC 스타일의 API를 사용해 보고 있습니다.
또한, 최근에는 클라이언트-서버 간의 API도 통일하기 위해서 GrpahQL을 시도해보고 있습니다.
이에 대해서는 추후 다른 포스팅으로 설명하겠습니다.
