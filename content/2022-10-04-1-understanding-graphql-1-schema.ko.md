---
title: "GraphQL 이해하기: (1) 스키마 정의"
tags: ['GraphQL']
date: 2022-10-04T00:00:00
author: Simon(윤상민)
summary:
  GraphQL은 query 방식만 정의한 단순한 스펙입니다. 하지만 개념이 간단하다고 그것을 동작하도록 구현하는 것까지 간단한 것은 아닙니다.
  GraphQL을 실제 제품에 적용하기까지는 많은 것들을 이해해야 합니다. 이에 대해 차례로 설명해보려고 합니다. 첫번째로 다뤄볼 내용은 스키마 정의입니다.
original: https://sixmen.com/ko/tech/2022-10-04-1-understanding-graphql-1-schema/
---

[GraphQL](https://graphql.org/)이란 것은 대부분 들어보셨을 것으로 생각합니다. 그리고 페이스북이 만들었다는 것 정도는 아실 것 같습니다. 근데 여기서 말하는 GraphQL이란 뭘까요?

GraphQL 자체는 데이터 query를 어떻게 할지만 정해놓았습니다.

즉

```graphql
type User {
  id: ID!
  name: String!
}

type Query {
  user(id: ID!): User!
}
```

와 같이 정의된 스키마에

```graphql
query {
  user(id: "10") {
    id
    name
  }
}
```

와 같이 질의하면

```graphql
{
  "data": {
    "user": {
      "id": "10",
      "name": "Simon"
    }
  }
}
```

라는 결과만 내놓으면 됩니다.

하지만 개념이 간단하다고 그것을 동작하도록 구현하는 것까지 간단한 것은 아닙니다. GraphQL을 실제 제품에 적용하기까지는 많은 것들을 이해해야 합니다. 이에 대해 차례로 설명해보려고 합니다. 첫번째로 다뤄볼 내용은 스키마 정의입니다.

> 언어나 구현체 별로 세부 내용이 다를 수도 있습니다. 따라서 앞으로 설명할 내용은 주로 참조 구현인 [GraphQL.js](https://github.com/graphql/graphql-js)에 대한 내용이 됩니다. 여기에 더해서 대중적으로 많이 쓰이는 Java 계열의 라이브러리([graphql-java](https://www.graphql-java.com/), [DGS Framework](https://netflix.github.io/dgs/)등)를 일부 포함합니다. 다른 언어에서 사용하는 다른 라이브러리는 다른 생김새를 가지고 있을 수 있겠지만, 개념이 크게 다르지 않을 것으로 생각합니다.
> 

## 날(raw) 객체를 사용해서 정의하기

GraphQL 스키마는 GraphQLSchema 클래스의 인스턴스입니다. 이런 클래스들을 이용해 직접 정의할 수 있습니다. [GraphQL.js의 코드](https://github.com/graphql/graphql-js#using-graphqljs)를 가져와 보겠습니다.

```tsx
import { GraphQLObjectType, GraphQLSchema, GraphQLString, printSchema } from 'graphql';

const schema = new GraphQLSchema({
  query: new GraphQLObjectType({
    name: 'RootQueryType',
    fields: {
      hello: {
        type: GraphQLString,
      },
    },
  }),
});

console.log(printSchema(schema));
```

위 코드를 실행하면 다음과 같은 스키마가 만들어지는 것을 볼 수 있습니다.

```graphql
schema {
  query: RootQueryType
}

type RootQueryType {
  hello: String
}
```

RootQueryType를 Query로 바꾸면 좀 더 익숙한 스키마가 만들어집니다.

```graphql
type Query {
  hello: String
}
```

커스텀 타입도 추가할 수 있습니다.

```tsx
import { GraphQLList, GraphQLNonNull, GraphQLObjectType, GraphQLSchema, GraphQLString, printSchema } from 'graphql';

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
      },
    },
  }),
});

console.log(printSchema(schema));
```

위 코드는 다음과 같은 스키마를 정의한 것입니다.

```graphql
type Query {
  users: [User!]!
}

type User {
  name: String!
}
```

JVM 계열에서 기반이 되는 [graphql-java](https://www.graphql-java.com/)는 이 형태의 스키마 생성을 지원합니다. 

```kotlin
val userType = GraphQLObjectType.newObject()
    .name("User")
    .field(
        GraphQLFieldDefinition.newFieldDefinition()
            .name("name")
            .type(GraphQLNonNull(GraphQLString))
    )
    .build()

val schema = GraphQLSchema.newSchema()
    .query(
        GraphQLObjectType.newObject()
            .name("Query")
            .field(
                GraphQLFieldDefinition.newFieldDefinition()
                    .name("users")
                    .type(GraphQLNonNull(GraphQLList(GraphQLNonNull(userType))))
            )
    ).build()

println(SchemaPrinter().print(schema))
```

이 방식은 간단한 스키마를 정의하는데도 많은 노력이 들고 틀릴 가능성도 높습니다. (다만 리졸버를 정의시 같이 포함할 수 있다는 장점은 있습니다.) 그래서 GraphQL 도입 초기에 예제만 보고 무조건 이렇게 해야 하는 것으로 알고 있을 때 잠깐만 사용했고, 현재는 이렇게 정의하지 않습니다. 다만 내부에서는 이 형태이기 때문에 이해하고 있으면 GraphQL 실행 최적화를 할 때 도움이 됩니다.

## 스키마 정의 문자열에서 스키마 생성하기

날 객체를 쓰는 것보다 좀 더 나은 방법은 스키마 정의 문자열에서 스키마를 생성하는 것입니다. buildSchema 함수를 사용하면 됩니다.

```tsx
import { buildSchema } from 'graphql';

const schema = buildSchema(`
type User {
  name: String!
}

type Query {
  users: [User!]!
}
`);
```

이 방식은 스키마 우선(schema-first) 접근으로 불립니다. graphql-java도 이 방식을 지원하고, DGS도 이 방식을 사용합니다. 이렇게 생성한 스키마에 리졸버는 따로 붙여줘야 합니다.

다른 방식으로 [graphql-tag](https://github.com/apollographql/graphql-tag) 모듈의 gql 태그를 쓰는 방법이 있습니다. 다만 이 태그는 parse 함수를 써서 GraphQLSchema 객체가 아닌 DocumentNode 객체를 만들어 내기 때문에, [makeExecutableSchema](https://www.graphql-tools.com/docs/generate-schema)를 사용해 스키마 객체로 변환할 필요가 있습니다. 이 방식은 IDE에서 문법 강조가 되는 장점이 있었지만, 최근에는 gql 태그가 아니더라도 문법 강조가 되는 것으로 알고 있습니다. 그리고 저희는 현재 GraphQL 질의를 `.graphql` 파일로 만들어 문법 강조를 받고 있기 때문에 이 방식은 사용하지 않습니다. (오래전에 시도해서 아직 일부 코드에 흔적이 남아있습니다.)

## 코드에서 스키마 생성하기

또 다른 방법으로는 코드에서 스키마를 유도해 내는 것입니다. 이 방법은 기본 라이브러리에서 지원하지 않고 [TypeGraphQL](https://typegraphql.com/)이라는 다른 라이브러리를 사용합니다.

```tsx
import 'reflect-metadata';
import { buildSchemaSync, ObjectType, Field, Resolver, Query } from 'type-graphql';

@ObjectType()
class User {
  @Field(() => String)
  name: string;
}

@Resolver()
class UserResolver {
  @Query(() => [User])
  users(): User[] {
    return [];
  }
}

const schema = buildSchemaSync({
  resolvers: [UserResolver],
});
```

이 방식은 코드 우선(code-first) 접근으로 불립니다. [GraphQL Kotlin](https://opensource.expediagroup.com/graphql-kotlin/docs/)도 이 방식을 사용합니다.

리졸버 구현시 결국 코드로 된 모델(클래스)이 필요한데, 이 모델을 스키마 정의에 바로 사용할 수 있다는 장점이 있습니다. 그리고 같은 모델을 데이터베이스 테이블 정의에도 사용할 수 있다는 것([TypeORM](https://typeorm.io/)이나 [CORMO](https://croquiscom.github.io/cormo/)를 사용해서)이 좋아보여서 한때 전체에 적용했었습니다.

하지만 막상 시간이 지나니 거슬리는 점들이 꽤 나왔습니다.

- GraphQL 모델(타입)과 데이터베이스 테이블이 미묘하게 달라서 한 클래스로 양쪽을 모두 지원하는게 어색한 경우가 많았습니다.
- 타 서비스에서 GraphQL API를 이용할 때, 서비스가 제공하는 GraphQL API(스키마)를 한눈에 보고 싶을 때가 있는데 코드와 스키마가 섞여서 전체를 한눈에 보기 어렵습니다.
- 원하는 스키마를 정의하기 위해 TypeGraphQL의 방식을 따로 배워야 합니다. 예를 들어 TypeScript 타입은 `User[]`로 쓰는데 타입 정의는 `[User]`로 해야 합니다. `[User]`, `[User!]`, `[User]!`, `[User!]!` 구분은 `nullable` 옵션으로 하는데 직관성이 아무래도 떨어진다고 보입니다.
- TypeGraphQL로 안 되는 부분이 있었습니다. 당시에 enum의 주석을 추가하는게 불가능했고, 현재는 가능해졌지만 TypeScript의 한계로 자연스럽지 않습니다. (decorator를 사용하지 못하고, `registerEnumType`의 옵션으로 기술해야 합니다.)

그래서 현재는 스키마 우선 접근을 사용하는 것으로 바뀌었습니다. 스키마 타입과 코드 클래스를 각기 정의해야 하는 단점도 [GraphQL Code Generator](https://www.graphql-code-generator.com/) 같은 코드 생성기를 사용하면 어느 정도 해소가 됩니다.
