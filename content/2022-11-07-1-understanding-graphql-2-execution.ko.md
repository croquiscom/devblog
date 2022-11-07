---
title: "GraphQL 이해하기: (2) 실행 및 전송"
tags: ['GraphQL']
date: 2022-11-07T00:00:00
author: Simon(윤상민)
original: https://sixmen.com/ko/tech/2022-11-07-1-understanding-graphql-2-execution/
---

[이전 글](/ko/2022-10-04-1-understanding-graphql-1-schema/)에서 GraphQL 스키마를 정의했습니다. 이제 이 스키마에 질의를 하고 그 결과를 받을 수 있습니다.

<!--more-->

## 실행

### GraphQL.js

graphql 메소드를 써서 질의를 할 수 있습니다.

```tsx
import { graphql, GraphQLList, GraphQLNonNull, GraphQLObjectType, GraphQLSchema, GraphQLString } from 'graphql';

const User = new GraphQLObjectType({
  name: 'User',
  fields: {
    name: {
      type: new GraphQLNonNull(GraphQLString),
    },
  },
});

const schema = new GraphQLSchema({
  query: new GraphQLObjectType({
    name: 'Query',
    fields: {
      users: {
        type: new GraphQLNonNull(new GraphQLList(new GraphQLNonNull(User))),
        resolve: () => [{ name: 'Johnny' }],
      },
    },
  }),
});

(async () => {
  const result = await graphql({ schema, source: 'query { users { name } }' });
  console.log(JSON.stringify(result, null, 2));
})();
```

실행시 다음과 같은 결과를 얻을 수 있습니다.

```json
{
  "data": {
    "users": [
      {
        "name": "Johnny"
      }
    ]
  }
}
```

### GraphQL Java

GraphQL 클래스의 execute 메소드를 써서 질의를 할 수 있습니다.

```kotlin
data class User(val name: String)

val userType = GraphQLObjectType.newObject().name("User").field(
    GraphQLFieldDefinition.newFieldDefinition().name("name").type(GraphQLNonNull(GraphQLString))
).build()

val usersFetcher = DataFetcher {
    listOf(User("Johnny"))
}

val codeRegistry =
    GraphQLCodeRegistry.newCodeRegistry().dataFetcher(FieldCoordinates.coordinates("Query", "users"), usersFetcher)
        .build()

val schema = GraphQLSchema.newSchema().query(
    GraphQLObjectType.newObject().name("Query").field(
        GraphQLFieldDefinition.newFieldDefinition().name("users")
            .type(GraphQLNonNull(GraphQLList(GraphQLNonNull(userType))))
    )
).codeRegistry(codeRegistry).build()

val graphql = GraphQL.newGraphQL(schema).build()
println(graphql.execute("query { users { name } }").toString())
```

다음은 그 결과입니다

```
ExecutionResultImpl{errors=[], data={users=[{name=Johnny}]}, dataPresent=true, extensions=null}
```

## 전송

GraphQL.js는 한 프로세스 안에서 질의만 처리하고, 서버-클라이언트 구조에 대해서 해주는 것은 아무 것도 없습니다. API를 클라이언트에 전송하려면 별도의 라이브러리가 필요합니다. [express-graphql](https://github.com/graphql/express-graphql) 이나 [Apollo Server](https://www.apollographql.com/docs/apollo-server/)를 통해 보통 사용되는 HTTP 프로토콜을 통한 GraphQL API 서빙이 가능합니다.

비슷하게 GraphQL Java도 질의 처리만 담당합니다. HTTP를 통해 서빙하려면 [Spring for GraphQL](https://spring.io/projects/spring-graphql) 같은 모듈이 필요합니다. ([Tutorial with Spring Boot | GraphQL Java](https://www.graphql-java.com/tutorials/getting-started-with-spring-boot/) 참고)

```tsx
import express from 'express';
import { graphqlHTTP } from 'express-graphql';

const app = express();
app.use('/graphql', graphqlHTTP({ schema }));
app.listen(4567);
```

내부 코드를 보면 그다지 복잡하지 않습니다. HTTP 프로토콜에 맞춰 URL이나 body에서 query, variables등을 얻어, GraphQL.js 라이브러리로 질의하고(graphql 메소드 대신, parse, validate, execute로 나눠진 메소드를 사용하긴 합니다), HTTP 프로토콜에 맞춰 결과를 반환합니다.

HTTP 전송은 GraphQL 스펙에 의해 커버되지 않습니다. ([GraphQL over HTTP](https://github.com/graphql/graphql-over-http) 저장소에서 논의가 진행되고는 있습니다) 그래도 express-graphql 이라는 표준 구현과 [Serving over HTTP](https://graphql.org/learn/serving-over-http/) 문서에 의해 큰 틀은 정의가 되어 있습니다.

## HTTP 프로토콜 서빙시 이슈

### 상태 코드

HTTP 프로토콜에는 상태 코드가 있습니다. 하지만 GraphQL 특성상 그 실행 결과를 HTTP 상태 코드에 매칭하는 것은 큰 의미가 없습니다. 예를 들어 두 개의 리소스를 요청했는데 하나만 없는 경우 404 Not Found일까요, 아닐까요? 두 개의 Mutation을 실행하는데 하나는 리소스 생성, 하나는 수정일 수도 있는데 201 Create를 반환해야 할까요?

그래서 GraphQL은 보통 최소한의 상태 코드만 사용합니다.

- 200: 요청 성공
- 400: 요청에 문제가 있음 (문법 오류, 유호성 오류등)
- 500: 서버에 문제가 있음

여기까지는 비교적 명확하지만 어플리케이션 로직 수행 중 에러가 난 경우(즉 errors 객체가 있는 경우)가 애매합니다. 또 GraphQL은 부분 성공이라는 개념도 있습니다. (일부만 성공해서 data에 값이 있지만, errors도 있는 경우)

express-graphql은 data가 없는 경우 500을 반환하게 되어 있습니다. 반면에 [Apollo Server는 순 에러인 경우에도 200을 반환](https://www.apollographql.com/docs/apollo-server/data/errors/#setting-http-status-code-and-headers)합니다.

200 성공이 아닌 경우, GraphQL 응답이 아닐 수도 있습니다. (예를 들어 중간에 거치는 로드 밸러서에서 타임아웃 발생시 JSON이 아니였습니다) 400, 500 시 GraphQL errors 객체로 간주하고 처리하려고 했더니, JSON이 아니여서 의미 없는 에러(SyntaxError)를 보게 되는 경우를 겪었습니다.

그래서 400, 500 에러는 취급하지 못하는 에러(클라이언트를 잘못 작성했거나, 서버 접근이 안 되는 등 사용자가 처리할 수 없는 에러)인 경우로 정의했습니다. (많은 HTTP 클라이언트가 400, 500 에러시 예외를 던집니다) 반면 어플리케이션 오류(사용자 행동에 문제가 있고, 사용자가 알아야 하는 - 예를 들어 비밀번호가 틀림 -)는 일단 호출 자체는 성공으로 간주할 수 있도록 200을 반환하는 것을 규칙으로 정했습니다. 어플리케이션 오류는 그 이후에 errors 필드 존재 여부로 판단합니다.

다만 이렇게 처리한 경우 호출 자체는 성공이기 때문에 대부분의 모니터링 툴에서 에러로 잡히지 않습니다. 그래서 저희는 모니터링 툴에 던지는 데이터를 커스터마이즈 해서 이 문제를 피했습니다. (Node.js의 경우고 Java에서는 해결하지 못했습니다.) 상태 코드는 200인데 에러로 나오는 것이라서 좀 어색합니다. (이 이슈로 차후에는 규칙을 바꿀 가능성도 있습니다.)

### 엔드포인트

GraphQL은 엔드포인트를 하나로 정의하고 있습니다. 기능상에 문제는 없지만 모니터링에 문제가 있습니다. 기능별로 latency나 에러율 판단이 불가능합니다.

Node.js에서 모니터링 툴을 커스터마이즈 해서 회피해보긴 했지만, 그게 불가능한 경우도 있어 완전한 해결책은 아닙니다. 또한 건드릴 수 없는 부분(예 AWS 로드 밸런서)에서의 로그 확인/모니터링이 불가능합니다.

그래서 카카오스타일에서는 클라이언트가 엔드포인트를 다르게 호출하는 것을 컨벤션으로 잡았습니다. `/graphql/<operation name>` 형태로 호출하면 되고, 주요 GraphQL 서버 프레임워크는 뒤에 문자열을 무시하고 동일하게 처리할 수 있습니다.

여기에 더해 마이크로서비스 간의 호출에서 operation name이 겹치는 경우도 있습니다. (예 GetProductList) 이 경우 어느 마이크로서비스에서 호출한 건지 알 수 없습니다. 그래서 마이크로서비스 간의 호출에서는 서비스명을 추가하도록 컨벤션을 정했습니다. `/graphql/<service name>__<operation name>`

더 복잡한 케이스도 있습니다. 저희는 API gateway 패턴을 사용하고 있는데, API gateway에서 여러 서비스를 호출할 수 있습니다. 예를 들어 클라이언트가 다음과 같이 요청했을 때

```graphql
query GetUserOrderList {
  user {
    name
    order_list {
      order_number
    }
  }
}
```

user와 order라는 서비스에 각각 요청을 하게 됩니다.

```graphql
{
  user {
    id
    name
  }
}
```

```graphql
{
  order_list(user_id: "1234") {
    order_number
  }
}
```

이때 각 마이크로서비스에서 어떤 식으로 요청이 온 건지 구분하기 위해서 각각 `api__GetUserOrderList__user`, `api__GetUserOrderList__order_list` 라는 경로와 operation name을 갖도록 컨벤션을 정해서 운영하고 있습니다.
