---
title: 웹뷰 액티비티간 데이터 동기화하기
tags: ['React','Frontend']
date: 2022-10-12T00:00:00
author: Jason(황주성)
summary:
    지그재그 에픽 서비스는 여러 웹뷰를 사용하도록 구성되어 있습니다. 한 화면에서 변동된 데이터를 다른 화면에 반영해야 하는 기술 이슈가 발생했는데 이를 해결한 방법에 대해 설명합니다.
images: [/img/content/2022-10-12-1/problem.png]
---

안녕하세요! 👋
카카오스타일 프론트엔드 챕터 소속 Jason(제이슨/황주성)입니다.

여러분은 혹시 서비스를 개발하면서 브라우저의 윈도우, 탭 혹은 웹뷰 액티비티 간 데이터를 동기화 해줘야 했던 경험이 있으신가요?

페이스북이나 인스타그램과 같이 사용자가 상세 페이지에서 게시물 좋아요를 누른 뒤에 타임라인 화면으로 돌아왔을 때 해당 변경 내용이 반영된 경우를 예를 들 수 있을 것 같습니다.

작년 초 오픈한 지그재그 에픽 서비스에서도 이와 비슷한 기능이 들어갔는데요, 앱 내 서비스를 제공하면서 가능한 네이티브 앱을 사용하는 듯한 경험을 주기 위해 페이지 이동 시 앱 인터페이스를 통해 새로운 웹뷰 액티비티와 함께 페이지를 보여주는 방식을 적용하게 되었습니다.

![epick.png](/img/content/2022-10-12-1/epick.png)

그러다 보니 메인 화면에서 게시물을 클릭하여 새로운 액티비티를 연 뒤에 좋아요를 클릭하고 액티비티를 닫게 됐을 때 이전에 있던 메인 화면에서도 해당 좋아요 상태가 반영되어야 했고 이러한 부분에서 액티비티 간 데이터 동기화가 필요하게 되었습니다.

![problem.png](/img/content/2022-10-12-1/problem.png)

여러 방법을 시도하다 최종적으로 저는 이 문제를 Broadcast Channel이라는 Web API를 접한 뒤 pubkey/broadcast-channel 라이브러리를 활용하여 해결하게 되었고, 오늘은 이 부분에 대해 간략하게 여러분들께 공유 드리려고 합니다.

## Broadcast Channel API

[Broadcast Channel API](https://developer.mozilla.org/en-US/docs/Web/API/Broadcast_Channel_API)란 동일한 출처에서 서로 다른 브라우징 컨텍스트(탭, 윈도우, iframe 등)들이 채널을 개설하거나 참여하여 해당 채널에서 메시지를 전송하거나 받는 등 양방향 통신을 가능하게 해줍니다.

![Broadcast Channel.png](/img/content/2022-10-12-1/broadcast_channel.png)

> 참조: [https://developer.mozilla.org/en-US/docs/Web/API/Broadcast_Channel_API](https://developer.mozilla.org/en-US/docs/Web/API/Broadcast_Channel_API)

공식 문서의 예시도 나와 있듯 사용법이 정말 간단한데요.

먼저 새로운 BroadcastChannel 인터페이스를 생성해주면서 임의의 채널 이름을 인자로 넣어주게 되면 내부에서 해당 채널을 생성하거나 이미 열려있는 경우 해당 채널에 참여하게 됩니다.

```tsx
const bc = new BroadcastChannel('test_app');
```

### 메시지 수신

메시지 수신은 `onmessage`를 활용하거나 `addEventListener`를 추가하여 수신할 수 있습니다.

```tsx
// onmessage 방식
bc.onmessage = function(event) {
	console.log(event);
};

// addEventListener 방식
bc.addEventListener('message', function(event) {
	console.log(event);
});
```

### 메시지 전달

그러고 나서 `postMessage` 메서드를 통해 메시지를 보내면 아래와 같이 결과를 얻을 수 있습니다.

```tsx
bc.postMessage("Hello! I'm here!");
```

![code1.png](/img/content/2022-10-12-1/code1.png)

> 서로 다른 윈도우에서 왼쪽은 메시지를 수신. 오른쪽은 메시지를 전달.

### 채널 닫기

`close` 메서드를 호출해서 채널을 닫게 되면 이후 `postMessage`를 통해 메시지를 전달해도 수신하지 않게 됩니다.

```tsx
bc.close();
```

![code2.png](/img/content/2022-10-12-1/code2.png)

## pubkey/broadcast-channel 라이브러리

네이티브 Web API의 경우 [지원 브라우저 스펙](https://caniuse.com/broadcastchannel)이 제한적이다 보니 네이티브 방식과 함께 추가로 환경에 따라 별도 localStorage, IndexedDB 등 다양한 메소드로 제공해주는 [pubkey/broadcast-channel](https://github.com/pubkey/broadcast-channel) 라이브러리를 사용하게 되었습니다.

먼저 패키지를 설치해줍니다.

```bash
# npm
npm install broadcast-channel
# yarn
yarn add broadcast-channel
```

채널 생성은 기존 네이티브 Web API랑 비슷하며 필요할 경우 따로 옵션을 설정할 수 있습니다.

```jsx
import { BroadcastChannel } from 'broadcast-channel';

// 기본 사용법
const bc = new BroadcastChannel('test_app');

// 옵션 - 로컬스토리지 방식만 사용할 경우
const bc = new BroadcastChannel('test_app', {
	type: 'localstorage', // 사용 방식 지정: 'native', 'idb', 'localstorage'
});
```

### 메시지 수신

기존 네이티브 Web API와 다르게 파라미터가 `event`가 아닌 `message`입니다.

```jsx
// onmessage 방식
bc.onmessage = function(message) {
	console.log(message); // "Hello! I'm here!"
};

// addEventListener 방식
bc.addEventListener('message', function(message) {
	console.log(message); // "Hello! I'm here!"
});
```

### 메시지 전달 및 채널 닫기

메시지 전달 부분과 채널을 닫는 부분은 기존과 동일합니다.

```jsx
// 메시지 전달
bc.postMessage("Hello! I'm here!");
```

```jsx
// 채널 닫기
bc.close();
```

## 리액트에서 함께 사용해보기

이제 간단한 리액트 Counter 앱에 broadcast-channel 라이브러리를 도입하여 탭 간 데이터 동기화하는 것을 만들어 보겠습니다.

![sample.png](/img/content/2022-10-12-1/sample.png)

### 기본 Counter 코드

```tsx
// src/App.tsx
import { useState } from 'react';

const App = () => {
  const [count, setCount] = useState<number>(0);

  const handleClick = () => {
    setCount((prev) => {
      const next = prev + 1;
      return next;
    });
  };

  return (
    <div>
      <h1>Counter</h1>
      <div>
        <div>Current count: {count}</div>
        <div>
          <button onClick={handleClick}>Count</button>
        </div>
      </div>
    </div>
  );
};

export default App;
```

### useBroadcastChannel React Hooks

리액트에서 사용하기 편하게 broadcast-channel 라이브러리를 훅으로 만들어줍니다.
파라미터로는 **채널 이름**, **메시지 핸들러**, **라이브러리 옵션**을 받도록 구현해주었습니다.

```tsx
// src/hooks.ts
import { useRef, useEffect, useCallback } from 'react';
import { BroadcastChannel, BroadcastChannelOptions } from 'broadcast-channel';

export interface UseBroadcastChannelOptions
  extends Omit<BroadcastChannelOptions, 'node'> {}

export function useBroadcastChannel<T>(
  channelName: string,
  onMessage: (message: T) => void,
  options?: UseBroadcastChannelOptions
) {
  const broadcastChannelRef = useRef<BroadcastChannel<T> | null>(null);
  const onMessageRef = useRef<((message: T) => void) | null>(null);

  const handlePostMessage = useCallback((message: T) => {
    if (broadcastChannelRef.current) {
      broadcastChannelRef.current.postMessage(message);
    }
  }, []);

  useEffect(() => {
    onMessageRef.current = onMessage;
  }, [onMessage]);

  useEffect(() => {
    let mounted = true;
    const channel = new BroadcastChannel<T>(channelName, options);

    const handleMessage = (message: T) => {
      if (!mounted) {
        return;
      }
      onMessageRef.current?.(message);
    };

    channel.onmessage = handleMessage;
    broadcastChannelRef.current = channel;

    return () => {
      mounted = false;
      broadcastChannelRef.current = null;
      channel.close();
    };
  }, [channelName, options]);

  return { postMessage: handlePostMessage };
}
```

### Counter App에 useBroadcastChannel 도입

마지막으로 만들었던 훅을 리액트 앱에 추가하고 `onMessage` 부분과 `postMessage` 부분을 도입해 줍니다.

```tsx
// src/App.tsx
import { useState } from 'react';
import { useBroadcastChannel } from './hooks';

const App = () => {
  const [count, setCount] = useState<number>(0);
  const { postMessage } = useBroadcastChannel<number>('test-app', (message) => {
    // 메시지를 전달받으면 setCount 함수 호출
    setCount(message);
  });

  const handleClick = () => {
    setCount((prev) => {
      const next = prev + 1;
      // 다른 윈도우나 탭에 알려주기 위해 postMessage 메서드 호출
      postMessage(next);
      return next;
    });
  };

  return (
    <div>
      <h1>Counter</h1>
      <div>
        <div>Current count: {count}</div>
        <div>
          <button onClick={handleClick}>Count</button>
        </div>
      </div>
    </div>
  );
};

export default App;
```

![sample_result.gif](/img/content/2022-10-12-1/sample_result.gif)

## 마치며

만약 [TanStack Query](https://tanstack.com/query/v4)(React Query)를 사용해 데이터를 관리하고 있다면 직접 데이터를 주고 받는 대신 실험 버전 플러그인인 [broadcastQueryClient](https://tanstack.com/query/v4/docs/plugins/broadcastQueryClient)를 활용해 데이터를 동기화 할 수도 있습니다. 클라이언트 웹뷰간 데이터를 동기화 하는 대신 웹뷰 전환이 일어날 때(visibilitychange 이벤트) 서버에서 새로 데이터를 받아올 수도 있습니다. 이와 같이 문제를 해결하는 방법은 여러가지가 있으니 상황에 맞게 도입해보면 좋을 것 같습니다.

추가로 위에 만들었던 리액트 훅을 [모듈](https://github.com/use-broadcast-channel/use-broadcast-channel)로 만들어 공개했습니다.
이슈 및 PR은 언제나 환영입니다. :) (~~Star도 주시면 좋습니다~~)

마지막으로 지그재그 에픽 서비스 및 지그재그 앱 내 웹뷰 페이지를 함께 개발해보고 싶으시면 언제든 편하게 [링크](https://career.kakaostyle.com/o/31890)를 통해 지원해주세요!

감사합니다.