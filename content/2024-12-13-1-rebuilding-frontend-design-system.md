---
title: '프론트엔드팀의 디자인 시스템 재구축기'
tags: ['Frontend']
date: 2024-12-13T01:00:00
author: Jason(황주성)
---

안녕하세요, 카카오스타일 지그재그 서비스 FE팀의 제이슨입니다.

2023년 초, 저희 팀은 비즈니스와 더불어 기술적인 개선이 필요하다는 것을 느꼈습니다. 그중에서도 특히 여러 지면에서 독립적으로 관리되고 있던 **상품 카드 컴포넌트의 일원화** 작업이 중요하게 여겨졌고. 이 문제를 해결하기 위해서는 단순 리팩토링을 넘어, 팀 전체의 UI/UX를 통합적으로 관리할 수 있는 디자인 시스템의 재구축이 필요하다고 판단했습니다.

<!--more-->

당시 팀 리더와의 1:1 미팅에서 프로젝트를 맡아보면 어떻겠냐는 제안을 받게 되었는데 이런 제안이 처음에는 큰 부담으로 다가왔습니다. 무엇보다, 디자인 시스템을 완성한다는 것은 마치 이루어질 수 없는 꿈처럼 느껴졌기 때문입니다. 디자이너와 개발자가 한마음이 되어야 하는 이상적인 목표는 쉽지 않은 도전이었고, 상품 카드를 하나의 시스템으로 통합하는 작업 역시 큰 난관으로 느껴졌기 때문입니다.

위와 같은 이유로 처음에는 조금 망설였지만, 고민 끝에 '**안 된다고 포기하기보다는 일단 해보는 게 뭐라도 얻을 수 있지 않을까**'라는 생각이 들었습니다. 그렇게 저는 디자인 시스템의 기반을 재구축하는 작업을 시작했고, 이를 바탕으로 상품 카드 컴포넌트를 일원화하는 목표를 설정하게 되었습니다.

이 글에서는 2023년 중반부터 1년 이상 진행했던 디자인 시스템 재구축 프로젝트에서 마주한 **상품 카드 통합, CSS 변수 기반 토큰 도입, 모듈화 작업** 등 주요 과제와 그 해결 과정을 공유하고자 합니다. 비슷한 고민을 하고 계신 분들께 조금이나마 도움이 되었으면 좋겠습니다.

## 프로젝트 초기 준비

### 기존 디자인 시스템 현황 파악

프로젝트를 시작하기에 앞서, 기존 디자인 시스템이 어떻게 관리되고 있는지 파악했습니다. 기존에는 여러 지면에서 각각 독립적으로 관리되고 있었으며, 일관성이 부족하고 중복되는 코드가 많았습니다. 스타일링은 [Emotion 라이브러리](https://emotion.sh/docs/introduction)를 활용했는데, 각 컴포넌트는 색상, 타이포그래피, 아이콘 등 기본적인 디자인 토큰과 에셋을 개별적으로 가져와 적용하는 방식이었습니다.

또한 디자인 시스템이라고 붙이기는 했지만 단순한 컴포넌트 모음에서 크게 벗어나지 않은 상태였습니다. 당시 앱 플랫폼의 디자인 시스템을 잘 갖추어져 있었기 때문에, 이 경험을 바탕으로 웹 환경에 최적화해서 디자인 시스템을 재구축하기로 했습니다.

### 목표 설정

현황을 파악한 뒤, 다음과 같은 목표를 설정하게 되었습니다.

1. **프로젝트 구조 정의**: 모듈화를 통해 유지보수와 확장성을 개선.
2. **스타일링 방식 선택**: 런타임 CSS-in-JS 방식의 한계를 고려하여 제로 런타임 스타일링 방식으로 전환.
3. **CSS 변수 기반 디자인 토큰과 테마 관리**: 테마와 디자인 토큰 관리의 효율성 개선.
4. **상품 카드 컴포넌트 일원화**: 중복 코드를 줄이고 일관성을 높이기 위한 시스템 통합.

## 프로젝트 구조 정의

기존에는 색상, 아이콘, 테마, 컴포넌트 등 모든 요소가 **하나의 패키지** 안에서 구성되어 있었습니다. 이 방식은 초기에는 관리가 편했지만, 점차 기능이 추가되면서 **관심사가 명확하지 않아 유지보수와 확장이 어려워지는 문제**가 발생했습니다. 특히, 새로운 기능이 추가될 때 배럴 파일에 해당 기능을 내보내는 작업이 필요했는데, 이 과정에서 **변경 내역이 누락되거나 충돌**이 발생하는 경우가 잦았습니다. 결과적으로 **배포 및 코드 변경에 대한 부담이 커지게 되며**, 복잡도가 증가함에 따라 **개발 생산성**이 점점 저하되었습니다.

이 문제를 해결하기 위해 **관심사 분리 원칙**을 적용하고자 했습니다.

**관심사 분리 원칙**은 소프트웨어 설계에서 서로 다른 책임을 가진 코드를 명확히 분리함으로써, 시스템의 가독성, 유지보수성, 확장성을 높이는 데 초점을 맞추는 원칙입니다. 이를 디자인 시스템 패키지에 적용해 다음과 같이 각각의 모듈 패키지로 분리하였습니다.

- **Core**: 로깅 및 전반적인 코어 기능을 제공
- **Components**: 디자인 시스템 컴포넌트 제공
- **Icons**: 디자인 시스템 아이콘 에셋 제공
- **Themes**: 서비스의 테마 스타일 제공
- **Tokens**: 디자인 시스템에 정의된 디자인 토큰 제공
- **ZDS (Zigzag Design System)**: 각 모듈을 포함하는 메인 패키지

![프로젝트 구조 정의.png](/img/content/2024-12-13-1/01.png)

### 과도한 모듈 세분화는 오히려 단점이 될 수 있다

모듈을 세분화하게 되면 **Nx**나 **Turborepo**에서 제공하는 **증분 빌드(Incremental Build)** 기능을 통해 코드 변경이 있는 패키지만 따로 빌드 스크립트를 호출할 수 있어 패키지 배포 측면에서 이점이 있습니다. 예를 들어, Button 컴포넌트를 별도 패키지로 분리한다면 전체 Components 패키지를 빌드하는 대신 Button 컴포넌트만 따로 빌드하여 빌드 시간을 단축시킬 수 있습니다.

그러나 이러한 장점에도 불구하고 **초기 단계에서의 과도한 세분화는 오버 엔지니어링으로 이어져 프로젝트를 진행하는 데 오히려 허들이 될 수 있다**고 생각했습니다. 이에 증분 빌드의 매력적인 장점이 있음에도, 주어진 리소스와 상황을 고려하여 Components 패키지 구조를 유지하는 방향으로 결정하였습니다.

## 스타일링 방식 선택

기존에 사용하던 Emotion 라이브러리는 런타임 환경에서 스타일을 주입하는 방식이었고, 이로 인해 약간의 성능 문제가 있었습니다. 또한, 이러한 런타임 방식은 React Server Components(RSC)와의 구조적인 한계로 호환되지 않는 점도 있었는데요. 당시 RSC가 React 생태계에서 주요 논점으로 떠오른 만큼 이러한 문제를 해결할 새로운 스타일링 방식을 검토할 필요가 있었습니다.

### 고려 사항

앞서 언급한 문제들을 해결하면서 새로운 스타일링 방식을 선택하기 위해 다음과 같은 기준을 정의했습니다.

1. **CSS 변수 기반 스타일링 지원**: CSS 변수를 활용해 디자인 토큰을 유연하게 관리할 수 있는지.
2. **유연한 테마 관리**: 다크 테마, 라이트 테마 등 다양한 테마를 효율적으로 지원할 수 있는지.
3. **타입 안전성 및 휴먼 에러 방지**: 오타로 인한 오류를 방지하고, 존재하지 않는 토큰 사용 시 개발자가 즉각 피드백을 받을 수 있는지.
4. **가벼운 번들 사이즈**: 서비스 번들 크기를 최소화할 수 있는지.
5. **제로 런타임 지원**: 스타일링은 빌드 시 생성되어야 하며, 런타임이 필요한 경우에도 최소한의 크기로 RSC와 호환 가능한지.
6. **학습 러닝 커브**: 팀원들이 새로운 방식에 적응하기 쉬운지.

### 후보군 및 장단점

위 기준을 바탕으로 네 가지 스타일링 방식을 검토했습니다.

**Vanilla Extract**:

- **장점**:
  - 타입 안전성과 디자인 시스템 구축에 필요한 유틸리티 제공 (e.g., styleVariants, recipes, sprinkles, createThemeContract)
  - 기본적으로 빌드 시 스타일을 추출하며, 필요시 런타임 스타일도 제공
  - 프레임워크에 구애받지 않음
  - 런타임 스타일 사용 시 가벼운 번들 크기 (GZIP 기준 718B)
- **단점**:
  - Tagged Template Literals 미지원
  - 복잡한 CSS 선택자 사용 제한
  - 초기 학습 러닝 커브 존재

**Emotion**:

- **장점**:
  - 가장 낮은 학습 러닝 커브
  - Tagged Template Literals 지원으로 직관적인 사용 가능
- **단점**:
  - 런타임 스타일 생성으로 인한 성능 부담
  - 런타임 의존성으로 인해 RSC와 호환되지 않음

**Linaria**:

- **장점**:
  - Emotion과 유사한 사용법으로 러닝 커브가 낮음
  - 스타일을 빌드 시 생성하므로 RSC와 호환 가능
- **단점**:
  - Vanilla Extract와 비교해 고도화된 유틸리티 미제공

**CSS Modules**:

- **장점**:
  - CSS 파일을 추출하므로 빌드 후 가벼움
  - 프레임워크에 구애받지 않음
- **단점**:
  - 타입 안전성 미제공
  - 테마 관리 기능 미지원
  - 컴포넌트와 스타일을 같은 파일에서 관리할 수 없음

### 최종 결정

다양한 스타일링 방식을 비교한 결과, 저희는 디자인 시스템을 재구축하기 위해 **Vanilla Extract**를 선택하게 되었습니다.

**Linaria**는 Emotion과 유사한 **Tagged Template Literals 방식**을 사용하여, **러닝 커브가 낮고 빠르게 적용할 수 있다는 점**에서 서비스 제작 환경에 적합한 방식으로 바라볼 수 있었습니다만, 이번 프로젝트의 목표를 고려했을 때 **Vanilla Extract**의 **유틸리티 기능, 타입 안정성, 제로 런타임 방식**이 **디자인 시스템 구축에 더 적합하다고 판단했습니다.**

## CSS 변수 기반 디자인 토큰과 테마 관리

기존에는 다음과 같은 방식으로 사용되고 있었습니다.

**1. 테마별 디자인 토큰 정의**

자바스크립트 변수를 통해 테마별 디자인 토큰을 정의합니다.

```tsx
// themes.ts
export const lightTheme = {
  color: {
    textPrimary: '#292b2b',
    background: '#ffffff',
  },
};

export const darkTheme = {
  color: {
    textPrimary: '#d0d4d6',
    background: '#000000',
  },
};
```

**2. 사용자 환경에 따른 초기 설정**

페이지 진입 시 브라우저의 `prefers-color-scheme` 속성을 활용하여 사용자 환경에 맞는 테마를 감지한 뒤, 이를 HTML 태그의 `data-theme` 속성에 설정합니다.

```html
<script>
  // 사용자의 테마를 감지하고 HTML 태그에 설정
  var theme = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
  var html = document.querySelector('html');
  html.setAttribute('data-theme', theme);
</script>
```

**3. ThemeProvider와 React 상태 동기화**

설정된 `data-theme` 속성값을 기반으로 React 상태를 초기화하고, 해당 테마에 맞는 디자인 토큰을 `ThemeProvider`에 주입합니다.

```tsx
// _app.tsx
import { useEffect, useState } from 'react';
import { ThemeProvider } from '@emotion/react';
import { AppProps } from 'next/app';

import { darkTheme, lightTheme } from './themes';

const App = ({ Component, pageProps }: AppProps) => {
  const [theme, setTheme] = useState('');

  // 마운트 시 HTML 태그 data-theme 속성값으로 테마 설정
  useEffect(() => {
    if (typeof window === 'undefined') {
      return;
    }
    const html = document.querySelector('html') as HTMLHtmlElement;
    const theme = html.dataset.theme || 'light';
    setTheme(theme);
  }, []);

  return (
    <ThemeProvider theme={theme === 'dark' ? darkTheme : lightTheme}>
      <Component {...pageProps} />
    </ThemeProvider>
  );
};

export default App;
```

**4. 컴포넌트에서 테마 토큰 사용**

컴포넌트에서는 `ThemeProvider`에 주입된 테마값을 참조하여 스타일을 지정합니다.

```tsx
// Button.tsx
import styled from '@emotion/styled';

export const Button = styled.button`
  color: ${({ theme }) => theme.color.textPrimary};
  background-color: ${({ theme }) => theme.color.background};
`;
```

### 기존 방식의 문제

이러한 기존 방식이 초기에는 간단하고 효율적이었지만, 프로젝트가 확장되면서 몇 가지 문제를 마주하게 되었습니다.

**1. 디자인 토큰의 가독성 부족**

컴포넌트 스타일을 지정할 때 의미 있는 토큰을(`textPrimary`)을 사용했음에도, 최종 CSS에는 실제 값(`#292b2b`)만 표시되어 어떤 토큰이 사용되었는지 파악하기 어려웠습니다.

```tsx
// Button.tsx
import styled from '@emotion/styled';

export const Button = styled.button`
  color: ${({ theme }) => theme.color.textPrimary};
  background-color: ${({ theme }) => theme.color.background};
`;
```

```css
.Button__local__hash {
  color: #292b2b;
  background-color: #ffffff;
}
```

**2. 동적 테마 적용의 복잡성**

테마에 맞는 스타일을 적용하기 위해 `data-theme` 속성을 설정하고 React 상태를 별도로 관리해야 하는 점에서 사용의 어려움이 있었습니다. 또한, `ThemeProvider`에 의존하다 보니 테마 전환 시 컴포넌트가 리렌더링되어 성능 저하가 발생할 가능성도 있었습니다.

**3. FOUC(Flash of Unstyled Content) 현상**

서버 사이드 렌더링 환경에서는 `prefers-color-scheme` 속성을 확인할 수 없다 보니, 초기 페이지 로딩 시 React 상태를 동기화 하는 과정에서 기본 테마가 잠시 노출된 후 다크 테마로 전환되는 깜빡임 현상이 발생했습니다.

### 개선된 방식

위 문제를 해결하기 위해 **CSS 변수를 도입**하고, 기본적인 테마 적용은 React 상태에 의존하지 않고 **브라우저 레벨에서 테마를 관리**하고자 했습니다.

실제 프로젝트에서 적용된 방식은 좀 더 복잡하지만, 간단히 공유하면 다음과 같습니다.

**1. 디자인 토큰 정의**

Vanilla Extract의 `createGlobalThemeContract` API를 사용하여 디자인 토큰을 정의합니다. 여기서는 디자인 토큰의 종류를 명시적으로 하기 위해 **토큰 계약**(`TokenContract`)을 작성하고, API를 통해 생성된 **CSS 변수**(`vars`)를 관리합니다.

```tsx
// tokens/src/contracts/index.ts
export const colorTokenContract = {
  textPrimary: 'color-text-primary',
  background: 'color-background',
} as const;

export type ColorTokenContract = typeof colorTokenContract;

export const tokenContracts = {
  color: colorTokenContract,
} as const;

export type TokenContracts = typeof tokenContracts;
```

```tsx
// tokens/src/index.ts
import { createGlobalThemeContract } from '@vanilla-extract/css';

import { tokenContracts } from './contracts';

export const vars = createGlobalThemeContract(tokenContracts);

export type Vars = typeof vars;
```

**2. 테마별 디자인 토큰값 주입**

정의한 토큰 계약을 TypeScript의 `satisfies` 키워드와 함께 사용해 테마별 디자인 토큰값을 넣어줍니다.

```tsx
// tokens/src/zigzag/index.ts
import type { ColorTokenContract, TokenContracts } from '../contracts';

type TokenValue = string;

export const lightColor = {
  textPrimary: '#292b2b',
  background: '#ffffff',
} as const satisfies Record<ColorTokenContract, TokenValue>;

export const darkColor = {
  textPrimary: '#d0d4d6',
  background: '#000000',
} as const satisfies Record<ColorTokenContract, TokenValue>;

export const lightTheme = {
  color: lightColor,
} as const satisfies { [key in keyof TokenContracts]: Record<TokenContracts[key], TokenValue> };

export const darkTheme = {
  color: darkColor,
} as const satisfies { [key in keyof TokenContracts]: Record<TokenContracts[key], TokenValue> };
```

**3. 전역 테마 설정**

Vanilla Extract의 `createGlobalTheme` API를 사용해 `data-theme` 속성값에 따라 CSS 변수를 동적으로 적용합니다.

```tsx
// themes/src/zigzag.ts
import { createGlobalTheme } from '@vanilla-extract/css';

import { vars } from '../../tokens/src';
import { lightTheme, darkTheme } from '../../tokens/zigzag';

createGlobalTheme(':root,:root[data-theme="light"]', vars, lightTheme);
createGlobalTheme(':root[data-theme="dark"]', vars, darkTheme);
```

이렇게 작성한 코드는 최종 CSS에서 다음과 같이 출력됩니다.

```css
:root,
:root[data-theme='light'] {
  --color-text-primary: #292b2b;
  --color-background: #ffffff;
}
:root[data-theme='dark'] {
  --color-text-primary: #d0d4d6;
  --color-background: #000000;
}
```

**4. 컴포넌트 스타일링**

컴포넌트에서는 `vars`를 불러와 `ThemeProvider` 의존 없이 간결하게 테마에 맞는 스타일을 적용할 수 있습니다.

```tsx
// components/src/Button.css.ts
import { style } from '@vanilla-extract/css';

import { vars } from '../../tokens/src';

export const button = style({
  color: vars.color.textPrimary, // var(--color-text-primary)
  background: vars.color.background, // var(--color-background)
});
```

```tsx
// components/src/Button.tsx
import { button } from './Button.css';

export const Button = () => {
  return <button className={button}>Button</button>;
};
```

### 개선 결과

이러한 방식을 도입한 뒤, 저희는 다음과 같은 개선점을 가질 수 있게 되었습니다.

먼저, 디자인 리뷰 단계에서 컴포넌트에 적용된 스타일을 확인할 때 **CSS 변수**로 사용된 토큰을 개발자 도구에서 확인할 수 있어 디자이너와의 **원활한 피드백**을 주고받을 수 있게 되었습니다.

CSS 변수를 사용해 브라우저 레벨에서 테마를 관리하면서, 기존의 **컴포넌트 리렌더링으로 인한 성능 저하 우려가 해소**되었습니다. 또한, 이와 함께 **FOUC 현상도 해결**할 수 있었습니다.

마지막으로 Vanilla Extract에서 제공하는 API와 스타일링 방식 덕분에 CSS 변수를 안전하게 사용할 수 있었고, 이를 통해 **오타나 잘못된 토큰을 참조하는 경우를 방지하여 코드 안정성을 높일 수 있었습니다.**

## 상품 카드 컴포넌트 일원화

기존 상품 카드는 여러 지면에서 각각 독립적으로 관리되고 있었습니다. 이로 인해 UI와 비즈니스 로직이 중복되는 경우가 잦았고, 관련 기능을 수정하거나 확장하는 과정에서 반복적인 어려움이 있었습니다. 이러한 문제는 작업 효율성을 떨어뜨리는 주요 원인이 되었으며, 서비스 내에서 중요한 역할을 하는 컴포넌트인 만큼 효율적인 관리와 통합된 시스템으로 재구축이 필요했습니다.

### 디자인 스펙 리뷰

컴포넌트를 개발하기 전에, 먼저 디자인 스펙을 검토했습니다. 상품 카드의 내부는 크게 **썸네일**과 **메타데이터** 영역으로 구성되어 있었으며, 이 둘을 상황에 따라 **가로형**과 **세로형** 두 가지 레이아웃으로 사용하고 있었습니다.

![상품 카드 컴포넌트 일원화 1.png](/img/content/2024-12-13-1/02.png)

또한, 대부분 지면에서는 디자인 시스템에 정의된 UI를 따랐지만, 지면별로 UI가 조금씩 다르게 적용되는 사례도 확인할 수 있었습니다. 예를 들어, 장바구니 지면에서는 품절 상태일 때 메타데이터 영역에 "재입고 알림" 버튼이 추가로 들어가는 경우가 있었습니다.

![상품 카드 컴포넌트 일원화 2.png](/img/content/2024-12-13-1/03.png)

### 컴파운드 컴포넌트 패턴 도입

이처럼 상품 카드의 구조는 기본적으로 일관성을 유지하면서도 경우에 따라 지면별로 세부적으로 달라지는 경우가 있었습니다. 이러한 유연성을 유지하면서도 관리의 복잡성을 줄이기 위해, 블록 컴포넌트를 조합해 활용할 수 있는 **컴파운드 컴포넌트 패턴**을 도입하기로 결정했습니다.

이 패턴은 컴포넌트 내부에 블록 형태의 서브 컴포넌트를 제공해 사용자가 원하는 대로 조합할 수 있도록 설계하는 방식입니다. 상품 카드 컴포넌트에 이를 적용하기 위해, 저희는 다음과 같은 모듈 구조를 정의했습니다.

```tsx
<ProductCard>
  <ProductCard.Thumbnail>
    <ProductCard.ThumbnailNudge />
    <ProductCard.ThumbnailRank />
    <ProductCard.ThumbnailEmblem />
    <ProductCard.ThumbnailCheckbox />
    <ProductCard.ThumbnailLikeButton />
  </ProductCard.Thumbnail>
  <ProductCard.Metadata>
    <ProductCard.MetadataItem>
      <ProductCard.MetadataTitle />
    </ProductCard.MetadataItem>
    <ProductCard.MetadataItem>
      <ProductCard.MetadataPrice />
    </ProductCard.MetadataItem>
    <ProductCard.MetadataItem>
      <ProductCard.MetadataOption />
    </ProductCard.MetadataItem>
    <ProductCard.MetadataItem>
      <ProductCard.MetadataBadgeItems />
    </ProductCard.MetadataItem>
    <ProductCard.MetadataItem>
      <ProductCard.MetadataReview />
    </ProductCard.MetadataItem>
  </ProductCard.Metadata>
</ProductCard>
```

이 모듈 구조를 활용하면 앞서 언급한 "재입고 알림" 버튼과 같은 사례도 다음과 같이 비교적 쉽게 대응할 수 있습니다.

```tsx
const CartSoldOutExample = () => {
  return (
    <ProductCard>
      <ProductCard.Thumbnail />
      <ProductCard.Metadata>
        <ProductCard.MetadataItem>
          <ProductCard.MetadataTitle />
        </ProductCard.MetadataItem>
        <ProductCard.MetadataItem>
          <ProductCard.MetadataOption />
        </ProductCard.MetadataItem>
        <ProductCard.MetadataItem>
          <ProductCard.MetadataBadgeItems />
        </ProductCard.MetadataItem>
        {/* 재입고 알림 버튼 추가 */}
        <ProductCard.MetadataItem>
          <Button>재입고 알림</Button>
        </ProductCard.MetadataItem>
      </ProductCard.Metadata>
    </ProductCard>
  );
};
```

### 상품 카드 컴포넌트의 계층적 설계

컴파운드 컴포넌트 패턴은 UI를 유연하게 조립할 수 있다는 장점이 있지만, 대부분의 지면에서는 디자인 시스템에 정의된 기본 UI를 사용하는 경우가 많았습니다. 이러한 경우에도 각 지면에서 컴포넌트를 조립해 사용하는 과정은 번거로움으로 다가올 가능성이 있었습니다. 더불어, 상품 클릭 시 상세 페이지로 이동하거나 찜하기 기능과 같은 공통 비즈니스 로직이 중복으로 작성될 가능성도 있었습니다.

이를 해결하기 위해 컴포넌트 레이어를 **UI 로직, 비즈니스 로직, 지면별 로직**으로 분리하였습니다.

1. **UI 컴포넌트**:
   - 상품 카드 내부의 썸네일, 메타데이터, 뱃지 등을 노출하는 순수 UI 레이어 입니다.
   - 독립적이고 재사용 가능한 블록 형태로 구성되어 있습니다.
2. **서비스 컴포넌트**:
   - UI 컴포넌트를 기반으로 비즈니스 로직(예: 상품 카드 클릭 시 상세 페이지로 이동, 찜하기 기능 등)을 추가합니다.
   - 공용 기능을 포함하여 중복 코드를 최소화합니다.
3. **지면별 로직**:
   - 서비스 컴포넌트를 사용하면서, 로깅과 같이 특정 지면에 필요한 동작을 추가로 처리합니다.

### 기존 코드 to 개선 코드

아래는 세로형 상품 카드 구조를 개선하기 전후의 스크린샷입니다. 왼쪽이 기존 코드, 오른쪽이 새롭게 작성된 코드입니다.

![기존 코드 to 개선 코드.png](/img/content/2024-12-13-1/04.png)

기존 코드의 경우 여러 가지 Props와 조건문이 뒤섞여 하나의 파일내에서 처리하다 보니, 코드 가독성과 유지보수성이 낮아지는 문제가 있었습니다.

이를 위에서 UI 컴포넌트, 서비스 컴포넌트, 커스텀 훅으로 로직을 구분함으로써, 파일 단위가 작아지고 관심사가 명확해졌습니다.

![MetadataPrice 컴포넌트 예시.png](/img/content/2024-12-13-1/05.png)

### 결과

**컴파운드 컴포넌트 패턴**과 **계층적 설계**, 그리고 **공용 커스텀 훅**의 도입으로, **UI와 비즈니스 로직**을 명확히 분리하고 지면별 요구 사항에 따라 유연하게 확장할 수 있는 기반을 마련했습니다. 이후 이러한 구조를 바탕으로 11개의 지면에 상품 카드를 성공적으로 적용하며 통합 작업을 완료할 수 있었습니다.

![상품 카드 컴포넌트 일원화 실제 사례 1.png](/img/content/2024-12-13-1/06.png)

![상품 카드 컴포넌트 일원화 실제 사례 2.png](/img/content/2024-12-13-1/07.png)

![상품 카드 컴포넌트 일원화 실제 사례 3.png](/img/content/2024-12-13-1/08.png)

## 협업과 커뮤니케이션

프로젝트를 리딩하면서 많은 어려움이 있었습니다. 디자인 시스템을 재구축하기 위해 설계를 고민하는 것도 쉽지 않았지만, 타 팀과의 커뮤니케이션과 프로젝트 매니징은 저에게 특히 큰 어려움으로 작용했던 것 같습니다.

### Inverse 색상 토큰 사례

기억에 남는 사례 중 하나는 테마 기반 토큰에서 Inverse(강조) 개념을 디자이너분들에게 설명했던 경험입니다.

기존에는 디자인 시안에 라이트 테마와 다크 테마 토큰을 혼용해 강조 효과를 내는 경우가 있었습니다. 이는 반대되는 테마의 색상을 가져와 사용하는 방식으로, 테마 전환 시 화면에 여러 테마가 혼재되며 동작이 원활하지 않을 가능성을 만들었습니다.

특히, 디자이너분들이 테마를 스위칭하기 위해 사용하는 피그마 Appearance 플러그인에서도 비슷한 문제가 발생했는데요, **테마 전환이 일부만 적용되어 변경되지 않은 부분을 수동으로 조정해야 하는 번거로움**이 있었습니다.

이러한 상황에서 이 문제를 개선할 수 있는 Inverse 색상 토큰의 필요성을 디자이너분들에게 설득해야 했습니다. 그렇기에 단순히 말로 설명하는 것만으로는 충분하지 않다고 판단했고, **Figma**와 **FigJam**을 활용해 디자이너분들이 공감할 만한 사례를 시각적으로 정리해 공유했습니다.

![Figma와 FigJam을 활용해 Inverse 색상 토큰의 필요성을 공유](/img/content/2024-12-13-1/09.png)

이 과정을 통해 Inverse 색상 토큰의 필요성을 설명할 수 있었고, 이후 신규 색상 시스템 작업에서 Inverse 색상 토큰 개념이 도입되는 것을 보며 약간의 보람을 느낄 수 있었습니다. 직접적인 영향을 미쳤는지는 알 수 없지만, 작업의 결과로 이어졌다는 점에서 의미 있는 경험이었다고 생각이 들었습니다.

### 방향을 잃을 뻔했던 순간

작업을 진행하다 보니, 설정했던 목표 외에 예상치 못한 문제에서 깊은 고민에 빠지게 되었습니다.

여러 컴포넌트를 하나로 묶은 복잡한 구조를 어떻게 하면 확장성 있게 설계할 수 있을지 고민하던 중, **David Schnurr**이 작성한 [컴포넌트 재정의 패턴](https://dschnurr.medium.com/better-reusable-react-components-with-the-overrides-pattern-9eca2339f646)을 접하게 되었는데요. 그러나 검토를 진행할수록 고려해야 할 요소들이 점점 늘어났고, 이로 인해 초기 목표가 흐릿해지고 방향을 잃는 상황에 놓였습니다.

사실, 목표와 맞지 않는 부분은 과감히 제외하고 나아가야 했지만, 혼자만의 고민에 갇혀 판단이 점점 더 흐릿해졌던 것 같습니다.

초기에는 혼자 프로젝트를 진행하며 이러한 고민을 해결하기 쉽지 않았지만, 이후 두 동료와 함께 프로젝트를 진행하게 되면서 상황이 나아졌습니다.

동료들과 협업을 시작한 뒤, 매주 위클리 미팅을 통해 진행 상황을 공유하는 자리를 만들었습니다. 이 과정에서 해당 문제를 동료들과 공유했고, 유용한 피드백을 받을 수 있었습니다. 특히, 동료의 조언을 통해 지금 당장의 목표와 우선순위를 다시 돌아볼 수 있었고, 이를 계기로 혼자만의 고민에서 벗어나 올바른 방향으로 나아갈 수 있었습니다.

이러한 경험을 통해 동료와의 협업과 피드백의 중요성을 다시 한번 깨닫게 되었던 것 같습니다.

## 프로젝트의 흔적을 남기며

개인적으로 프로젝트를 진행하면서 매 순간의 과정을 남기려고 노력했습니다. 물론, 과정을 기록하는 것은 결코 쉬운 일이 아니었습니다. 작업에 몰두하다 보면 메모를 남기는 것이 귀찮게 느껴질 때도 있었고, 기록이 진행을 방해한다고 생각될 때도 있었습니다. 그럼에도 기록을 남기려 했던 이유는 기록하는 습관을 기르고 싶었던 개인적인 다짐과, 프로젝트 리딩을 맡으면서 작업의 흐름과 결정 과정을 명확히 남겨두고 싶다는 욕심이 있었기 때문이었습니다.

물론 프로젝트를 진행하며 설계는 끊임없이 변했기에, 처음부터 완벽한 기록을 남기기란 불가능했습니다. 대신 떠오르는 아이디어나 주요 결정 사항을 간단히 메모하고, 이를 점진적으로 다듬어 문서를 작성하는 방식을 선택했습니다.

이후 이러한 기록들은 프로젝트가 진행되는 동안 큰 도움이 되었습니다. 새로운 팀원이 합류했을 때, 남겨둔 문서를 통해 프로젝트의 히스토리를 빠르게 파악할 수 있게 되었고, 상품 카드 통합 가이드 문서는 각 지면에서 작업할 때 중요한 참고 자료가 되기도 했습니다. 또한, 프로젝트가 완료된 지 1년이 지난 지금, 당시 남겨둔 기록들은 이번 글을 작성하며 과정을 되짚고 정리하는 데도 큰 힘이 되었습니다.

결과적으로, 흔적을 남기는 습관은 단순히 기억을 보존하는 것을 넘어, 협업 효율성을 높이고 프로젝트를 완성하는 데 중요한 기반이 되었다고 생각합니다.

![프로젝트의 흔적을 남기며.png](/img/content/2024-12-13-1/10.png)

![상품 카드 교체 작업을 진행하면서 챕터 채널에 공유](/img/content/2024-12-13-1/11.png)

## 디자인 시스템 재구축, 그 이후

디자인 시스템 재구축은 서비스 전반에 걸쳐 긍정적인 변화를 가져왔습니다.

먼저, 상품 카드 컴포넌트 일원화 작업을 통해 **중복 코드를 크게 줄이는 데 성공**했습니다. 계층적으로 설계된 컴포넌트 구조 덕분에 공통 로직을 재사용할 수 있었으며, 지면별로 필요한 로직도 쉽게 추가할 수 있었습니다.

또한, 재구축 이후 진행된 **지그재그 홈 지면 UI 전면 개편**에서는 계층적 설계의 효과를 실감할 수 있었습니다. 상품 카드 컴포넌트 전체 UI가 변경되는 상황에서도 앱 버전별 UI를 분기 처리하는 작업을 효율적으로 처리할 수 있었습니다. 과거에는 지면별로 코드를 수정해야 했겠지만, 통합된 컴포넌트 덕분에 빠르고 비교적 유연하게 작업을 진행할 수 있었습니다.

최근 진행된 **디자인 시스템 색상 시스템 개편** 작업에서도 CSS 변수 기반의 디자인 토큰과 테마 관리 방식이 큰 도움이 되었습니다. 기존 방식이었다면 새롭게 도입된 시맨틱 색상의 토큰을 확인하기 어려웠겠지만, CSS 변수를 활용해 이를 원활하게 구현할 수 있었고, 아울러 디자인 리뷰 단계에서도 효율적으로 작용했습니다.

프로젝트를 진행한 덕분에, 단순히 디자인 시스템을 개선하는 데 그치지 않고, 이후 지그재그 서비스의 **확장성과 효율성을 높이는 중요한 기반**이 되었다고 생각합니다.

## 앞으로의 계획

이번 재구축을 통해 상품 카드를 통합하고 서비스 전반에 걸쳐 **일관성과 효율성**을 확보할 수 있었습니다. 하지만 아직 제공하지 못한 컴포넌트들이 있어 아쉬운 점도 남아 있는데요. 앞으로는 더 많은 디자인 시스템 컴포넌트를 제공해 신뢰도를 높이고, 장기적으로는 **사내에서 운영 중인 다른 서비스에서도 활용할 수 있는 범용 디자인 시스템으로 확장**해 보고 싶은 개인적인 바람도 있습니다.

이를 위해서는 지금보다 더 많은 고민과 다양한 팀 간의 협업이 필요하겠지만, 이번 프로젝트를 통해 얻은 경험을 바탕으로 이러한 목표를 점진적으로 만들어 나갈 수 있을 것이라고 생각합니다.

지금까지 긴 글 읽어주셔서 감사합니다.
