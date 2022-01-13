---
title: 프론트엔드 상태 관리에 대한 여정
tags: ['Frontend', 'Jotai']
date: 2022-01-13
author: Simon(윤상민)
original: http://sixmen.com/ko/tech/2022-01-13-1-frontend-state-management/
---

카카오스타일은 React에서 상태 관리를 위해 최근에 Jotai를 도입했습니다. Jotai에 대해 소개하기에 앞서 Jotai에 다다르기까지의 과정에 대해 설명해보려고 합니다.

<!--more-->

## 선언형 UI

할일 관리 화면을 상상해봅시다. 초기 웹에서 보편적이였던 jQuery를 사용한다면, 할 일 추가를 위해 다음과 같이 작성할 것 같습니다.

```tsx
const todos = [];
$('#text').change(function () {
  const text = $(this).val();
  $(this).val('');
  todos.push({ text, completed: false });
  $('#list').append(`<li>${text}</li>`);
});
```

이런 구성은 todos 변수(모델)와 #list 원소의 내용(뷰)을 동기화 시키는 것이 굉장히 어렵습니다. 그래서 React를 비롯한 대부분의 현대식 프레임워크는 모델과 뷰의 관계를 선언형(declarative)으로 정의하면 알아서 모델의 변경 사항을 뷰에 반영해주어서 뷰 코드를 단순하게 만들어줍니다.

> 최근에는 네이티브 앱 개발에서도 SwiftUI나 Jetpack compose 처럼 선언형 UI 프레임워크가 나오고 있습니다.

저는 어떤 화면을 표현하기 위한 데이터와 뷰와의 관계(매핑) 대부분은 직관적으로 정의할 수 있다고 생각합니다. 이렇게 구성한 뷰를 React가 효율적으로 최종 DOM에 반영해주기 때문에, 결국 우리가 가장 신경써야 할 부분은 데이터 모델링과 사용자 행위에 따라 데이터가 어떻게 바뀌는지에 대한 것입니다. 이 데이터를 React에서는 상태라 부르고, 극단적으로 (렌더링은 React가 책임져주므로) 상태 관리만 잘 하면 좋은 어플리케이션이 만들어진다고 생각합니다. 이게 중요하지만 그만큼 어렵다 보니 상태 관리 라이브러리가 다양하게 나온 것이라고 생각합니다.

> 이 데이터에는 UI를 위한 데이터(예를 들어 Collapse 컴포넌트의 접기 상태)도 있다는 것에서 일반적인 모델과 구분됩니다. 저는 이게 MVVM 패턴의 ViewModel이라고 생각합니다. 현재 네이티브 앱에서 선언형 UI까지는 하지 못햇지만 MVVM 패턴을 사용해 뷰와 데이터를 분리하고 있습니다.

## Mithril

지그재그 초기에는 내부 툴을 위해 [Mithril](https://mithril.js.org/)을 사용했는데 몇단계의 개선을 통해 최종적으로는 다음과 같이 MVVM 구성을 했습니다.

> 당시에는 제 기준으로 React와 큰 차이가 없었는데, 이후 React는 [훅](https://ko.reactjs.org/docs/hooks-intro.html)이라는 큰 변화가 생겼고, Mithril은 큰 변화없이 정체되다가 현재는 완전히 멈추었습니다. 2019년 이후 React를 사용하는 것으로 정책이 바뀌었지만, 일부 프로젝트(예 FAQ)에 아직 흔적이 남아있습니다.

```tsx
interface SignupViewAttrs {
  token?: string;
}

class SignupViewModel {
  token: string;
  email: Stream.Stream<string>;
  password: Stream.Stream<string>;
  password_confirm: Stream.Stream<string>;
  enabled: Stream.Stream<boolean>;

  constructor(attrs: SignupViewAttrs) {
    this.token = attrs.token || '';
    this.email = Stream('');
    this.password = Stream('');
    this.password_confirm = Stream('');
    this.eanbled = Stream.merge([this.email, this.password, this.password_confirm]).map(
      ([email, password, password_confirm]) => {
        return email.length > 0 && password.length > 0 && password === password_confirm;
      },
    );
  }

  async signup(event) {
    // signup logic
  }
}

class SignupView implements m.ClassComponent<SignupViewAttrs> {
  vm: SignupViewModel;

  oninit({ attrs }: m.CVnode<SignupViewAttrs>) {
    this.vm = new SignupViewModel(attrs);
  }

  view({ attrs }: m.CVnode<SignupViewAttrs>) {
    return (
      <form class='form-horizontal' onsubmit={(event) => this.vm.signup(event)}>
        <div class='form-group'>
          <input class='form-control' value={this.vm.email()} onchange={m.withAttr('value', this.vm.email)} />
        </div>
        <div class='form-group'>
          <input
            type='password'
            class='form-control'
            value={this.vm.password()}
            onchange={m.withAttr('value', this.vm.password)}
          />
        </div>
        <div class='form-group'>
          <input
            type='password'
            class='form-control'
            value={this.vm.password_confirm()}
            onchange={m.withAttr('value', this.vm.password_confirm)}
          />
        </div>
        <div class='form-group'>
          <button type='submit' class='btn btn-default' disabled={!this.vm.enabled()}>
            가입하기
          </button>
        </div>
      </form>
    );
  }
}
```

## MobX

이후에 2019년 초 커머스 플랫폼으로 전환을 시작하면서 웹으로 구성한 화면들이 생겨나기 시작했는데 이때 React와 [Next.js](https://nextjs.org/)를 선택했습니다. 그리고 상태관리 라이브러리를 선택해야 했는데, 당시 [Redux](https://redux.js.org/)가 대새였지만 저희팀은 [MobX](https://mobx.js.org/)를 선택했습니다. 그 선택에 제가 관여를 하진 않았는데, 아마 OOP 스타일인게 영향을 미치지 않았을까 싶습니다. 거기에 지금도 그렇지만 Redux를 잘 쓰려면 알아야 할 개념과 부가적인 라이브러리가 많습니다. 개인적으로 상태는 최소한의 범위만 영향을 주는 것이 부수 효과가 적다고 생각하기 때문에, [글로벌 상태를 하나의 스토어에 두는 Redux 컨셉](https://redux.js.org/tutorials/fundamentals/part-2-concepts-data-flow#single-source-of-truth)에 거부감이 있습니다.

```tsx
import { computed, observable, observer } from 'mobx';

class Store {
  @observable email: string = '';
  @observable password: string = '';
  @observable password_confirm: string = '';

  @computed
  get enabled() {
    return this.email.length > 0 && this.password.length > 0 && this.password === this.password_confirm;
  }
}

@observer
class LoginView extends React.Component<{ store: Store }> {
  render() {
    const store = this.props.store;
    return (
      <div>
        <input value={store.email} onChange={(e) => (store.email = e.target.value)} />
        <input value={store.password} onChange={(e) => (store.password = e.target.value)} />
        <input value={store.password_confirm} onChange={(e) => (store.password_confirm = e.target.value)} />
        <button disabled={!store.enabled}>가입하기</button>
      </div>
    );
  }
}
```

## useReducer

이후 회사 내부에 여러 웹 프로젝트가 생기면서 기술에 파편화가 일어나고 있던 상황에서, 2021년 중반에 새로 시작한 프로젝트를 새로운 표준으로 삼기 위해, 상태 관리에 대해 다시 한번 조사해봤습니다. 이미 훅이 대세가 됐고 너무 좋아해서 기본 훅을 최대한 활용해 보기로 했습니다. MobX는 데코레이터를 활용하는 것과 훅과 어울리지 않는 다는 인상이 있어 배제했습니다. (최신 버전에서는 달라진 것으로 알고 있습니다)

처음 시도는 useReducer였습니다. 다만 이것만으로는 반복되는 코드가 많아서 [Redux Toolkit](https://redux-toolkit.js.org/)의 도움을 받았습니다. 그리고 [Ducks 패턴](https://github.com/erikras/ducks-modular-redux)을 참고해서 파일 구성을 했습니다.

```tsx
// store.ts
import { createSelector, createSlice, PayloadAction } from '@reduxjs/toolkit';

interface State {
  email: string;
  password: string;
  submitting: boolean;
}

export const initial_state: State = {
  email: '',
  password: '',
  submitting: false,
};

const login_slice = createSlice({
  name: 'login',
  initialState: initial_state,
  reducers: {
    setEmail(state, action: PayloadAction<string>) {
      state.email = action.payload;
    },
    setPassword(state, action: PayloadAction<string>) {
      state.password = action.payload;
    },
    startLogin(state) {
      state.submitting = true;
    },
    endLogin(state) {
      state.submitting = false;
    },
  },
});

export const { setEmail, setPassword, startLogin, endLogin } = login_slice.actions;
export default login_slice.reducer;

const self_selector = (state: State) => state;
const button_enabled_selecter = createSelector(self_selector, (state) => {
  return state.email.length > 0 && state.password.length > 0 && !state.submitting;
});

export const selector = createSelector(button_enabled_selecter, (button_enabled) => {
  return {
    button_enabled,
  };
});

// Login.tsx
import { useReducer, ReactElement } from 'react';
import reducer, { initial_state, selector, setEmail, setPassword, startLogin, endLogin } from './store';

export default function Login(): ReactElement {
  const [state, dispatch] = useReducer(reducer, initial_state);
  const { button_enabled } = selector(state);

  const login = async () => {
    try {
      dispatch(startLogin());
      // login logic
      DefaultRouter.push('/');
    } catch (error) {
      dispatch(endLogin());
      alert(error);
    }
  };

  return (
    <div className='max-w-screen-md mx-auto mt-10'>
      <div>
        <div className='text-4xl'>이메일</div>
        <div className='my-4'>
          <input
            className='w-full border-2 border-black text-4xl px-6 py-4'
            name='email'
            value={state.email}
            onChange={(e) => dispatch(setEmail(e.target.value))}
          />
        </div>
      </div>
      <div>
        <div className='text-4xl'>암호</div>
        <div className='my-4'>
          <input
            className='w-full border-2 border-black text-4xl px-6 py-4'
            name='password'
            type='password'
            value={state.password}
            onChange={(e) => dispatch(setPassword(e.target.value))}
          />
        </div>
      </div>
      <div className='mt-8'>
        <button
          className='bg-blue-300 w-full border-2 border-black text-4xl px-6 py-4 disabled:opacity-50'
          onClick={login}
          disabled={!button_enabled}
        >
          로그인하기
        </button>
      </div>
    </div>
  );
}
```

UI와 로직을 분리하는게 가장 큰 목표인데, login 로직이 아직 컴포넌트에 남아있습니다. useReducer로는 비동기 처리가 어려워서 [use-reducer-async 모듈](https://github.com/dai-shi/use-reducer-async)을 참고해 비동기 리듀서를 만들었습니다.

```tsx
import {
  Dispatch,
  Reducer,
  ReducerAction,
  ReducerState,
  useCallback,
  useEffect,
  useLayoutEffect,
  useReducer,
  useRef,
} from 'react';
import { AnyAction } from 'redux';

export type AsyncAction<S, A = AnyAction> = (dispatch: AsyncDispatch<S, A>, getState: () => S) => void;

export type AsyncDispatch<S, A> = Dispatch<A | AsyncAction<S, A>>;

const isBrowser = typeof window !== 'undefined';
const useIsomorphicLayoutEffect = isBrowser ? useLayoutEffect : useEffect;

export function useAsyncReducer<R extends Reducer<any, any>>(
  reducer: R,
  initialState: ReducerState<R>,
  initState?: (state: ReducerState<R>) => ReducerState<R>,
): [ReducerState<R>, AsyncDispatch<ReducerState<R>, ReducerAction<R>>] {
  const [state, dispatch] = useReducer(reducer, initialState, initState as any);

  const last_state = useRef(state);
  useIsomorphicLayoutEffect(() => {
    last_state.current = state;
  }, [state]);
  const getState = useCallback(() => last_state.current, []);

  const async_dispatch = useCallback(
    (action: ReducerAction<R> | AsyncAction<ReducerState<R>, ReducerAction<R>>) => {
      if (typeof action === 'function') {
        (action as AsyncAction<ReducerState<R>, ReducerAction<R>>)(async_dispatch, getState);
      } else {
        return dispatch(action);
      }
    },
    [dispatch, getState],
  );

  return [state, async_dispatch];
}
```

이후에 다음과 같이 login 액션을 분리했습니다.

```tsx
export function login(): AsyncAction<State> {
  return async (dispatch, getState) => {
    try {
      const state = getState();
      dispatch(slice.actions.startLogin());
      // login logic
      DefaultRouter.push('/');
    } catch (error) {
      dispatch(slice.actions.endLogin());
      alert(error);
    }
  };
}
```

## Jotai

useReducuer를 사용해 한 페이지에 있는 여러 개의 상태를 개별 useState 대신 별도 파일로 분리하는 목적은 달성했지만 썩 맘에 들지 않았습니다.

- 개인적으로 그냥 비지니스 로직이 담긴 함수를 리듀서라고 정의하는 것에 대한 거부감이 좀 있습니다. (로직을 처리하는게 아니라, state → state 변환을 처리하는 개념에 치중)
- 동기 액션과 비동기 액션 처리 정의가 다르게 생겼습니다.
- button_enabled 같은 계산된 속성과 일반 속성 사용법이 너무 다릅니다.
- 개별 상태를 하위 컴포넌트에 일일이 전달할 필요는 없어졌지만 (Prop Drilling), state와 dispatch는 하위 컴포넌트에 전달해야 했습니다. (Context 적용을 고민해봤지만, 뭔가 잘 어울리지 않았습니다.)

연구를 더 하면 더 낫게 구성할 가능성도 있지만, 근본적으로 제가 원하는 모습이 아닌 것 같다는 생각이 들었습니다.

우선 Redux 같은 복잡한 라이브러리를 쓰지 않고, React 기본 기능을 최대한 활용하면서 Prop Drilling을 피할 수 있는 방향, 즉 Context를 어떻게 활용하면 좋을까 여러가지 찾아봤습니다. 그런데 해당 화면에 필요한 상태를 한 Context에 모두 담아버리면 성능 이슈가 있다고 나왔습니다. (그래서 useContextSelector 같은게 나온 것으로 알고 있습니다.)

그러던 중 프론트엔드 미팅에서 누군가 [Jotai](https://jotai.org/)를 써봤다는 얘기가 나와서 한번 조사를 해보게 됐습니다. 처음에는 어떻게 쓰면 좋을지 감이 안 잡혔는데, 일단 큰 state를 정의하는 대신, 개별 상태(atom)를 정의해서 조합해서 사용한다는 것이 맘에 와 닿았고 좀 더 깊에 연구를 들어갔습니다. 그 결과 제가 원하는 것을 대부분 달성할 수 있는 것으로 확인됐습니다. (계산된 속성/반응형 속성 관련해서는 아직 해결책을 못 찾은 부분이 있습니다) 무엇보다 개념이 단순하고 코드 크기가 작다는 것이 맘에 들었습니다. [Recoil](https://recoiljs.org/ko/)도 Facebook이 직접 관리해서 장기적으로 유지가 될 가능성이 높다고 생각해 살펴봤지만, key가 존재하고, selector가 atom과 구분되는 등 비슷한 개념을 더 복잡하게 정의하고 있다고 생각해 최종적으로는 선택하지 않았습니다. (사업 초기에 Mithril을 선택한 이유도 비슷했습니다. React, RxJS등에서 제게 필요한 최소한의 기능만 작은 코드 베이스로 제공했습니다.)

Jotai 사용법은 단순합니다. 원하는 상태가 있으면 atom으로 정의하고, useState 대신, useAtom을 사용하면 됩니다. 그러면 다른 컴포넌트에서도 useAtom을 통해 그 값을 얻거나 변경할 수 있습니다.

```tsx
import { atom } from 'jotai'

const count_atom = atom(0);

const Counter: FC = () => {
  const [count, setCount] = useAtom(count_atom);
  ...
};
```

액션(로직)의 경우 쓰기 전용 atom으로 정의하면 됩니다. 값을 담은 변수는 snake_case, 함수는 camelCase로 정의하는 저희 컨벤션에 따라 로직을 담은 atom은 camelCase로 정의합니다.

```tsx
const incCountAtom = atom(null, (get, set, inc) => {
  set(count_atom, get(count_atom) + inc);
});

const Counter: FC = () => {
  const incCount = useUpdateAtom(incCountAtom);
  ...
};
```

그냥 정의하면 모든 atom은 전역으로 공유됩니다. 독립된 공간이 필요하다면 Provider로 감싸주면 됩니다. 이번에 만든 어플리케이션은 대부분 Next.js 페이지 단위로 상태를 관리하고 있어서 페이지 컴포넌트를 Provider로 감싸서 사용하고 있습니다.

다음 글에서는 Jotai 활용에 대해 좀 더 자세히 설명하도록 하겠습니다.
