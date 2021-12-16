---
title: Server Driven UI 설계를 통한 UI 유연화
tags: ['GraphQL','UI']
date: 2021-12-16
author: simon.z(박성범)
original: https://parksb.github.io/article/38.html
---

웹과 달리 네이티브 모바일 앱은 빌드, 배포 후에는 수정이 불가능합니다.
만약 잘못된 위치에 버튼을 배치한 채로 스토어에 앱을 배포했다면,
그리고 사용자가 잘못된 버전의 앱을 설치했다면 버튼의 위치를 수정할 방법이 없습니다.
유일한 방법은 사용자가 스스로 스토어에 들어가 수정된 버전의 앱으로 업데이트하는 것 뿐입니다.

배포 후 수정이 불가능하다는 특성이 부딪히는 또 다른 상황은 A/B 테스트입니다.
소프트웨어를 사용하는 동안 일어나는 사용자의 행동과 경험은 화면 구성이나 문구에 따라 크게 달라지기 때문에 최적의 화면을 디자인하는 것이 중요합니다.
그런데 사용자의 행동과 경험을 예측하는 것은 너무 어려운 일이기 때문에 현실의 사용자들에게 다양한 유형의 UI를 제공하고,
어떤 UI가 적합한지 실측할 필요가 있습니다.
실제로 카카오스타일을 비롯한 많은 소프트웨어 기업들이 사용자를 A, B 그룹으로 나누고 (더 많은 그룹으로 나눌 수도 있습니다)
각 그룹에게 서로 다른 UI를 제공해 가장 적합한 UI를 선정하는 A/B 테스트를 진행하고 있습니다.

유연한 UI를 제공하려면 UI가 클라이언트의 빌드와 배포로부터 자유로워야 합니다.
이러한 목표를 이루기 위해 웹뷰와 같이 네이티브 환경을 벗어난 다양한 방법을 선택할 수도 있겠지만,
현실에서는 다양한 이유로 웹뷰를 사용할 수 없는 상황이 있습니다.
이 글에서는 간단한 예시를 통해 Server Driven UI의 개념에 대해 설명하고,
네이티브 모바일 앱의 UI를 유연하게 다루기 위해 카카오스타일의 지그재그UX그룹이 Server Driven UI 설계를 어떻게 사용하고 있는지 소개하고자 합니다.

<!--more-->

## 서버에서 UI 다루기

클라이언트과 달리 서버는 언제든 변경, 배포할 수 있습니다.
그렇다면 서버에서 제공하는 API를 이용해 동적으로 클라이언트의 UI를 구성하면 어떨까요?
서버가 API 응답에 UI 정보를 담아 클라이언트에 제공하고,
클라이언트가 API 응답에 따라 화면을 렌더링한다면 서버에서 API 응답을 변경하는 것만으로 클라이언트의 화면 구성을 동적으로 변경할 수 있을 것입니다.

예를 들어 사용자에게 홈 화면을 제공하는 경우, 서버가 제공하는 REST API `screen`을 통해 `home` 화면에 대한 UI 정보를 얻을 수 있습니다.

```
GET /screen/home
```

이 API는 홈 화면을 구성하는 UI 요소 리스트를 JSON 포맷으로 응답합니다.
따라서 클라이언트는 응답의 `data` 리스트를 순회하며 각각의 `type`에 해당하는 UI 요소를 화면에 그려주면 됩니다.

![2021-12-16-1-01.png](/img/content/2021-12-16-1/2021-12-16-1-01.png)

이렇게 하면 클라이언트를 새로 배포하지 않아도 서버에서 `data` 리스트의 요소를 변경함으로써 클라이언트가 유연한 UI를 제공할 수 있을 것입니다.
이처럼 UI에 대한 정보를 서버에서 관리, 제공하는 것이 Server Driven UI 설계의 기본 개념입니다.

## 재사용 가능한 UI 컴포넌트 제공하기

서버에서 UI를 관리하면 유연성을 확보할 수 있지만, 사용하는 UI 요소의 재사용성을 고려하지 않으면 다양한 화면에서 UI 요소를 교체하기 어려워집니다.
이러한 문제를 피하려면 모든 UI 요소를 재사용 가능한 컴포넌트로 구성하고, UI 컴포넌트를 다양한 화면에서 조립해서 사용할 수 있도록 만들어야 합니다.

또한 수시로 화면에 새로운 컴포넌트가 추가되고 제거되면 서버와 클라이언트 사이의 타입 정의에 불일치가 발생하기 쉽습니다.
이때 GraphQL을 사용하면 서버와 클라이언트가 공유하는 스키마를 통해 API의 타입 안전성을 보장할 수 있습니다.

### 쿼리 설계

서버는 UI 컴포넌트 리스트를 반환하는 `screen` 쿼리를 통해 특정 화면에 대한 UI 정보를 제공합니다.

```graphql
type Query {
  screen(screenType: ScreenType!): Screen!
}

enum ScreenType {
  HOME
  SIGN_IN
}

type Screen {
  components: [Component!]!
}
```

클라이언트는 `screen` 쿼리를 호출하며 홈 화면에서는 `screenType: HOME` 인자를, 로그인 화면에서는 `screenType: SIGN_IN` 인자를 전달할 것입니다.
서버는 쿼리를 받으면 해당 `screenType`에 맞는 컴포넌트를 조합하여 `Screen` 타입의 `components` 필드에 `Component` 리스트를 담아 응답합니다.

`Component`는 유니온 타입입니다. 유니온 타입은 다양한 타입의 컴포넌트를 `Component`라는 하나의 타입으로 다룰 수 있게 해줍니다.
`Screen` 타입의 `components` 필드가 `Component` 리스트를 반환한다는 것은 리스트 안에 `AppBar`, `TextButton`, `Image` 타입이 섞일 수 있다는 의미입니다.

```graphql
union Component = AppBar | TextButton | Image

type AppBar {
  title: String!
}

type TextButton {
  text: String!
  route: String
}

type Image {
  url: String!
}
```

만약 컴포넌트들이 공통 필드를 가진다면 `Component`를 유니온 타입 대신 인터페이스로 만들어도 됩니다.

```graphql
interface Component {
  position: Int!
}

type AppBar implements Component {
  position: Int!
  title: String!
}

type TextButton implements Component {
  position: Int!
  text: String!
  route: String
}

type Image implements Component {
  position: Int!
  url: String!
}
```

유니온 타입은 단순히 독립적인 컴포넌트 타입들을 하나의 타입으로 사용하기 위한 방식이었다면,
인터페이스는 각각의 컴포넌트 타입들이 추상 타입인 `Component`를 구현하는 방식이기 때문에 어떤 타입이 UI 컴포넌트인지 명확해진다는 장점이 있습니다.

### 요청과 응답

GraphQL의 재사용 가능한 필드 묶음인 프래그먼트(Fragment)는 UI 컴포넌트를 주고받기에 매우 적합합니다.
클라이언트에서 컴포넌트를 요청할 때는 사용 가능한 모든 컴포넌트 프래그먼트를 요청할 것입니다.

```graphql
query fetchScreen {
  screen(screenType: HOME) {
    components {
      ... on AppBar {
        __typename
        title
      }
      ... on TextButton {
        __typename
        text
        route
      }
      ... on Image {
        __typename
        url
      }
    }
  }
}
```

주의할 점은 ’사용 가능한 모든 컴포넌트’를 요청한다는 점입니다.
만약 구현 당시에 사용할 컴포넌트만 요청하면 차후 서버에서 다른 컴포넌트를 화면에 추가해도 보여줄 수 없기 때문입니다.

요청을 받은 서버는 홈 화면에서 사용할 컴포넌트를 골라서 반환합니다.
이 예시에서는 홈 화면에 `AppBar` 컴포넌트 하나와 `TextButton` 컴포넌트 두 개를 응답합니다.

```kotlin
fun screen(screenType: ScreenType): Screen =
  Screen(
    when (screenType) {
      ScreenType.HOME => getHomeComponents(),
      ScreenType.SIGN_IN => getSignInComponents(),
    }
  )
```

```kotlin
fun getHomeComponents(): List<Component> =
  listOf(
    AppBar(
      title = "Home",
    ),
    TextButton(
      text = "Sign in",
      route = "/sign_in",
    ),
     TextButton(
      text = "Sign up",
      route = null,
    ),
  )
```

코틀린 코드로 예시를 든 이유는 지그재그UX그룹의 서버가 코틀린으로 작성되어 있기 때문입니다.
프로그래밍 언어의 선택은 Server Driven UI나 GraphQL과는 전혀 관련이 없습니다. 다양한 언어로 된 GraphQL API 서버 구현체가 있기 때문에 언어는 문제가 되지 않습니다.

요청이 성공하면 서버에서 의도한 GraphQL 응답을 받을 수 있습니다.

```json
{
  "data": {
    "screen": {
      "components": [
        {
          "__typename": "AppBar",
          "title": "Home"
        },
        {
          "__typename": "TextButton",
          "text": "Sign in",
          "route": "/sign_in"
        },
        {
          "__typename": "TextButton",
          "text": "Sign up",
          "route": null
        }
      ]
    }
  }
}
```

앞서 클라이언트가 `components` 필드 아래에 `Image` 프래그먼트도 요청했지만,
서버가 `Image` 컴포넌트를 응답하지 않았기 때문에 리스트에는 포함되지 않았습니다.
반대로 서버가 `Image` 컴포넌트를 응답했지만 클라이언트가 요청하지 경우에도 리스트에 포함되지 않습니다.
따라서 서버가 신규 컴포넌트를 정의하거나 기존 컴포넌트에 신규 필드를 추가해도 구버전 클라이언트에서는 신규 컴포넌트와 필드를 요청하지 않기 때문에 클라이언트의 하위호환성을 확보할 수 있습니다.
단, 기존 컴포넌트에 대해 구버전 클라이언트에서 사용 중인 필드를 제거하거나 non-nullable 필드를 nullable 필드로 바꾸는 경우 하위호환성이 깨지므로 주의해야 합니다.

## 견고한 디자인 시스템과 위젯으로 화면 그리기

통일감있는 컴포넌트를 사용하려면 디자인 시스템이 잘 잡혀 있어야 합니다.
만약 UI 레벨에서 디자인 시스템이 정립되어 있지 않다면 애초에 컴포넌트를 개념을 도입하는 것이 어불성설일 뿐더러,
서버 개발자와 클라이언트 개발자, 디자이너 사이에 사용하는 용어가 달라져 커뮤니케이션 비용도 증가합니다.
따라서 이상적으로 Server Driven UI 설계를 실현하기 위해서는 디자인 시스템과 그에 따른 UI의 컴포넌트화가 선행되어야 합니다.

플러터(Flutter)의 [머티리얼 라이브러리(Material Library)](https://api.flutter.dev/flutter/material/material-library.html)는
구글의 머티리얼 디자인 시스템을 높은 수준으로 구현하고 있어 Server Driven UI를 바로 적용할 수 있습니다.
지그재그 앱에 플러터를 사용하고 있지는 않지만, 서버 개발자인 저는 간단한 데모를 만들기에 적합하다고 판단해 사용해봤습니다.

![2021-12-16-1-02.png](/img/content/2021-12-16-1/2021-12-16-1-02.png)

### 프래그먼트-컴포넌트-위젯 대응

플러터가 가진 위젯(Widget) 개념이 컴포넌트 개념과 부합한다는 점도 Server Driven UI 설계와 잘 맞습니다.
플러터의 위젯은 웹 프론트엔드 프레임워크인 리액트(React)의 컴포넌트 시스템으로부터 영감을 받아 만들어졌으며, 각 위젯은 자신의 현재 상태에 따른 UI를 표현합니다.

클라이언트의 추상 클래스 `Component`는 서버에서 응답하는 GraphQL 유니온 타입 `Component`에 대응됩니다. `Component`를 구현하는 클래스는 위젯을 반환하는 `compose` 메서드를 함께 구현해야 합니다.

```dart
abstract class Component {
  Widget compose(Map<String, dynamic> args, BuildContext context);
}
```

가령 앱 상단에 들어가는 앱바 UI를 의미하는 `AppBarComponent`는 `Component` 클래스를 구현하며, `[AppBar]` 위젯을 반환하는 `compose` 메서드를 갖습니다.

```dart
class AppBarComponent implements Component {
  Widget compose(Map<String, dynamic> args, BuildContext context) {
    return AppBar(
      title: Text(args['title']),
    );
  }
}
```

`compose` 메서드는 `args` 인자의 `title` 프로퍼티에 접근해 앱바의 타이틀을 채웁니다.
이때 `args` 인자는 서버의 응답에 포함되는 `AppBar` 프래그먼트의 필드들이 `Map<String, dynamic>` 타입으로 전달될 것입니다.

클라이언트가 서버로부터 받은 응답을 파싱한 다음, `components` 필드에 포함된 각각의 프래그먼트들을 자신의 컴포넌트에 대응시키고,
각 컴포넌트의 위젯에 대응시키려면 GraphQL 스키마를 바탕으로 한 컴포넌트 레지스트리가 필요합니다.

```dart
class Registry {
  static final Map<String, Component> _dictionary = {
    'AppBar': AppBarComponent(),
    'TextField': TextFieldComponent(),
    'Image': ImageComponent(),
  };

  static Widget getComponent(dynamic component, BuildContext context) {
    var matchedComponent = _dictionary[component['__typename']];
    if (matchedComponent != null) {
      return matchedComponent.compose(component, context);
    } else {
      return null;
    }
  }

  static List<Widget> getComponents(dynamic components, BuildContext context) {
    var matchedComponent = components as List<dynamic>;
    return matchedComponent.map((component) => getComponent(component, context))
        .where((element) => element != null)
        .toList();
  }
}
```

클라이언트는 응답 내용을 바탕으로 위젯 리스트를 얻기 위해 레지스트리의 `getComponents` 메서드를 호출하고,
`components` 필드를 순회하며 `getComponent` 메서드를 통해 프래그먼트를 위젯으로 변환합니다.

`getCompnent` 메서드는 프래그먼트에 포함된 메타 필드 `__typename` 값을 이용해 각 프래그먼트를 컴포넌트에 대응시키고,
해당 컴포넌트의 `compose` 메서드를 호출해 컴포넌트 각각의 위젯을 반환합니다. 만약 클라이언트가 모르는(`_dictionary`에 등록되지 않은) 컴포넌트가 응답에 포함되어 있다면 필터링될 것입니다.

### 컴포넌트 조립

앞서 살펴본 레지스트리를 이용해 서버에서 응답하는 모든 컴포넌트를 위젯으로 변환하고, 각 화면에 맞는 위젯을 조립할 수 있게 되었습니다.
지금까지의 흐름을 서버, API 응답, 클라이언트로 정리하면 아래와 같습니다.

![2021-12-16-1-03.png](/img/content/2021-12-16-1/2021-12-16-1-03.png)

실제 동작하는 코드는 [github.com/parksb/server-driven-ui](https://github.com/parksb/server-driven-ui)에서 확인할 수 있습니다.

## 지그재그의 Server Driven UI

여기까지 Server Driven UI의 개념과 구현에 대해 살펴봤습니다.
개념적인 예시였지만 지그재그도 같은 방식으로 화면을 구성하고 있습니다.
과거에는 각 페이지를 위한 전용 쿼리를 사용해야 했습니다.
기존 화면에 새로운 UI 요소를 추가하려면 API 응답에 새 필드를 추가해야 했고,
UI를 구성하기 위한 클라이언트 작업도 필요했습니다.
그러나 이제는 여러 화면에서 하나의 쿼리를 사용할 수 있게 되었고,
동일한 컴포넌트를 여러 화면에서 재사용하는 것도 가능하게 되었습니다.
가령 홈탭에 사용하는 상품 카드 컴포넌트는 베스트탭에도 그대로 사용하고 있습니다.

![2021-12-16-1-04.png](/img/content/2021-12-16-1/2021-12-16-1-04.png)

클라이언트가 서버로부터 응답받은 컴포넌트를 조립해 화면을 구성하기 때문에,
만약 컴포넌트의 종류나 순서를 바꾸고 싶다면 클라이언트 변경없이 서버에서 응답을 변경해주기만 하면 됩니다.
따라서 A/B 테스트에 따른 유저군별 UI는 물론, 개별 사용자를 위한 맞춤 개인화 UI도 쉽게 제공할 수 있습니다.

### 같은 컴포넌트, 다른 내용

다양한 화면에 같은 컴포넌트를 사용하되, 각 컴포넌트의 내용을 서로 다르게 제공하기 위해서 지그재그는 컴포넌트에 메서드를 결합하는 방식을 고안했습니다.
컴포넌트는 앞서 살펴본 것과 같이 재사용 가능한 UI 요소를 의미하며, 메서드는 해당 UI 요소를 어떤 내용으로 채울지 의미합니다.
컴포넌트와 메서드는 `Component : Method` 페어를 이루는데, 이 페어를 '컴포넌트 메서드 (Component Method)'라고 부릅니다.
서버는 각 화면마다 어떤 컴포넌트를 어떤 메서드로 제공할지 표현하는 설계도를 가지고 있어야 합니다. 아래는 홈 탭과 베스트 탭의 설계도입니다.

```kotlin
typealias ComponentMethod = Pair<Component, Method>

enum class Screen(val componentMethods: List<ComponentMethod>) {
  HOME(
    listOf(
      ComponentMethod(Component.BANNER_GROUP, Method.HOME),
      ComponentMethod(Component.BANNER, Method.HOME),
      ComponentMethod(Component.TEXT_TITLE, Method.HOME),
      ComponentMethod(Component.GOODS_GROUP, Method.HOME),
      ComponentMethod(Component.GOODS_CARD_LIST, Method.HOME),
    ),
 ),
  BEST(
    listOf(
      ComponentMethod(Component.CATEGORY, Method.GENERAL),
      ComponentMethod(Component.SORTING, Method.GENERAL),
      ComponentMethod(Component.GOODS_CARD_LIST, Method.BEST)
    ),
  ),
}
```

홈 탭과 베스트 탭에 모두 상품 카드 목록이 필요하기 때문에 `GOODS_CARD_LIST` 컴포넌트를 사용하고 있습니다.
하지만 그 내용은 달라야하기 때문에 홈 탭의 상품 카드 목록은 `GOODS_CARD_LIST : HOME` 페어를, 베스트 탭의 상품 카드 목록은 `GOODS_CARD_LIST : BEST` 페어를 이루고 있습니다.

컴포넌트 메서드를 바탕으로 컴포넌트의 내용을 채우고, 클라이언트에게 제공할 최종 컴포넌트를 생성하는 비즈니스 로직도 필요합니다.
아래  `ComponentGeneratable` 인터페이스는 컴포넌트 메서드 프로퍼티와 컴포넌트를 반환하는 `generate` 메서드를 갖춘 인터페이스입니다. 

```kotlin
interface ComponentGeneratable {
  val componentMethod: ComponentMethod

  fun generate(): Component
}
```

어떤 클래스가 `ComponentGeneratable` 인터페이스를 구현한다면, 해당 클래스는 컴포넌트를 생성할 수 있는 구현체라는 의미가 됩니다.
따라서 홈 화면에 보여줄 상품 카드 목록은 `HomeGoodsCardListGenerator` 구현체를 통해, 베스트 화면에 보여줄 상품 카드 목록은 `BestGoodsCardListGenerator` 구현체를 통해 제공할 수 있습니다.

```kotlin
class HomeGoodsCardListGenerator : ComponentGeneratable {
  override componentMethod = ComponentMethod.HOME

  override generate(): GoodsCardList {
    val goodsList: List<Goods> = getGoodsList().shuffled()
    return GoodsCardList(goodsList.map { GoodsCard(it.name, it.price) })
  }
}
```

```kotlin
class BestGoodsCardListGenerator : ComponentGeneratable {
  override componentMethod = ComponentMethod.BEST

  override generate(): GoodsCardList {
    val goodsList: List<Goods> = getGoodsList().sortedByDescending { it.score }
    return GoodsCardList(goodsList.map { GoodsCard(it.name, it.price) })
  }
}
```

이제 화면에 따라 컴포넌트 리스트를 반환하는 `getHomeComponents` 함수와 `getBestComponents` 함수를 따로 작성하지 않고,
하나로 통합해 `getComponents` 함수로 만들 수 있습니다. `screenType` 인자에 따라 설계도를 참조해 해당 화면에 제공할 컴포넌트를 반환하면 됩니다.

```kotlin
fun getComponents(screenType: ScreenType): List<Component> =
  when (screenType) {
    ScreenType.HOME -> Screen.HOME.componentMethods
    ScreenType.BEST -> Screen.BEST.componentMethods
  }.map { componentMethod ->
    componentMaker.make(componentMethod)
  }
```

`ComponentMaker`의 `make`함수는 클래스 프로퍼티 `generatorMap`으로부터 컴포넌트 메서드를 인자로 전달받고,
해당 컴포넌트 메서드에 대응되는 `ComponentGeneratable`의 구현체를 찾아 해당 구현체의 `generate` 함수를 호출합니다.

```kotlin
class ComponentMaker(generators: List<ComponentGeneratable>) {
  private val generatorMap: Map<ComponentMethod, ComponentGeneratable> =
    generators.associateBy { it.componentMethod }

  fun make(componentMethod: ComponentMethod): Component =
    generatorMap[componentMethod]?.generate()
      ?: throw IllegalArgumentException("...")
}
```

저희 서버는 스프링부트를 사용하고 있기 때문에 클래스 생성자가 `List<ComponentGeneratable>` 타입 인자를 주입받음으로써
`ComponentGeneratable` 인터페이스의 모든 구현체를 얻을 수 있습니다.
따라서 `ComponentMaker`가 컴포넌트 메서드와 컴포넌트 생성 구현체의 키-값 맵을 미리 `generatorMap` 프로퍼티로 만들어 두는 것이 가능합니다.

이로써 화면별 컴포넌트를 응답하는 함수를 따로 작성하지 않고, 앞서 만든 설계도를 변경하는 것만으로 쉽게 화면에 따라 적절한 컴포넌트를 응답할 수 있게 되었습니다.

### 앞으로의 과제

이 정도로도 충분히 유연하게 UI를 관리할 수 있지만, 더 복잡한 상황에 대응할 수 있어야 합니다.
지금은 수직으로 컴포넌트를 쌓고 있는데, 보다 다양한 형태로 컴포넌트를 배치하기 위해서 컴포넌트의 상위 개념인 '레이아웃'에 대해 구상하고 있습니다.
뿐만 아니라 특정 컴포넌트 내에서의 페이지네이션, 페이지 전체가 아닌 일부 컴포넌트에 대한 리로딩을 지원하기 위한 방법도 앞으로 해결해야할 과제 중 하나입니다.

이처럼 Server Driven UI를 고도화하는 데 많은 도전이 남아있고, 지그재그UX그룹은 다양한 사용자들에게 최적의 경험을 제공하기 위한 기술적 고민을 이어가고 있습니다.
카카오스타일에서 함께 고민하고, 개발하고 싶으시다면 언제든 부담없이 다음 링크를 통해 지원해주세요: [https://kakaostyle.recruiter.co.kr/app/jobnotice/view?systemKindCode=MRS2&jobnoticeSn=70743](https://kakaostyle.recruiter.co.kr/app/jobnotice/view?systemKindCode=MRS2&jobnoticeSn=70743)

긴 글 읽어주셔서 감사합니다 :)

## 참고자료

- [김도훈, “Server Driven UI (Feat.Flutter)”, 2020.](https://medium.com/@kimdohun0104/server-driven-ui-feat-flutter-87fcbb04e610)
- [박호준, “GraphQL이 가져온 에어비앤비 프론트앤드 기술의 변천사”, DEVIEW 2020, 2020.](https://deview.kr/2020/sessions/337)
- [Tom Lokhorst, “Server Driven UI”, Tom Lokhorst’s blog, 2020.](http://tom.lokhorst.eu/2020/07/server-driven-ui)
- [Ryan Brooks, “A Deep Dive into Airbnb’s Server-Driven UI System”, 2021.](https://medium.com/airbnb-engineering/a-deep-dive-into-airbnbs-server-driven-ui-system-842244c5f5)
