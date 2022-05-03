---
title: ESM 삽질기
tags: ['Node.js']
date: 2022-04-09T00:00:00
author: Simon(윤상민)
original: http://sixmen.com/ko/tech/2022-04-09-1-esm-problem/
---

저희는 주기적으로 Node.js 모듈을 최신 버전으로 업데이트하고 있습니다.
Node.js를 10년째 사용 중인데, CoffeeScript → TypeScript, 콜백 → Async.js → Promise(& async, await) 전환 하면서 몇 번 혼란의 시기가 있었습니다.
하지만 모듈 시스템은 쭉 이어져왔습니다.
그런데 최근에 이 모듈 시스템에 큰 변화가 생겼고 기존 변화와 다르게 양립이 잘 안 되서 모듈 업데이트를 제대로 못 하고 있습니다.
이 문제를 일으킨 ESM이 뭐고 어떤 작업이 필요한지 알아보려고 합니다. (개인적으로 만족하는 깔끔한 해결책이 나오지 못했습니다)

<!--more-->

## 발생하는 문제

[chalk](https://www.npmjs.com/package/chalk) 란 모듈이 5.0으로 가면서 Pure ESM 모듈이 됐습니다. 이를 가져다 쓰면 다음과 같은 에러가 발생합니다.

```tsx
import chalk from 'chalk';
console.log(chalk.yellow('Hello'));
```

```
Error [ERR_REQUIRE_ESM]: require() of ES Module /a/node_modules/chalk/source/index.js from /a/a.ts not supported.
Instead change the require of index.js in /a/a.ts to a dynamic import() which is available in all CommonJS modules.
```

## ESM이란 무엇인가?

초기 JavaScript는 모듈 시스템이 없었습니다.
클라이언트쪽에서는 [Require.js](https://requirejs.org/)란 것이 많이 쓰였습니다.
한편 서버(Node.js)에서는 CommonJS가 적용되어 따로 발전을 했습니다.
라이브러리가 클라이언트, 서버를 모두 지원하기 위한 [패턴들이 개발](https://stackoverflow.com/questions/16521471/relation-between-commonjs-amd-and-requirejs)되어 적용됐던 기억이 나네요.
그후 [Browserify](https://browserify.org/), [webpack](https://webpack.js.org/) 같은 번들 시스템이 나오면서 CommonJS 쪽으로 통일되었습니다.

대부분의 경우 잘 동작하지만 뭔가 문제가 있으시까 새로운 시스템이 나왔겠죠? 상세한 히스토리는 잘 모르지만 제가 아는 CommonJS의 가장 큰 문제는 런타임에 모듈을 읽는 다는 것입니다.
다음 예를 보겠습니다.

```jsx
// a.js
console.log('a1');
console.log(require('./b').b);
console.log('a2');
exports.a = 1;

// b.js
console.log('b1');
console.log(require('./a').a);
console.log('b2');
exports.b = 2;
```

```bash
$ node a.js 
a1
b1
undefined
b2
2
a2
```

위의 예에서 보다시피 require는 그 줄에 다다를 때 실행됩니다.
순환 참조가 발생하는 경우(`require('./a')`) 모듈을 다시 읽지는 않습니다.
이때문에 주의를 기울이지 않으면 위 예처럼 모듈이 내보낸 값이 얻어지지 않는 문제가 발생할 수 있습니다.

TypeScript의 import문은 사실 require로 변환되는 코드이기 때문에 기존 컴파일 언어에 익숙하신 분이 보면 당황할만한 부분이 좀 있습니다.

```tsx
// a.ts
console.log('a1');
import { b } from './b';
console.log(b);
console.log('a2');
export const a = 1;

// b.ts
console.log('b1');
import { a } from './a';
console.log(a);
console.log('b2');
export const b = 2;
```

```
$ ts-node a.ts 
a1
b1
undefined
b2
2
a2
```

아마 이런 저런 이유 때문에 [ESM](https://nodejs.org/api/esm.html)이란 것이 나왔으리라 생각합니다.
(몇년전에 `.cjs`, `.mjs` 확장자 얘기가 나오는 글들 보면서 무슨 얘기가 진행되는 거야 라고 넘어간 기억이 있습니다.)

async/await 문법이 나온 이후에 가장 아쉬운 점 중 하나가 최상위 단계에서 await가 불가능하다는 것입니다.

```
$ cat a.js                                                                                                                                                                         1 ↵
await Promise.resolve(1);
$ node a.js 
/a/a.js:1
await Promise.resolve(1);
^^^^^

SyntaxError: await is only valid in async functions and the top level bodies of modules
```

따라서 함수를 만들거나 [IIFE](https://developer.mozilla.org/ko/docs/Glossary/IIFE)를 사용해야 했습니다.
이것은 CommonJS의 한계로 인한 것이고 ESM에서는 가능해졌습니다.
이런 이유도 있어서 CommonJS에서 ESM 모듈을 require 하는 것이 불가능합니다.
반대로 ESM 모듈에서 CommonJS 모듈을 읽는 것은 가능하지만 신경써야 할 것들이 있습니다.

이렇게 ESM이 만들어진 후에 Sindre Sorhus란 분이 [ESM 전환을 선언](https://blog.sindresorhus.com/get-ready-for-esm-aa53530b3f77)했습니다.
그리고 이 분이 만드는 많은 모듈들(예 [file-type](https://www.npmjs.com/package/file-type).
[npm 개인 홈](https://www.npmjs.com/~sindresorhus)에 들어가보면 1165개의 모듈에 관여하고 있다고 나오네요)이 [Pure ESM](https://gist.github.com/sindresorhus/a39789f98801d908bbc7ff3ecc99d99c) 모듈로 전환됐습니다.
Pure ESM은 모듈이 CommonJS/ESM 양쪽을 지원하도록 구성할 수도 있지만, 굳이 ESM만 제공한다는 뜻입니다.

문제는 CommonJS 프로젝트에서는 ESM 모듈을 불러오는 것이 불가능하다는 것에 있습니다.
따라서 프로젝트가 ESM으로 전환해야지만 Pure ESM 모듈을 사용할 수 있습니다.

## 무엇이 문제인가?

### TypeScript에서 원인 찾기

위 예제에서 다시 시작하겠습니다

```tsx
import chalk from 'chalk';
console.log(chalk.yellow('Hello'));
```

ts-node로 실행해보면 다음과 같은 에러가 발생합니다.

```
$ ts-node a.ts 
Error [ERR_REQUIRE_ESM]: require() of ES Module /a/node_modules/chalk/source/index.js from /a/a.ts not supported.
Instead change the require of index.js in /a/a.ts to a dynamic import() which is available in all CommonJS modules.
```

컴파일된 JavaScript 결과물을 보면 원인을 알 수 있습니다.

```jsx
"use strict";
exports.__esModule = true;
var chalk_1 = require("chalk");
console.log(chalk_1["default"].yellow('Hello'));
```

ESM 모듈은 require가 아니라 import를 해야 합니다.

### JavaScript에서 문제 해결

TypeScript가 아니라 JavaScript로 import 구문을 사용해 작성해 봅니다. 이번에는 다른 에러가 납니다.

```
$ cat a.js 
import chalk from 'chalk';
console.log(chalk.yellow('Hello'));
$ node a.js
(node:72179) Warning: To load an ES module, set "type": "module" in the package.json or use the .mjs extension.
/a/a.js:1
import chalk from 'chalk';
^^^^^^

SyntaxError: Cannot use import statement outside a module
```

파일명을 `.mjs`로 바꾸면 잘 실행됩니다.

```
$ node a.mjs 
Hello
```

파일명을 바꾸는 대신 전체 프로젝트를 ESM을 사용하는 것으로 선언할 수 있습니다. package.json에 `"type": "module"`을 추가합니다.

```
$ cat a.js 
import chalk from 'chalk';
console.log(chalk.yellow('Hello'));
$ cat package.json 
{
  "type": "module",
  "dependencies": {
    "chalk": "^5.0.1"
  }
}
$ node a.js 
Hello
```

또는 TypeScript 실행시 보여준 에러 처럼 dynamic import를 사용할 수 있습니다.

```
$ cat a.js 
(async () => {
  const chalk = await import('chalk');
  console.log(chalk.default.yellow('Hello'));
})();
$ node a.js 
Hello
```

정리하면 JavaScript에서 Pure ESM 모듈을 읽기 위해서는 다음 세가지 방법이 있습니다.

- `.mjs` 확장자 사용
- 전체 프로젝트를 ESM으로 전환
- dynamic import 사용

### TypeScript로 되돌아 가서

`.mts` 란 확장자도 인식하고, tsc로 컴파일 해보면 `.mjs`로 나오긴 하지만 적절한 변환은 안 됩니다.

dynamic import 구문을 사용해도 여전히 실행이 안 됩니다.
컴파일된 결과물을 보면 여전히 require로 변환이 됩니다.
이를 해결하려면 모듈시스템을 ES 것을 사용한다고 선언해야 합니다.
tsconfig에서 [module 설정](https://www.typescriptlang.org/tsconfig#module)을 적절히 해줘야 합니다.

```
$ cat a.ts 
(async () => {
  const chalk = await import('chalk');
  console.log(chalk.default.yellow('Hello'));
})();
$ cat tsconfig.json 
{
  "compilerOptions": {
    "target": "es2017",
    "module": "es2020",
    "moduleResolution": "node"
  }
}
$ ts-node a.ts 
Hello
```

import를 require로 변환하지 않고 그대로 두는 건 module 설정이지만, Node.js에서 import 구문을 이해하는 것을 별개입니다.
package.json에 `"type": "module"` 도 추가하면 일반 import 구문도 동작합니다.
ts-node로 실행시에는 `--esm` 옵션을 줘야 동작합니다.

```
$ cat a.ts 
import chalk from 'chalk';
console.log(chalk.yellow('Hello'));
$ cat package.json 
{
  "type": "module",
  "dependencies": {...}
}
$ ts-node --esm a
Hello
$ tsc --module es2020 
$ cat a.js
import chalk from 'chalk';
console.log(chalk.yellow('Hello'));
```

## 실전 적용

이제 ESM의 동작 원리에 대해 약간 감이 옵니다. (저는 이 글을 쓰면서 정리하는데도 아직도 헷갈립니다) 이제 실전 적용을 해봅니다.

JavaScript에서는 require와 dynamic import를 혼합해서 쓸 수 있습니다.
다시 말해 ESM 전환(`"type": "module"`)을 하지 않아도 ESM 모듈을 쓰는 것이 가능합니다.
(static import가 안 되므로 코드를 다르게 작성하는 불편함은 있습니다.)

하지만 TypeScript에서는 import를 require로 변환 또는 모드 import로 유지, 두 가지 선택지 밖에 없습니다.
require로는 ESM 모듈을 쓸 수 없으므로 import 유지(`"module": "es2020"`)를 해야 합니다.
이 경우 Node.js에서 import 구문을 사용하므로 ESM 전환(`"type": "module"`)도 해야 합니다.

단순히 import 구문만 쓰면 되는게 아닙니다.
[불러올 파일의 확장자를 모두 기술](https://nodejs.org/api/esm.html#mandatory-file-extensions)해줘야 합니다.
TypeScript 임에도 불구하고 `.js` 확장자를 써줘야 합니다.
또 저는 디렉토리명으로 import 하는 것을 종종 사용하는데 모두 파일명으로 바꿔줘야 합니다.
(`from './services' → from '.services/index.js'`) 이 과정을 도와주는 도구([fix-esm-import-path](https://www.npmjs.com/package/fix-esm-import-path))도 있습니다.

샘플로 만들어본 프로젝트에서는 이걸로 동작했습니다.
하지만 실제 프로젝트로 가니 또 다른 이슈가 있었습니다.
`__dirname` 을 쓸 수 없다고 해서 변환을 해야 했습니다.
(예 `loadSchemaSync(join(__dirname, './index.graphql')`)

이제 컴파일도 되고 구동해봅니다. 안 됩니다. ESM 모듈에서는 require 구문을 쓰는게 아예 안 됩니다.

```
$ node a.js 
file:///a/a.js:1
const http = require('http');
             ^

ReferenceError: require is not defined in ES module scope, you can use import instead
This file is being treated as an ES module because it has a '.js' file extension and '/a/package.json' contains "type": "module". To treat it as a CommonJS script, rename it to use the '.cjs' file extension.
```

그런데 저희 주요 프로젝트 구조에는 TypeScript 내에서 require를 의존하는 곳이 있습니다.

```jsx
// tools/server.js
process.env.TZ = 'Etc/UTC';
require('ts-node/register/transpile-only');
require('../app/server');

// config/index.ts
function loadConfig<T>(dir: string, env?: string): T {
  const base = cloneDeep(require(`${dir}/default`).default as T);
  ...
  return base;
}
```

다른 건 몰라도 config는 당장 고치기 어려워 보였습니다.
또 즐겨쓰고 있는 [REPL](https://github.com/croquiscom/rinore)도 제대로 동작을 안 하는 건 좀 심각했습니다.

## 그래서 해결책은?

결국 이 이상 시간을 쏟기는 어려워서 어플리케이션을 ESM 모드로 전환하는 것은 포기했습니다.
하지만 ESM 모듈은 여전히 필요했습니다.

다행히 이번에 조사할 때는 저번에 찾지 못했던 [회피 방법](https://github.com/TypeStrong/ts-node/discussions/1290)을 찾았습니다.
TypeScript가 변환하지 않도록 import 문을 감추는 것입니다.

```jsx
new Function('specifier', 'return import(specifier)')
```

[eval도 가능](https://stackoverflow.com/a/70546326/3239514)하다는데 테스트해보진 않았습니다.

다만 위 코드보다는 라이브러리를 활용하는 솔루션이 더 직관적인 것 같아서 이 방법을 사용했습니다.
[tsimportlib](https://www.npmjs.com/package/tsimportlib) 라이브러리를 사용하면 됩니다.

아쉬운 대로 동작합니다만 나중에 프로젝트가 ESM으로 전환됐을 때 dynamic import를 static import로 바꿔줘야 할 것 같아 꼭 필요한 곳에만 쓰는 것으로 생각하고 있습니다.

다행히 dynamic import는 서버에서만 필요했고, 프론트엔드 코드에서는 Next.js등이 잘 처리해주는지 static import로도 잘 동작했습니다.

## 마무리

개인적인 느낌으로 ESM은 Python2 → Python3를 전환시의 혼란을 보는 것 같습니다.
저를 포함해 많은 사람들이 당황해하고 불만을 터트리네요

![[https://github.com/sindresorhus/meta/discussions/15#discussioncomment-2495719](https://github.com/sindresorhus/meta/discussions/15#discussioncomment-2495719)](/img/content/2022-04-09-1/2022-04-09-1-01.png)
[https://github.com/sindresorhus/meta/discussions/15#discussioncomment-2495719](https://github.com/sindresorhus/meta/discussions/15#discussioncomment-2495719)

하지만 좋은 싫든 ESM으로의 전환은 시작된 것 같습니다.
조금 더 생태계가 안정되면 다시 전환 시도를 해야 할 것 같습니다.

## Appendix

- [Modules: ECMAScript modules | Node.js Documentation](https://nodejs.org/api/esm.html)
- [JavaScript modules - JavaScript | MDN](https://developer.mozilla.org/ko/docs/Web/JavaScript/Guide/Modules)
- [Node Modules at War: Why CommonJS and ES Modules Can’t Get Along](https://redfin.engineering/node-modules-at-war-why-commonjs-and-es-modules-cant-get-along-9617135eeca1) ([번역](https://roseline.oopy.io/dev/translation-why-cjs-and-esm-cannot-get-along), [요약](https://yceffort.kr/2020/08/commonjs-esmodules))
- [Pure ESM package](https://gist.github.com/sindresorhus/a39789f98801d908bbc7ff3ecc99d99c)
- [Get Ready For ESM. JavaScript Modules will soon be a… | by Sindre Sorhus | 🦄 Sindre Sorhus’ blog](https://blog.sindresorhus.com/get-ready-for-esm-aa53530b3f77)
- [ES Modules in NodeJS - Troubleshooting Resources](https://docs.joshuatz.com/cheatsheets/node-and-npm/node-esm/)
- [Dynamic \`import()\` with \`"module": "commonjs"\`](https://github.com/TypeStrong/ts-node/discussions/1290)
- [CommonJS vs native ECMAScript modules | ts-node](https://typestrong.org/ts-node/docs/imports/)
- [tsimportlib](https://www.npmjs.com/package/tsimportlib)
