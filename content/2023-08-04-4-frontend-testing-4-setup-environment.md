---
title: '프론트엔드 테스트 자동화 전략 - 4. 테스트 환경 구성'
tags: ['Frontend', 'Testing']
date: 2023-08-04T04:00:00
author: Martin(유덕남)
---

이전 글에서는 테스트 전략과, 테스트를 작성하는 방법들에 대해서 알아봤습니다. 하지만, 테스트를 실행하는 환경에 대해서는 스토리북을 사용한다고 가정했을 뿐, 구체적인 이야기를 진행하지는 않았습니다.

이번 글에서는, 테스트 프레임워크를 활용해서 테스트를 자동으로 실행할 수 있는 환경을 구성하는 방법에 대해 알아보겠습니다.

설명하는 내용의 특성상, 개념적인 이야기보다는 설정 파일에 대한 내용이 더 많습니다. 정독하는 것보다는, 실제로 테스트 환경을 구성하면서 매뉴얼 개념으로 읽어보시는게 더 효과적일 것이라 생각합니다.

<!--more-->

## 개요

테스트 프레임워크는 테스트에 필요한 여러 함수들과 실행 환경을 만들어주고, 프로젝트에 존재하는 테스트 코드를 모아서 실행해줍니다. 모든 테스트를 실행한 뒤 결과를 제공해줘서, 코드에 어떤 이슈가 있는지 바로 확인할 수 있습니다.

GitHub Actions는 PR이 올라오거나, 커밋이 푸시될 때마다 테스트를 실행해줘서, 배포하거나 머지하기 전에 문제가 없는지 자동으로 체크할 수 있습니다.

특히, 자동으로 테스트를 실행함으로써 지속적인 통합과 배포(CI/CD)를 안정적으로 구현할 수 있습니다. 코드 변경 사항이 발생하면 GitHub Actions를 통해 자동으로 테스트가 실행되고, 테스트 결과를 통해 변경 사항의 유효성을 검증할 수 있습니다. 이를 통해 빠른 피드백을 받을 수 있고, 프로젝트의 품질을 유지하면서 안정적인 배포를 실현할 수 있습니다.

## 테스트 프레임워크의 종류

프론트엔드에서 테스트 프레임워크는 크게 JS 테스트 프레임워크, E2E 테스트 프레임워크 둘로 나누어집니다.

JS 테스트 프레임워크는 실제 브라우저를 띄우지 않고, jsdom과 같이 브라우저를 흉내내는 도구를 사용해 Node.js 기반으로 실행되는 테스트 프레임워크입니다. 브라우저를 사용하지 않기 때문에 테스트를 진행하는 속도가 매우 빠릅니다. 하지만, webpack 등 번들러 설정과 별개로 빌드 환경을 세팅해야 하고, 웹 브라우저 API를 모킹해야 한다는 단점이 있습니다.

E2E 테스트 프레임워크는 이미 빌드된 프로젝트를 웹 브라우저에서 실제로 띄워서, 사용자의 동작을 흉내내는 식으로 테스트를 수행합니다. 이미 구성된 빌드 환경을 사용하고, 그 위에서 테스트를 진행하기 때문에 구성하는 과정이 쉬운 편입니다. 하지만 실제로 웹 브라우저를 띄우기 때문에, JS 테스트 프레임워크보다는 느린 편입니다.

이렇게 둘의 특성이 크게 갈리기 때문에, 개발 난이도나, 테스트 정확도, 테스트 시간을 고려해서 선택이 필요합니다.

## 테스트 프레임워크

### storybook/test-runner

[storybook/test-runner](https://github.com/storybookjs/test-runner)는 웹 브라우저를 실제로 띄워서, 스토리북의 스토리를 하나씩 실행해보는 테스트 실행 도구입니다. 스토리북 설정을 그대로 사용할 수 있어서, 설정하기는 정말 간단합니다.

기존에 빌드해둔 스토리북에 의존하기 때문에, 스토리북 빌드를 진행하거나, 스토리북 서버를 띄운 상태에서 테스트를 진행해야 한다는 특징이 있습니다.

- `npm install @storybook/test-runner --save-dev` 로 설치를 진행하고,
- `npm run storybook` 으로 스토리북 서버를 켠 뒤
- `npx test-storybook --url http://localhost:7001` 과 같이 서버에 접속해서 테스트를 진행하도록 실행만 해주면 됩니다.

설정은 매우 쉽지만, [playwright](https://playwright.dev/) (E2E 테스트 프레임워크)를 사용해서 웹 브라우저를 띄워서 테스트를 돌리기 때문에, 성능이 느릴 수 있습니다.

특히 CPU와 메모리를 크게 사용하기 때문에 (메모리를 32GB 넘게 사용하는 일도 많습니다), 문제가 되는 경우 `--maxWorkers 4` 와 같은 옵션을 지정해서 동시 실행 개수를 제한해야 합니다.

속도 문제가 체감이 되지 않는다면, storybook/test-runner를 사용하는 것이 제일 쉽고 빠르기 때문에 권장하고 싶습니다. `--watch` 모드를 사용한다면 변경된 부분만 다시 실행할 수 있기 때문에 성능 이슈를 크게 줄일 수 있습니다.

### jest

[jest](https://jestjs.io/)는 자바스크립트 개발에서 제일 많이 쓰이는 테스트 프레임워크입니다. vitest 등 여러 대체제가 있지만, 현재로써는 가장 인기 있고, 성능이 좋기 때문에 jest를 검토해봤습니다.

jest는 별도로 테스트 환경 설정이 필요한데, 설정에서 webpack과 다른 개념이 많기 때문에 조금 난이도가 있는 편입니다.

- webpack에서 쓰이는 loader (`ts-loader`, `babel-loader`, …)같은 개념이 jest에는 없기 때문에 이런 내용들을 mock 파일로 대체하거나, 별도의 transformer를 설치하는 작업이 필요합니다.
  - https://jestjs.io/docs/webpack 도 참고해주세요.
- 실제 웹 브라우저를 사용하지 않기 때문에 브라우저 환경에 있는 기능들을 전부 다시 구현해야 합니다. `jsdom`이 이런 역할을 어느정도 수행해주지만, jsdom이 처리해주지 않는 API들은 별도로 구현해야 하기 때문에 번거롭습니다.
- jest 자체적으로도 이런저런 버그가 많기 때문에 우회할 수 있는 방법을 찾아봐야 합니다. 대표적으로 Node.js 특정 버전 이후로 메모리가 계속 샌다는 이슈가 있고, jest는 이를 우회하기 위해서 테스트 프로세스를 주기적으로 재시작하는 기능을 가지고 있습니다.

Next.js에서도 jest를 위한 설정을 제공하고 있으므로, Next.js 프로젝트를 사용한다면 참고해주세요. ([#](https://nextjs.org/docs/app/building-your-application/testing/jest))

파트너센터 프로젝트에서는 테스트 코드가 상당히 많아서, `@storybook/test-runner`로는 로컬에서 테스트가 10분-15분 이상 소요되는 일도 잦았기 때문에, 성능이 제일 좋은 jest를 사용해서 스토리북 테스트를 진행하기로 했습니다.

### vitest

[vitest](https://vitest.dev/)는 vite의 설정을 그대로 사용할 수 있는 테스트 프레임워크입니다. 비록 프로젝트에서 vite를 사용하고 있지는 않지만, jest보다는 설정이 훨씬 간편하고, jest가 가지고 있는 버그들도 없기 때문에 검토해봤습니다.

하지만, jest보다 3배정도 느려서, 성능 차이가 꽤 났기 때문에, jest를 그대로 사용하기로 했습니다.

## jest 테스트 작성

jest 테스트 작성 방법은 `describe`, `it`, `expect` 등을 사용해서 작성할 수 있는데, 관련된 내용은 기존 글에서 이미 다뤘기 때문에 넘어갑니다.

jest와 react-testing-library를 사용하면 아래와 같이 스토리북을 그대로 실행하는 테스트를 작성할 수 있습니다. 이런 방법을 통해서 별도로 .test.tsx를 작성하지 않고 스토리북을 테스트하는 환경을 구성할 수 있다면, 별다른 작업 없이도 테스트 자동화가 가능해서 유용할 것이라고 생각했습니다.

```tsx
// Main.test.tsx
import { composeStories } from '@storybook/testing-react';
import { render } from '@testing-library/react';
import React from 'react';
import * as file from './Main.stories';

const stories = composeStories(file);

describe('Main', () => {
  Object.entries(stories).forEach(([key, Story]) => {
    it(Story.storyName ?? key, async () => {
      const { container, unmount } = render(<Story />);
      try {
        if (Story.play != null) {
          await Story.play?.({ canvasElement: container, args });
        }
      } finally {
        unmount();
      }
    });
  });
});
```

## jest 환경 구성하기

먼저, 아래 명령으로 jest에서 사용할 여러 패키지들을 설치하고 설정 파일을 생성합니다.

```bash
npm install jest jest-environment-jsdom ts-jest@types/jest --save-dev
npm install @testing-library/jest-dom @testing-library/react @testing-library/user-event --save-dev
npx jest --init
```

### moduleNameMapper

빌드가 정상적으로 이루어지게 하기 위해서는 웹팩과 비슷한 빌드 환경을 구성해야 합니다.

많은 프로젝트에서 TypeScript의 alias 기능을 사용하고 있을텐데요, ts-jest에서 제공하는 `pathsToModuleNameMapper` 를 사용하면 tsconfig.json을 읽어서 자동으로 alias에 대응하는 설정을 생성해줍니다.

또한, 웹팩에서는 .png, .jpg, .css와 같은 파일을 그대로 import해올 수 있는데, jest는 Node.js 기반으로 돌아가기 때문에 기본적으로는 불가능합니다. 따라서, 이런 확장자가 감지되면 fileMock.js가 대신 로딩되도록 이름을 바꿔주어야 합니다.

```tsx
// jest.config.js
const { pathsToModuleNameMapper } = require('ts-jest');
module.exports = {
  moduleNameMapper: {
    '\\.(jpg|jpeg|png|gif|eot|otf|webp|svg)$': '<rootDir>/mocks/fileMock.js',
    '\\.(css|scss)$': '<rootDir>/mocks/fileMock.js',
    ...pathsToModuleNameMapper(compilerOptions.paths),
  },
};

// fileMock.js
module.exports = '';
```

### babel / swc

이어서, JSX와 import/export 문법을 사용할 수 있도록 babel이나 swc를 사용해야 합니다. swc가 babel에 비해 훨씬 빠르지만, emotion 플러그인을 사용하는 경우에는 ARM 기반 맥에서 오류가 발생하고 있어서, 분기 처리를 해두었습니다.

- `npm install @swc/core @swc/helpers @swc/jest @swc/plugin-emotion babel-jest --save-dev`

```tsx
// jest.config.js
module.exports = {
  transform: {
    // ARMv8에서 @swc/jest가 제대로 동작하지 않는 이슈 존재
    '.+\\.(t|j)sx?$': process.arch === 'arm64' ? ['babel-jest', { configFile: './.babelrc.json' }] : '@swc/jest',
  },
};

// .babelrc.json
{
  "presets": [
    [
      "@babel/preset-env",
      {
        "useBuiltIns": "usage",
        "corejs": 3
      }
    ],
    "@babel/preset-react",
    "@babel/preset-typescript"
  ],
  "plugins": [["@emotion", { "autoLabel": "always" }]]
}

// .swcrc
{
  "$schema": "https://json.schemastore.org/swcrc",
  "jsc": {
    "parser": {
      "syntax": "typescript",
      "tsx": true,
      "decorators": true,
      "dynamicImport": false
    },
    "target": "es5",
    "externalHelpers": true,
    "experimental": {
      "plugins": [["@swc/plugin-emotion", {}]]
    }
  },
  "minify": false
}
```

### jsdom과 브라우저 모킹

이어서, jest에서 React 컴포넌트 테스트를 진행하려면 브라우저 환경을 흉내낼 수 있어야 합니다.

jsdom이 대부분의 브라우저 API를 제공해주긴 하지만, 추가로 필요한 내용들은 테스트 환경이 구성될 때마다 실행되는 파일인 `mocks/setupJest.ts` 에 넣어두었습니다.

```tsx
// jest.config.js
module.exports = {
  testEnvironment: 'jsdom',
  setupFilesAfterEnv: ['<rootDir>/mocks/setupJest.ts'],
};
```

이제, 앱에서 사용하는 다른 API 목들과, 필요한 설정들을 `setupJest.ts` 안에 구성합니다. 아래는 프로젝트에서 필요한 내용을 하나씩 구성한 것이기 때문에, 만약 아래 내용이 없어도 정상적으로 동작한다면 빼도 무방합니다.

- https://github.com/trurl-master/jsdom-testing-mocks
- https://github.com/hustcc/jest-canvas-mock
- https://github.com/dumbmatter/fakeIndexedDB
- `npm install jsdom-testing-mocks jest-canvas-mock fake-indexeddb --save-dev`

```tsx
// mocks/setupJest.ts
import { mockViewport, mockIntersectionObserver, mockResizeObserver } from 'jsdom-testing-mocks';
import { initialize } from 'msw-storybook-addon';
import { setGlobalConfig } from '@storybook/testing-react';

import 'regenerator-runtime/runtime';
import 'whatwg-fetch';
import 'fake-indexeddb/auto';
import 'jest-canvas-mock';
import '@testing-library/jest-dom';

import * as sbConfig from './sbConfig';

mockViewport({ width: '1280px', height: '1024px' });
mockIntersectionObserver();
mockResizeObserver();

// ref: https://jestjs.io/docs/manual-mocks#mocking-methods-which-are-not-implemented-in-jsdom
// ref: https://github.com/jsdom/jsdom/issues/2524
Object.defineProperty(window, 'TextEncoder', {
  writable: true,
  value: util.TextEncoder,
});
Object.defineProperty(window, 'TextDecoder', {
  writable: true,
  value: util.TextDecoder,
});

window.Element.prototype.scrollIntoView = jest.fn();
window.Element.prototype.scrollTo = jest.fn();
window.URL.createObjectURL = jest.fn(() => '');
window.URL.revokeObjectURL = jest.fn();

initialize();

setGlobalConfig(sbConfig);

beforeEach(() => {
  // 스토리북 내부에서는 비동기 API (await findByText()) 을 전제하기 때문에
  // act를 사용하지 않아도 괜찮으므로 경고 메시지를 제거합니다.
  (global as any).IS_REACT_ACT_ENVIRONMENT = false;
  document.getElementsByTagName('html')[0].innerHTML = '';
});

// mocks/sbConfig.tsx
// 테스트 환경에서 사용할 스토리북 전역 설정을 여기에 추가합니다.
export const parameters = [];
export const decorators = [];
```

만약 i18next를 사용하는 경우에는 번역 데이터에 영향받지 않도록, 아래와 같이 CI 모드로 변경하는 것을 권장합니다.

```tsx
// mocks/setupJest.ts
import i18next from 'i18next';
import { initReactI18next } from 'react-i18next';

i18next.use(initReactI18next).init({
  lng: 'cimode',
  fallbackLng: false,
});
```

### require.context 대응

웹팩에서는 프로젝트 디렉터리에서 조건에 맞는 모든 파일들을 가져올 수 있게 하는 [require.context](https://webpack.js.org/guides/dependency-management/#requirecontext) 라는 기능을 지원하고 있습니다. 만약 require.context를 사용하고 있다면, jest에서는 제공하지 않는 기능이기 때문에, 사용하는 쪽에서 분기 처리가 필요합니다.

```tsx
// Webpack 환경과 Node.js 환경 모두 대응이 필요하고, Webpack의 경우 'require.context' 내부의
// 정규표현식을 코드에 같이 묻어두어야 하기 때문에 별도로 함수로 분리할 수가 없었습니다.
if (typeof __webpack_require__ === 'function') {
  const fixtures_context = require.context('..', true, /^\.\/(?!node_modules)[^/]+\/.+\.fixtures\.tsx?$/i);
  fixtures_context.keys().forEach((filename) => {
    const imported = fixtures_context(filename);
    processFixtureFile(imported);
  });
} else {
  // Webpack에서는 'require' 함수 호출을 모두 감지해서 조건에 맞는 파일을 모두 번들링하기 때문에,
  // require('../' + filename) 패턴을 인식해서 프로젝트에 있는 모든 파일을 번들링하게 됩니다!
  // 이쪽 코드는 Node.js 환경에서만 실행될 것을 알기 때문에, eval을 통해서 Webpack이 처리할 수 없도록
  // 막았습니다.
  const glob = eval('require')('glob');
  const path = eval('require')('path');
  const files = glob.sync('**/*.fixtures.{ts,tsx}', {
    cwd: path.resolve(__dirname, '..'),
  });
  files.forEach((filename) => {
    const imported = eval('require')('../' + filename);
    processFixtureFile(imported);
  });
}
```

### jest 메모리 누수

Node.js 16.10 버전 이후로 jest에서 메모리가 누수되는 문제가 있는데, 해결되지 않은 상태기 때문에 jest에서는 메모리 사용량이 특정 용량을 넘어가면, 워커 프로세스를 재시작하는 옵션을 제공합니다. ([#](https://github.com/jestjs/jest/issues/11956))

> (2024.07.19) Node.js 20.10.0에서 수정되었습니다.

```tsx
// jest.config.js
module.exports = {
  // https://github.com/jestjs/jest/issues/11956
  workerIdleMemoryLimit: '1G',
};
```

### .stories.tsx를 테스트로 자동으로 변환하기

이렇게 해서 jest 환경 구성까지는 마쳤는데, 현재로써는 스토리북 파일 (`stories.tsx`) 마다 테스트 파일 (`test.tsx`)을 따로 만들어야 하기 때문에 번거롭다고 생각했습니다.

그래서, `.stories.tsx` 를 자동으로 테스트로 변환시킬 수 있는 방법을 찾아봤습니다.

먼저, testMatch를 수정해서 `stories.tsx` 도 테스트 파일로 잡히도록 수정합니다.

```tsx
// jest.config.js
module.exports = {
  testMatch: ['**/__tests__/**/*.[jt]s?(x)', '**/?(*.)+(spec|test).[tj]s?(x)', '**/?(*.)+(stories).[tj]s?(x)'],
};
```

그 뒤에, jest의 transformer 기능을 사용해서, `.stories.tsx`를 읽었을 때 babel을 돌린 뒤 `runStorybookTests` 함수를 실행해서 테스트로 변환하도록 작업했습니다.

```tsx
// mocks/sbTransformer.js
const { createTransformer: babelCreateTransformer } = require('babel-jest');

function createTransformer(userOptions) {
  const babel = babelCreateTransformer(userOptions);
  return {
    process(sourceText, sourcePath, config, options) {
      const babelResult = babel.process(sourceText, sourcePath, config, options);
      // babel-jest에서 반환한 결과를 꺼내서 변환
      const testCode = `"use strict";
var _exportValues = (function (exports) {
${babelResult.code}
return exports;
})({});

Object.assign(exports, _exportValues);
require('mocks/sbTest').runStorybookTests(_exportValues);
`;
      return { code: testCode };
    },
  };
}

module.exports = { createTransformer };

// mocks/sbTest.ts
export function runStorybookTests(file: any): void {
  // 후술
}

// jest.config.js
module.exports = {
  transform: {
    '.+\\.stories\\.(t|j)sx?$': '<rootDir>/mocks/sbTransformer.js',
  },
};
```

하지만, 이 방식을 통해 스토리북 파일을 테스트로 바꾸게 된다면, `test.tsx`에서 `stories.tsx`를 임포트할 때에도 스토리북의 내용이 테스트로 등록된다는 점은 유의해야 합니다.

```tsx
// Component.test.tsx
// 단순히 임포트를 했을 뿐인데, 스토리북의 스토리들이 알아서 테스트로 바뀝니다!
import * as Stories from './Component.stories';

describe('Component', () => {
  // ...
});
```

### 스토리북 jest 환경의 한계

스토리북에서는 [react-docgen-typescript-plugin](https://www.npmjs.com/package/@storybook/react-docgen-typescript-plugin) 이라는 웹팩 플러그인을 사용해서 컴포넌트의 타입 정보를 자동으로 얻어옵니다.

이는 스토리북에서 controls나 타입 정보를 표시하는 것뿐만 아니라, `onClick` 과 같은 prop에 자동으로 mock 함수를 집어넣는데도 사용됩니다.

하지만 jest에서는 이 웹팩 플러그인을 사용할 수 없기 때문에, mock 함수를 자동으로 넣어줄 수 없습니다. mock 함수가 누락되면 스토리가 정상적으로 실행되지 않는 경우도 많기 때문에, jest로 스토리북을 실행하려면 해결이 필요했습니다.

여러 방법을 찾아보았지만, 간단한 해결책은 보이지 않아서, `.stories.tsx` 에 `argTypes` 를 사용해서 함수가 필요함을 나타내도록 했습니다. 또한, 테스트 실행이 불가능한 경우 `skipTest` parameter를 사용해서 건너뛸 수 있도록 했습니다.

```tsx
// Component.stories.tsx
export default {
  component: Component,
  argTypes: {
    // 이렇게 명시적으로 onClose prop이 action (콜백 함수)임을 나타냅니다.
    // 모든 스토리북에서 관련된 작업이 필요합니다!
    onClose: { action: 'onClose' },
  },
  parameters: {
    // 스토리북의 테스트가 불가능한 경우 이렇게 parameters에 skipTest를 추가해서
    // 테스트를 건너뜁니다.
    skipTest: true,
  },
} as ComponentMeta<typeof Component>;

// mocks/sbTest.tsx
Object.entries(file.default.argTypes ?? {}).forEach(([key, value]) => {
  if ((value as any)?.action != null) {
    args[key] = jest.fn();
  }
});
```

이를 모두 종합하면, sbTest.tsx는 아래와 같은 코드를 가지고 있습니다.

```tsx
// mocks/sbTest.tsx
import { composeStories } from '@storybook/testing-react';
import { cleanup, render } from '@testing-library/react';
import React from 'react';

export function runStorybookTests(file: any): void {
  const name = file.default?.title ?? file.default?.component?.displayName ?? file.default?.component?.name;
  const stories = composeStories(file);

  describe(name, () => {
    Object.entries(stories).forEach(([key, Story]: [string, any]) => {
      if (Story.parameters.skipTest) {
        it.skip(Story.storyName ?? key, () => {});
        return;
      }
      it(Story.storyName ?? key, async () => {
        const args = {
          ...Story.args,
        };
        Object.entries(file.default.argTypes ?? {}).forEach(([key, value]) => {
          if ((value as any)?.action != null) {
            args[key] = jest.fn();
          }
        });
        try {
          const { container, unmount } = render(<Story {...args} />);
          try {
            if (Story.play != null) {
              await Story.play?.({ canvasElement: container, args });
            }
          } finally {
            unmount();
          }
        } finally {
          cleanup();
        }
      });
    });
  });
}
```

### 설정 마무리

이렇게 하면 jest 환경 구성과, 스토리북 테스트 구성이 모두 완료됩니다. 상당히 설정할 내용이 많았습니다!

마지막으로, `npm test`를 실행했을 때 `jest`가 실행되도록 `package.json`만 변경해주면 마무리됩니다.

```jsx
// package.json
{
  "scripts": {
    "test": "jest"
  }
}
```

이렇게 구성했을 때, 로컬에서 테스트를 돌리면 2분 (120초) 내외로 모든 테스트가 완료되는걸 볼 수 있었습니다. 이외에도, `--watch` 모드를 사용하면 수정된 내용에 관련된 테스트만 다시 돌릴 수 있어서 성능 향상에 도움이 됩니다.

## GitHub Actions 구성

이렇게 테스트를 `npm test`를 통해 자동으로 돌릴 수 있는 환경이 구성되었으면, 이제 GitHub Actions와 같은 CI 환경에서 실행해서, PR이 올라오거나 커밋이 푸시될 때마다 테스트를 실행할 수 있습니다.

설정도 매우 간단해서, 이미 사용하고 있던 GitHub Actions 설정이 있다면 `npm test`를 실행하도록 바꿔주기만 하면 끝납니다.

하지만 성능 문제가 심각한 편입니다. GitHub Actions에서 제공해주는 컴퓨터는 CPU를 2쓰레드밖에 제공해주지 않기 때문에, 로컬에서는 2분으로 끝날게 거의 30분 가까이 걸리게 됩니다. 더 성능이 좋은 인스턴스를 사용하는 옵션은 아직 베타라서 사용하기가 어려웠습니다. ([#](https://docs.github.com/en/actions/using-github-hosted-runners/using-larger-runners))

> (2024.07.19) 현재는 공개적으로 사용가능합니다. 이와 별개로 카카오스타일에서는 현재 GitHub가 제공하는 러너 대신 자체 러너를 사용해 상황에 맞출 수 있게 됐습니다. 그럼에도 불구하고 한계는 있어 아래 내용이 여전히 의미가 있습니다.

대신, jest를 포함한 여러 프레임워크들은 `shard`라는 기능을 제공합니다. 테스트를 원하는 개수로 나눠서, 각 컴퓨터에서 shard를 실행하면 모든 테스트가 수행되는 식으로 병렬화를 가능하게 해줍니다.

즉, 아래 명령을 3대의 컴퓨터에서 하나씩 동시에 실행하면, 프로젝트 전체에 대해서 테스트가 완료되는 구조입니다.

```bash
npm test -- -w 2 --shard=1/3
npm test -- -w 2 --shard=2/3
npm test -- -w 2 --shard=3/3
```

또한, GitHub Actions에서는 [matrix](https://docs.github.com/en/actions/using-jobs/using-a-matrix-for-your-jobs)라는 기능을 지원합니다. 이 기능을 사용하면 동일한 GitHub Actions 스크립트를 서로 다른 설정으로 병렬로 돌릴 수 있게 해줍니다.

![1.png](/img/content/2023-08-04-4/1.png)

shard와 matrix를 사용해서, 아래와 같이 GitHub Actions을 8병렬로 돌리게 설정했습니다.

```tsx
jobs:
  prepare-cache:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v3
      - name: Setup Node.js
        uses: actions/setup-node@v3
        with:
          node-version: '16.x'
      - name: Compute cache key
        id: cache-key
        run: echo "key=${{ runner.os }}-node-test-${{ hashFiles('package-lock.json') }}" >> $GITHUB_OUTPUT
      - name: Cache node modules
        id: cache-modules
        uses: actions/cache@v3
        with:
          path: |
            node_modules
          key: ${{ steps.cache-key.outputs.key }}
          restore-keys: |
            ${{ runner.os }}-node-test-
      - name: Install packages
        if: steps.cache-modules.outputs.cache-hit != 'true'
        run: npm install
    outputs:
      cache-key: ${{ steps.cache-key.outputs.key }}
	test-jest:
	  runs-on: ubuntu-latest
	  needs: prepare-cache
	  strategy:
	    fail-fast: false
	    matrix:
	      shard: [1, 2, 3, 4, 5, 6, 7, 8]
	  steps:
	    - name: Checkout
	      uses: actions/checkout@v3
		  - name: Setup Node.js
	      uses: actions/setup-node@v3
	      with:
	        node-version: '16.x'
	    - name: Cache node modules
	      id: cache-modules
	      uses: actions/cache/restore@v3
	      with:
	        path: |
	          node_modules
	        key: ${{ needs.prepare-cache.outputs.cache-key }}
	    - name: Run tests
	      run: npm test -- -w 2 --shard=${{ matrix.shard }}/${{ strategy.job-total }}
```

이렇게 matrix를 사용하면 30분 가까이 걸리던 CI 테스트를 5분 안에 마칠 수 있게 됩니다.

비용 이슈를 고민해봤을 때도, 8대를 3분씩 돌리는 것과 1대를 24분씩 돌리는 것의 비용 차이가 없기 때문에, 이렇게 쪼개서 진행해도 문제가 없다고 생각했습니다.

## 코드 커버리지

마지막으로, 테스트 프레임워크들은 보통 코드 커버리지 기능을 지원합니다. 이를 사용하면 테스트 코드가 구체적으로 소스 코드의 어떤 부분을 실행했는지를 측정해줍니다.

![2.png](/img/content/2023-08-04-4/2.png)

위 예시에서는 `resolveString`의 위쪽 부분은 202회 실행되었지만, 아래쪽 부분은 실행이 되지 않아서 빨간색으로 표시된 것을 볼 수 있습니다. 이런 식으로, 소스 코드에서 if문이나, 함수 실행 등을 자세히 추적해서 어느 부분의 테스트가 누락되었는지 구체적으로 볼 수 있도록 해줍니다.

jest도 커버리지를 지원하기 때문에, `npm test -- --coverage` 를 통해서 바로 코드 커버리지를 생성할 수 있고, `lcov-report` 의 `index.html` 을 보고 구체적으로 코드에서 누락된 부분을 분석할 수 있습니다.

GitHub Actions을 사용한다면, [jest-coverage-report-action](https://github.com/ArtiomTr/jest-coverage-report-action)을 사용하면 PR을 올렸을 때 댓글로 커버리지를 자동으로 남겨주도록 구성할 수도 있습니다.

![3.jpg](/img/content/2023-08-04-4/3.jpg)

하지만 위처럼 샤딩을 사용하는 경우에는 설정이 복잡합니다. 샤딩에서 사용하고자 하신다면 다음 코멘트를 참고해주세요. ([#](https://github.com/ArtiomTr/jest-coverage-report-action/issues/286#issuecomment-1427038607))

## 마치며

설정할 내용이 많아서 꽤 길었지만, 이렇게 해서 jest 환경을 구성하고, 스토리북 테스트를 돌릴 수 있도록 구성했습니다. 또한 GitHub Actions으로 jest를 실행할 수 있도록 구성했고, 샤딩을 통해 분산 처리가 가능하도록 했습니다. 이를 통해 프로젝트에서 테스트를 작성하고, 필요할 때마다 실행해서 프로젝트가 잘 동작하는지 자동으로 확인할 수 있습니다.

이렇게 해서, 테스트 작성에 대해서 전반적인 내용을 다뤄봤습니다.

- 테스트를 하는 이유, 테스트의 방향성과 전략
- 테스트 설계 방법과, 테스트 작성 방법
- 테스트 자동화 환경 구성하기

이 글들을 통해서 테스트에 대해서 고민해보는 기회가 되었으면 좋겠고, 테스트를 통해서 제품의 품질을 높이고, 디버깅이나 테스트하는데 드는 시간을 아껴볼 수 있으셨으면 좋겠습니다.

감사합니다.
