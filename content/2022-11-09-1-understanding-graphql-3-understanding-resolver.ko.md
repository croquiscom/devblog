---
title: "GraphQL 이해하기: (3) 리졸버의 이해"
tags: ['GraphQL']
date: 2022-11-09T00:00:00
author: Simon(윤상민)
original: https://sixmen.com/ko/tech/2022-11-09-1-understanding-graphql-3-understanding-resolver/
---

GraphQL 스키마를 정의했고, 클라이언트에서 온 요청을 서버가 처리하기 위해 필요한 기술을 알아봤습니다. 이제 클라이언트에서 온 요청에 따라 적절한 데이터를 반환하는 과정이 남았습니다. 이는 리졸버(resolver)라는 것이 담당합니다. Java쪽에서는 데이터 페처(data fetcher)라고도 부릅니다. 리졸버를 완전히 이해하면 GraphQL을 전부를 알았다고 할만큼 GraphQL의 핵심이라고 볼 수 있습니다.

<!--more-->

## 리졸버 구현하기

리졸버는 필드 요청이 들어온 경우 그 값을 제공하는 역할을 합니다. Query 타입에 users 라는 필드를 정의한 경우 `query { users }` 라는 질의로 값을 요청할 수 있고, 그 경우 users 필드 정의의 resolve 함수가 호출됩니다. 다음은 이전 글에서 리졸버 부분을 가져왔습니다.

```tsx
users: {
  type: new GraphQLNonNull(new GraphQLList(new GraphQLNonNull(User))),
  resolve: () => [{ name: 'Johnny' }],
},
```

위 예제에서는 리졸버를 스키마 정의와 함께 구현했습니다. 개인적인 경험에서는 리졸버를 분리하는 것이 코드 유지보수에 나았습니다. GraphQL Java의 GraphQLCodeRegistry도 스키마와 리졸버를 분리해주는 도구입니다. 반면 코드 우선 접근에서는 리졸버과 스키마 정의와 붙어있게 됩니다.

Node.js에는 GraphQL 사용을 도와주는 [GraphQL Tools](https://www.the-guild.dev/graphql/tools) 라이브러리가 있습니다. GraphQL Tools의 [addResolversToSchema](https://www.the-guild.dev/graphql/tools/docs/resolvers#addresolverstoschema-schema-resolvers-resolvervalidationoptions-inheritresolversfrominterfaces-)를 사용하면 만들어진 스키마에 따로 정의한 리졸버를 연결할 수 있습니다. ([makeExecutableSchema](https://www.the-guild.dev/graphql/tools/docs/generate-schema#makeexecutableschema)를 사용하면 buildSchema와 addResolversToSchema를 한번에 해줍니다.)

```tsx
import { buildSchema } from 'graphql';
import { addResolversToSchema } from '@graphql-tools/schema';

const pure_schema = buildSchema(`
type User {
  name: String!
}

type Query {
  users: [User!]!
}
`);

const resolvers = {
  Query: {
    users: () => [{ name: 'Johnny' }],
  },
};

const schema = addResolversToSchema({ schema: pure_schema, resolvers });
```

위와 같은 형태로 Query 타입과 Mutation 타입의 모든 필드에 대해 리졸버를 구현해 연결해주면 기본적인 데이터 제공이 끝납니다.

비동기로 데이터를 가져와 반환해야 하는 경우에는 Promise 객체를 반환하면 graphql 라이브러리가 프로미스의 이행(fulfill)을 기다려 데이터를 반환합니다.

```tsx
import fs from 'fs/promises';

const resolvers = {
  Query: {
    users: async () => JSON.parse(await fs.readFile('users.json', 'utf-8')),
  },
};
```

## 리졸버 vs 컨트롤러

Spring이나 Rails 같은 프레임워크에서는 REST API를 컨트롤러 클래스에서 구현합니다. 주어진 API에 대해 값을 반환한다는 측면에서 컨트롤러와 리졸버는 비슷한 일을 합니다. GraphQL을 얕은 수준에서 사용하면 REST API와 비슷하게 사용할 수도 있습니다. 이 관점에서 GraphQL과 REST API의 차이는 다음 정도입니다.

- GET은 Query, POST, PUT, DELETE는 Mutation에 대응합니다.
- 동사가 분리되어 있지 않다보니 GraphQL은 보통 API 이름을 함수명처럼 짓게 됩니다. 반면 REST API는 명사 부분을 신경써서 이름을 짓게 됩니다.
- REST API는 명사 부분에 따라 API를 그룹화 할 수 있고, 이에 따라 컨트롤러도 분리할 수 있습니다. 반면 GraphQL은 경로, 네임스페이스 개념이 없다보니 API가 같은 그룹이란게 잘 드러나지 않고, 리졸버도 알아서 나눠야 합니다.
- GraphQL은 타입 체크가 내장되어 있고, 데이터 반환 형태도 표준화되어 일정합니다. 반면 HTTP 상태 코드를 사용하지 않기 때문에 리소스 없음과 권한 없음과 같은 구분은 표준화되어 있지 않습니다.
- GraphQL은 한 요청에 여러 API(즉 여러 Query 필드)를 호출할 수 있습니다.

컨트롤러는 최상위 레벨(Query, Mutation)의 요청에 대해서만 인식하고 처리하는데 반해, 리졸버는 그 하위 필드에 대해서도 정의할 수 있다는 점에서 GraphQL과 REST API의 차이가 생깁니다. 반대로 그 필요성이 없다면 굳이 GraphQL을 사용할 필요가 없다는 뜻이 됩니다.

다음 스키마를 보겠습니다.

```graphql
type User {
  id: ID!
  name: String!
  mobile_tel: String!
}

type Post {
  id: ID!
  title: String!
  author_id: ID!
  author: User!
}

type Query {
  getPosts: [Post!]!
  getUser(id: ID!): User!
}
```

Post와 User는 별도의 리소스이기 때문에 순수 REST API라면 getPosts에서 author_id만 반환하고, author는 별도로 getUser를 호출해 가져가는 것이 자연스럽습니다. 다만 실제에서는 효율을 위해 getPosts에서 author도 같이 반환하게 구현할 겁니다. 하지만 글 목록에서 전화번호는 필요하지 않을테니 아마 name만 반환하는 형태로 할 것 같습니다. 즉 Post.author의 User 타입과 Query.getUser의 User 타입은 사실상 관계없는 타입일 가능성이 높습니다.

반면에 GraphQL에서는 자연스럽게 두 타입이 이어집니다. 또 REST API에서는 모든 클라이언트에게 author를 제공하던지, 제공하지 않는 선택지만 있다면, GraphQL은 필요한 클라이언트만 author를 요청하고, 요청받을 때만 저장소(DB)에 접근하는 것이 가능합니다.

다음은 위 스키마를 가볍게 구현해본 예입니다. 모든 타입의 모든 필드에 리졸버를 붙일 수 있습니다. Query, Mutation도 똑같이 타입이라고 간주하면 됩니다.

```tsx
import { makeExecutableSchema } from '@graphql-tools/schema';
import { graphql } from 'graphql';

const type_defs = `
type User {
  id: ID!
  name: String!
  mobile_tel: String!
}

type Post {
  id: ID!
  title: String!
  author_id: ID!
  author: User!
}

type Query {
  getPosts: [Post!]!
  getUser(id: ID!): User!
}`;

const posts = [
  { id: '1', title: 'Post 1', author_id: '51' },
  { id: '2', title: 'Post 2', author_id: '52' },
  { id: '3', title: 'Post 3', author_id: '51' },
];

const authors = {
  51: { id: '51', name: 'John', mobile_tel: '01012345678' },
  52: { id: '52', name: 'Alex', mobile_tel: '01087654321' },
};

const resolvers = {
  Query: {
    getPosts: () => posts,
    getUser: (_source: any, args: any) => authors[args.id],
  },
  Post: {
    author: (source: any) => authors[source.author_id],
  },
};

const schema = makeExecutableSchema({ typeDefs: type_defs, resolvers });

(async () => {
  const result = await graphql({
    schema,
    source: 'query { getPosts { id title author { id name } } getUser(id: "51") { id name mobile_tel } }',
  });
  console.log(JSON.stringify(result, null, 2));
})();
```

다음은 실행 결과입니다.

```json
{
  "data": {
    "getPosts": [
      {
        "id": "1",
        "title": "Post 1",
        "author": { "id": "51", "name": "John" }
      },
      {
        "id": "2",
        "title": "Post 2",
        "author": { "id": "52", "name": "Alex" }
      },
      {
        "id": "3",
        "title": "Post 3",
        "author": { "id": "51", "name": "John" }
      }
    ],
    "getUser": { "id": "51", "name": "John", "mobile_tel": "01012345678" }
  }
}
```

## 리졸버 호출 순서와 기본 동작

리졸버는 모든 필드에 대해서 호출됩니다. 그리고 상위 필드 부터 하위 필드 순으로 호출됩니다. (당연히 상위 필드가 값을 반환해야만 어떤 하위 필드가 있는지 알 수 있겠죠) 같은 레벨에서는 순서를 보장하지 않습니다. (다만 사이드 이펙트가 있는 Mutation 만은 순서대로 실행합니다.)

이와 같은 기준으로 위 쿼리를 보면 다음과 같은 필드에 대해 리졸버가 호출됐을 겁니다.

1. Query.getPosts, Query.getUser
2. getPosts[0].id, getPosts[0].title, getPosts[0].author, getPosts[1].id, getPosts[1].title, getPosts[1].author, getPosts[2].id, getPosts[2].title, getPosts[2].author, getUser.id, getUser.name, getUser.mobile_tel
3. getPosts[0].author.id, getPosts[0].author.name, getPosts[1].author.id, getPosts[1].author.name, getPosts[2].author.id, getPosts[2].author.name

하지만 우리가 정의한 리졸버는 이 중 5개만 대응됩니다. 나머지는 [초기 리졸버](https://the-guild.dev/graphql/tools/docs/resolvers#default-resolver)가 호출됩니다. 초기 리졸버는 상위 필드에서 반환한 객체에서 해당 이름의 필드를 반환하도록 되어 있습니다.

다음은 GraphQL.js 초기 리졸버 코드입니다.

```tsx
export const defaultFieldResolver: GraphQLFieldResolver<unknown, unknown> =
  function (source: any, args, contextValue, info) {
    // ensure source is a value for which property access is acceptable.
    if (isObjectLike(source) || typeof source === 'function') {
      const property = source[info.fieldName];
      if (typeof property === 'function') {
        return source[info.fieldName](args, contextValue, info);
      }
      return property;
    }
  };
```

다음은 GraphQL Java의 초기 리졸버 코드입니다.

```java
public class GraphQLCodeRegistry {
    public static class Builder {
        private DataFetcherFactory<?> defaultDataFetcherFactory = env -> PropertyDataFetcher.fetching(env.getFieldDefinition().getName());
    }
}

public class PropertyDataFetcher<T> implements DataFetcher<T>, TrivialDataFetcher<T> {
    public T get(DataFetchingEnvironment environment) {
        Object source = environment.getSource();
        if (source == null) {
            return null;
        }

        if (function != null) {
            return (T) function.apply(source);
        }

        return (T) PropertyDataFetcherHelper.getPropertyValue(propertyName, source, environment.getFieldType(), environment);
    }
}
```

이 동작을 이해하면 결과를 원하는 대로 조작할 수 있습니다. 예를 들어 사용자 이름을 소문자로 변경하려면 다음 리졸버를 추가하면 됩니다.

```tsx
const resolvers = {
  User: {
    name: (source: any) => source.name.toLowerCase(),
  },
};
```

User 타입에 적용되기 때문에 getPosts와 getUser 결과 모두에 적용됩니다.

한편 데이터는 어떤 리졸버가 반환해도 괜찮습니다. 즉 Post.author 리졸버를 구현하는 대신 getPosts를 다음과 같이 구현해도 동일한 결과를 얻을 수 있습니다. 대신 `getPost(id: ID!)` 와 같이 Post 타입을 반환하는 다른 API가 있다면 그쪽에도 동일하게 구현해줘야 합니다.

```tsx
const resolvers = {
  Query: {
    getPosts: () => posts.map((post) => ({ ...post, author: authors[post.author_id] })),
  },
};
```

만약 getPosts가 author를 이미 반환하고 있는데, Post.author 리졸버를 구현했다면 어떻게 될까요? 위 원리를 이해했다면 아시겠지만, 호출 됩니다. author를 구하는데 DB 접근을 하고 있다면 중복 요청을 하는 셈이 되겠죠. 만약 getPosts도 author를 반환하는게 효율적이고, 다른 API를 위해 Post.author도 구현해야 했다면 다음과 같이 중복 동작을 막을 수 있습니다.

```tsx
const resolvers = {
  Post: {
    author: (source: any) => (source.author ? source.author : authors[source.author_id]),
  },
};
```

## 다른 라이브러리 예제

위 스키마를 다른 라이브러리로 구현한 예제입니다. 표현 방식은 다르지만 리졸버 원리는 동일합니다.

### GraphQL Java

```kotlin
data class Post(val id: String, val title: String, val author_id: String)
data class User(val id: String, val name: String, val mobile_tel: String)

val posts = listOf(
    Post("1", "Post 1", "51"),
    Post("2", "Post 2", "52"),
    Post("3", "Post 3", "51"),
)
val users = mapOf(
    "51" to User("51", "John", "01012345678"),
    "52" to User("52", "Alex", "01087654321"),
)

val typeRegistry = SchemaParser().parse(
    """
type User {
  id: ID!
  name: String!
  mobile_tel: String!
}

type Post {
  id: ID!
  title: String!
  author_id: ID!
  author: User!
}

type Query {
  getPosts: [Post!]!
  getUser(id: ID!): User!
}""".trimIndent()
)
val queryBuilderFunction = { builder: TypeRuntimeWiring.Builder ->
    builder.dataFetcher("getPosts", StaticDataFetcher(posts))
        .dataFetcher("getUser") { env -> users[env.getArgument("id")] }
}
var postBuilderFunction = { builder: TypeRuntimeWiring.Builder ->
    builder.dataFetcher("author") { env -> users[env.getSource<Post>().author_id] }
}
var userBuilderFunction = { builder: TypeRuntimeWiring.Builder ->
    builder.dataFetcher("name") { env -> env.getSource<User>().name.lowercase() }
}
val runtimeWiring = RuntimeWiring.newRuntimeWiring()
    .type("Query", queryBuilderFunction)
    .type("Post", postBuilderFunction)
    .type("User", userBuilderFunction)
    .build()
val schema = SchemaGenerator().makeExecutableSchema(typeRegistry, runtimeWiring)

val graphql = GraphQL.newGraphQL(schema).build()
val query = """query { getPosts { id title author { id name } } getUser(id: "51") { id name mobile_tel } }"""
println(graphql.execute(query).toString())
```

실행 결과입니다.

```
ExecutionResultImpl{errors=[], data={getPosts=[{id=1, title=Post 1, author={id=51, name=john}}, {id=2, title=Post 2, author={id=52, name=alex}}, {id=3, title=Post 3, author={id=51, name=john}}], getUser={id=51, name=john, mobile_tel=01012345678}}, dataPresent=true, extensions=null}
```

### DGS Framework

DGS는 프레임워크이기 때문에 규칙에 따라 파일들을 작성해줘야 합니다.

[Getting Started 문서](https://netflix.github.io/dgs/getting-started/)에 따라 Spring Boot 프로젝트를 생성하고 DGS Framework를 의존성에 추가해줍니다.

`src/main/resources/schema/schema.graphqls` 에 스키마를 작성합니다.

```graphql
type User {
  id: ID!
  name: String!
  mobile_tel: String!
}

type Post {
  id: ID!
  title: String!
  author_id: ID!
  author: User!
}

type Query {
  getPosts: [Post!]!
  getUser(id: ID!): User!
}
```

데이터 페처는 다음과 같이 구현해주면 됩니다.

```kotlin
@DgsComponent
class PostDataFetcher {
    data class Post(val id: String, val title: String, val author_id: String)

    private val posts = listOf(
        Post("1", "Post 1", "51"),
        Post("2", "Post 2", "52"),
        Post("3", "Post 3", "51"),
    )

    @DgsQuery
    fun getPosts() = posts
}
```

```kotlin
@DgsComponent
class UserDataFetcher {
    data class User(val id: String, val name: String, val mobile_tel: String)

    private val users = mapOf(
        "51" to User("51", "John", "01012345678"),
        "52" to User("52", "Alex", "01087654321"),
    )

    @DgsQuery
    fun getUser(@InputArgument id: String) = users[id]

    @DgsData(parentType = "Post", field = "author")
    fun author(dfe: DgsDataFetchingEnvironment) = users[dfe.getSource<PostDataFetcher.Post>().author_id]

    @DgsData(parentType = "User", field = "name")
    fun name(dfe: DgsDataFetchingEnvironment) = dfe.getSource<User>().name.lowercase()
}
```

http://localhost:8080/graphiql 에 접속해서 질의를 입력하면 결과를 볼 수 있습니다.