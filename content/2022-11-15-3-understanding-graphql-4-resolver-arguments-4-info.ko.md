---
title: "GraphQL 이해하기: (4) 리졸버 인자 - 4. info"
tags: ['GraphQL']
date: 2022-11-15T03:00:00
author: Simon(윤상민)
original: https://sixmen.com/ko/tech/2022-11-15-3-understanding-graphql-4-resolver-arguments-4-info/
---

GraphQL.js 리졸버의 마지막 인자는 info입니다. info는 현재 처리 중인 질의에 대한 정보가 들어가 있습니다. 보통은 리졸버 구현에 info가 필요하지 않지만 최적화나 복잡한 연결을 위해서는 info의 내용이 필요합니다.

<!--more-->

## variableValues

variableValues 속성에는 실행시 준 변수 값이 들어있습니다. 그런데 변수를 사용한 경우에만 값이 있기 때문에 생각보다 쓸 만한 곳은 없습니다. 아래 예에서 query도 필드의 인자이지만 variableValues에는 포함되지 않습니다.

```tsx
import { makeExecutableSchema } from '@graphql-tools/schema';
import { graphql, GraphQLResolveInfo } from 'graphql';

const type_defs = `
type User {
  id: ID!
  name: String!
}

type Query {
  users(query: String, length: Int): [User!]!
}`;

const users = [
  { id: '1', name: 'Francisco' },
  { id: '2', name: 'Alexander' },
];

const resolvers = {
  Query: {
    users: (_source: unknown, _args: unknown, _context: any, info: GraphQLResolveInfo) => {
      console.log(info.variableValues); // { length: 5 }
      return users;
    },
  },
  User: {
    name: (source: any, _args: unknown, _context: any, info: GraphQLResolveInfo) => {
      console.log(info.variableValues); // { length: 5 }
      return source.name;
    },
  },
};

const schema = makeExecutableSchema({ typeDefs: type_defs, resolvers });

(async () => {
  await graphql({
    schema,
    source: `query($length: Int) { users(query: "H", length: $length) { id name } }`,
    variableValues: { length: 5 },
  });
})();
```

GraphQL Java에서는 DataFetchingEnvironment.getVariables()로 얻을 수 있습니다.

## path, fieldName, parentType, returnType

path을 통해 현재 리졸버가 어떤 경로에 의해 실행됐는지 알 수 있습니다.

```tsx
import { makeExecutableSchema } from '@graphql-tools/schema';
import { graphql, GraphQLResolveInfo } from 'graphql';

const type_defs = `
type Name {
  first: String!
  last: String!
}

type User {
  id: ID!
  name: Name!
}

type Query {
  users: [User!]!
}`;

const users = [
  { id: '1', name: { first: 'John', last: 'Doe' } },
  { id: '2', name: { first: 'Michael', last: 'Frank' } },
];

const resolvers = {
  Query: {
    users: (_source: unknown, _args: unknown, _context: any, info: GraphQLResolveInfo) => {
      console.log(JSON.stringify(info.path, null, 2));
      return users;
    },
  },
  User: {
    name: (source: any, _args: unknown, _context: any, info: GraphQLResolveInfo) => {
      console.log(JSON.stringify(info.path, null, 2));
      return source.name;
    },
  },
  Name: {
    first: (source: any, _args: unknown, _context: any, info: GraphQLResolveInfo) => {
      console.log(JSON.stringify(info.path, null, 2));
      return source.first;
    },
  },
};

const schema = makeExecutableSchema({ typeDefs: type_defs, resolvers });

(async () => {
  await graphql({ schema, source: `query { users { id name { first last } } }` });
})();
```

다음과 같은 구조의 데이터입니다. users는 배열이기 때문에 중간에 ‘0’이 키로 존재합니다.

```json
{ "key": "users", "typename": "Query" }

{
  "prev": {
    "prev": { "key": "users", "typename": "Query" },
    "key": 0
  },
  "key": "name", "typename": "User"
}

{
  "prev": {
    "prev": {
      "prev": { "key": "users", "typename": "Query" },
      "key": 0
    },
    "key": "name", "typename": "User"
  },
  "key": "first", "typename": "Name"
}
```

fieldName, parentType, returnType에는 다음 스키마에 해당하는 타입이 들어가 있습니다.

```
users, Query, [User!]!
name, User, Name!
first, Name, String!
```

GraphQL Java에서는 DataFetchingEnvironment의 `getExecutionStepInfo().getPath()`, `getField().getName()`, `getParentType()`, `getExecutionStepInfo().getType()`으로 얻을 수 있습니다.

## fieldNodes

fieldNodes에는 현재 실행중인 리졸버가 반환해야 하는 필드 정보가 들어가 있습니다. (GraphQL Java에는 getField()로 얻을 수 있습니다.) 쿼리 최적화등에 사용할 수 있어서 가장 많이 쓰는 속성입니다.

위 예에서 각 리졸버에 각각 `users { id name { first last } }`, `name { first last }`, `first`라는 값이 들어온다고 보면 됩니다. GraphQL.js의 내부 구조체를 그대로 주기 때문에 직접 쓰기에는 어렵습니다. 그래서 카카오스타일에서는 [@croquiscom/crary-graphql](https://github.com/croquiscom/crary-node/tree/master/packages/graphql)이라는 자체 라이브러리를 만들어 사용하고 있습니다.

### getFieldList

`getFieldList(info)`를 실행하면 현 리졸버가 반환해야 할 필드 목록을 반환합니다. 위 예에서는 `[ 'id', 'name.first', 'name.last' ]`, `[ 'first', 'last' ]`, `[]`가 실행 결과가 됩니다. 이를 활용해 클라이언트가 요청한 필드만 처리하는 최적화를 할 수 있습니다.

중첩된 필드는 `.` 으로 묶여 1차원 배열로 반환하는데, 카카오스타일에서 쓰는 ORM인 [CORMO](https://croquiscom.github.io/cormo/)에서 객체 컬럼이 있을 때 사용하는 select 구문의 인자로 그대로 쓸 수 있는 형태를 가지고 있습니다.

```tsx
class Name {
  @cormo.Column({ type: String, required: true })
  public first: string;

  @cormo.Column({ type: String, required: true })
  public last: string;
}

@cormo.Model()
class User extends cormo.BaseModel {
  id: number;

  @cormo.ObjectColumn(Name)
  public name: Name;
}

const records = await User.where().select(getFieldList(info));
```

`{ users { id name { first } } }`와 같이 일부 필드만 요청한 경우 위 코드는 `SELECT id, name_first FROM users`와 같이 요청한 컬럼만 DB에서 가져오는 최적화된 쿼리로 변환됩니다.

### getFieldList1st

getFieldList1st는 getFieldList와 유사하지만 첫번째 깊이의 필드만 반환합니다. 즉 위 예에서는 `[ 'id', 'name' ]`, `[ 'first', 'last' ]`, `[]` 를 반환합니다.

args 아티클에 있는 total_count, item_list 예에서 `getFieldList1st(info).includes('item_list')` 조건문을 써서 item_list를 요청한 경우에만 DB에서 목록을 가져오는 최적화를 할 수 있습니다.

### addArgumentToInfo, addFieldToInfo, removeArgumentFromInfo, removeFieldFromInfo

카카오스타일에서는 API gateway를 두고 있고, 거기서 GraphQL을 각 마이크로서비스로 분배합니다. 이 때 클라이언트 요청을 일부 변형한 후에 마이크로서비스로 전달할 필요가 있어서 만든 유틸리티입니다. info에 필드를 추가/삭제하거나 인자를 변형할 수 있습니다.

마이크로서비스에서 계정 정보를 반환하는 Query.user(id: ID!) API를 제공한다고 가정해 봅시다. 하지만 API gateway에서는 이 API를 그대로 쓰는게 아니라 현재 로그인한 사용자의 정보를 반환하는 Query.user 형태로 클라이언트에 노출하고 있습니다. 로그인한 사용자 정보는 API gateway가 알고 있고, 마이크로서비스 API 호출시 이를 인자에 추가해줘야 합니다. 이 로직을 다음과 같이 구현하고 있습니다. (hookResolver는 기존 리졸버의 동작 앞뒤에 다른 동작을 추가할 수 있는 유틸리티입니다.)

```tsx
hookResolver(schema.getQueryType()!.getFields().user, async (source, args, context, info, resolve) => {
  const user_id: string | undefined = context.session.login_user_id;
  if (!user_id) {
    return null;
  }
  info = addArgumentToInfo(info, 'id', user_id, new GraphQLNonNull(GraphQLID));
  // 또는 info = info.addArgument('id', user_id, new GraphQLNonNull(GraphQLID));
  return await resolve(source, args, context, info);
});
```
