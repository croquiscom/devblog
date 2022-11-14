---
title: "GraphQL 이해하기: (4) 리졸버 인자 - 1. source"
tags: ['GraphQL']
date: 2022-11-12T00:00:00
author: Simon(윤상민)
original: https://sixmen.com/ko/tech/2022-11-12-1-understanding-graphql-4-resolver-arguments-1-source/
---

GraphQL.js의 리졸버는 네개의 인자를 가지고 있습니다. 그 중 첫번째 인자는 source 입니다.

<!--more-->

> GraphQL Java에서는 DataFetchingEnvironment.getSource로 얻을 수 있습니다.

앞서 설명했듯이 리졸버는 상위 필드에서 하위 필드 순서로 호출됩니다. source는 상위 필드에서 반환한 값이 들어갑니다. 상위 필드가 없는 Query 필드에는 execute(graphql) 메소드의 rootValue 값이 들어옵니다. 다만 실전에서 rootValue를 사용해 본 적은 없습니다.

굉장히 단순한 동작이지만 상위 필드에서 반환한 값이 **그대로** 들어온 다는 점을 이해해두면 좋습니다. 카카오스타일에서는 이 특성을 활용한 리졸버가 있습니다.

앞선 예제를 다시 보겠습니다.

```tsx
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

const resolvers = {
  Query: {
    getPosts: () => posts,
  },
  Post: {
    author: (source: any) => authors[source.author_id],
  },
};
```

GraphQL의 Post 타입과 구현 부분의 Post 인터페이스는 명백하게 같지 않습니다. 하지만 문제 없이 동작하죠. 이 차이를 명확히 보기 위해 Post 클래스를 정의하는 것으로 바꿔보겠습니다.

```tsx
class Post {
  constructor(public id: string, public title: string, public author_id: string) {}
}

const posts: Post[] = [new Post('1', 'Post 1', '51'), new Post('2', 'Post 2', '52'), new Post('3', 'Post 3', '51')];

const resolvers = {
  Query: {
    getPosts: () => posts,
  },
  Post: {
    author: (source: Post) => authors[source.author_id],
  },
};
```

이렇게 하면 GraphQL의 Post 타입과 다르다는 점이 명확히 눈에 들어옵니다.

타입스크립트에서는 필드만 동일하면 해당 클래스와 같은 타입으로 인지합니다. 둘을 섞어서 정의해보면 어떻게 될까요?

```tsx
const posts: Post[] = [
  new Post('1', 'Post 1', '51'),
  { id: '2', title: 'Post 2', author_id: '52' },
  { id: '3', title: 'Post 3', author_id: '51' },
];

const resolvers = {
  Post: {
    author: (source: Post) => {
      console.log(source.id, source instanceof Post);
      return authors[source.author_id];
    },
  },
};
```

결과는

```
1 true
2 false
3 false
```

이 됩니다. 극단적으로는 다음과 같은 것도 가능합니다.

```tsx
const resolvers = {
  Query: {
    getPosts: () => posts.map((post) => ({ _id: post.id })),
  },
  Post: {
    id: (source: { _id: string }) => source._id,
    title: (source: { _id: string }) => posts.find((post) => post.id === source._id)!.title,
    author: (source: { _id: string }) => authors[posts.find((post) => post.id === source._id)!.author_id],
  },
};
```

위에서 알 수 있듯이 상위 필드가 반환하는 값이 GraphQL 타입과 무관해도 아무 문제없습니다.

GraphQL Java에서도 동작은 같습니다. (DGS 예이지만, DGS가 GraphQL Java 위에서 동작하므로 차이가 없습니다.)

```kotlin
data class Id(val _id: String)
data class User(val id: String, val name: String, val mobile_tel: String)

val users = mapOf(
    "51" to User("51", "John", "01012345678"),
    "52" to User("52", "Alex", "01087654321"),
)

@DgsComponent
class PostDataFetcher {
    data class Post(val id: String, val title: String, val author_id: String)

    private val posts = listOf(
        Post("1", "Post 1", "51"),
        Post("2", "Post 2", "52"),
        Post("3", "Post 3", "51"),
    )

    @DgsQuery
    fun getPosts() = posts.map { Id(it.id) }

    @DgsData(parentType = "Post", field = "id")
    fun id(dfe: DgsDataFetchingEnvironment) = dfe.getSource<Id>()._id

    @DgsData(parentType = "Post", field = "title")
    fun title(dfe: DgsDataFetchingEnvironment) = posts.find { it.id == dfe.getSource<Id>()._id }!!.title

    @DgsData(parentType = "Post", field = "author")
    fun author(dfe: DgsDataFetchingEnvironment) = users[posts.find { it.id == dfe.getSource<Id>()._id }!!.author_id]
}
```

잘 활용하면 좋지만 코드를 새로 접한 사람에게 혼란을 줄 수도 있습니다. 또 위 특성 때문에 타입 언어와 안 어울리는 부분이 있습니다. 저희의 경우 TypeScript 프로젝트에 [GraphQL Code Generator](https://www.the-guild.dev/graphql/codegen)를 사용해 리졸버 타입을 지정해주고 있는데, getPosts 리졸버가 반환하는 값에 non-null인 author 필드 값이 없다고 타입 에러가 나기 때문에 어쩔 수 없이 any를 써주고 있습니다.
