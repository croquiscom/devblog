---
title: 크로키의 스택 - GraphQL
tags: ['Croquis','Stack','GraphQL','마이크로서비스','Microservice']
date: 2019-05-22
author: Sangmin Yoon
original: http://sixmen.com/ko/tech/2019-05-22-1-croquis-stack-graphql/
---

현재 크로키는 API를 [GraphQL](https://graphql.org/)로 만들고 있습니다.
아직 많은 부분에 대해서 연구 중이어서 현재 상황만 간단하게 정리해 보겠습니다.

<!--more-->

Thrift를 1년 정도 쓴 시점부터 여러 가지 불편함을 느끼고 대안을 찾다가 GraphQL을 선택했습니다.
GraphQL 생태계가 Node.js를 중심으로 발전하고 있어서 크게 망설이지 않고 정할 수 있었던 것 같습니다.

외부에 영향을 주지 않는 기능 중 N+1 문제를 가지고 있는 기능을 하나 선택해 변환을 해봤습니다.
조금 생각은 해야 하지만 충분히 기존 API에 성능이 떨어지지 않고 사용은 더 편하게 할 수 있는 것을 확인하고 조금씩 확대해나갔습니다.

1년 이상 진행하면서 정리된 API 스펙은 [스타일 가이드 저장소](https://github.com/croquiscom/style-guide/blob/master/API/GraphQL.md)에서 공개하고 있습니다.

## 스키마 정의

처음에는 GraphQLObjectType을 써서 정의했습니다.

{{< highlight typescript >}}
import { GraphQLInt, GraphQLNonNull, GraphQLObjectType, GraphQLString } from 'graphql';

const type = new GraphQLObjectType({
  name: 'Shop',
  fields: {
    id: {
      type: new GraphQLNonNull(GraphQLInt),
    },
    name: {
      type: new GraphQLNonNull(GraphQLString),
    },
    url: {
      type: new GraphQLNonNull(GraphQLString),
    },
  },
});
{{< /highlight >}}

그러다가 타입이 많아지면 보기가 힘들어서 스키마 문자열을 통해 정의하는 것으로 변경해 봤습니다.

{{< highlight typescript >}}
import { makeExecutableSchema } from 'graphql-tools';

const typeDefs = `
type Shop {
  id: ID!
  name: String!
  url: String!
}
`;

const resolvers = {
  Query: {
    shop: ShopService.shop,
  },
};

const schema = makeExecutableSchema({
  typeDefs: [typeDefs],
  resolvers: [resolvers],
});
{{< /highlight >}}

현재는 resolver 구현에도 타입 체킹이 되고, DB 모델과 통일시키기 위해 [type-graphql](https://typegraphql.ml/)을 적용했습니다.
다만 현재 [퍼포먼스 이슈](https://github.com/19majkel94/type-graphql/issues/254) 때문에
[수정한 버전](https://github.com/croquiscom/type-graphql/tree/croquis-190305)을 사용하고 있습니다.

{{< highlight typescript >}}
import { Field, ID, ObjectType } from 'type-graphql';

@ObjectType()
export class Shop {
  @Field((type) => ID, { nullable: false })
  id: string;

  @Field((type) => String, { nullable: false })
  name: string;

  @Field((type) => String, { nullable: false })
  url: string;
}
{{< /highlight >}}

## 클라이언트 호출 코드

클라어인트에서는 [apollo 툴](https://www.apollographql.com/)을 사용해 코드를 생성해 호출하고 있습니다.

**_안드로이드_**
{{< highlight java >}}
LoginInput input = LoginInput.builder().email(email).password(password).build();
apolloClient.mutate(
    LoginMutation.builder().input(input).build()
).enqueue(new ApolloCall.Callback<LoginMutation.Data>() {
    ...
});
{{< /highlight >}}

**_iOS_**
{{< highlight swift >}}
let input = LoginInput(email: email, password: password)
apolloClient.perform(mutation: LoginMutation(input: input)) { (result, error) in
    ...
}
{{< /highlight >}}

**_웹_**
{{< highlight javascript >}}
// api.ts (apollo-tooling 위에 자체 스크립트로 생성한 파일)
import * as types from './types';

export async function login(variable: types.LoginVariables, options?: GqlRequestOptions) {
  const query = 'mutation Login($input: LoginInput!) { login(input: $input) }';
  return await request<types.Login, types.LoginVariables>(query, variable, options);
}

// LoginView.ts
async login() {
  await api.login({
    input: { email, password },
  });
}
{{< /highlight >}}

## 마무리하며

전환을 시작한 이후로 많은 GraphQL API를 만들었지만, 기존 API는 손대지 못하고 거의 그대로 사용하고 있습니다.
그걸 보면서 진작에 GraphQL로 전환했으면 두 번 작업하는 일이 줄어들었을 터라는 생각이 듭니다.
하지만 초반에 적용했으면 아직 안정화되지 않은 생태계로 인해 고생했을 것 같습니다.

웹 기술을 TypeScript로, GraphQL로, React로 전환할 때마다, 이 방향이 맞는지, 이 시기가 적당한지 고민이 됩니다.
서비스를 이어가는 와중에 기술 부채를 털어낼 적절한 시기를 놓치지 않도록 계속 노력하고 있습니다.

차후에도 GraphQL을 사용하면서 의미가 있는 부분이 있으면 공개하도록 하겠습니다.
