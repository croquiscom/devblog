---
title: Vertical-Align(1) - Line Box
tags: ['css', 'front-end', 'vertical-align']
date: 2019-04-26
author: Jaeyoung Tae
---

프론트엔드 개발자에게 중앙 정렬을 어떻게 하냐고 물어보면 inline 요소는 text-align 속성을 center로 지정하고, block 요소는 margin 속성을 auto로 지정한다고 대답할 겁니다.
그런데 좌우가 아니라 위아래 수직 정렬을 어떻게 하겠냐고 물어보면 대답을 선뜻 못하거나 굉장히 다양한 답변들이 나옵니다.
그 여러 방법들 중에 개발자들이 사용하면서도 "왜 되는거지?"라고 의구심을 많이 품게 되는 vertical-align에 대해서 자세히 써보려고 합니다.

<!--more-->

<style>
.block-container {
  border: 1px solid lightgray;
}
.box {
  display: inline-block;
  width: 100px;
  margin-right: 10px;
  background-color: darkgray;
}
.small { height: 100px; }
.medium { height: 200px; }
.big { height: 300px; }
.top { vertical-align: top; }
.bottom { vertical-align: bottom; }
</style>

벤더사들의 구현에 따라 달라질 수 있지만 [표준 명세서](https://www.w3.org/TR/CSS2/visudet.html#propdef-vertical-align)에서는 vertical-align에 대한 설명을 이렇게 시작합니다.
<div class="card">
    <div class="card-body">
        이 속성은 line box 안에서 inline-level 요소에 의해 생성되는 박스들의 수직 위치에 영향을 미칩니다.
    </div>
</div>

inline-level 요소는 한 줄에 나열할 수 있는 요소들을 말합니다.
display 속성을 inline, inline-block, inline-table 등으로 지정해서 만들 수 있는데요.
이 요소들에 의해서 만들어진 가상의 박스들은 곧 해당 요소의 크기를 나타냅니다.

간단한 예를 들자면 아래처럼 css가 적용된 요소의 박스 크기는 100*100px입니다.
{{< highlight css >}}
.box {
  display: inline-block;
  width: 100px;
  height: 100px;
}
{{< /highlight >}}

inline은 inline-block와 다르게 width/height가 아니라 폰트 매트릭스에 따른 계산이 필요하므로 추후에 다루겠습니다.

아무튼 각 줄마다 이런 inline-level 박스들을 가지고 있는 박스를 line box라고 하는데요.
이 line box를 이해하면 vertical-align에 적용 가능한 값들 중 top/bottom을 완벽하게 이해할 수 있습니다.
왜냐하면 top은 line box의 최상단에, bottom은 line box의 최하단에 정렬시켜주기 때문인데요.
그렇다면 line-box는 어떻게 계산되는 걸까요?

많은 조건들이 있지만 첫 번째로 inline-level 요소들의 높이를 계산해서 가장 큰 값을 가져옵니다.
아래의 예시를 보시죠!
{{< highlight css >}}
.block-container {
  border: 1px solid lightgray;
}
.box {
  display: inline-block;
  width: 100px;
  margin-right: 10px;
  background-color: darkgray;
}
.small { height: 100px; }
.big { height: 300px; }
.top { vertical-align: top; }
.bottom { vertical-align: bottom; }
{{< /highlight >}}
{{< highlight html >}}
<div class="block-container">
  <div class="box small top"></div>
  <div class="box big top"></div>
  <div class="box small bottom"></div>
</div>
{{< /highlight >}}
<div class="block-container">
  <div class="box small top"></div>
  <div class="box big top"></div>
  <div class="box small bottom"></div>
</div>

높이가 300px인 박스 한 개와 100px인 박스 두 개를 만들었습니다.
그리고 작은 박스 두 개에 각각 top과 bottom을 줬는데요.
보시다시피 가장 큰 inline-level 요소인 300px 박스를 기준으로 최상단과 하단에 배치됩니다.
큰 박스에는 top을 줬지만 line box와 높이가 같으므로 위치의 변화는 없습니다.
<br/><br/>

{{< highlight css >}}
.medium { height: 200px; }
{{< /highlight >}}
{{< highlight html >}}
<div class="block-container">
  <div class="box small top"></div>
  <div class="box big top"></div>
  <div class="box small bottom"></div>
  <div class="box medium bottom"></div>
</div>
{{< /highlight >}}
<div class="block-container">
  <div class="box small top"></div>
  <div class="box big top"></div>
  <div class="box small bottom"></div>
  <div class="box medium bottom"></div>
</div>

높이가 200px인 박스를 추가했지만 여전히 가장 큰 높이는 300px이므로, 높이가 300px인 line box를 기준으로 수직정렬됩니다.

그럼 inline-level 요소들의 높이보다 더 크게 line box를 만드려면 어떻게 해야 할까요?
[strut](https://www.w3.org/TR/CSS2/visudet.html#strut)에 대한 설명을 보면 그 답을 알 수 있습니다.
<div class="card">
    <div class="card-body">
        컨텐츠가 inline-level 요소로 구성된 블록 컨테이너 요소에서 'line-height'는 line box의 최소 높이를 지정합니다.
        최소 높이는 baseline 위의 최소 높이와 그 아래의 최소 깊이로 구성되며, 각 line box들의 시작이 font/line-height 속성을 가지고 width 0인 inline box인 것과 같습니다.
        우리는 이 가상의 박스를 "strut"라고 부릅니다.
    </div>
</div>

조금 풀어 써보자면 width가 0이어서 layout에는 영향을 주지 않는 가상의 박스가 있는데 이를 strut라고 하고,
이 strut는 부모 block 요소로부터 font/line-height를 상속받아 inline-level 요소처럼 line box에 영향을 미친다는 뜻입니다.
line-height가 100px로 지정된 block요소는 100px, font-size가 15px에 line-height가 5로 지정되었다면 75px 높이를 가지는 strut를 만들 수 있죠!
<br/><br/>

{{< highlight html >}}
<div class="block-container" style="line-height: 300px;">
  <div class="box small top"></div>
  <div class="box big top"></div>
  <div class="box small bottom"></div>
  <div class="box medium bottom"></div>
</div>
{{< /highlight >}}
<div class="block-container" style="line-height: 300px;">
  <div class="box small top"></div>
  <div class="box big top"></div>
  <div class="box small bottom"></div>
  <div class="box medium bottom"></div>
</div>

먼저 line-height를 300px로 지정한 화면입니다.
기존과 마찬가지로 line box의 높이가 300px이므로 별다른 변화는 없습니다.
<br/><br/>

{{< highlight html >}}
<div class="block-container" style="line-height: 400px;">
  <div class="box small top"></div>
  <div class="box big top"></div>
  <div class="box small bottom"></div>
  <div class="box medium bottom"></div>
</div>
{{< /highlight >}}
<div class="block-container" style="line-height: 400px;">
  <div class="box small top"></div>
  <div class="box big top"></div>
  <div class="box small bottom"></div>
  <div class="box medium bottom"></div>
</div>

line-height를 400px로 지정한 화면입니다.
line box가 400px로 늘어나서 위치가 달라졌습니다!
<br/><br/>

{{< highlight html >}}
<div class="block-container" style="height: 400px;">
  <div class="box small top"></div>
  <div class="box big top"></div>
  <div class="box small bottom"></div>
  <div class="box medium bottom"></div>
</div>
{{< /highlight >}}
<div class="block-container" style="height: 400px;">
  <div class="box small top"></div>
  <div class="box big top"></div>
  <div class="box small bottom"></div>
  <div class="box medium bottom"></div>
</div>

그럼 line-height가 아니라 height를 400px로 늘리면 어떻게 될까요?
안타깝지만 height는 line box에 영향을 주지 않기 때문에 line box는 300px로 유지됩니다.
<br/><br/>

{{< highlight html >}}
<div class="block-container" style="height: 300px; line-height: 400px;">
  <div class="box small top"></div>
  <div class="box big top"></div>
  <div class="box small bottom"></div>
  <div class="box medium bottom"></div>
</div>
{{< /highlight >}}
<div class="block-container" style="height: 300px; line-height: 400px; margin-bottom: calc(100px + 1rem);">
  <div class="box small top"></div>
  <div class="box big top"></div>
  <div class="box small bottom"></div>
  <div class="box medium bottom"></div>
</div>

마지막으로 height를 300px, line-height를 400px로 지정한 예제입니다.
line-height에 의해 line box는 400px이 되었지만 height는 300px이어서 요소들이 밖으로 삐져나온 것을 볼 수 있습니다.
<br/><br/>
오늘은 vertical-align 속성 중 가장 쉬운(?) top과 bottom에 대해서 정리해봤습니다.
vertical-align을 이용한 수직정렬에서 최상단과 하단은 부모 요소의 높이가 아니라 line box라는 점 꼭 기억하셨으면 좋겠습니다.
추후에 시간이 된다면 vertical-align의 다른 속성들(middle, text-top, text-bottom...)에 대해서도 정리해보겠습니다.
<br/><br/>
긴 글 읽어주셔서 감사합니다 :)
