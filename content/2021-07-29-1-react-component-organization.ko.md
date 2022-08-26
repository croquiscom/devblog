---
title: React 프로젝트 컴포넌트 구성
tags: ['React']
date: 2021-07-29
author: Simon(윤상민)
original: http://sixmen.com/ko/tech/2021-07-29-1-react-component-organization/
---

프로젝트가 시작된지 얼마 되지 않은 경우에 소스는 비교적 일관성을 가지고 있습니다. 하지만 시간이 지남에 따라 여러 사람이 참여하고, 비슷한 새로운 프로젝트가 만들어지면서 점점 일관성이 떨어지게 됩니다. (문서나 리뷰 과정이 있으면 비교적 낫지만, 완전히 방지하기는 어려운 것 같습니다) 또한 새로운 기술이 생기면서 (예를 들어 React Hook) 기존에 설정한 구조가 전혀 적합하지 않게 되는 경우가 생깁니다.

그런 의미에서 주기적으로 프로젝트 구성에 관한 가이드를 주기적으로 점검하고 갱신할 필요성이 있습니다. 이번 글에서는 2021년 7월 현재 React 프로젝트의 컴포넌트 구성에 대한 가이드를 설명하려고 합니다. (항상 예외 상황이 있기 마련이고, 이에 따른 변형을 허용하기에 가이드라는 용어를 쓰고 있습니다.)

<!--more-->

React 자체는 UI 구성을 위한 **라이브러리**이기 때문에 구성에 아무 제약이 없습니다. 반면 카카오스타일의 일부 프로젝트에서는 Next.js를 쓰고 있는데, 이는 **프레임워크**이기 때문에 여러가지 규칙이 있습니다. 전체적인 통일성을 위해 Next.js를 사용하지 않는 프로젝트에서도 Next.js와 유사한 구성을 하도록 가이드를 정했습니다.

## 라우트

Next.js 에서는 라우트를 pages 디렉토리에서 정하고 있습니다. 다만 카카오스타일에서는 pages를 프로젝트 루트에 두지 않고, src 밑에 모아두는 것을 선택했습니다. 비 Next.js 프로젝트에서도 마찬가지로 pages 밑에 두지만, 라우트 연결은 수동으로 해야 합니다.

다음은 비 Next.js에서의 라우트 설정 예입니다.

```tsx
import { BrowserRouter as Router, Switch, Route } from 'react-router-dom';
import HomePage from 'pages';
import LoginPage from 'pages/login';
import SignupPage from 'pages/signup';
import QnaQuestionMainPage from 'pages/qna/questions';
import QnaQuestionNewPage from 'pages/qna/questions/new';
import QnaQuestionDetailPage from 'pages/qna/questions/[question_id]';
import ChatRoomMainPage from 'pages/chat/rooms';
import ChatRoomDetailPage from 'pages/chat/rooms/[room_id]';

function App() {
  return (
    <Router>
      <Switch>
        <Route exact path='/'>
          <HomePage />
        </Route>
        <Route exact path='/login'>
          <LoginPage />
        </Route>
        <Route exact path='/signup'>
          <SignupPage />
        </Route>
        <Route exact path='/qna/questions'>
          <QnaQuestionMainPage />
        </Route>
        <Route exact path='/qna/questions/new'>
          <QnaQuestionNewPage />
        </Route>
        <Route path='/qna/questions/:question_id'>
          <QnaQuestionDetailPage />
        </Route>
        <Route exact path='/chat/rooms'>
          <ChatRoomMainPage />
        </Route>
        <Route path='/chat/rooms/:room_id'>
          <ChatRoomDetailPage />
        </Route>
      </Switch>
    </Router>
  );
}

export default App;
```

Next.js에서는 같은 위치에 페이지 파일이 있으면 자동으로 라우트 설정이 됩니다.

## 페이지를 실제 구성하는 컴포넌트

간단한 뷰는 페이지 파일에 넣을 수 있겠지만 복잡한 경우 여러 컴포넌트로 나누어야 하는데 이를 pages 밑에 두면 Next.js 라우트로 인식되므로 별개의 위치에 둬야 합니다. 따라서 이를 components 디렉토리에 두기로 했습니다. 이때 RESTful한 주소를 갖도록 위치한 페이지와 달리 도메인별로 묶어서 구성합니다.

QnaQuestionMainPage(`/pages/qna/questions/index.tsx`)에 대응하는 컴포넌트는 `/components/qna/question/main/index.tsx`에 위치하고, ChatRoomDetailPage(`/pages/chat/rooms/[room_id]/index.tsx`)에 대응하는 컴포넌트는 `/components/chat/room/detail/index.tsx`에 위치합니다. 컴포넌트 이름은 각각 QnaQuestionMain과 ChatRoomDetail입니다. 파일명을 컴포넌트 이름과 일치시킬지 여부를 내부에서 논의할 결과 진입점은 index.tsx로 통일하는 것으로 결정했습니다.

예를 들어 QnaQuestionMainPage는 대략 다음과 같은 형태가 됩니다.

```tsx
import { FC } from 'react';
import QnaQuestionMain from 'components/qna/question/main';

const QnaQuestionMainPage: FC = () => {
  return <QnaQuestionMain />;
};

export default QnaQuestionMainPage;
```

## 데이터 가져오기

Next.js 프로젝트와 비 Next.js 프로젝트는 데이터를 가져오는 시점이 다릅니다. Next.js는 클라이언트에 내보내기 전에 React와 무관하게 데이터를 가져오는데 반해, 비 Next.js 프로젝트는 클라이언트 로딩이 끝난 후 데이터를 가져와야 합니다. 어느 경우에든 비슷하게 구성하기 위해 데이터 가져오는 것을 fetchData라는 함수로 분리해 컴포넌트쪽에 둡니다. 각 컴포넌트는 상위 페이지로 부터 데이터를 props로 받아옵니다. 이렇게 구성하면 컴포넌트에 대한 스토리북 구성시 데이터를 다르게 부여하기 편하다라는 장점도 있습니다. 단점으로는 데이터가 고정이 아닌 경우(예를 들어 필터 설정, 정렬 옵션등에 의해 페이지 이동 없이 바뀌어야 하는 경우), 상위 페이지로 이를 전달하는 방법을 고민해 봐야 한다는 점이 있습니다.

다음은 위 규칙에 따라 구성한 컴포넌트 내용입니다.

```tsx
interface Question {
  id: string;
  title: string;
  date: number;
}

export interface Props {
  total_count: number;
  question_list: Question[];
}

const QnaQuestionMain: FC<Props> = (props) => {
  return (
    <div>
      {props.question_list.map((question) => (
        <QuestionView question={question} key={question.id} />
      ))}
    </div>
  );
};

export default QnaQuestionMain;

export async function fetchData(context: GetServerSidePropsContext | undefined): Promise<Props> {
  const result = await fetch(...);
  return {
    total_count: result.total_count,
    question_list: result.question_list,
  };
}
```

Next.js 프로젝트에서는 getServerSideProps 메소드에서 fetchData를 호출합니다.

```tsx
import type { GetServerSideProps } from 'next';
import QnaQuestionMain, { fetchData, Props } from 'components/qna/question/main';

export const getServerSideProps: GetServerSideProps<Props> = async (context) => {
  return {
    props: await fetchData(context),
  };
};

const QnaQuestionMainPage: FC<Props> = (props) => {
  return <QnaQuestionMain {...props} />;
};

export default QnaQuestionMainPage;
```

반면 비 Next.js 프로젝트에서는 useEffect 안에서 호출합니다.

```tsx
import QnaQuestionMain, { fetchData, Props } from 'components/qna/question/main';

const QnaQuestionMainPage: FC = () => {
  const [props, setProps] = useState<Props>({ total_count: 0, question_list: [] });

  useEffect(() => {
    const run = async () => {
      setProps(await fetchData());
    };
    run();
  }, []);

  return <QnaQuestionMain {...props} />;
};

export default QnaQuestionMainPage;
```

## 자잘한 규칙

컴포넌트를 내보낼 때는 default export를 사용하고 있습니다. 이렇게 하면 내부적으로 컴포넌트 이름을 바꿔도 사용하는 쪽에 영향이 없다는 장점이 있습니다. (예를 들어 jotai를 적용하면서 Provider로 감쌀 필요가 있었습니다) 다만 정의하는 쪽과 사용하는 쪽의 이름을 다르게 줄 수 있어서 찾기 어려워지는 단점도 있습니다. (이는 컴포넌트 이름을 잘 부여하고 주의깊게 사용하면 되긴 합니다) 여기에 스토리북에서 컴포넌트 Props를 제대로 인식하지 못하는 작은 문제도 있습니다. (default export를 사용하고 파일 이름이 컴포넌트와 다른 index.tsx일 경우 발생)

한 페이지 컴포넌트를 작게 쪼갠 경우 그 컴포넌트 사이에는 상대 경로로 참조하면 되지만, pages → components 처럼 멀리 떨어진 컴포넌트를 참조할 경우에는 절대 경로로 참조하는게 좋습니다. 이렇게 구성해야 파일을 `/pages/qna/questions/index.tsx` 에서 `/pages/questions/index.tsx`로 옮겨도 import 변경이 필요없습니다. 상대 경로로 참조 가능한 범위에 대해서는 사람마다 다르게 판단하기도 합니다.

절대 경로로는 src 밑의 디렉토리들(예 components, pages, hooks)을 사용하고 있습니다. 저는 `@/components/qna/question/main` 형태를 제안했는데, `components/qna/question/main`를 쓰는 것으로 정해졌습니다.

> [추가] 새로운 논의를 통해 2022년 3월에 `@/` 를 사용하는 것으로 규칙이 바뀌었습니다.
