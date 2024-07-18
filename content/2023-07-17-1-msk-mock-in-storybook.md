---
title: 'Storybook의 MSW mock 구조 개선'
tags: ['Storybook']
date: 2023-07-17T01:00:00
author: Martin(유덕남)
---

카카오스타일의 파트너센터 서비스에서는 UI 테스트와 문서화를 위해서 Storybook과 MSW를 사용하고 있습니다. Storybook의 각 스토리마다 MSW GraphQL mock을 개별로 정의해서 사용하고 있었는데, 이로 인해 코드가 중복되고 mock 누락으로 인한 오류가 자주 발생했습니다. 이런 문제를 해결하기 위해, 스토리마다 따로 정의된 MSW mock을 한 군데로 모아서 관리할 수 있는 새로운 구조를 제안하고, recast를 사용한 변환 스크립트를 작성하여 마이그레이션 하는 과정까지 다뤄봤습니다.

<!--more-->

## 기존 구조

Storybook에서 MSW를 사용할 수 있도록 해주는 애드온인 [msw-storybook-addon](https://storybook.js.org/addons/msw-storybook-addon/)은 아래와 같은 구조를 예시로 들고 있으며, 카카오스타일 프로젝트에서도 동일한 방식으로 스토리를 작성하고 있습니다.

```tsx
// Component.stories.tsx
import { rest, graphql } from 'msw';

export const Story = () => <Component />;

Story.parameters = {
  msw: {
    handlers: [
      graphql.query('GetUser', (req, res, ctx) => res(ctx.data({ id: 1 }))),
      rest.get('/user', (req, res, ctx) => res(ctx.json({ id: 1 }))),
    ],
  },
};
```

이 방식의 장점은 다음과 같습니다.

- 컴포넌트가 필요로 하는 API를 문서화할 수 있습니다.
- 테스트할 때에도 정의된 API mock만 사용하므로, 의도치 않게 테스트 케이스가 변하지 않습니다.

단점은 다음과 같습니다.

- API가 업데이트될 때 관련된 mock을 찾아서 수정해야 합니다.
- 컴포넌트를 수정할 때 API mock 추가를 누락해서 스토리에 오류가 발생하는 경우가 자주 있습니다.
- 여러 컴포넌트에서 공통적으로 사용되는 컴포넌트에 연관된 API가 수정되는 경우에는, 영향받는 모든 스토리를 수정해야 합니다.

파트너센터는 하나의 API 서버만 바라보고 있고, 페이지마다 사용할 수 있는 API도 모두 동일합니다. 그럼에도 불구하고 스토리마다 mock을 따로 작성하는 것이 관리의 어려움을 초래하고 있고, 장점보다 단점이 더 크다고 생각하게 되었습니다.

## 새로운 구조 제안

그래서, 스토리북의 API mock을 공통화해서 관리하는 방법을 고민하게 되었습니다. 간단하게, 아래처럼 하나의 파일에 모든 mock을 모아둔다고 생각하면 됩니다.

또한, API 응답을 컴포넌트의 props으로 직접 전달하는 사례도 존재하기 때문에, 이럴 때 사용할 수 있도록 API 응답을 그대로 상수로 정의해두는 fixtures도 사용해볼 수 있습니다.

```tsx
// fixtures.ts
export const USER = { id: 1 };

// mocks.ts
import { rest, graphql } from 'msw';
import { USER } from 'fixtures';

export const mocks = [
  graphql.query('GetUser', (req, res, ctx) => res(ctx.data(USER))),
  rest.get('/user', (req, res, ctx) => res(ctx.json(USER))),
];

// Component.stories.tsx
import { mocks } from 'mocks';
import { USER } from 'fixtures';

export const Story = () => <Component />;

Story.parameters = {
  msw: {
    handlers: mocks,
  },
};
Story.args = {
  user: USER,
};
```

API mock을 모아놓고 관리하면 다음과 같은 장점이 있습니다.

- 중복되는 API mock이 최소화되어, API가 변경될 때 관리가 쉽습니다.
- 컴포넌트에 API 호출이 추가되었을 때에도, 스토리마다 따로 대응할 필요가 없기 때문에 번거로움을 줄일 수 있습니다.
- 스토리를 작성할 때 API mock에 대해 별도로 고려하지 않아도 되어 작성 난이도가 크게 줄어듭니다.
- 전반적으로 프로젝트 내부에서 유지보수나 코드 재사용이 원활해집니다.

단점으로는 다음과 같은 것들이 있습니다.

- 전역에 API가 존재한다는 가정이 들어가기 때문에, 프로젝트 외부에서 컴포넌트를 추출해서 사용하는 것이 어려워질 수 있습니다.
- mock을 어떻게 관리할 것인지에 대한 가이드라인이 필요합니다.
- API mock을 오버라이드해야 하는 상황이 발생할 때, 이를 어떻게 처리할 것인지에 대한 고민이 필요합니다.
- 기존에 사용하던 모든 스토리를 수정해야 하는 문제가 있습니다.

파트너센터 프로젝트에서 사용하고 있던 컴포넌트를 다른 프로젝트에서 사용하지 않고 있고, 앞으로도 그럴 가능성이 없다고 판단해, 단점이 크지 않다고 생각했습니다.

따라서, 전환 비용만 지불할 수 있다면 앞으로 스토리북 관리 이슈를 최소화할 수 있도록 API mock을 중앙화하는 것이 좋다고 생각했습니다.

## 중앙화 전환 방법 검토

위의 단점에서 나온 대로, API mock을 어떻게 관리하고 마이그레이션할 것인지에 대해서는 따로 고민이 필요했습니다. 특히, 파트너센터 프로젝트는 방대하고, 작업자도 많기 때문에 마이그레이션 작업이 상당히 복잡해질 것으로 예상했습니다.

### 문제점

파트너센터에서는 기존에 GraphQL 스키마나, API mock을 관리하는 명확한 규칙이 없었습니다.

src 안의 fixtures, mocks, query 등의 공통 디렉토리를 사용하는 경우도 있었고, 컴포넌트 근처에 임의로 생성해두는 경우도 있는 등 일관성 없이 필요한 곳에 각각 추가해서 사용하고 있었습니다.

앱이나 스토리북에서 필요할 때마다 이렇게 제각각 존재하는 파일들을 임포트해서 사용하고 있었지만, 중앙화를 진행하게 된다면 이 구조를 어떻게 재구성할지에 대한 고민도 필요해집니다.

이런 상황을 감안하면서, fixtures와 mocks를 어떻게 모아서 관리할 수 있을지를 고민해봤습니다.

### 접근 1

먼저, 위의 `mocks.ts` 예제처럼 하나의 파일이나 폴더에 모든 API mock을 모아두는 방법을 생각해봤습니다.

하지만 이 상황에서 fixtures, mocks를 중앙화해서 관리하는 규칙을 따로 정하게 된다면, 폴더 규칙 관련해서 혼란이 발생하기 쉽다고 생각했습니다.

여러 방식을 고민해봤으나 (파일 하나로 묶어서 관리하기, GraphQL 파일별로 나누기 등등…) 어떤 방식을 쓰더라도 별로 직관적이지 않고, 오히려 불편함만 초래하기 쉬울 것 같았습니다.

특히, GraphQL쪽에 대한 규칙도 불명확한 상황이라서, 이렇게 fixtures / mocks 규칙을 정하게 된다면 GraphQL 관련 규칙도 동시에 정해야 한다는 문제가 있었습니다.

이런 상황이라서, 지금 폴더 규칙을 정의하는 것보다는, fixtures / mocks 정리 작업을 마치고 난 뒤 GraphQL 파일 정리를 따로 진행하는 것이 더 낫다고 판단했습니다.

### 접근 2

GraphQL, API mock 파일들이 프로젝트 전반적으로 봤을 때에는 일관된 규칙 없이 관리되고는 있지만, 작업자와 도메인별로 어느정도는 암묵적인 체계를 가지고 있다고 볼 수 있었습니다.

다시 말해서, 프로젝트 전체 규칙은 불명확하지만, 작업자별로 정리하는 패턴이 있다고 볼 수 있습니다.

이렇게 어느정도 암묵적인 체계는 잡혀있는 만큼, 이 체계를 그대로 들고갈 수 있다면 혼란을 최소화하고 빠르게 정리를 마칠 수 있다고 판단했습니다.

특히, GraphQL 파일이 어느정도 각자 유형에 맞춰서 정리되어 있는 만큼, fixtures와 mocks도 똑같은 카테고리를 들고 가져가는게 직관적이라고 생각했습니다.

그래서, GraphQL와 mock 파일을 같이 묶어서, 한 세트로 관리하는 방식이 현재로써는 제일 좋다고 판단했습니다.

### 결론

접근 2에 쓰여진 내용대로, GraphQL과 API mock 파일을 묶어서, 아래와 같은 방식으로 정의했습니다.

- `index.graphql` 에서 GraphQL 쿼리를 정의한다면
- `index.fixtures.ts` 에서 정적 API mock (fixture)를 정의하고
- `index.mocks.ts` 에서 동적 API mock을 정의

나중에는 GraphQL 파일 경로 등 여러가지에 대해서 정리가 필요하긴 하겠지만, 지금 시점에서는 이렇게 파일을 나란히 만드는 방식으로 관리하는 것이 난이도 면에서 적절하다고 생각했습니다.

특히, GraphQL과 나란히 fixtures, mocks 파일을 추가해주기만 하면 되므로, 디렉토리가 어떤지, 쿼리가 어느 파일에 들어가야 하는지 등에 대한 고민을 최소화할 수 있습니다.

fixtures, mocks를 별도로 나눈 이유는, API 응답을 스토리에서 props로 넘겨주거나, fixture 데이터를 가공해서 사용하는 경우도 많기 때문입니다. 모든 mock을 mocks에서 처리하는 것보다는, 상수로 관리할 수 있는 것들은 상수로 관리하는게 유리하다고 생각했습니다.

## 결정된 파일 형식

후술하겠지만, `fixtures.ts` 와 `mocks.ts` 의 내용을 중앙화된 API mock에 등록해야 하기 때문에, 이 파일들에 대한 형식도 정의가 필요합니다. 구체적으로는, 어떤 변수가 어떤 GraphQL 쿼리에 대응하는지 알 수 있어야 합니다.

### fixtures.ts

`fixtures.ts`에서는 GraphQL 쿼리 이름을 그대로 따라가는 것으로 정의했습니다. 이를 위해서 camelCase, snake_case, SCREAMING_SNAKE_CASE 등의 컨벤션을 섞어서 사용합니다.

예를 들어, GraphQL 쿼리 이름이 `GetShopContact` 라면, 여기에 대한 fixture 이름은 `GET_SHOP_CONTACT` 가 됩니다. 타입 검증을 위해서 타입 정보를 불러와서 지정해주는 것도 권장합니다.

GraphQL에 대응하는 쿼리들을 아래와 같은 형태로 입력해주면 됩니다.

```tsx
// shop.fixtures.ts
import { GetShopContact } from '@/api';
export const GET_SHOP_CONTACT: GetShopContact = {
  shop_contact: {
    name: '홍길동',
    phone: '010-0000-0000',
  },
};
```

fixtures에서는 GraphQL의 query, mutation 유형은 구분하지 않고 있습니다. 서로 이름이 겹치지 않기 때문에 굳이 구분할 필요가 없다고 판단했습니다.

다만, 프로젝트에서는 GraphQL 말고 REST API도 사용하고 있는데, 이들은 쿼리 이름이 없기 때문에 fixtures에 넣을 수 없습니다. 대신 REST API는 mocks에 들어가도록 했습니다.

### mocks.ts

mocks.ts에는 동적인 로직이 들어가거나, GraphQL 쿼리가 아닌 요청들이 포함됩니다. 여기에서는 상수가 아닌, msw의 API mock이 그대로 들어가게 됩니다.

msw API mock에서는 아래처럼 GraphQL 쿼리 이름이나, REST 엔드포인트를 입력받도록 하고 있습니다.

`graphql.query('GetSomething', () => ...)`

따라서, mock에서는 변수 이름에 구애받지 않고, export만 해주면 사용할 수 있습니다. 하지만, 가능하다면 대응하는 쿼리 이름이나, REST 주소와 동일하게 정의하는 것을 권장합니다.

```tsx
// info.mocks.ts
import { rest } from 'msw';
export const GET_INFO = rest.get('/api/provider/info', () => ...);
```

또한, GraphQL 말고 REST 요청도 API mock이 필요한데, REST API는 대응하는 graphql 파일이 없고, 사용처가 많지 않은 관계로, `old.mocks.ts` 라는 파일을 임의로 생성해서 정리해두었습니다.

## 스토리북에서 사용하기

이렇게 파일 규칙을 정했지만, 이걸 어떻게 스토리북에서 사용할 수 있게 할지도 고민이 필요합니다.

`.mocks.ts` 와 `.fixtures.ts` 가 소스코드 전체에 흩뿌려져 있게 되는데, 스토리북에서 이 파일들을 수동으로 불러와야 한다면 오히려 기존 방식보다 더 번거로울 수 있다고 생각했습니다.

이를 해결하기 위해서, webpack이 제공하는 `require.context` 기능을 활용하기로 했습니다. ([#](https://webpack.js.org/guides/dependency-management/#requirecontext))

`require.context('.', true, '*.js')` 와 같이 찾고 싶은 파일의 패턴을 입력하면, 폴더 안의 일치하는 모든 파일을 임포트해오는 기능입니다. 이를 통해서 프로젝트 안의 원하는 파일들을 한 번에 가져올 수 있습니다.

```tsx
const fixtures_context = require.context('..', true, /^\.\/(?!node_modules)[^/]+\/.+\.fixtures\.tsx?$/i);
```

다만, 프로젝트 폴더 구조상 소스 코드와 `node_modules` 등 다른 폴더들이 섞여있기 때문에, 이를 제외하느라 정규표현식이 조금 복잡해졌습니다.

위에 서술했던 규칙을 바탕으로, 파일들을 가져오고 msw-storybook-addon에 맞는 형식으로 변환해주는 `loadHandlers` 함수를 만들고, Storybook 전역 설정에서 호출하도록 해서 처리했습니다.

```tsx
import { camelCase, snakeCase } from 'lodash';
import { graphql, RequestHandler } from 'msw';
// graphql-codegen을 사용해서 .graphql 파일을 api/index.ts 로 모아두고 있습니다.
import * as api from 'api';

export function loadHandlers(): Record<string, RequestHandler | RequestHandler[]> {
  const handlers: Record<string, RequestHandler | RequestHandler[]> = {};

  const fixtures_context = require.context('..', true, /^\.\/(?!node_modules)[^/]+\/.+\.fixtures\.tsx?$/i);
  fixtures_context.keys().forEach((filename) => {
    const imported = fixtures_context(filename);
    Object.entries(imported).forEach(([name, value]) => {
      const mock_name = snakeCase(name); // get_list
      const api_name = camelCase(name); // getList
      const query_name = api_name.charAt(0).toUpperCase() + api_name.slice(1); // GetList
      const api_entry = api[api_name];
      if (api_entry != null && typeof api_entry === 'function') {
        // GraphQL query인지, mutation인지 알 수 없기 때문에 두 개 모두 만듭니다.
        handlers[mock_name] = [
          graphql.query(query_name, (req, res, ctx) => res(ctx.data(value as any))),
          graphql.mutation(query_name, (req, res, ctx) => res(ctx.data(value as any))),
        ];
      }
    });
  });

  const mocks_context = require.context('..', true, /^\.\/(?!node_modules)[^/]+\/.+\.mocks\.tsx?$/i);
  mocks_context.keys().forEach((filename) => {
    const imported = mocks_context(filename);
    Object.entries(imported).forEach(([name, value]) => {
      if (name === 'default') return;
      const mock_name = snakeCase(name); // get_list
      if (value instanceof RequestHandler) {
        handlers[mock_name] = value as any;
      } else if (Array.isArray(value) && value.every((item) => item instanceof RequestHandler)) {
        handlers[mock_name] = value as any;
      }
    });
  });

  return handlers;
}
```

### API 덮어 쓰기

이렇게 해서 모든 스토리에서 동일한 API를 쓸 수 있게 되었지만, 각 스토리에서 필요하다면 API mock을 덮어 씌워서 사용할 수도 있어야 합니다.

msw-storybook-addon은 아래와 같은 방식으로 스토리에서 API를 오버라이드하도록 되어 있습니다.

```tsx
export const Story = () => <UserProfile />;

Story.parameters = {
  msw: {
    handlers: {
      // category 키로 지정된 API mock을 아래 내용으로 덮어 씁니다
      category: [
        graphql.query('GetUser', () => ...),
        graphql.query('GetUsers', () => ...),
      ],
    },
  },
};
```

handlers는 배열이나, 오브젝트가 될 수 있습니다. 오브젝트로 지정하면 전역 설정에서 지정된 handlers와 병합이 됩니다. 즉, 전역 설정에서도 `category` 가 존재했다면 스토리에서 지정한 `category` 배열로 덮어 씌워집니다.

이를 활용해서 API를 덮어쓰는 작업이 가능하다고 판단했습니다. MSW 애드온이 객체를 합치는 방법으로 병합을 한다는 점에 착안해서, 객체의 키 이름을 일관적으로 지정하면, 쓰는 쪽에서 덮어쓸 수 있다고 생각했습니다.

`GetShopContact` 라는 쿼리에 대한 API mock은 `GET_SHOP_CONTACT` 라는 이름을 가지고 있습니다. 전역 설정에서 snake_case로 바꿔서 handlers 객체에 넣어주는 방법으로 msw-storybook-addon에 전달해 준다면, 이 키를 사용해서 덮어 씌우는게 가능합니다.

`mocks.ts` 에서 정의된 목들은 export된 이름을 snake_case로 바꿔서 처리하도록 `loadHandlers` 을 구현했습니다.

```tsx
export const Story = () => <UserProfile />;

Story.parameters = {
  msw: {
    handlers: {
      get_shop_contact: graphql.query('GetShopContact', () => ...),
    },
  },
};
```

만약 전체 API mock을 비활성화하고 덮어 씌우고 싶다면, 아래와 같이 `handlers` 를 배열로 사용할 수 있습니다.

```tsx
Story.parameters = {
  msw: {
    handlers: [
      // ...
    ],
  },
};
```

## 마이그레이션

이렇게 해서, 새로운 구조에 대한 정의와, 프로젝트 세팅은 완료했지만 큰 숙제가 남아있습니다. 기존 코드를 어떻게 바꿀 것인지가 큰 문제였습니다.

기존에 작성된 API mock들이 1000개가 넘어가는데, 이 mock들을 어떤 GraphQL 쿼리에 대응하는지 확인하고, 일일이 모두 옮기는 작업을 진행해야 합니다.

하나를 옮기는데 1분이 걸린다고 가정해도 16시간이 넘게 걸리는 작업이었는데요, 이렇게 하나씩 옮겨도, 코드베이스 전반적으로 수정이 필요하기 때문에 git 충돌이 발생하기 쉬웠습니다.

자동화를 진행해도 시간이 비슷하게 걸릴 것 같고, 파트너센터 외의 프로젝트에서도 비슷한 요구사항이 있을 것이라고 예상했기 때문에 자동화를 진행해 보게 되었습니다.

### 스크립트 동작 원리

여기서부터는 변환 스크립트의 동작 원리에 대해서 간단하게 설명해보고자 합니다.

자동으로 코드를 변환해주는 스크립트들은, 코드를 AST로 바꿔서 가공하고, 다시 이걸 코드로 되돌려서 저장하는 식으로 동작합니다.

### AST

[AST (Abstract Syntax Tree)](https://ko.wikipedia.org/wiki/%EC%B6%94%EC%83%81_%EA%B5%AC%EB%AC%B8_%ED%8A%B8%EB%A6%AC)는 코드를 트리 형태로 분석해놓은 데이터 구조체들을 의미합니다. HTML에 빗대어서 설명을 해보자면, HTML와 같은 언어도 결국에는 문자열로 불러와지기 때문에, `<div className='abc'><strong>Hello</strong> world</div>` 와 같은 문자열을 웹 브라우저에서 해석하는 과정이 필요합니다. 이를 파싱이라고 부릅니다.

이 해석 과정이 완료되면, 자바스크립트에서 DOM을 사용해서 편집할 수도 있고, 브라우저 자체적으로도 DOM 정보를 기반으로 렌더링을 진행할 수도 있습니다.

DOM으로 할 수 있는 것들의 예시는 아래와 같은 것들이 있습니다.

- `querySelector('.abc').children[0].tagName` 와 같은 방법으로 노드를 선택해서 가져오기
- `appendChild` 등의 함수를 사용해서 내용 변형, 노드 추가/삭제
- `querySelector('.abc').innerHTML` 으로 다시 HTML으로 변환

이런 일련의 과정들은 **HTML** 문자열을 사용하는 것이 아닌, 웹 브라우저에 내재된 **DOM** 을 사용해서 원하는 노드를 가져오고 편집하는 것입니다.

또한, 트리도 따로 고민해야 하는 어려운 개념이 아니라, 단순히 웹 개발할 때 흔히 보는 div 안에 div가 여러개 들어가는, 즉 HTML과 완전히 동일한 구조라고 볼 수 있습니다.

이런 개념들을 생각해보면, React가 나오기 전에 jQuery와 같은 라이브러리를 사용해서 했던 웹 개발은, 직접 AST를 수정하는 것과 동일하다고 생각할 수 있습니다.

비슷하게, 소스코드를 분석하는 것도, 웹 개발과 동일하게 HTML 문자열을 DOM으로 바꾸는 것처럼, JS 문자열을 AST로 바꾸는 과정을 진행합니다.

이 과정을 거치면, `a = 1 + 2;` 라는 문자열을 아래와 같이 바꾸게 됩니다.

```yaml
type: AssignmentExpression # left = right
operator: '='
left:
  type: Identifier # "a"라는 변수 지칭
  name: 'a'
right:
  type: BinaryExpression # left + right
  operator: '+'
  left:
    type: NumericLiteral # 1이라는 숫자 지칭
    value: 1
  right:
    type: NumericLiteral # 2이라는 숫자 지칭
    value: 2
```

이렇게 변환된 AST를 기반으로, 위의 HTML 예제와 마찬가지로 입맛대로 수정하는 것도 가능합니다.

다만, DOM은 브라우저에서 자체적으로 API를 제공해주지만 AST는 그렇지 않으므로, 이런 작업을 해주는 라이브러리를 별도로 찾거나 만들어야 한다는 문제점이 있습니다.

babel, typescript나 webpack같은 유틸리티들은 모두 이 AST를 원하는 대로 가공하는 방식으로 컴파일을 진행하고, 브라우저의 JS 인터프리터도 AST를 기반으로 명령을 파악하고 실행하는 방식으로 동작합니다.

AST가 어떻게 생겼는지 궁금하시다면, https://astexplorer.net/ 에서 직접 소스코드를 넣어보면서 둘러보시면 큰 도움이 됩니다.

이렇게 AST를 가공하는 작업을 도와주는 라이브러리는 생각보다 꽤 많습니다. 자바스크립트에는 아래와 같은 라이브러리들이 있습니다.

- https://babeljs.io/docs/babel-parser.html
- https://github.com/benjamn/recast
- https://github.com/benjamn/ast-types
- https://github.com/facebook/jscodeshift

추가로, AST와 같은 구조체를 활용하면, 직접 프로그래밍 언어를 만들어보고, 인터프리터나 컴파일러도 직접 만들어볼 수 있습니다. 문자열을 AST로 바꿔주는 파서를 자동으로 만들어주는 라이브러리들도 많이 존재하기 때문에, 관심 있으시면 한 번 찾아보시는걸 추천드립니다.

### 스크립트 구성

기존에도 jscodeshift 유틸리티를 사용해서 리팩토링을 진행한 적이 여러 번 있었지만, 각 파일별로 특정 부분을 찾아서 규칙대로 수정(예를 들어 `import` 구문을 찾아서, 경로를 수정)하는 정도였기 때문에 비교적 간단했습니다.

하지만, 이번 요구사항은 생각보다 많이 복잡합니다. 궁극적으로 하고 싶은 것은, 스토리 파일에서 `msw` mock을 추출해서 GraphQL 파일과 나란히 배치하는 것이었지만, 과정이 그렇게 쉽지는 않았습니다.

먼저, jscodeshift는 파일 하나에 대해서 수정만 가능했기 때문에, jscodeshift 대신 [recast](https://github.com/benjamn/recast) 라이브러리를 사용해서 직접 파일을 열어가면서 수정하는 것으로 결정했습니다.

그 뒤, 요구사항을 생각해보면서 어떤 부분에서 고민이 필요한지부터 정리해봤습니다.

- 어떻게 스토리 파일에서 API mock을 추출할 것인지
- 어떻게 mock을 GraphQL 쿼리에 매핑시킬 것인지
- 어떻게 mock을 fixtures나 mocks 중 어디에 소속하는지 파악할 것인지
- 어떻게 GraphQL 쿼리의 스키마 파일이 어디에 위치하는지 알아낼 것인지
- 어떻게 스토리 파일에서 원래 있던 mock을 청소할 것인지
- 어떻게 스토리 파일에서 mock에서 쓰던 import나 변수들을 정리할 것인지
- 어떻게 fixtures, mocks 파일을 만들 것인지

이렇게 고민해볼 요소를 한 차례 정리해보고, 각 요소별로 해결 방법을 찾아보는 식으로 접근했습니다.

- 스토리 파일에서 API mock 추출 방법
  - 소스 코드에서 `**/*.stories.tsx` 파일은 무조건 스토리 파일이므로 이걸 찾아서 AST로 변환한 뒤에 특정 패턴을 찾아내면 됩니다.
  ```tsx
  export default {
    parameters: {
      msw: {
        handlers: {
          test: graphql.query('Test' /* ... */),
        },
      },
    },
  };
  ```
  - 위 예시를 토대로, ‘export default’ 를 찾아서, 그 오브젝트 안의 `parameters`, `msw`, `handlers` 를 순서대로 들어가면 API mock들이 존재한다는 것을 확인할 수 있습니다.
  - querySelector로는 `querySelector('export > .parameters > .msw > .handlers')` 같은 느낌으로 접근이 가능하겠지만, 아쉽게도 `recast` 라이브러리가 이런 기능을 제공해주지는 않고 있습니다.
  - 따라서 직접 노드를 순회하면서 패턴을 찾는 로직을 짜야 했습니다.
  - 일단 handlers 안쪽으로 들어가고 나면, `graphql.query` 와 같은 함수 호출을 찾으면 이게 API mock이라고 단정할 수 있다고 봤습니다.
- GraphQL 쿼리 매핑 방법
  - `graphql.query('Test', (req, res, ctx) => res(ctx.data({ ... })))` 와 같이 API mock이 작성된다는 것을 확인할 수 있습니다.
  - 즉, API mock 함수 호출의 첫번째 인자는 쿼리 이름이라고 볼 수 있습니다.
  - 다만, REST API mock도 존재하는데, 이건 쿼리 이름을 추출할 수 없으므로 임의로 ‘RestApi’라는 이름으로 대체하기로 했습니다.
- fixtures, mocks 여부 판단
  - 위에서 설명했던 규칙대로, 단순히 상수로 나열할 수 있는 픽스쳐 데이터는 `.fixtures.ts` 로 보내고, 다른 로직이 들어가는 데이터는 `.mocks.ts` 로 보내는 것으로 정리했습니다.
  - 일단, `(req, res, ctx) => res(ctx.data(데이터))` 와 같은 형태기만 하면 추출이 가능하므로, 해당 패턴과 일치하는지 먼저 확인하고,
  - 데이터 내부에서 `req`, `res` 등의 변수를 사용하지 않는지를 확인합니다.
    - 즉, 데이터 내부에서 ArrowFunctionExpression 의 인자를 사용하지 않는지를 확인하면 됩니다.
    - “req”, “res” 등의 변수 이름 (Identifier)가 사용되지 않는 경우 문제가 없다고 볼 수 있습니다.
  - 모든 조건을 만족한다면, mock API 함수 안쪽에 있는 데이터 노드만 꺼냅니다.
  - mock으로 보내야 한다면, 모든 데이터의 보존이 필요하므로 `graphql.query()`째로 노드를 꺼냅니다.
- GraphQL 쿼리와 스키마 위치 파악 방법
  - GraphQL 쿼리로 돌아와서, ‘GetList’ 와 같은 쿼리가 어떤 스키마에 대응하는지 어떻게 파악할 수 있을 지도 알아봐야 합니다.
  - `graphql` 패키지에서도 GraphQL 언어를 AST로 바꿔주는 `parse` 함수를 제공해주고 있습니다.
  - `*.graphql` 파일을 찾아서, AST로 바꾼 뒤, 파일에 존재하는 모든 쿼리의 이름을 추출합니다.
  - 해당 이름들이 해당 파일 경로에 대응한다고 기록만 해두면 됩니다.
    - Map<string, string>에 쿼리 이름 → 파일 경로 와 같은 형식으로 기록합니다.
- 스토리 파일에서 원래 있던 mock 청소하기
  - `graphql.query` 호출만 지우면 일단 mock은 제거되지만, 더이상 API mock이 없음에도 불구하고 `parameters.msw.handlers` 객체는 남아있게 됩니다.
  - 그래서, `graphql.query` 호출을 지운 뒤, 부모 노드를 찾아가면서, 부모 노드가 비어있으면 부모 노드를 삭제하도록 하면 이렇게 불필요한 parameters 객체도 자동으로 삭제할 수 있습니다.
- 스토리 파일의 mock에서 쓰던 import, 변수 청소하기
  - API mock에서 사용하던 변수나 임포트 구문들도 모두 mocks 파일로 옮겨올 수 있어야 합니다.
    - `import { graphql } from 'msw';` 와 같이, 사용하던 모든 임포트들을 다 옮겨와야 합니다.
  - 관련해서는 설명하기 너무 복잡해서 간단하게 설명하자면,
  - `ast-types` 패키지의 scope 기능을 활용하면, 해당 AST 노드가 어떤 변수들을 볼 수 있는지, 또 해당 변수가 어느 지점에서 생성됐는지 파악할 수 있습니다.
    - 말 그대로 변수의 스코프를 분석해주는 도구라고 볼 수 있습니다.
  - 이를 통해서 API mock에서 참조하는 변수들의 임포트 구문들을 추출하고 나서,
  - API mock을 지웠을 때, 남은 스토리 코드에서 더 이상 참조하지 않는다면 삭제하도록 했습니다.
- fixtures, mocks 파일 만들기
  - 이 모든 과정을 마치면, API mock 파일을 생성할 준비가 끝납니다.
  - 어떤 정보를 모았는지 정리해보면 아래와 같습니다.
    - GraphQL 쿼리별로 모인 API mock들의 소스코드와, mock이 필요로 하는 임포트 목록
    - GraphQL 쿼리가 어떤 `.graphql` 파일에 속하는지에 대한 매핑 정보
  - 이 정보를 토대로, 각 `.graphql` 파일별로 어떤 API mock이 존재하는지 정리합니다.
  - 존재한다면, fixtures / mocks 여부를 확인하고, `.fixtures.ts`와 `.mocks.ts` 을 생성합니다.
    - mock API 선언 규칙대로 변수 이름을 바꿔서, `export const GET_LIST = ...` 형태로 API mock 구문을 생성합니다.
    - mock API들이 필요로 하는 import를 전부 취합해서, 중복되는 항목들을 제거한 뒤 import 구문을 생성합니다.
    - 이렇게 생성된 구문들을 문자열로 바꿔서 저장합니다.

생각보다 고민해볼 요소가 너무 많았지만, 위 내용들을 정리했을 때, 아래와 같은 프로세스로 구성될 것이라고 정리해볼 수 있습니다.

- GraphQL 매핑 생성
- 스토리 파일 분석
  - API mock 추출 및 제거
  - 임포트 정리
- mock, fixtures 파일 생성
  - 대응되는 API mock 확인 및 붙여넣기
  - 임포트 생성

위 프로세스대로 함수들을 만들어가면서 완성을 했고, 어느정도 후처리는 필요하긴 했지만 성공적으로 자동화를 마칠 수 있었습니다.

- 코딩 스타일이 깨지는 경우가 있어서, prettier를 별도로 돌려주어야 합니다.
- 기존에도 소스코드에서 `fixtures.ts` 라는 이름으로 임포트해서 스토리북에서 사용하는 용례가 있었습니다.
  - 문제는 변수 이름이 겹치면서, `export const GET_LIST = GET_LIST;` 와 같은 엉뚱한 구문을 생성하게 됩니다.
  - 별도의 대응이 가능하긴 하지만, 이런 경우가 별로 많지 않아서 수작업으로 `export { GET_LIST } from 'components/abcd/fixtures.ts'` 와 같이 변경해주었습니다.
- 여러 파일에서 비슷한 fixture를 사용하는 경우도 많아서, 수작업으로 중복되는 항목을 제거해야 합니다.

프로젝트마다 구성이 크게 다르기 때문에 직접 사용하시기에는 어려울 수 있겠지만, 참고가 되었으면 해서 완성된 마이그레이션 스크립트도 공유해봅니다.

https://gist.github.com/yoo2001818/4d12015c6d5ee9006723f66ecde09f1f

## 마치며

이렇게 해서 구조 설계, 설정 변경 및 마이그레이션 작업까지 모두 마칠 수 있었습니다.

실제로 반영해본 결과, 사용하는 API들에 신경쓰지 않아도 스토리를 작성할 수 있게 되어서, 스토리 작성 난이도가 크게 낮아지고, 스토리북 오류 발생을 최소화할 수 있었습니다.

스토리북 구조 관련해서 고민하고 계신 분들께 도움이 되었으면 합니다. 감사합니다.
