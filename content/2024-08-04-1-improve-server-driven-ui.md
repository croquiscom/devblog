---
title: 'Server Driven UI 호출 구조 개선'
tags: ['GraphQL', 'UI']
date: 2024-08-04T01:00:00
author: Dante(황혁주)
---

카카오스타일에서는 [서버 드리븐 UI(Server Driven UI, 이하 SDUI)](https://devblog.kakaostyle.com/ko/2021-12-16-1-server-driven-ui)를 통해 UI의 유연성을 가져가고 있습니다. 서버가 클라이언트 UI를 동적으로 제어하므로써 빌드 및 배포 없이도 UI 업데이트를 할 수 있고, A/B 테스트도 효율적으로 수행할 수 있었습니다. 다만 이렇게 구축된 시스템을 몇년간 운영하다보니 몇가지 문제점이 발생했습니다.

이 글에서는 초기 구조에서 어떤 문제가 발생했는지 살펴보고, 전시팀에서 어떤 방식으로 개선해 나갔는지에 대해 이야기 해보려고 합니다.

<!--more-->

> [이전 포스팅](https://devblog.kakaostyle.com/ko/2021-12-16-1-server-driven-ui)을 먼저 읽으시면 좋습니다. 기존 SDUI는 하나의 쿼리로 한 화면에 그려지는 모든 데이터를 내려받는 구조입니다.
> ![1.png](/img/content/2024-08-04-1/1.png)

## 기존 SDUI의 문제점

1. **컴포넌트 간 의존성**

- 한 화면을 그리는데 필요한 모든 데이터를 하나의 쿼리로 가져오게 되어 있어서, 모든 컴포넌트의 데이터가 준비되어야만 앱에서 데이터를 받을 수 있었습니다.
- 이로 인해 사용자가 데이터를 받는 시간이 가장 느린 데이터에 맞춰지고, **사용자가 느끼기에 앱이 느리다고 인식할 가능성을 높였습니다.**
  ![2.png](/img/content/2024-08-04-1/2.png)

2. **오류 처리**

- 하나의 쿼리로 모든 데이터를 처리하기 때문에, 예외 처리를 적절히 하지 않으면 일부 컴포넌트에서 발생한 예외가 SDUI 쿼리 전체의 실패로 이어지곤 했습니다.
  ![3.png](/img/content/2024-08-04-1/3.png)
- 하나의 쿼리에서 사용하는 컴포넌트가 다양하다보니 오류 발생 시 문제가 생긴 부분을 빠르게 파악하여 수정하는 데 시간이 많이 소요되었습니다.

3. **확장성 문제**

- 앱의 기능이 확장되거나 새로운 컴포넌트가 추가될 때마다 단일 쿼리를 수정해야 하므로, 확장성이 떨어졌었습니다.

4. **테스트의 어려움**

- 모든 데이터를 단일 쿼리로 처리하다 보니, 특정 컴포넌트를 독립적으로 테스트하기 어려웠습니다. 이는 **컴포넌트 별로 개별적인 테스트를 수행하기 어렵게 만들어, 버그를 발견하고 수정하는 데 시간이 많이 걸렸습니다.**
- 단일 쿼리의 결과에 의존하는 테스트 환경에서는 일부 컴포넌트의 변경이 전체 시스템에 영향을 미칠 수 있어, 안정적인 테스트가 어려웠습니다.

이러한 문제점들은 사용자 경험을 저하시킬 뿐만 아니라, 개발 및 유지보수 과정에서도 복잡성을 증가시켰습니다. **따라서 더 유연하고 효율적인 구조로 개선이 필요했습니다.** 새로운 구조는 이러한 문제들을 해결하고, 시스템의 유연성과 확장성을 높이며, 사용자 경험을 향상시키는 방향으로 설계되어야 했습니다.

[![Hatena Think Question](/img/content/2024-08-04-1/hatena-1184896_1280.png)](https://pixabay.com/illustrations/hatena-think-question-in-trouble-1184896/)

## 쿼리 설계

기존의 단일 쿼리 구조에서 발생한 문제들을 해결하기 위해, 각 컴포넌트별로 독립적인 API를 호출하는 구조로 변경하였습니다.

어떻게?? 코드를 보면서 이야기 해봅시다!

서버에서는 template 쿼리를 통해 화면에 그려져야할 컴포넌트의 최소 정보(type, id)를 제공합니다.

```graphql
type Query {
  """
  page_id에 맵핑되는 현재 컴포넌트 순서를 리턴한다.
  """
  template(page_id: String!): [Component!]!
}

type Component {
  id: ID!
  type: ComponentType!
}

enum ComponentType {
  BANNER
  MENU
  ITEM
}
```

## 요청과 응답

아래 쿼리를 통해 특정 페이지(ex. `BRAND`)에 어떤 컴포넌트들이 배치될 것인지를 서버로부터 받아옵니다.

```graphql
query FetchTemplate {
  template(page_id: "BRAND") {
    components {
      id
      type
    }
  }
}
```

`template` 쿼리 요청을 통해 컴포넌트의 `id`와 `type`을 리턴 받습니다.

- id: 나중에 `type`에 매핑되는 API를 호출할 때 노출되어야 할 데이터를 매핑하기 위해 사용됩니다.
- type: 컴포넌트의 스켈레톤을 생성하고, 적절한 API를 호출하기 위해 사용됩니다.

서버에서는 다음과 같은 방식으로 데이터를 반환합니다.

```kotlin
fun template(page_id: String): List<Component> {
    return dbRepository.findAllByPageId(page_id)
        .map { it.toComponent() }
}
```

요청을 받은 서버는 별다른 비즈니스 로직 없이 저장된 값을 반환하기 때문에 빠른 속도로 응답을 전달할 수 있습니다.

```json
{
  "data": {
    "template": [
      {
        "type": "BANNER",
        "id": "0"
      },
      {
        "type": "MENU",
        "id": "0"
      },
      {
        "type": "ITEM",
        "id": "0"
      },
      ...
    ]
  }
}
```

앱에서는 해당 값을 전달받고, `type` 형태에 맞는 스켈레톤을 그립니다.

![4.png](/img/content/2024-08-04-1/4.png)

이후 각 컴포넌트 `type`에 대응하는 API를 호출하게 됩니다. (데이터 지연 로딩(lazy loading))

## **성능 변화**

- 구조를 변경하고 난 후 ATF(Above the Fold) 영역의 성능 변화 입니다.
- 최적화 이전에는 모든 상품 카드와 데이터를 한 번에 불러오는 방식으로 인해 페이지 전체 로딩 시간이 길었습니다.
  - 예를 들어, **screen 쿼리**의 성능은 P90기준 670~680ms였습니다.
    ![5.png](/img/content/2024-08-04-1/5.png)
- 최적화 후에는 필요한 컴포넌트만 개별적으로 불러와, ATF 영역의 로딩 시간이 크게 단축되었습니다.
  - template 쿼리의 성능은 P90 기준으로 4.5ms~5ms를 기록했습니다.
    ![6.png](/img/content/2024-08-04-1/6.png)
  - 상단의 두 개 컴포넌트의 로딩 시간은 각각 4.9ms, 2.8ms이였습니다.
    ![7.png](/img/content/2024-08-04-1/7.png)
    ![8.png](/img/content/2024-08-04-1/8.png)
  - 이로 인해 ATF 화면 로딩 시간이 670ms에서 10ms(5ms + 5ms)로 대폭 개선되었습니다.
    - 여기서 더 나아가 template 쿼리와 상단 컴포넌트를 한번에 요청한다면 5ms로 이론상 로딩 시간 측면에서는 최적이 될 수 있습니다. 다만 오류 처리등은 상대적으로 복잡해지므로 거기까지 최적화는 하지 않았습니다.
  - ATF 영역의 로딩 속도가 현저히 빨라져, 유저는 이전보다 훨씬 빠르게 페이지를 로딩하는 경험을 할 수 있었습니다.

## 결론

GraphQL의 장점으로 뽑히는 것 중 하나가 데이터를 한번에 요청해 라운드 트립(Round-trip)을 줄일 수 있다는 부분입니다. 그렇기 때문에 카카오스타일 SDUI에서도 한번에 요청하는 것으로 초기 모델을 설계했습니다.

하지만 레이턴시 증가, 단일 장애점(SPOF) 같은 문제를 겪었고, 이를 해결하기 위해 설계를 다시 고민했습니다. 그리고 쿼리를 분할하는 간단한 방법으로 많은 문제를 해결할 수 있었습니다.

향후에도 SDUI를 지속적으로 개선하고 발전시켜 나가면서, 더 나은 사용자 경험과 효율적인 개발 환경을 제공해 나갈 계획입니다.
