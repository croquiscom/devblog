---
title: "GraphQL 이해하기: (4) 리졸버 인자 - 3. context"
tags: ['GraphQL']
date: 2022-11-15T02:00:00
author: Simon(윤상민)
original: https://sixmen.com/ko/tech/2022-11-15-2-understanding-graphql-4-resolver-arguments-3-context/
---

GraphQL.js 리졸버의 세번째 인자는 context입니다. 이 인자는 온전히 사용자가 설정하는 것으로 매 요청마다 새로 생성되며 같은 요청을 처리하는 리졸버가 상태를 공유하기 위해 사용합니다.

<!--more-->

다음과 같이 적당한 값을 넣어서 한번 실행해보면 동작 방식을 금방 이해할 수 있습니다.

```tsx
import { makeExecutableSchema } from '@graphql-tools/schema';
import { graphql } from 'graphql';

const type_defs = `
type User {
  id: ID!
  name: String!
}

type Query {
  users: [User!]!
}`;

const users = [
  { id: '1', name: 'Francisco' },
  { id: '2', name: 'Alexander' },
];

interface Context {
  foo: number;
  bar?: number;
}

const resolvers = {
  Query: {
    users: (_source: unknown, _args: unknown, context: Context) => {
      console.log('users', context);
      context.bar = (context.bar || 0) + 1;
      return users;
    },
  },
  User: {
    name: (source: any, _args: unknown, context: Context) => {
      console.log('name', context);
      context.bar = (context.bar || 0) + 1;
      return source.name;
    },
  },
};

const schema = makeExecutableSchema({ typeDefs: type_defs, resolvers });

(async () => {
  await graphql({ schema, source: `query { users { id name } }`, contextValue: { foo: 1 } });
  await graphql({ schema, source: `query { users { id name } }`, contextValue: { foo: 100, bar: 10 } });
})();
```

실행 결과는 다음과 같습니다.

```
users { foo: 1 }
name { foo: 1, bar: 1 }
name { foo: 1, bar: 2 }
users { foo: 100, bar: 10 }
name { foo: 100, bar: 11 }
name { foo: 100, bar: 12 }
```

컨텍스트의 가장 일반적인 사용예는 클라이언트 요청의 부가 정보를 담는 것입니다. 요청시 준 HTTP 헤더, 로그인 상태인 경우 로그인 한 사용자 정보 같은 것들이 있습니다.

다음은 실제 클라이언트 요청을 처리하는 프레임워크인 [Apollo Server](https://www.apollographql.com/docs/apollo-server/)에서 컨텍스트를 설정해 본 예제입니다.

```tsx
import { IncomingMessage, ServerResponse } from 'http';
import { ApolloServer } from '@apollo/server';
import { startStandaloneServer } from '@apollo/server/standalone';

interface Context {
  req: IncomingMessage;
  res: ServerResponse;
}

const resolvers = {
  Query: {
    getUser: (_source: any, args: any, context: Context) => {
      console.log(Object.keys(context)); // [ 'req', 'res' ]
      console.log(context.req.headers); // { host: 'localhost:4000', 'content-type': 'application/json', ... }
      return users[args.id];
    }
  },
};

const server = new ApolloServer({ typeDefs, resolvers });

(async () => {
  await startStandaloneServer<Context>(server, {
    context: async ({req, res}) => ({req, res}),
  });
})();
```

GraphQL Java의 경우 GraphQLContext라는 속성으로 제공합니다. DGS Framework의 경우 HTTP 요청을 처리해주는데 이를 제공하기 위해 GraphQLContext를 감싼 DgsContext를 제공합니다. `println(dfe.getDgsContext().requestData)` 로 내용을 출력해보면 `DgsWebMvcRequestData(extensions={}, headers=[host:"localhost:8080", accept:"application/json", ...], webRequest=ServletWebRequest: uri=/graphql;client=127.0.0.1)` 와 같은 결과를 볼 수 있습니다.

## DataLoader와 컨텍스트

앞선 글에서 얘기했듯이 리졸버는 독립적으로 동작하는 것이 좋습니다. 그렇다보니 한번에 요청할 수 있는 것을 나눠서 요청하는 N+1 쿼리 문제가 발생합니다. 이를 해결해주는 라이브러리로 [DataLoader](https://github.com/graphql/dataloader)가 있습니다. 그런데 이 DataLoader는 요청별로 생성하는 것이 좋습니다. 즉 요청별로 다른 값을 가지는 컨텍스트를 사용할 필요가 있습니다.

> In many applications, a web server using DataLoader serves requests to many different users with different access permissions. It may be dangerous to use one cache across many users, and is encouraged to create a new DataLoader per request:

필요할 때 DataLoader 인스턴스를 생성하기 위해 카카오스타일에서는 컨텍스트를 활용한 다음 패턴을 주로 사용합니다.

```tsx
interface Context {
  loader: { [loader_name: string]: DataLoader<any, any> | undefined };
}

// for Apollo Server
{
  context: async ({ req, res }) => ({ loader: {} }),
}

// resolver
my_field(soruce, args, context: Context) {
  const loader_name = 'MyType.my_field';
  let loader: DataLoader<string, MyFieldType> | undefined = context.loader[loader_name];
  if (!loader) {
		loader = new DataLoader<string, MyFieldType>(async (keys) => {
			// return Array<MyFieldType> for keys
		});
		if (context) {
			context.loader[loader_name] = loader;
		}
  }
	return loader.load(source.key_for_my_field);
}
```

참고로 [GraphQL Java](https://www.graphql-java.com/documentation/batching)는 DataLoader에 대한 처리가 라이브러리 내부에 들어와 있습니다. DataLoaderRegistry 클래스를 생성해 ExecutionInput으로 주면 DataFetchingEnvironment.getDataLoader를 통해 DataLoader를 얻을 수 있습니다. [DGS Framework](https://netflix.github.io/dgs/data-loaders/)에서는 DgsDataLoader 어노테이션을 통해 등록하면 됩니다.
