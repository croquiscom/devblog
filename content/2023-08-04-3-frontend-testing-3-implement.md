---
title: '프론트엔드 테스트 자동화 전략 - 3. 구현하기'
tags: ['Frontend', 'Testing']
date: 2023-08-04T03:00:00
author: Martin(유덕남)
---

이전 글에서는 제품의 요구사항을 분석하며, 테스트 케이스를 산출하는 방법에 대해 알아봤습니다. 이 글에서는 구체적으로 어떻게 테스트 코드를 작성할 수 있는지에 대해 알아봅니다.

<!--more-->

## 테스트 작성하기

첫 번째 글에서 언급한 바와 같이, 프론트엔드의 테스트는 대부분 통합 테스트로 간주될 수 있습니다. 프론트엔드의 주된 역할은 사용자, 서버 등 다양한 구성요소를 연결하는 것이기 때문에, 프론트엔드가 근본적으로 복잡한 로직을 가지는 경우는 그리 많지 않습니다. 하지만 다른 구성요소들이 연결되면서, 간단한 로직들이 서로 엉키면서 복잡해지는 경우가 대부분입니다.

그럼에도 불구하고 프론트엔드에서 직접 사용하는 로직이 존재할 수 있습니다. 예를 들어, 우편번호나 전화번호의 유효성을 검사하는 로직이나, 배송지가 제주나 산간 지역인지 판단하는 로직을 프론트엔드에서 구현할 수 있습니다. 이러한 로직들은 입력과 출력이 명확하고, 대부분 순수 함수로 만들어 관리할 수 있기 때문에 유닛 테스트를 작성할 수 있습니다. 유닛 테스트는 테스트가 간편한 편이고, 엄밀하게 검사해볼 수 있기 때문에 컴포넌트 내부에 순수 함수로 추출 가능하고, 충분히 복잡한 로직이 있는 경우 별도의 함수로 분리하는 것을 권장합니다.

UI 컴포넌트의 경우, 브라우저 환경, 사용자의 상호작용, 서버 API 등을 전제로 하는 경우가 많습니다. 이 경우, 하나의 함수로 입력과 출력을 테스트하기는 어렵고, UI 컴포넌트의 동작을 테스트해야 합니다. 이를 통합 테스트라고 합니다.

통합 테스트 관점에서는, 요구사항을 달성하기 위해서 다른 구성요소들과의 상호작용이 중요합니다. 구현 세부사항에 대한 테스트, 예를 들어 특정 클래스의 존재 여부나 컴포넌트의 상태를 확인하는 것은 요구사항 검증에 중요한 내용이 아닙니다.

테스트를 작성할 때는 이를 염두에 두어야 하며, 이를 통해 위양성이 발생하는 것을 피할 수 있습니다. 리팩토링을 진행하는 상황에서는 컴포넌트를 어떻게 개선할지에 대한 그림이 있으므로, 어떤 요소가 테스트에 포함되지 말아야 할 대상인지 파악할 수 있을 것입니다.

하지만, 하위 컴포넌트의 경우에는 콜백 함수 호출이나 props에 따른 동작을 테스트에 포함해야 합니다. 하위 컴포넌트 관점에서는 상위 컴포넌트는 제어할 수 있는 대상이 아니며, 우리가 제어할 수 없는 다른 구성 요소로 간주해야 합니다. 다시 말해, 기술적인 세부사항 자체가 하위 컴포넌트에서 요구되는 사항이 됩니다.

![2023-08-04-3.png](/img/content/2023-08-04-3.png)

이러한 내용을 바탕으로 유닛 테스트와 통합 테스트를 작성하는 방법을 살펴보겠습니다.

### 유닛 테스트

일반적으로 테스트를 작성할 때는 jest, mocha, chai, vitest와 같은 프레임워크를 사용합니다. 이러한 프레임워크는 범용적으로 사용할 수 있어서, 프론트엔드뿐만 아니라 Node.js 서버 개발 등 다양한 분야에서 널리 활용됩니다.

각 테스트는 하나의 구성요소만을 확인해야 합니다. 예를 들어, "checkRegion" 함수를 테스트한다고 가정해봅시다. 테스트의 제목은 "제주도 지역의 주소를 입력하면, is_jeju 가 true로 반환된다"와 같이 요구사항을 명확하게 설명해야 합니다.

```tsx
import { checkRegion } from './utils';

describe('checkRegion', () => {
  it('제주도 지역의 주소를 입력하면, is_jeju가 true로 반환된다', () => {
    // Arrange
    const input = {
      address: '제주 제주시 공항로 2 제주국제공항',
      detail_address: '공항 1층',
      city: '제주시',
      state: '제주',
      post_code: '63115',
    };
    // Act
    const { is_jeju } = checkRegion(input);
    // Assert
    expect(is_jeju).toBe(true);
  });
});
```

테스트는 주로 AAA (Arrange, Act, Assert) 패턴으로 구성됩니다. 이는 테스트를 준비하는 단계, 실제로 "checkRegion" 함수를 실행해보는 단계, 그리고 실행 결과를 확인하는 단계로 나누어집니다. AAA 패턴을 사용하면 어떤 것을 검증하기 위해 테스트가 작성되었는지 명확하게 확인할 수 있습니다.

jest에서는 "expect" 함수를 사용하여 실행 결과를 확인할 수 있습니다. 예를 들어, "expect(result).toBe(123);"는 result가 123이어야 함을 기대하고, 다른 값이라면 테스트가 실패합니다.

함수 호출 여부를 확인해야 하는 경우에는 mock을 사용할 수도 있습니다. "jest.fn()"을 사용하면 jest의 mock 함수를 생성할 수 있습니다. 이 mock 함수는 호출될 때마다 전달된 매개변수와 반환값을 기록합니다. 이를 통해 mock 함수의 호출 여부나 매개변수 전달이 올바른지를 검증할 수 있습니다.

또한 jest.mock, jest.spyOn과 같은 기능들도 존재합니다. 이를 사용하면 "fs"나 "localStorage"와 같은 다양한 객체들의 구현을 우리가 만든 함수로 대체할 수 있습니다. 이를 통해 구현체가 특정 상황을 가정하도록 해서 테스트를 작성할 수 있습니다.

```tsx
import fs from 'fs';
import { saveExcel } from './saveExcel';

describe('saveExcel', () => {
  it('saveExcel은 파일을 저장한다', async () => {
    const writeFileFn = jest.spyOn(fs, 'writeFile').mockImplementation(() => {});
    const callbackFn = jest.fn();
    const input = [
      ['ID', '이름'],
      [1, '테스트'],
    ];

    await saveExcel(input, 'output.xlsx', callbackFn);

    expect(writeFileFn).toHaveBeenCalled();
    expect(callbackFn).toHaveBeenCalled();
  });
});
```

mock의 사용에 대해서는 상반된 의견이 존재합니다. "Mockist"와 "Classical" 테스트 전략으로 구분되는데, 프론트엔드에서는 Mockist 전략을 따르기는 어렵다고 생각이 들긴 합니다. 관련된 내용은 백엔드 관점에서 쓰여진 자료가 많긴 하지만, 쉽게 찾아볼 수 있으므로 궁금하시면 참고해보시기 바랍니다. ([#](https://algopoolja.tistory.com/119))

### 통합 테스트

통합 테스트는 하나의 구성요소가 아닌 여러 구성요소들이 함께 동작하는지를 확인하는 테스트입니다. 이러한 테스트는 각 구성요소들의 상호작용을 검증하고, 구체적인 구현 내용은 검증하지 않습니다. 따라서, 프론트엔드의 경우 대부분의 테스트가 통합 테스트 범주에 속한다고 볼 수 있습니다. 이는 프론트엔드 자체가 여러 구성요소를 연결하는 역할을 수행하기 때문입니다.

통합 테스트도 jest와 같은 테스트 프레임워크를 사용하여 작성할 수 있습니다. 사실 테스트 프레임워크 입장에서는 유닛 테스트와 통합 테스트를 명확히 구분하지 않으며, 우리의 편의를 위해 이를 구분해놓은 것입니다.

하지만, 프론트엔드에서는 스토리북을 이미 활용하고 있는 경우가 많습니다. 스토리북은 각 컴포넌트를 격리시켜놓고, 컴포넌트의 실행에 필요한 환경과 목을 제공합니다. 따라서, 스토리북을 사용하고 있다면 별도로 통합 테스트 코드를 작성하는 대신, 스토리북에서 제공하는 [Interaction tests](https://storybook.js.org/docs/writing-tests/interaction-testing)을 활용하는 것이 좋습니다.

```tsx
export const Save = Primary.bind({});
Save.storyName = '주소를 입력하고 저장 버튼을 누르면 저장 API가 호출되고 onClose가 호출된다';
Save.play = async ({ canvasElement, args }) => {
  const { getSpy } = initMSWSpy();
  const canvas = within(canvasElement);

  await userEvent.input(await canvas.findByPlaceholderText('주소를 입력해주세요.'), '서울 중구 세종대로 2');
  await userEvent.click(await canvas.findByText('저장'));

  await expect(getSpy('UpdateUserShippingAddressBook')).toBeCalled();
  await expect(args.onClose).toBeCalled();
};
```

Interaction tests을 활용하면 위와 같이 테스트를 작성할 수 있습니다.

스토리북은 각 컴포넌트의 유형에 따라 스토리로 관리되며, 테스트를 위해 추가로 스토리를 생성할 수 있습니다.

각 테스트는 사용자의 행동이나 props와 같이, 컴포넌트의 동작을 결정짓거나 사용자의 여정을 나타낼 수 있는 이름으로 작성되어야 합니다.

- "주소를 입력하고 저장 버튼을 누르면 저장 API가 호출되고 onClose가 호출된다."
- "주소를 입력하지 않으면 저장 버튼이 비활성화된다."

통합 테스트는 사용자의 여정을 나타내는 형태로 작성되기 때문에 AAA 패턴을 적용하기 어려운 경우가 많습니다. 대신 "구성, 행동, 확인, 행동, 확인"과 같이 "행동, 확인" 단계가 반복되는 패턴으로 작성됩니다.

예를 들어, "주소를 입력하고" "주소가 입력되었는지 확인하고" "저장 버튼을 누르고" "저장 API가 호출되었는지 확인하고" "onClose가 호출되었는지 확인합니다"와 같이, 테스트는 여러 단계로 나뉘어 진행됩니다.

### 스토리 자체로써 테스트

사실, 스토리북을 컴포넌트별로 잘 구성했다면 추가로 테스트를 작성하지 않아도, 컴포넌트에서 “켜기만 했을 뿐인데 오류가 발생하는 상황”을 스토리북에서 잡아낼 수 있습니다. 이렇게, 별도의 검증 로직 없이 단순히 켜지는지 테스트하는 것을 “Smoke test”라고 부릅니다.

스토리북만 작성한다면, 아무 것도 하지 않아도 스토리를 smoke test로 손쉽게 변환해볼 수도 있습니다. 개발적으로 별다른 작업이 필요한 것은 아니고, 테스트를 자동으로 실행해주는 라이브러리 (jest, storybook/test-runner 등)에서 구성해주면 됩니다. 관련된 내용은 다음 글에서 다뤄볼 예정입니다.

## 모킹하기

통합 테스트를 위해서는 제품을 사용하는 환경을 흉내낼 수 있어야 합니다. 이런 일련의 과정을 모킹이라고 부릅니다.

### 사용자 행동 흉내내기 (testing-library/react)

React에서 테스트를 작성할 때는 [React Testing Library](https://testing-library.com/docs/react-testing-library/intro/)를 사용하는 것이 권장됩니다. 이 테스트 라이브러리는 React 내부 동작에는 신경쓰지 않고, 사용자 관점에서 테스트를 작성할 수 있도록 설계되어 있습니다.

테스트를 작성할 때는 HTML 태그, alt 속성, 텍스트 등 외적으로 보이는 요소를 검색하고, 해당 요소에 클릭이나 키보드 이벤트 등을 발생시키며, 외적으로 보이는 결과를 확인하여 검증합니다.

UI의 경우, 필요한 특정 노드가 보이지 않으면 테스트는 실패한 것으로 간주될 수 있기 때문에 사용자의 여정을 따라가는 방법으로도 테스트를 작성할 수 있습니다.

요소를 찾기 위해 텍스트나 HTML 태그를 사용할 수 없는 경우, 가능하면 시맨틱 HTML이나, ARIA 태그 등 접근성을 고려한 방법으로 코드를 변경하는 것이 좋습니다.

className이나 id를 사용하는 것은 권장되지 않습니다. 이러한 요소는 컴포넌트의 리팩토링 과정에서 쉽게 변경될 수 있으며, 사용자 관점에서는 중요하지 않기 때문입니다.

이런 ID가 꼭 필요하다면, data-testid를 사용하면 해당 요소가 테스트에 중요하다는 것을 명확히 인식할 수 있으므로 리팩토링 과정에서 오류를 발생시키지 않도록 도움을 줄 수 있습니다.

대부분의 프론트엔드 로직은 비동기로 동작하므로, React Testing Library는 비동기 작업을 쉽게 수행할 수 있도록 설계되었습니다.

DOM 노드를 가져오기 위해 `await canvas.findByText(/도움말/)`와 같은 방법을 사용하거나, 클릭 이벤트를 시뮬레이션하기 위해 `await userEvent.click(element)`와 같은 방법을 사용할 수 있습니다. 또한, input이나 keyboard 등 사용자의 행동을 표현할 수 있는 다양한 기능을 제공합니다.

```tsx
CreateNew.storyName = 'API 키를 생성할 수 있고, 약관 동의 모달이 표시된다';
CreateNew.play = async ({ canvasElement }) => {
  const { getSpy } = initMSWSpy();
  const canvas = within(canvasElement.parentElement!);

  await userEvent.click(await canvas.findByText(/인증키 발급/, { selector: 'button' }));
  await userEvent.click(await canvas.findByText('동의', { selector: 'button' }));
  const modal_el = await canvas.findByText('인증키 발급 완료');
  await expect(getSpy('CreateAuthKey')).toBeCalled();
  await userEvent.click(await canvas.findByText('복사하기', { selector: 'button' }));
  await userEvent.click(await canvas.findByText('확인', { selector: 'button' }));
  await waitForElementToBeRemoved(modal_el, { timeout: 1000 });
};
```

자세한 내용은 React Testing Library의 문서를 참조해 주세요.

### 서버 흉내내기 (MSW)

스토리북에서 컴포넌트를 테스트할 때는 실제 서버에 연결하지 않고 API 응답을 모방하여 구현하게 됩니다. 이러한 모킹은 [MSW](https://mswjs.io/)를 사용하여 처리할 수 있습니다.

스토리북에서는 MSW를 쉽게 사용할 수 있도록 도와주는 [MSW 애드온](https://storybook.js.org/addons/msw-storybook-addon)이 있습니다. 이 애드온을 사용하면 각 스토리에 사용할 목을 지정하는 방법으로 MSW를 구성할 수 있습니다.

```tsx
export const Story = () => <Component />;

Story.parameters = {
  msw: {
    handlers: {
      user: [
        graphql.query('GetUser', (req, res, ctx) => res(ctx.data({ ... })),
        graphql.query('GetUsers', (req, res, ctx) => res(ctx.data({ ... })),
      ],
    },
  },
};
```

하지만, 컴포넌트에서 API 호출이 불규칙하게 일어나게 되고, 페이지마다 명시적으로 API 호출을 추적하지 않기 때문에 시간이 흐를수록 점점 목을 관리하기가 어려워졌습니다.

파트너센터 제품에서는 페이지마다 사용할 목을 관리하는 대신, 공통으로 사용할 msw 목을 한 곳에 모아 프로젝트 전체에서 공유하는 방법으로, API 호출에 대해 신경쓰지 않는 방향으로 모킹을 구성했습니다.

어떤 방법을 사용하더라도, 스토리마다 오버라이드가 가능하다면 괜찮다고 생각합니다.

MSW 목은 단순히 데이터를 반환하는 것뿐만 아니라, 실제로 localStorage에 값을 쓰거나 로직에 따라 다른 데이터를 반환하는 등 다양한 작업을 수행할 수 있습니다. 하지만 MWS 목의 로직이 복잡해질수록 실제 로직을 테스트하는 대신 모킹의 로직을 테스트하는 상황이 발생할 수 있습니다. 예를 들어, 목에서 localStorage를 제어하므로 테스트에 localStorage를 검증하는 로직이 들어간다면 이는 컴포넌트의 동작을 테스트하는 것이 아니라, 목을 테스트하고 있기 때문에 옳지 않은 상황으로 볼 수 있습니다.

편의상 "목"이라는 표현했지만, 이렇게 테스트에 사용되는 기능들을 "테스트 더블(test double)"이라고도 부르고, 목은 그 중 하나입니다. 프론트엔드 테스트에서는 그다지 중요하지 않기 때문에 자세히 다루지는 않겠습니다.

MSW에서는 API가 호출되었는지 확인하는 기능을 제공하고 있지 않아서, 컴포넌트에서 “저장” API를 제대로 호출했는지 확인해보기가 어려웠습니다. 이를 해결하기 위해 `initMSWSpy` 함수를 별도로 제작해서, GraphQL 호출을 열어볼 수 있도록 작업했습니다.

```tsx
import { jest } from '@storybook/jest';
import { getWorker } from 'msw-storybook-addon';

// 테스트 코드에서 서버로의 요청이 정상적으로 이루어지는지 확인하기 위해 사용되는 Spy입니다.
// 목의 정합성을 테스트하는 용도가 아닌, 클라이언트에서 서버로 보내는 API 요청의
// 유무를 검증하기 위한 용도로만 사용해주세요!

const SPY_MAP: Map<string, jest.Mock> = new Map();
let IS_INITIALIZED = false;

export function initMSWSpy(): { getSpy: (name: string) => jest.Mock } {
  SPY_MAP.clear();

  function getSpy(name: string): jest.Mock {
    const entry = SPY_MAP.get(name);
    if (entry == null) {
      const new_entry = jest.fn() as unknown as jest.Mock;
      SPY_MAP.set(name, new_entry);
      return new_entry;
    }
    return entry;
  }

  if (!IS_INITIALIZED) {
    getWorker().events.on('request:end', (req) => {
      let name = req.url.pathname;
      const gql_pattern = /graphql\/([a-zA-Z0-9_-]+)$/.exec(name);
      if (gql_pattern != null) {
        name = gql_pattern[1];
      }
      const mock_fn = getSpy(name);
      mock_fn(req);
    });
    IS_INITIALIZED = true;
  }

  return { getSpy };
}
```

```tsx
CreateNew.storyName = '주소를 새로 등록할 수 있다';
CreateNew.play = async ({ canvasElement }) => {
  const { getSpy } = initMSWSpy();
  const canvas = within(canvasElement);

  await userEvent.click(await canvas.findByText('저장'));
  await expect(getSpy('CreateUserShippingAddressBook')).toBeCalled();
};
```

이렇게 사용자의 행동을 모방하는 방법과 서버의 동작을 모방하는 방법(API 목)을 살펴보았습니다. 이 둘이 제일 중요하긴 하지만, 프론트엔드에서는 이 두 가지만 있는 것은 아닙니다. 예를 들어, 주소록에서는 다음 우편번호 서비스를 사용하고 있습니다. 하지만 다음 우편번호 서비스의 UI는 우리가 제어할 수 없기 때문에 이를 테스트하는 것은 좋은 방법이 아닙니다.

이렇듯 이외에도 다른 구성요소들이 존재하는데, 이런 다른 구성요소를 모킹하는 방법을 알아봅시다.

### 컨텍스트 흉내내기

React 컴포넌트에서는 Context를 자주 사용하는 경우가 많습니다. Context를 사용하면 상위 컴포넌트에서 하위 컴포넌트로 값들을 암시적으로 전달할 수 있습니다. 이 Context 기능은 전역적으로 사용되는 값이나 환경과 관련된 값들을 전달하는 용도로 자주 활용됩니다.

Context를 모킹하기 위해서는 스토리북의 decorator를 사용해 간단히 처리할 수 있습니다. 예를 들어, react-router를 사용하는 경우에는 decorators에 MemoryRouter를 넣어 테스트하고자 하는 컴포넌트를 덮어씌워주기만 하면 됩니다.

```tsx
Story.decorators = [
  (Story) => (
    <MemoryRouter initialEntries={['/']}>
      <Story />
    </MemoryRouter>
  ),
];
```

### 기타 구성요소 모킹하기

jest는 다른 구성요소들을 우리가 만든 객체로 대체할 수 있는 목(Mock) 기능을 제공하고 있습니다.

```tsx
import fs from 'fs/promises';

jest.mock('fs/promises');

it('fs 테스트', () => {
  fs.readFile.mockResolvedValue(Promise.resolve());
  // ...
  expect(fs.readFile).toBeCalled();
});
```

주로 "jest.mock"이 사용되지만, 웹 브라우저 환경에서는 외부와의 통신을 위해 별도의 객체로 만들어진 내용들이 window 객체 안에 있기 때문에 jest.mock을 사용하기 어려울 수 있습니다.

이 경우에는 "jest.fn"을 사용하여 특정 함수를 교체하거나, "jest.spyOn"을 사용해볼 수 있습니다.

jest.spyOn을 사용하면 기존의 구현체를 그대로 유지하면서 해당 객체가 읽고 쓰는 값을 감시할 수 있습니다. 반면 jest.fn을 사용하면 원하는 함수로 특정 함수를 대체할 수 있습니다.

```tsx
Story.play = () => {
  const oldPostcode = window.daum.Postcode;
  // Postcode의 동작을 새로 덮어 쓴다
  window.daum.Postcode = jest.fn(function (args) {
    this.open = () => {};
    // 주소 입력 콜백을 호출한다
    args.oncomplete({
      // ...
    });
  });
  // ...
  expect(window.daum.Postcode).toHaveBeenCalled();
  // 스토리북에서 테스트를 진행하는 경우 덮어쓰기 전의 값으로 되돌림
  window.daum.Postcode = oldPostcode;
};

Story.play = () => {
  // 실제 window.daum.Postcode를 활용한다
  jest.spyOn(window.daum, 'Postcode');
  // ...
  expect(window.daum.Postcode).toHaveBeenCalled();
};
```

단, 목 함수를 사용한 후에는 테스트 환경이 새로고침되기 전까지는 해당 함수가 수정된 상태로 유지되므로 주의해야 합니다. jest는 “jest.restoreAllMocks” 와 같은 유틸 함수를 제공해주기 때문에 이런 문제에서 자유로운 편이지만, 스토리북에서는 관련된 유틸 함수가 존재하지 않으므로 유의해야 합니다. 기존 객체를 들고 있다가 테스트가 끝나는 시점에 되돌려주는 등의 로직이 별도로 필요합니다!

## E2E 테스트

통합 테스트를 작성해도, 하나의 페이지나 컴포넌트에 대해서만 테스트를 진행하기 때문에, 사용자 여정의 전체를 확인해보기는 어렵습니다. 이런 내용을 확인해보고 싶으면 E2E (End-to-End) 테스트를 작성해볼 수 있습니다.

E2E 테스트는 mock이 아닌, 실제로 환경에서 사용자와 동일하게 테스트를 진행해봅니다. 이를 위한 도구로는 Cypress, Playwright와 같은 것들이 있습니다.

하지만, E2E 테스트는 특성상 준비 과정이 까다롭고, 깨지기 쉽고, 진행 시간도 오래 걸리기 때문에 다루지 않았습니다. 특히, E2E 테스트에서 실패가 발생하면 어떤 부분에서 이슈가 발생했는지 파악하기 어렵다는 특징이 있습니다.

그럼에도 불구하고, 실제로 사용자가 문제를 겪을 수 있을 지 광범위하게 확인하는 용도로는 유용하기 때문에, 나중에 검토해볼 수 있겠습니다. 이 글에서는 E2E 테스트까지는 다루지는 않았습니다.

## 마치며

다뤘던 내용을 간단하게 정리하면서 마무리해봅시다.

- 프론트엔드의 테스트는 대부분 통합 테스트입니다. 그러나 유닛 테스트로 분리 가능한 것들은 함수로 따로 떼내는 것이 좋습니다.
- 유닛 테스트는 하나의 구성요소를 단독으로 분리해서 입력과 출력을 테스트해봅니다.
- 테스트는 3가지 패턴으로 나뉘어집니다. AAA (Arranage 구성, Act 행동, Assert 확인).
- 통합 테스트는 여러 구성요소들의 상호작용을 검증하고, 구체적인 구현을 검증하지는 않습니다.
- 프론트엔드에서는 스토리북에 이미 테스트 환경을 구성해두고 있으므로, 스토리북의 Interaction tests를 활용하는 것이 좋습니다.
- 작성된 스토리북을 단순히 제대로 돌아가는지 테스트하는 것만으로도 기본적인 검증이 가능합니다.
- 통합 테스트는 사용자 여정에 따라 “행동, 확인”이 계속해서 반복되는 구조입니다. 사용자 여정을 잘 드러내는 테스트를 작성하는 것이 좋습니다.
- React UI를 테스트할 때에는 React Testing Library를 사용합니다. 내부 구현에는 신경쓰지 않고, 유저에게 보이는 것들을 위주로 테스트합니다.
- 서버 모킹은 MSW를 사용해서 처리합니다.
- 컨텍스트는 스토리북의 decorator 기능을 사용해서 처리합니다.
- 이 외의 다른 구성요소는 jest.spyOn, jest.fn을 활용해서 처리할 수 있지만, 테스트 환경이 오염될 수 있으므로 유의해야 합니다.
- 사용자의 여정 전체를 확인해보려면, E2E 테스트의 작성도 고려해볼 수 있습니다.

테스트 환경 구축에 대해 아직 다루지 않았음을 알아채셨을 것입니다. 테스트 환경은 그 특수성으로 인해 구축이 어려운 경우가 많고, 상당한 양의 컴퓨터 자원을 요구하기 때문에 GitHub Actions와 같은 CI/CD에 관련해서도 고려해야 하는 내용이 있습니다. 다음 글에서는 테스트 환경 구축에 대해 자세히 알아보도록 하겠습니다.

하지만, 스토리북은 이미 Interaction tests이라는 이름으로 테스트 환경을 내장하고 있습니다. 스토리북 버전을 7로 업데이트하는 것을 권장하지만, 패키지 버전을 잘 신경쓴다면 6.5 버전에서도 실험해볼 수 있습니다. 스토리북의 Interaction tests을 사용하면 별도의 테스트 환경을 구축하지 않고도 스토리북 내부에서 테스트를 실행해볼 수 있습니다.

아직 스토리북 6.5 버전을 사용하고 있다면, 아래 패키지들을 사용하면 됩니다.

```json
{
  "@storybook/addon-interactions": "^6.5.16",
  "@storybook/testing-library": "^0.0.13",
  "@storybook/jest": "^0.0.10"
}
```

이렇게 해서, 프론트엔드 앱에서 요구사항과 테스트 케이스를 산출해내고 실제로 구현하는 방법까지 알아봤습니다. 스토리북을 활용하면 테스트를 작성해보는 허들이 많이 낮아서, 손쉽게 시도해볼 수 있을 것이라고 생각합니다.

다음 번에 리팩토링을 진행할 때, 실제로 테스트를 작성해보시면 더 잘 이해해보실 수 있으리라 생각합니다. 테스트에 관련해서 이 글이 도움이 되었기를 바랍니다.
