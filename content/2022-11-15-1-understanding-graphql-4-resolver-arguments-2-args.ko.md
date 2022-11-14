---
title: "GraphQL 이해하기: (4) 리졸버 인자 - 2. args"
tags: ['GraphQL']
date: 2022-11-15T01:00:00
author: Simon(윤상민)
original: https://sixmen.com/ko/tech/2022-11-15-1-understanding-graphql-4-resolver-arguments-2-args/
---

GraphQL.js 리졸버의 두번째 인자는 args입니다. 해당 필드에 인자가 주어지면 그 값이 들어옵니다.

<!--more-->

> GraphQL Java에서는 DataFetchingEnvironment.getArguments 로 얻을 수 있습니다.

## 인자 처리하기

프로그래밍에서 함수 호출에 인자가 있는 것은 당연하기 때문에 어렵지 않은 개념일 겁니다. 다만 GraphQL에서 간과하기 쉬운 특성으로 객체 속성에도 인자를 줄 수 있다는 점이 있습니다. 이를 활용해 데이터를 서버에서 적절히 가공해 클라이언트에 주도록 할 수 있습니다.

```tsx
import { makeExecutableSchema } from '@graphql-tools/schema';
import { graphql } from 'graphql';

const type_defs = `
type User {
  id: ID!
  name(length: Int): String!
}

type Query {
  users(query: String, length: Int): [User!]!
}`;

interface User {
  id: string;
  name: string;
}

const users: User[] = [
  { id: '1', name: 'Francisco' },
  { id: '2', name: 'Alexander' },
  { id: '3', name: 'Picasso' },
  { id: '4', name: 'Charles' },
  { id: '5', name: 'Frederick' },
  { id: '6', name: 'Nicholas' },
];

const resolvers = {
  Query: {
    users: (_source: unknown, args: { query?: string; length?: number }) => {
      console.log(`users args: ${JSON.stringify(args)}`);
      const filtered = args.query ? users.filter((user) => user.name.includes(args.query!)) : users;
      return args.length ? filtered.slice(0, args.length) : filtered;
    },
  },
  User: {
    name: (source: User, args: { length?: number }) => {
      console.log(`name args: ${JSON.stringify(args)}`);
      return args.length ? source.name.slice(0, args.length) : source.name;
    },
  },
};

const schema = makeExecutableSchema({ typeDefs: type_defs, resolvers });

(async () => {
  const result = await graphql({
    schema,
    source: `query {
  a: users(query: "o", length: 2) { id name }
  b: users(length: 2) { id name(length: 3) }
  c: users(query: "o", length: null) { id name(length: null) }
}`,
  });
  console.log(JSON.stringify(result, null, 2));
})();
```

실행 결과는 너무 당연해서 별다른 설명이 필요없습니다.

```
users args: {"query":"o","length":2}
name args: {}
name args: {}
users args: {"length":2}
name args: {"length":3}
name args: {"length":3}
users args: {"query":"o","length":null}
name args: {"length":null}
name args: {"length":null}
name args: {"length":null}
{
  "data": {
    "a": [
      { "id": "1", "name": "Francisco" },
      { "id": "3", "name": "Picasso" }
    ],
    "b": [
      { "id": "1", "name": "Fra" },
      { "id": "2", "name": "Ale" }
    ],
    "c": [
      { "id": "1", "name": "Francisco" },
      { "id": "3", "name": "Picasso" },
      { "id": "6", "name": "Nicholas" }
    ]
  }
}
```

하나 주목할 점은 nullable 인자에 null을 준 것과 아예 누락한게 다르다는 점입니다. JavaScript에서 null과 undefined는 모든 사람들에게 혼란을 주는 괴이한 스펙이지만, 가끔은 유용/필요할 때가 있습니다. 다만 GraphQL API는 모든 언어를 생각해야 하기 때문에 null과 누락이 다르다는 특성을 실제 활용한 적은 없습니다.

다음은 DGS Framework로 구현한 예입니다.

```kotlin
data class User(val id: String, val name: String)

val users = listOf(
    User("1", "Francisco"),
    User("2", "Alexander"),
    User("3", "Picasso"),
    User("4", "Charles"),
    User("5", "Frederick"),
    User("6", "Nicholas"),
)

@DgsComponent
class UserDataFetcher {
    @DgsQuery
    fun users(dfe: DgsDataFetchingEnvironment): List<User> {
        val query = dfe.getArgument<String?>("query")
        val length = dfe.getArgument<Int?>("length")
        println("users ${dfe.arguments} / $query / $length")
        val filtered = if (query != null) users.filter { it.name.contains(query) } else users
        return if (length != null) filtered.subList(0, length) else filtered
    }

    @DgsData(parentType = "User", field = "name")
    fun name(dfe: DgsDataFetchingEnvironment): String {
        val length = dfe.getArgument<Int?>("length")
        println("name ${dfe.arguments} / $length")
        val name = dfe.getSource<User>().name
        return if (length != null) name.substring(0, length) else name
    }
}
```

질의 결과는 당연히 동일하고, arguments를 한번 살펴보면 null이 들어온 경우와 값이 주어지지 않은 경우가 구분되는 것을 확인할 수 있습니다.

```
users {query=o, length=2} / o / 2
name {} / null
name {} / null
users {length=2} / null / 2
name {length=3} / 3
name {length=3} / 3
users {query=o, length=null} / o / null
name {length=null} / null
name {length=null} / null
name {length=null} / null
```

## 상위 필드의 인자 사용

User 타입의 필드 리졸버를 구현이 필요하다고 생각해봅시다. 그런데 이 User 객체가 getPosts → Post → author를 거쳐 온 것인지, getUser에서 온 것인지 구분할 수가 없습니다. 따라서 리졸버는 가급적 어떤 경로에서 온 것인지 몰라도 동작하도록 구현하는 것이 바람직합니다. 그런데 상위 필드의 인자를 사용한다? 얼핏 봐도 하면 안 되는 일 같지만 아쉽게도 이게 필요한 경우가 있습니다.

서버에서 리소스 목록을 반환하는 API는 기본이라고 볼 수 있죠. 그리고 이 목록이 방대하기 때문에 페이지네이션으로 가져오는 경우도 흔합니다. 페이지네이션을 보여주려면 요청한 목록 외에 전체 리소스 개수도 필요합니다. 물론 GraphQL을 사용하면 목록과 개수를 한번에 요청하는 것이 가능합니다. 흔한 요구사항인 만큼 페이스북이 처음 GraphQL을 내놓을때 [Connections](https://relay.dev/graphql/connections.htm) 라는 스펙을 [Relay](https://relay.dev/)와 함께 제시했습니다.

이 스펙으로 포스트 목록을 요청하면 다음과 같은 형태가 됩니다.

```graphql
query {
  getPosts {
    totalCount
    pageInfo {
      hasNextPage
    }
    edges {
      cursor
      node {
        id
        title
        author { name }
      }
    }
  }
}
```

개인적으로 이 스펙은 복잡해서 이해하기 어렵다고 느껴졌기 때문에 카카오스타일에서는 Connection, Edge, Node 대신 단순한 List, Item 개념을 사용해서 목록을 구현하고 있습니다. cursor를 위로 빼서 Edge 필요성을 없애고, hasNextPage를 `next_cursor != null` 로 대체했다고 보시면 됩니다.

```graphql
type PostList {
  total_count: Int!
  item_list: [Post!]!
  next_cursor: String
}

type Query {
  getPosts: PostList!
}
```

항상 글 전체 목록만 가져올리는 없겠죠? 원하는 글 목록에 대한 조건을 추가해봅시다. 페이지네이션은 전통적인 방식인 OFFSET & LIMIT으로 구현하기로 했습니다.

```graphql
type Query {
  getPosts(
		author_id: ID
		date_created_gte: Float
		date_created_lt: Float
		title_contains: String
		limit: Int
		skip: Int
	): PostList!
}
```

total_count, item_list를 구현할 때 위 인자를 모두 알아야 합니다. (total_count 구현시에는 limit, skip이 필요하지 않습니다) 하지만 이 리졸버에서 getPosts의 인자를 얻을 방법이 없습니다. 그렇다고 total_count, item_list에 인자를 중복 기술하는 것은 좋아보이지 않습니다.

이전 source 설명 아티클에서 말씀드린 테크닉을 사용하면 상위 인자를 얻을 수 있습니다.

```tsx
const resolvers = {
  Query: {
    getPosts: (_source: unknown, args: GetPostsArgs) => ({ __args: args }),
  },
  PostList: {
    total_count: ({ __args: args }: { __args: GetPostsArgs }) => {
      // get total count with arguments
    },
    item_list: ({ __args: args }: { __args: GetPostsArgs }) => {
      // get item list with arguments
    },
  },
};
```

원 리졸버의 args와 헷갈리기 때문에 익숙해지려면 시간이 걸리지만 동작은 합니다. 이 테크닉을 사용하지 않으려면 getPosts에서 total_count, item_list를 모두 구해 반환하면 됩니다.

```tsx
const resolvers = {
  Query: {
    getPosts: (_source: unknown, args: GetPostsArgs) => {
      const total_count = 0; // get total count with arguments
      const item_list = []; // get item list with arguments
      return { total_count, item_list };
    },
  },
};
```

이 경우 내가 total_count, item_list 중 하나만 요청한 경우에도 나머지를 계산해야 하는 비효율이 발생합니다. (다음에 설명할 info를 사용해 최적화할 수는 있습니다) 어느 쪽이든 그렇게 깔끔하지는 않습니다만, 개인적으로는 주로 전자의 패턴을 많이 사용하고 있습니다. (후자로 한 경우도 있습니다.) 상위 인자를 접근하는 것은 일반적으로 좋지 않은 패턴이므로 위와 같이 실질적으로 하나의 쌍으로 간주되는 경우만 사용하시는 것이 좋습니다.

GraphQL Java도 똑같이 구현할 수 있지만, 상위 필드가 반환해주는 값을 별도로 전달 받을 수 있는 localContext 라는 개념이 있어 이를 활용할 수 있습니다.

```kotlin
class PostDataFetcher {
    data class Post(val id: String, val title: String, val author_id: String)
    data class PostList(val total_count: Int, val item_list: List<Post>)

    @DgsQuery
    fun getPosts(dfe: DgsDataFetchingEnvironment): DataFetcherResult<PostList> {
        println("getPosts ${dfe.arguments}")
        return DataFetcherResult.newResult<PostList>()
            .data(PostList(0, emptyList()))
            .localContext(dfe.arguments)
            .build()
    }

    @DgsData(parentType = "PostList", field = "total_count")
    fun totalCount(dfe: DgsDataFetchingEnvironment): Int {
        println("totalCount ${dfe.getLocalContext<Map<String, Object>>()}")
        return 10
    }

    @DgsData(parentType = "PostList", field = "item_list")
    fun itemList(dfe: DgsDataFetchingEnvironment): List<Post> {
        println("itemList ${dfe.getLocalContext<Map<String, Object>>()}")
        return listOf(Post("1", "Post 1", "51"))
    }
}
```
