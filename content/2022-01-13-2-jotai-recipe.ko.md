---
title: Jotai 레시피
tags: ['Frontend', 'Jotai']
date: 2022-01-13
author: Simon(윤상민)
original: http://sixmen.com/ko/tech/2022-01-13-2-jotai-recipe/
---

이번 글에서는 카카오스타일에서 Jotai를 어떤 식으로 사용하고 있는지 여러가지 패턴에 대해 설명하려고 합니다.

<!--more-->

## 상태 정의하고 사용하기

[Jotai](https://jotai.org/)의 기본 사용법은 간단합니다. [useState](https://ko.reactjs.org/docs/hooks-reference.html#usestate)로 정의하던 상태가 있으면,
[atom](https://jotai.org/docs/api/core#atom) 메소드로 정의하고 [useAtom](https://jotai.org/docs/api/core#use-atom)을 써서 사용하면 됩니다.

```tsx
import { atom, useAtom } from 'jotai';
import { FC } from 'react';

const count_atom = atom(0);

const App: FC = () => {
  const [count, setCount] = useAtom(count_atom);
  return (
    <div>
      <div>{count}</div>
      <button onClick={() => setCount(count + 1)}>Inc</button>
    </div>
  );
};
```

위 예제에서는 useState와 다른게 없지만, 하위 컴포넌트에서 해당 상태에 접근해야 할 경우 차이가 발생합니다.

```tsx
import { atom } from 'jotai';
import { useAtomValue, useUpdateAtom } from 'jotai/utils';
import { FC } from 'react';

const count_atom = atom(0);

const Counter: FC = () => {
  const count = useAtomValue(count_atom);
  return <div>{count}</div>;
};

const IncButton: FC = () => {
  const setCount = useUpdateAtom(count_atom);
  return <button onClick={() => setCount((count) => count + 1)}>Inc</button>;
};

const App: FC = () => {
  return (
    <div>
      <Counter />
      <IncButton />
    </div>
  );
};
```

[useAtomValue](https://jotai.org/docs/utils/use-atom-value)와 [useUpdateAtom](https://jotai.org/docs/utils/use-update-atom)은
읽기나 쓰기 중 하나만 필요할 때 사용가능한 유틸리티 함수입니다.
쓰기 함수는 useState의 setState 처럼 이전 상태를 받아 이용할 수 있습니다.

## 파생 atom

원시 atom의 값에서 파생된 atom을 정의할 수도 있습니다. MobX나 Vue의 computed 속성과 비슷합니다.
useMemo와 같이 의존한 atom의 값이 바뀐 경우에만 재계산을 합니다.

```tsx
const email_atom = atom('');
const password_atom = atom('');
const button_enabled_atom = atom((get) => {
  return get(email_atom).length > 0 && get(password_atom).length > 0;
});
```

> [같은 Provider가 제공한 atom의 값만 얻을 수 있습니다.](https://github.com/pmndrs/jotai/issues/619)
> 

## 액션 atom

쓰기 전용 atom을 통해 비즈니스 로직을 정의할 수 있습니다.

```tsx
// 전화번호 인증 과정 중 전화번호 입력 필드 값이 바뀔 때 호출한다
const updateMobileTelAtom = atom(null, (get, set, value: string) => {
  // 인증 과정이 완료된 경우 전화번호를 변경할 수 없다
  if (get(authenticated_atom)) {
    return;
  }
  // 전화번호 표시에서 -등 기타 문자는 제거한다
  set(mobile_tel_atom, value.replace(/[^0-9]/g, ''));
  // 인증 번호 입력 시간을 초기화한다
  set(remain_time_atom, 0);
});
```

대부분의 로직은 서버 API 호출을 필요로 하는 경우가 많습니다. 이 경우 응답을 기다리는, 즉 비동기 동작이 필요합니다.
Redux에서는 [thunk](https://redux.js.org/usage/writing-logic-thunks) 같은 미들웨어가 필요하지만, Jotai에서는 자연스럽게 정의할 수 있습니다.

```tsx
// 전화번호 인증 토큰을 발송한다
const sendAuthenticationTokenAtom = atom(null, async (get, set) => {
  // 중복 발송을 막는다
  if (get(submitting_atom)) {
    return;
  }
  try {
    set(submitting_atom, true);
    await fetch('/sendAuthenticationToken', { mobile_tel: get(mobile_tel_atom) });
    set(submitting_atom, false);
    // 이전 에러 메시지를 초기화한다
    set(authentication_error_atom, undefined);
    // 토큰 입력을 초기화한다
    set(token_atom, '');
    // 입력 시간을 2분으로 초기화한다
    set(remain_time_atom, 120);
  } catch (error: any) {
    set(submitting_atom, false);
    alert(error.message);
  }
});
```

## 디렉토리 구조

값과 액션이 사실 같은 atom이지만, 편의상 구분하고 있습니다.
이 둘을 묶은 용어를 고민하다가, Redux, MobX 등에서 쓰는 store라고 부르기로 했습니다. (ViewModel이라고 부를까도 고민했습니다.)

MobX에서 값과 액션을 한 클래스로 만들면 파일을 나누기가 어려운데 반해, Jotai는 atom의 모음이다 보니 나누기가 편리합니다.
값은 atoms 디렉토리, 액션은 actions 디렉토리에 둡니다. atoms는 연관성이 높은 것들을 한 파일로 묶고, 액션은 보통 길이가 길기 때문에 액션 별로 파일을 만들고 있습니다.

```tsx
// src/components/model/detail/store/index.ts
export * from './atoms';
export * from './actions';
```

```tsx
// src/components/model/detail/store/atoms/index.ts
import { atom } from 'jotai';

export * from './orderer';

export const submitting_atom = atom(false);
```

```tsx
// src/components/model/detail/store/atoms/orderer.ts
import { atom } from 'jotai';

export const orderer_email_atom = atom('');
export const orderer_mobile_tel_atom = atom('');
export const orderer_name_atom = atom('');
```

```tsx
// src/components/model/detail/store/actions/index.ts
export * from './purchase';
```

```tsx
// src/components/model/detail/store/actions/purchase.ts
import { atom } from 'jotai';
import {
  orderer_email_atom,
  ...
} from '../atoms';

export const purchaseAtom = atom(null, async (get, set) => {
  const orderer_email = get(orderer_email_atom);
  ...
});
```

## Provider와 초기값

atom의 값은 글로벌에 존재하는 atom에 저장되는 것이 아니라 Context와 비슷하게 컴포넌트 트리 상에 저장됩니다.
[Provider](https://jotai.org/docs/api/core#provider)를 사용하면 atom이 저장될 Context를 제공할 수 있습니다.
(즉 참조하는 Provider가 다르면 같은 atom을 use해도 값이 다릅니다) Provider를 지정하지 않으면 기본 저장소가 사용됩니다.

[컴포넌트 구성 아티클](https://www.notion.so/React-4d3def2180fe4989b39b643b22b7d899)에서 설명했듯이 페이지와 내부 구성 컴포넌트가 분리되어 있는데,
스토리북에서도 정상 동작하도록 내부 컴포넌트쪽에 Provider 선언을 두고 있습니다.

```tsx
// Jotai 적용 전
const ProfileAddress: FC<{address1: string; address2: string}> = (props) => {
  const [address1, setAddress1] = useState(props.address1);
  const [address2, setAddress2] = useState(props.address2);
  return <div></div>;
};

export default ProfileAddress;
```

```tsx
// Jotai 적용 후
const address1_atom = atom('');
const address2_atom = atom('');

const ProfileAddress: FC = () => {
  const [address1, setAddress1] = useAtom(address1_atom);
  const [address2, setAddress2] = useAtom(address2_atom);
  return <div></div>;
};

const ProfileAddressWithProvider: FC<{ address1: string; address2: string }> = (props) => {
  return (
    <Provider
      initialValues={[
        [address1_atom, props.address1],
        [address2_atom, props.address2],
      ] as Array<[Atom<unknown>, unknown]>}
    >
      <ProfileAddress />
    </Provider>
  );
};

export default ProfileAddressWithProvider;
```

위와 같이 외부에서 Props로 받아 온 값을 initialValues로 atom에 넣어주면 이후 Props 참조 없이, atom에서 값을 읽을 수 있습니다.

디렉토리 구조에서 설명했듯이 atom 정의는 하위 디렉토리에서 하고 있습니다.
이런 atom을 초기화하는 코드도 atom 정의와 같이 있는 것이 바람직하기 때문에, 초기화 내용을 분리해 store/atoms/index.ts 에 만들고 있습니다.

```tsx
// store/atoms/index.ts
import { Atom, atom } from 'jotai';

export const address1_atom = atom('');
export const address2_atom = atom('');

export function getInitialValues(
  address1: string,
  address2: string,
): Array<[Atom<unknown>, unknown]> {
  return [
    [address1_atom, address1],
    [address2_atom, address2],
  ];
}
```

## onMount과 localStorage

atom에 고정된 값 대신 처음 사용되는 시점에 값을 정해지도록 할 수 있습니다.
예를 들어 atom 값을 localStorage에서 가져와 초기화 시키고 싶을 수 있습니다.
이 경우 [onMount](https://jotai.org/docs/api/core#on-mount)를 사용하면 됩니다.

```tsx
const toolip_seen_atom = atom<boolean>(true);
toolip_seen_atom.onMount = (set) => {
  set(window.localStorage.getItem('toolip_seen') === 'true');
};
```

그런데 위 코드로는 atom 값을 갱신했을 때 localStorage에 반영되지 않습니다.
쓰기시 커스텀 동작을 하면서, 저장도 하고 싶은 경우, 저장용 atom을 분리해야 합니다.

```tsx
const toolip_seen_base_atom = atom<boolean>(true);
toolip_seen_base_atom.onMount = (set) => {
  set(window.localStorage.getItem('toolip_seen') === 'true');
};
const toolip_seen_atom = atom(
  (get) => get(toolip_seen_base_atom),
  (_, set, seen: boolean) => {
    set(toolip_seen_base_atom, seen);
    window.localStorage.setItem('toolip_seen', seen ? 'true' : 'false');
  },
);
```

같은 역할을 하는 것으로 [atomWithStorage](https://jotai.org/docs/utils/atom-with-storage) 유틸리티 함수가 있는데,
일부 환경에서 오동작을 하는 듯 해서 사용하지 못하고 있습니다. (Promise를 사용해 비동기적으로 동작하는 부분을 의심하고 있습니다.)

## atom 조합 및 분리

개별 atom도 사용하지만, 그 값을 합친 것도 필요한 경우가 있습니다. 파생 atom으로 이를 구현할 수 있습니다.

```tsx
import { atom } from 'jotai';

const orderer_email_atom = atom('');
const orderer_mobile_tel_atom = atom('');
const orderer_name_atom = atom('');
const orderer_atom = atom((get) => ({
  email: get(orderer_email_atom),
  mobile_tel: get(orderer_mobile_tel_atom),
  name: get(orderer_name_atom),
}));
```

반대로 atom이 전체 값을 가지고 있는데, 그 중 일부만 필요한 경우도 있습니다.
[selectAtom](https://jotai.org/docs/utils/select-atom)을 사용하면 됩니다. 원본 atom의 값을 바꿀 일이 없을 때 사용하면 편리합니다.

```tsx
import { atom } from 'jotai';
import { selectAtom } from 'jotai/utils';

const order_atom = atom<Order>(...);
const ordered_product_atom = selectAtom<OrderProduct>(order_atom, (order) => order.product);
```

## immer

atom이 복잡한 객체일 때, 일부 속성만 편하게 갱신하기 위해서 [immer](https://immerjs.github.io/immer/)를 사용할 수 있습니다.
도움을 주는 [유틸리티 모듈](https://jotai.org/docs/integrations/immer)도 있습니다.

```tsx
// immer를 사용하지 않는 경우
const selected_atom = atom<{ [key: string]: boolean }>({ apple: true, banana: false });
const setSelectedAtom = atom(null, (get, set, value: { fruit: string; checked: boolean }) => {
  const selected = get(selected_atom);
  set(selected_atom, { ...selected, ...{ [value.fruit]: value.checked } });
});

// immer를 사용하는 경우
import { produce } from 'immer';
const selected_atom = atom<{ [key: string]: boolean }>({ apple: true, banana: false });
const setSelectedAtom = atom(null, (get, set, value: { fruit: string; checked: boolean }) => {
  set(
    selected_atom,
    produce(get(selected_atom), (draft) => {
      draft[value.fruit] = value.checked;
    }),
  );
});

// immer 연동 모듈을 사용하는 경우
import { atomWithImmer } from 'jotai/immer';
const selected_atom = atomWithImmer<{ [key: string]: boolean }>({ apple: true, banana: false });
const setSelectedAtom = atom(null, (get, set, value: { fruit: string; checked: boolean }) => {
  set(selected_atom, (draft) => {
    draft[value.fruit] = value.checked;
  });
});
```

## 공용 컴포넌트

여러 페이지에서 사용하는 공통 컴포넌트가 있을 수 있습니다.
그리고 그 컴포넌트가 제공하는 상태를 atom으로 정의해 부모가 읽을 수 있도록 만들 수 있습니다.
이때 부모가 읽을 수 있도록 공용 컴포넌트에 Provider를 별도로 두지 않았습니다.
다만 Provider가 별도로 존재하지 않으므로 인스턴스를 여러개 만들 수는 없습니다. (Input 컴포넌트 같은 것은 불가능)

```tsx
// common/EditReceiverView/index.tsx
const receiver_name_atom = atom('');
const receiver_mobile_tel_atom = atom('');
const receiver_postcode_atom = atom('');
const receiver_address1_atom = atom('');
const receiver_address2_atom = atom('');

export const receiver_atom = atom((get) => ({
  name: get(receiver_name_atom),
  mobile_tel: get(receiver_mobile_tel_atom),
  postcode: get(receiver_postcode_atom),
  address1: get(receiver_address1_atom),
  address2: get(receiver_address2_atom),
}));

export function getInitialValues(
  default_receiver: {
    name: string;
    mobile_tel: string;
    postcode: string;
    address1: string;
    address2: string | null;
  } | null,
): Array<[Atom<unknown>, unknown]> {
  return [
    [receiver_name_atom, default_receiver?.name ?? ''],
    [receiver_mobile_tel_atom, default_receiver?.mobile_tel ?? ''],
    [receiver_postcode_atom, default_receiver?.postcode ?? ''],
    [receiver_address1_atom, default_receiver?.address1 ?? ''],
    [receiver_address2_atom, default_receiver?.address2 ?? ''],
  ];
}

const EditReceiverView: FC = () => {
  const [receiver_name, setReceiverName] = useAtom(receiver_name_atom);
  ...

  return (
    <div>
      <Input
        label='받는 분'
        type='text'
        placeholder='이름을 입력해주세요'
        value={receiver_name}
        onChange={setReceiverName}
      />
      ...
    </div>
  );
};

export default EditReceiverView;
```

```tsx
// order-sheet/index.tsx
import { receiver_atom, getInitialValues as EditReceiverView_getInitialValues } from 'common/EditReceiverView';

const order_sheet_atom = atom<OrderSheet>({});

function getInitialValues(
  order_sheet: OrderSheet,
  default_receiver: {
    name: string;
    mobile_tel: string;
    postcode: string;
    address1: string;
    address2: string | null;
  } | null,
): Array<[Atom<unknown>, unknown]> {
  return [
    [order_sheet_atom, order_sheet],
    ...EditReceiverView_getInitialValues(default_receiver),
  ];
}

const purchaseAtom = atom(null, async (get, set) => {
  const order_sheet = get(order_sheet_atom);
  const receiver = get(receiver_atom);
  ...
});

const OrderSheet: FC = () => {
  const purchase = useUpdateAtom(purchaseAtom);

  return (
    <div>
      ...
      <EditReceiverView />
      ...
      <button onClick={() => purchase()}>구매하기</button>
      ...
    </div>
  );
};

const OrderSheetWithProvider: FC<Props> = (props) => {
  return (
    <Provider
      initialValues={getInitialValues(
        props.order_sheet,
        props.default_receiver,
      )}
    >
      <OrderSheet />
    </Provider>
  );
};

export default OrderSheetWithProvider;
```

## 테스트

테스트는 중요하지만, 잘 하기는 쉽지 않습니다. 특히 수시로 변경되는 UI는 안정적이고 믿을 수 있는 테스트를 작성하기가 더 어렵습니다.
하지만 상태를 뷰와 분리하면 그나마 테스트가 좀 쉬워집니다. Jotai로 만든 store는 뷰와 무관하기 때문에 테스트 작성이 비교적 용이합니다.

다음과 같이 포인트 최대 적용이라는 액션을 만들었습니다.

```tsx
import { atom } from 'jotai';

// 주문액
const payment_amount_atom = atom(0);

// 소유한 포인트 금액
const available_point_atom = atom(0);

// 최대 사용가능한 포인트 금액
const maximum_usable_point_atom = atom((get) => {
  const available_point = get(available_point_atom);
  if (available_point <= 0) {
    return 0;
  }
  const payment_amount = get(payment_amount_atom);
  return available_point <= payment_amount ? available_point : payment_amount;
});

// 사용할 포인트 금액
const point_to_use_atom = atom(0);

// 사용가능한 최대 포인트를 적용한다
const applyAllPointAtom = atom(null, (get, set) => {
  set(point_to_use_atom, get(maximum_usable_point_atom));
});

// Provider의 initialValues를 위한 도움 함수
function getInitialValues(
  payment_amount: number,
  available_point: number,
): Array<[Atom<unknown>, unknown]> {
  return [
    [payment_amount_atom, payment_amount],
    [available_point_atom, available_point],
  ];
}
```

다음은 이 액션에 대한 테스트 코드입니다.(action 파일과 같은 디렉토리에 위치시켰습니다)
현재 카카오스타일은 [Jest](https://jestjs.io/) 프레임워크를 사용중이고(서버는 [Mocha](https://mochajs.org/)를 사용하고 있습니다),
[Testing Library](https://testing-library.com/)의 도움을 받고 있습니다.

```tsx
import { renderHook, act } from '@testing-library/react-hooks';
import { Provider } from 'jotai';
import { useAtomValue, useUpdateAtom } from 'jotai/utils';
import { getInitialValues, maximum_usable_point_atom, point_to_use_atom } from '../atoms';
import { applyAllPointAtom } from './applyAllPoint';

describe('applyAllPoint', () => {
  it('포인트 사용액 기본값은 0이다', () => {
    const { result } = renderHook(() => ({
      point_to_use: useAtomValue(point_to_use_atom),
    }));

    expect(result.current.point_to_use).toBe(0);
  });

  it('사용 가능한 금액만큼 적용된다', () => {
    const initial_values = getInitialValues(
      92500,
      10000,
    );
    const { result } = renderHook(
      () => ({
        point_to_use: useAtomValue(point_to_use_atom),
        maximum_usable_point: useAtomValue(maximum_usable_point_atom),
        applyAllPoint: useUpdateAtom(applyAllPointAtom),
      }),
      {
        wrapper: ({ children }) => <Provider initialValues={initial_values}>{children}</Provider>,
      },
    );

    act(() => {
      result.current.applyAllPoint();
    });

    expect(result.current.maximum_usable_point).toBe(10000);
    expect(result.current.point_to_use).toBe(10000);
  });

  it('사용 가능한 금액이 주문 금액보다 많으면 주문 금액만큼 적용된다', () => {
    const initial_values = getInitialValues(
      92500,
      200000,
    );
    const { result } = renderHook(
      () => ({
        point_to_use: useAtomValue(point_to_use_atom),
        maximum_usable_point: useAtomValue(maximum_usable_point_atom),
        applyAllPoint: useUpdateAtom(applyAllPointAtom),
      }),
      {
        wrapper: ({ children }) => <Provider initialValues={initial_values}>{children}</Provider>,
      },
    );

    act(() => {
      result.current.applyAllPoint();
    });

    expect(result.current.maximum_usable_point).toBe(92500);
    expect(result.current.point_to_use).toBe(92500);
  });
});
```
