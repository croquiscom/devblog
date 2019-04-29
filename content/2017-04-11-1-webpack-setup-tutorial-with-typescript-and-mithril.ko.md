---
title: webpack, TypeScript, Mithril을 사용하는 프로젝트 생성 튜토리얼
tags: ['webpack','TypeScript','Mithril','튜토리얼']
date: 2017-04-11
author: Sangmin Yoon
original: http://sixmen.com/ko/tech/2017-04-11-1-webpack-setup-tutorial-with-typescript-and-mithril/
---

클라이언트 JavaScript 개발 환경은 빠르게 변화하고 있습니다.
다양한 관련 기술 중 빌드 툴 쪽에서 최근 가장 주목 받는 것은 [webpack](https://webpack.js.org/)이라고 할 수 있습니다.

webpack 전체는 굉장히 방대하기 때문에 한번에 이해하기가 쉽지 않습니다.
인터넷에 이미 잘 구성된 설정파일이 많긴 하지만,
기본적인 설정에 대해서 알아두면 많은 도움이 됩니다.

이번 글에서는 크로키에서 사용하는 [TypeScript](https://www.typescriptlang.org/),
[Mithril](https://mithril.js.org/) 환경에 맞는 webpack 설정을 갖추는 과정을
단계별로 설명합니다.

<!--more-->

# 기본이 되는 웹 페이지 생성 ([3f7ac54](https://github.com/sixmen/mithril-examples/commit/3f7ac5420af5dd705f8f1488b338b77112ae6716))

우선 다른 툴/라이브러리/프레임워크를 배제한 기본 파일로 부터 시작합니다.

**_app/index.html_**
{{< highlight html >}}
<!DOCTYPE html>
<html lang='en'>

<head>
  <meta charset='utf-8'>
  <title>Sample App</title>
</head>

<body>
  <script src='index.js'></script>
</body>

</html>
{{< /highlight >}}

**_app/index.js_**
{{< highlight javascript >}}
console.log('Hello');
{{< /highlight >}}

`app/index.html` 파일을 브라우저로 열면 콘솔에 Hello가 출력됩니다.

# npm 개발 환경 설정 ([50fd3c0](https://github.com/sixmen/mithril-examples/commit/50fd3c0cd4f44f22f5f532ad849befef5bfae37f))

webpack, Mithril 라이브러리는 npm을 통해 사용하므로 npm 개발환경을 갖춰야 합니다.
`package.json` 파일을 생성하고 `node_modules` 디렉토리를 Git 무시 목록에 추가합니다.

**_package.json_**
{{< highlight json >}}
{
  "name": "setup-from-scratch"
}
{{< /highlight >}}

# webpack을 통해 js 번들을 생성하기 ([8978b0e](https://github.com/sixmen/mithril-examples/commit/8978b0e6032007729b75021074ba2b015934c33b))

webpack을 사용하면 원본 js 파일을 잘 묶어서 최종 js 파일을 만들어 내도록 할 수 있습니다.

우선 webpack을 설치합니다.

{{< highlight bash >}}
$ npm install --save-dev webpack
{{< /highlight >}}

`app/index.js` 파일을 진입점으로 하는 묶음 js 파일 `dist/main.js`를 만들어내는 webpack 설정은 다음과 같습니다.

**_webpack.config.js_**
{{< highlight javascript >}}
const path = require('path');

module.exports = {
  context: path.resolve(__dirname, 'app'),
  entry: './index',
  output: {
    path: path.resolve(__dirname, 'dist'),
    filename: '[name].js'
  }
};
{{< /highlight >}}

webpack을 실행하면 최종 js 파일이 만들어지는 것을 볼 수 있습니다.

{{< highlight bash >}}
$ ./node_modules/.bin/webpack
Hash: d063a108d2635900dd0a
Version: webpack 2.3.3
...

$ ls dist
main.js
{{< /highlight >}}

예제에서는 원본 js 파일이 하나뿐이라 묶으나 안 묶으나 큰 차이가 없지만,
import나 require등의 구문을 사용하면 요구하는 js 파일의 내용이 모두 main.js에 포함되는 것을 확인할 수 있습니다.

# html-webpack-plugin을 이용해서 HTML 파일을 생성하기 ([3b037f7](https://github.com/sixmen/mithril-examples/commit/3b037f7716822f9b8779fab7a4e6375586c72b5d))

결과물이 동작하려면 HTML 파일도 있어야 합니다. 단순히 `app/index.html`을 `dist/index.html`로 복사하는 방법도 있지만,
[html-webpack-plugin](https://github.com/jantimon/html-webpack-plugin)을 사용하면 HTML 파일을 적절히 생성해 줍니다.

우선 html-webpack-plugin을 설치합니다.

{{< highlight bash >}}
$ npm install --save-dev html-webpack-plugin
{{< /highlight >}}

`webpack.config.js`에 html-webpack-plugin 설정을 추가합니다.

**_webpack.config.js_**
{{< highlight diff >}}
 const path = require('path');

+const HtmlWebpackPlugin = require('html-webpack-plugin');
+
 module.exports = {
   context: path.resolve(__dirname, 'app'),
   entry: './index',
   output: {
     path: path.resolve(__dirname, 'dist'),
     filename: '[name].js'
-  }
+  },
+  plugins: [
+    new HtmlWebpackPlugin({
+      template: 'index.html'
+    })
+  ]
 };
{{< /highlight >}}

html-webpack-plugin을 사용하면 최종 js 파일이 자동으로 HTML에 추가됩니다. 원본에서 이를 제거합니다.

**_app/index.html_**
{{< highlight diff >}}
 <body>
-  <script src='index.js'></script>
 </body>
{{< /highlight >}}

다시 webpack을 실행하면 `dist/index.html` 파일이 생성된 것을 볼 수 있습니다.
이 파일을 브라우저로 열면 이전과 마찬가지로 콘솔에 Hello가 출력됩니다.

# webpack-dev-server 사용하기 ([71e7af3](https://github.com/sixmen/mithril-examples/commit/71e7af35e1e26bfd184655edfbd6365fb2389c91))

파일을 수정할 때마다 webpack을 실행하는 것을 비효율적입니다. 한번 실행해놓고 파일을 수정하면 자동으로 브라우저에 반영되면 좋을 것 같습니다.
이럴 때 사용하는 것이 [webpack-dev-server](https://webpack.js.org/configuration/dev-server/)입니다.

webpack-dev-server를 설치하고 실행하면 파일을 수정할 때마다 브라우저가 릴로드됩니다.
(--open 옵션을 주면 브라우저가 자동으로 실행됩니다.)

{{< highlight bash >}}
$ npm install --save-dev webpack-dev-server
$ ./node_modules/.bin/webpack-dev-server --open
{{< /highlight >}}

webpack / webpack-dev-server를 실행할 때 경로를 써주는 것이 귀찮을 경우 [npm 스크립트](https://docs.npmjs.com/misc/scripts)를 활용하면 편리합니다.

**_package.json_**
{{< highlight diff >}}
   "devDependencies": {
     "html-webpack-plugin": "^2.28.0",
     "webpack": "^2.3.3",
     "webpack-dev-server": "^2.4.2"
+  },
+  "scripts": {
+    "build": "webpack",
+    "start": "webpack-dev-server --open"
   }
 }
{{< /highlight >}}

위와 같이 추가해주면 다음부터는 다음과 같이 실행할 수 있습니다.

{{< highlight bash >}}
$ npm start # 개발시
$ npm run bild # 배포 파일 생성시
{{< /highlight >}}

# TypeScript 설정하기 ([5bb9d39](https://github.com/sixmen/mithril-examples/commit/5bb9d3901e427b595e2744811cd9103184c510de))

TypeScript를 사용하도록 설정하는 것은 [webpack & TypeScript](https://webpack.js.org/guides/webpack-and-typescript/) 문서를 참고하면 쉽게 할 수 있습니다.
TypeScript 지원을 위한 loader가 두가지가 있는데 여기서는 [awesome-typescript-loader](https://github.com/s-panferov/awesome-typescript-loader)를 사용합니다.

{{< highlight bash >}}
$ npm install --save-dev typescript awesome-typescript-loader
{{< /highlight >}}

**_webpack.config.js_**
{{< highlight diff >}}
     path: path.resolve(__dirname, 'dist'),
     filename: '[name].js'
   },
+  module: {
+    rules: [
+      {
+        test: /\.tsx?$/,
+        loader: 'awesome-typescript-loader',
+        exclude: /node_modules/
+      }
+    ]
+  },
+  resolve: {
+    extensions: ['.js', '.ts', '.tsx']
+  },
   plugins: [
     new HtmlWebpackPlugin({
       template: 'index.html'
{{< /highlight >}}

원본 js 파일의 확장자를 ts로 변경하고 webpack을 실행하면 awesome-typescript-loader 에 의해서 js로 변경되어 최종 js로 합쳐집니다.

# Mithril 설정하기 ([d24f1ac](https://github.com/sixmen/mithril-examples/commit/d24f1ac43aed3c0acf7a6e01ae54743e419afada))

사전작업이 끝났으니 이제 사용하려는 프레임워크를 추가하고 본격적인 코드를 작성해 보겠습니다.

최종 결과물에 포함될 프레임워크는 일반 의존 모듈로 추가하고, TypeScript를 위한 타입 정의 파일은 개발 의존 모듈로 추가합니다.

{{< highlight bash >}}
$ npm install --save mithril
$ npm install --save-dev @types/mithril
{{< /highlight >}}

`index.html`에 프레임워크가 렌더링할 타겟을 추가하고, 간단한 Mithril 코드를 작성해봅니다.

**_app/index.html_**
{{< highlight diff >}}
 <body>
+  <div id='app'></div>
 </body>
{{< /highlight >}}

**_app/index.ts_**
{{< highlight typescript >}}
import * as m from 'mithril';

class App implements m.ClassComponent<{}> {
    view() {
        return m('div', 'Hello Mithril');
    }
}

m.mount(document.getElementById('app'), App);
{{< /highlight >}}

# JSX 설정하기 ([a106af0](https://github.com/sixmen/mithril-examples/commit/a106af0ff92ed872231705d614289ea1cf65d36d))

Mithril도 React에서 나온 JSX 문법을 사용할 수 있습니다. 이를 설정해봅니다.
(저는 JSX를 선호하는데 Mithril 사용자들은 m() 형태를 더 선호하는 것으로 보입니다. https://github.com/lhorie/mithril.js/issues/1619)

[TypeScript의 JSX 지원 기능](https://www.typescriptlang.org/docs/handbook/jsx.html)을 사용하고, factory 함수를 Mithril에 맞게 설정하면 됩니다.

**_tsconfig.json_**
{{< highlight json >}}
{
  "compilerOptions": {
    "jsx": "react",
    "jsxFactory": "m"
  }
}
{{< /highlight >}}

이제 JSX 문법을 사용할 수 있습니다. 다만 확장자를 tsx로 변경해야 합니다.

**_app/index.tsx_**
{{< highlight diff >}}
 class App implements m.ClassComponent<{}> {
     view() {
-        return m('div', 'Hello Mithril');
+        return <div>Hello Mithril with JSX</div>;
     }
 }
{{< /highlight >}}

# CSS 추가하기 ([53518ea](https://github.com/sixmen/mithril-examples/commit/53518eac007afdca4dbfadecbea2eea8b18ee8e8))

이제 웹 페이지에 스타일을 적용해보겠습니다.
이는 [css-loader](https://github.com/webpack-contrib/css-loader)와 [style-loader](https://github.com/webpack-contrib/style-loader)를 사용해서 이루어집니다.
모듈을 설치하고 css 파일에 대해서 두 loader를 사용하도록 설정합니다.

{{< highlight bash >}}
$ npm install --save-dev css-loader style-loader
{{< /highlight >}}

**_webpack.config.js_**
{{< highlight diff >}}
        test: /\.tsx?$/,
         loader: 'awesome-typescript-loader',
         exclude: /node_modules/
+      },
+      {
+        test: /\.css$/,
+        loader: ['style-loader', 'css-loader']
       }
     ]
{{< /highlight >}}

이제 스타일을 추가해봅니다.

**_app/index.css_**
{{< highlight css >}}
.message {
  font-size: 20px;
  color: magenta;
}
{{< /highlight >}}

**_app/index.tsx_**
{{< highlight diff >}}
 import * as m from 'mithril';

+import './index.css';
+
 class App implements m.ClassComponent<{}> {
     view() {
-        return <div>Hello Mithril with JSX</div>;
+        return <div class='message'>Hello Mithril with JSX</div>;
     }
 }
{{< /highlight >}}

웹 페이지의 텍스트에 크기와 색상이 적용된 것을 볼 수 있습니다.

# 지역 범위의 CSS 적용하기 ([6105a82](https://github.com/sixmen/mithril-examples/commit/6105a821f6d05527c8f60964ab86d6fed45e937d))

컴포넌트별로 나누어서 개발을 하는 경우 CSS도 각 컴포넌트별로 가지는 것이 편리합니다.
이 경우 다른 컴포넌트와 클래스 이름이 겹쳐서 컴포넌트 조합후 전체 스타일이 엉망이 될 가능성이 있습니다.
이를 해결하기 위해서 [BEM](https://en.bem.info/)과 같은 네이밍 컨벤션을 사용하기도 하고,
스타일을 HTML 원소 인라인으로 포함시키기도 합니다.

저는 css-loader의 지역 범위 기능을 선호합니다.
이를 사용하면 같은 클래스 이름을 사용해도 최종 결과물에서는 겹치지 않는 이름으로 변경됩니다.
대신 코드에서 이렇게 임의로 생성한 이름을 CSS 클래스명으로 설정하는 작업이 필요합니다.

지역 범위를 사용하려면 CSS 파일에 :local을 붙여줍니다.

**_app/index.css_**
{{< highlight diff >}}
-.message {
+:local .message {
   font-size: 20px;
{{< /highlight >}}

이렇게 하면 `index.css`가 다음과 같은 구조체를 내보냅니다.

{{< highlight js >}}
module.exports = {
  "message": "Ag7q-vI0hGDj8L_qsNLr7"
}
{{< /highlight >}}

이 구조체를 사용해서 HTML 원소에 적절한 클래스명을 설정해줍니다.
다만 TypeScript가 CSS 파일이 내보내는 구조체를 인식하지 못하기 때문에 타입 정의 파일을 만들어 줘야 컴파일이 됩니다.

**_app/index.d.ts_**
{{< highlight typescript >}}
declare module '*.css' {
    const styles: { [key: string]: string };
    export = styles;
}
{{< /highlight >}}

**_app/index.tsx_**
{{< highlight diff >}}
+/// <reference path='index.d.ts'/>
+
 import * as m from 'mithril';

-import './index.css';
+import styles = require('./index.css');

 class App implements m.ClassComponent<{}> {
     view() {
-        return <div class='message'>Hello Mithril with JSX</div>;
+        return <div class={styles.message}>Hello Mithril with JSX</div>;
     }
 }
{{< /highlight >}}

다만 이렇게 하면 CSS의 클래스명에 대한 검증을 하지 못합니다. (styles.massage로 오타를 내도 알 수 없음)
이에 대한 타입 정의 파일을 만들어 주는 [typed-css-modules](https://github.com/Quramy/typed-css-modules) 모듈은 있지만,
webpack과 부드럽게 연동하는 방법은 찾지 못했습니다.

# 스타일을 별도 CSS 파일로 내보내기 ([37a2741](https://github.com/sixmen/mithril-examples/commit/37a274103a51309d05cb7dceaf7f99cc6951f57f))

위와 같이 CSS를 작업한 경우 실행시간에 style 원소로 추가됩니다.

![Runtime DOM](/img/content/2017-04-11-1-01.jpg)

저는 이것보다는 별도의 CSS 파일로 내보내고 싶었습니다.
이는 [extract-text-webpack-plugin](https://webpack.js.org/guides/code-splitting-css/)을 사용해서 할 수 있습니다.
extract-text-webpack-plugin 모듈을 추가하고, 적절한 설정을 해주면 `main.css` 파일이 만들어집니다.
이 extract-text-webpack-plugin 사용시 style-loader는 필요하지 않습니다.

{{< highlight bash >}}
$ npm install --save-dev extract-text-webpack-plugin
{{< /highlight >}}

**_webpack.config.js_**
{{< highlight diff >}}
 const path = require('path');

+const ExtractTextPlugin = require('extract-text-webpack-plugin');
 const HtmlWebpackPlugin = require('html-webpack-plugin');

 module.exports = {
...
       },
       {
         test: /\.css$/,
-        loader: ['style-loader', 'css-loader']
+        loader: ExtractTextPlugin.extract('css-loader')
       }
     ]
   },
...
   plugins: [
     new HtmlWebpackPlugin({
       template: 'index.html'
+    }),
+    new ExtractTextPlugin({
+      filename: '[name].css'
     })
   ]
{{< /highlight >}}

# 마무리 ([f596154](https://github.com/sixmen/mithril-examples/commit/f5961546ccdd444da68c8c6bf518948b3527d8c1))

마지막으로 배포를 위한 코드 최적화 버전을 생성합니다.
webpack은 이를 위한 간단한 옵션을 제공합니다. `-p` 만 붙여주면 js 파일과 css 파일이 최소화됩니다.

**_package.json_**
{{< highlight diff >}}
   "scripts": {
-    "build": "webpack",
+    "build": "webpack -p",
     "start": "webpack-dev-server --open"
   }
{{< /highlight >}}

webpack은 여기서 다루지 못한 많은 기능을 가지고 있습니다. 예를 들어

* [원할한 캐싱을 위해 내용에 따라 파일명을 다르게 생성하는 기능](https://webpack.js.org/guides/caching/)
* 외부 라이브러리를 vendor.js 등의 파일로 분리
* SASS등의 CSS 전처리기 사용
* 이미지, 글꼴 파일 처리
* [Hot Module Replacement](https://webpack.js.org/guides/hmr-react/)

등이 있습니다. 이런 부분들은 차후 기회가 되면 다른 글로 소개하도록 하겠습니다.
