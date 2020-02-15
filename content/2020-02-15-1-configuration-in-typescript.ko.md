---
title: TypeScript에서의 환경 설정 관리
tags: ['TypeScript']
date: 2020-02-15
author: Sangmin Yoon
original: http://sixmen.com/ko/tech/2020-02-15-1-configuration-in-typescript/
---

응용프로그램을 작성하다 보면 여러 가지 환경 설정(configuration)이 필요합니다.
이번 글에서는 TypeScript에서 환경 설정을 관리하는 저희의 방법을 설명합니다.

<!--more-->

프로젝트 초기에는 환경 설정을 코드 중간에 넣어서 개발하는 경우가 많을 것으로 생각합니다.
그러다가 규모가 커지면 여러 가지 이유로 코드에서 분리해서 관리할 필요성이 늘어납니다.
첫 번째는 보안 측면의 이슈입니다. 암호나 접근키(access key) 등을 코드에 넣는 것은 보통 좋은 방향이 아닙니다.
이런 값은 보통 환경 변수(environment variable)에 담아서 사용하는 경우가 많습니다.
프로세스 구동 시에 환경 변수를 설정해두는 것은 꽤 귀찮은 작업이기 때문에 [dotenv](https://github.com/motdotla/dotenv) 같은 모듈을 사용하기도 합니다.
두 번째는 상황에 따라 다른 값을 적용해야 하는 경우입니다. 개발 중, 운영 환경, 자동화 테스트 등의 상황마다 다른 값이 필요한 경우가 많습니다.
이런 경우를 지원하는 것으로 [config](https://github.com/lorenwest/node-config)라는 모듈이 있습니다.

크로키의 경우 첫 번째 이슈는 그렇게 크지 않았습니다.
운영 환경에 적절한 환경 변수를 설정하는 것도 꽤 번거롭기 때문에 AWS Instance Role이나 Parameter Store 같은 방법을 써서 회피하고 있습니다.
하지만 환경에 따라 설정이 달라지는 경우는 많았기 때문에 config 모듈은 사용하고 있었습니다.
config 모듈은 필요한 기능을 제공했지만, 오타 등의 이유로 개발 중에는 잘 동작하는데 운영 환경에서는 잘못된 설정이 적용되거나 하는 실수가 종종 발생했습니다.
그래서 저희가 사용하는 TypeScript 언어의 장점을 살려 설정도 타입 검사가 이루어졌으면 하는 바람이 생겼습니다.
[node-config-ts](https://github.com/tusharmath/node-config-ts)라는 모듈이 있었지만, 원하는 형태와는 조금 거리가 있었습니다.

여러 가지를 고민하던 중에 외부 모듈 없이도 타입 안정성 있는 설정을 구현할 수 있다는 생각이 들었습니다.
저희는 처음부터 설정 파일을 JSON이 아닌 JavaScript로 관리하고 있었습니다. 이를 그대로 TypeScript로 전환하면 그 자체가 타입 정의가 될 것 같았습니다.
이렇게 만들어진 저희 설정 파일 형식은 다음과 같습니다.

우선 설정의 기본 구조는 config/default.ts에 정의합니다. 이후 다른 코드에서는 이 파일의 내용을 기반으로 타입 검사가 이루어집니다.

{{< highlight typescript >}}
const Config = {
  test_mode: false,
  database: {
    host: 'mydb.mydomain.com',
    port: 3306,
    user: 'myuser',
    password: 'mypassword',
  },
};

export default Config;
{{< /highlight >}}

다른 환경에 대한 설정은 다른 부분에 대해서만 정의하면 됩니다. 다음은 테스트 환경을 위한 config/test.ts 파일입니다.

{{< highlight typescript >}}
const Config = {
  test_mode: true,
  database: {
    host: 'localhost',
    port: '5678',
  },
};

export default Config;
{{< /highlight >}}

이제 이를 묶어서 다른 코드에 제공할 config/index.ts 파일을 정의합니다.

{{< highlight typescript >}}
import _ from 'lodash';
import BaseConfig from './default';

const Config = _.cloneDeep(BaseConfig);

if (process.env.NODE_ENV) {
  try {
    const EnvConfig = require(`./${process.env.NODE_ENV}`).default;
    _.merge(Config, EnvConfig);
  } catch (e) {
    console.log(`Cannot find configs for env=${process.env.NODE_ENV}`);
  }
}

export { Config };
{{< /highlight >}}

이 설정 파일은 다음과 같이 사용하면 됩니다. 이 코드는 NODE_ENV에 따라 다른 결과를 출력합니다. 물론 타입 검사도 완벽히 동작합니다.

{{< highlight typescript >}}
import { Config } from './config';

console.log(Config.database);
{{< /highlight >}}

다만 이대로는 부족한 점이 있습니다. test.ts 파일에서 오타(예 test_mode -> testmode)나 타입 오류가 있어도 알려주지 않습니다.
이는 다음 방법으로 해결할 수 있습니다. default.ts에 다음 내용을 추가합니다.

{{< highlight typescript >}}
// from https://github.com/krzkaczor/ts-essentials
type DeepPartial<T> = {
  [P in keyof T]?: T[P] extends Array<infer U>
  ? Array<DeepPartial<U>>
  // tslint:disable-next-line:no-shadowed-variable
  : T[P] extends ReadonlyArray<infer U>
  ? ReadonlyArray<DeepPartial<U>>
  : DeepPartial<T[P]>
};

export type BaseConfigType = DeepPartial<typeof Config>;
{{< /highlight >}}

이제 test.ts를 다음과 같이 수정합니다.

{{< highlight typescript >}}
import { BaseConfigType } from './default';

const Config: BaseConfigType = {
  ...
};

export default Config;
{{< /highlight >}}

처음 정의 시 port의 타입이 달랐는데(string vs number) 이제는 다음과 같은 컴파일 오류가 발생합니다.

```
config/test.ts(5,3): error TS2322: Type '{ host: string; port: string; }' is not assignable to type 'DeepPartial<{ host: string; port: number; user: string; password: string; }>'.
  Types of property 'port' are incompatible.
    Type 'string' is not assignable to type 'number | undefined'.
```

저희는 이런 식으로 설정을 정의해서 잘 사용하고 있습니다. 다만 아쉬운 점이 아예 없지는 않습니다.
lodash의 merge를 사용하기 때문에 default 설정에서 정의한 값을 undefined로 덮어씌우지는 못합니다.
또 default 설정의 타입이 기준이 되기 때문에 환경마다 설정의 형태가 매우 다르다면 default에서 타입을 명시적으로 써줘야 할 수도 있습니다.

{{< highlight typescript >}}
// default
import Redis from 'ioredis';

const Config = {
  database: {
    password: 'mypassword' as string | null,
  },
  cache: {
    ...
  } as Redis.RedisOptions,
};

// test
const Config = {
  database: {
    password: null,
  },
};
{{< /highlight >}}

제 생각에 JavaScript 생태계에서 TypeScript는 뺄 수 없는 부분이 된 것 같습니다.
이 글이 TypeScript를 사용하시는 데 도움이 되었으면 합니다.
