---
title: '웹폰트 최적화를 통한 CDN 비용절감'
tags: []
date: 2024-06-28T01:00:00
author: Orca(장종오)
---

근래의 많은 기업과 마찬가지로 카카오스타일도 불필요한 비용 낭비가 발생하지 않도록 많은 노력을 기울이고 있습니다. 물론 이전이라고 사용하지 않는 리소스를 방치하며 비용을 낭비한 것은 아니고, 좀 더 세밀한 부분까지 주의를 기울이기 시작했다고 생각해주시면 됩니다. 이번 글은 그 중 하나를 소개해보려고 합니다.

<!--more-->

## 작업배경

최근 지그재그서비스 프론트엔드팀에서는 프론트엔드 리소스 관련 인프라 비용을 절감하기 위해 개선점을 찾고있습니다. 그 과정에서 AWS CloudFront의 사용량을 분석하던 중, 다른 리소스들에 비해 폰트의 호출량이 비정상적으로 높다는 것을 발견했습니다. 일반적으로 브라우저는 폰트를 요청을 할 때 메모리 캐시가 적용 되기 때문에, 측정된 호출 수치는 이상하다고 생각되었습니다. 또 WOFF2 포맷의 폰트 뿐만이 아니라, WOFF 포맷의 폰트 까지 꽤 많은 수의 호출이 생기는것을 보고, 깊게 살펴보기 시작했습니다.

무엇보다, CloudFront의 비용은 **사용한 데이터 용량과 요청수에 의해 산정되기 때문에, 이를 개선한다면, 많은 절감효과가 있을거라고 예상했습니다.**

![01.png](/img/content/2024-06-28-1/01.png)

![02.png](/img/content/2024-06-28-1/02.png)

당시 폰트의 호출량은 한달 기준으로 6억 4천만건이었으며, 데이터 전송량은 457TB였습니다.

![03.png](/img/content/2024-06-28-1/03.png)

이 수치를 기반으로 [AWS 요금 계산기](https://calculator.aws/)를 통해 한달 비용을 계산해보면

```
Tiered price for: 457,006 GB
10,240 GB x 0.12 USD = 1,228.80 USD
40,960 GB x 0.10 USD = 4,096.00 USD
102,400 GB x 0.095 USD = 9,728.00 USD
303,406 GB x 0.09 USD = 27,306.54 USD
총 티어 비용: 1,228.80 USD + 4,096.00 USD + 9,728.00 USD + 27,306.54 USD = 42,359.34 USD(아시아 태평양에서 인터넷으로 데이터 전송)
인터넷으로 데이터 전송 비용: 42,359.34 USD
오리진으로 데이터 전송 비용: 0 USD
639,405,635 요청 x 0.0000012 USD = 767.29 USD(아시아 태평양으로부터의 HTTPS 요청)
요청 비용: 767.29 USD
42,359.34 USD + 767.29 USD = 43,126.63 USD(총 비용 아시아 태평양)
CloudFront 가격 아시아 태평양 (월별): 43,126.63 USD
```

한달에 $43,000이고, 이를 연단위로 환산하면, $516,000입니다. 이를 글을쓰는 현재(6/28)기준 환율 1380원을 반영하면 한화로 1년에 7억원 이상을 지출하게 됩니다. (실제로는 약정이 있어 이정도까지는 안 됩니다 😅)

## 해결해야 할 문제

우리가 해결해야할 문제는 다음과 같이 두가지입니다.

1. 과도한 폰트 호출량 줄이기
2. 무거운 폰트 용량 경량화 하기

이 두가지를 순서대로 해결해보겠습니다.

## 과도한 폰트 호출량

### 문제분석

이제부터 문제가 되는 상황을 분석 해보겠습니다. 
유의미한 양의 폰트호출이 일어나는 곳으로는 크게 아래와 같이 분류됩니다.

- Android Webview
- IOS Webview
- Chrome, Safari, etc…

지그재그의 경우 과반수의 사용자가 애플 제품을 이용하므로 Safari를 의심했으나, 먼저 Chromium 기반의 브라우저 부터 살펴보기로했습니다.

### 문제상황 재현

1. Chromium

{{< raw_html >}}
<video src='/img/content/2024-06-28-1/04.mov' controls></video>
{{< /raw_html >}}

영상을 보면, 첫 페이지 진입 때, 폰트를 호출하고, 새로고침을 할 때마다, 메모리캐시가 잘 적용되는 것을 알 수 있습니다. ****

2. Safari

{{< raw_html >}}
<video src='/img/content/2024-06-28-1/05.mov' controls></video>
{{< /raw_html >}}

하지만, Safari 에서는 첫 페이지 진입 때 폰트를 가져왔음에도 불구하고, 새로고침을 할 때마다 새로이 폰트 요청을 하고, 또한 캐싱된 폰트도 가져오는 현상이 일어나고 있습니다.

이를 통해 Safari 브라우저에서, 문제가 발생했다는것을 알 수 있었습니다.

### Why?

그렇다면 왜 Safari에서는 캐시가 제대로 적용되지 않고, Chrome에서는 잘 적용이 되는것이며, 특히 Safari는 폰트 요청을 두번이나 하게 되는것일까요? 

이것에 대해서 생각을 하던 중, 머릿속에 팀에서 서비스 UX 개선작업을 위해 했던 작업중에, 폰트 리소스 요청을 최우선순위로 처리하는 작업이 떠올랐습니다.

```html
<link
    rel='preload'
    href={`${fontURL}`}
    as='font'
    type='font/woff2'
    crossorigin=''
/>
```

폰트는 서비스 글꼴에 가장 먼저 반영이 되어야 하기에 네트워크 요청 우선순위를 높여야, FOUT 현상이 일어나지 않습니다.

> FOUT란?
>
> 브라우저가 웹 글꼴을 다운로드하기 전에 텍스트가 대체 글꼴로 렌더링되는 현상을 말합니다.

> 참고로 [MDN 문서](https://developer.mozilla.org/en-US/docs/Web/HTML/Attributes/rel/preload#what_types_of_content_can_be_preloaded)에 따르면 preload를 통해 폰트를 요청하는 경우 CORS 활성화가 필요하다고 해서 crossorigin 옵션을 설정해줬습니다.

아래 첨부된 영상을 보면 텍스트가 꿀렁이는 모습을 볼 수 있습니다. **숫자가 바뀔 때마다 새로고침이 동작하고 있는 것입니다.**

{{< raw_html >}}
<video src='/img/content/2024-06-28-1/06.mov' controls></video>
{{< /raw_html >}}

폰트의 우선순위를 높인다면, 아래의 영상과 같이 개선할 수 있습니다. 텍스트의 꿀렁거림이 사라졌습니다!

{{< raw_html >}}
<video src='/img/content/2024-06-28-1/07.mov' controls></video>
{{< /raw_html >}}

그렇다면 정말로 이 preload힌트 때문에, 폰트 요청이 두번이나 일어나는 것일까요? 그래서 preload 힌트를 제거하고 다시 테스트 해봤습니다.

{{< raw_html >}}
<video src='/img/content/2024-06-28-1/08.mov' controls></video>
{{< /raw_html >}}

제거하고 테스트를 했더니 놀랍게도, 메모리 캐시까지 잘 적용되는것을 확인 할 수 있었습니다. 하지만, 그렇다고 사용성을 위해 폰트 우선순위를 높인 결과물을 되돌릴 수는 없었습니다.

그렇다면 다시, preload를 제거했을때의 상황을 좀 더 알아보겠습니다.

![09.png](/img/content/2024-06-28-1/09.png)

Safari 브라우저에서 preload를 제거하고 오직 CSS의 font-face url을 통한 폰트 요청에 대해서 요청 헤더를 보니, Safari 브라우저에서는 no-cors로 요청을 하고 있다는 점을 알게 되었습니다. 

그렇다면 Chrome 브라우저에서는 어떨까요?

![10.png](/img/content/2024-06-28-1/10.png)

Chrome 브라우저에서는 cors 요청을 하고 있고, cors 요청을 하기에 Origin 헤더가 요청헤더에 포함됩니다.  

[Origin MDN 문서](https://developer.mozilla.org/ko/docs/Web/HTTP/Headers/Origin)에서도 설명 되어 있듯이 Origin 요청 헤더는 cors 요청과 함께 전송되기에 no cors 요청에는 Origin 헤더가 요청헤더에 포함되지 않습니다.

다시 원래의 문제상황으로 돌아와 보겠습니다.

Safari 브라우저에서의 헤더를 살펴보겠습니다.

**첫 페이지 로드**

![11.png](/img/content/2024-06-28-1/11.png)

**새로고침 후**

![12.png](/img/content/2024-06-28-1/12.png)

![13.png](/img/content/2024-06-28-1/13.png)

위 이미지를 보면, 첫 페이지 진입과, 새로고침 후의 폰트 요청 방식이 서로 cors와 no-cors로 다르다는것을 알 수 있습니다.

위에서 알아본 결과를 바탕으로 추측해보자면, cors 요청은 link태그의 preload 힌트를 통한 요청, no-cors는 Safari 브라우저의 폰트요청 동작방식임을 유추해 볼 수 있습니다.

| cors / no-cors | Safari | Chrome |
| --- | --- | --- |
| font-face url 요청 | no-cors | cors |
| link preload 요청 | cors | cors |

간단히 차이점을 정리해보면 위 테이블과 같습니다. 

no-cors와 cors의 차이점은 Origin 헤더의 차이로도 연결 될 수 있습니다. 그렇다면, 이 차이가 어떻게 캐시 문제로 이어지는 걸까요? 

![14.png](/img/content/2024-06-28-1/14.png)

![15.png](/img/content/2024-06-28-1/15.png)

바로, 첨부된 이미지에서도 나와 있듯이, Vary 응답헤더에 Origin이라는 값이 설정되어 있어서입니다.

같은 URL로 요청을 하더라도 이 Vary 헤더에 설정된 헤더 종류에 따라서, URL과 헤더의 조합으로 캐시가 다르게 될 수도 있다고 합니다. ([#](https://developer.mozilla.org/en-US/docs/Web/HTTP/Caching#vary)) 우리 서비스의 경우에는, Vary 헤더에 Origin 헤더가 등록되어 있어, URL과 Origin헤더 값의 조합으로 캐시키가 설정됩니다.

Chrome 브라우저인 경우, link태그의 preload의 요청과 font-face url을 통한 요청 모두 cors요청이라 요청 헤더에  Origin 헤더가 둘다 포함되어 있었기에, 캐시키가 동일하여 캐시가 제대로 동작하지만, Safari 브라우저의 경우, link태그의 preload의 요청은 cors 요청이라 Origin 헤더가 포함되어있고, font-face의 url을 통한 요청은 no-cors 요청이라 Origin 헤더가 포함되어 있지 않아, URL + Origin값이 다르다보니 캐시가 의도한대로 동작하지 않았던 것이였습니다.

## 문제 해결

우리는 Safari 브라우저의 폰트 요청 방식이 Chrome 브라우저와 다소 차이가 있다는 점을 알아내고, 근본적으로 무엇이 원인인지 알게 되었습니다.

위에서 알아본 바에 따르면, 응답헤더로 오는 Vary 헤더로 인해 문제가 생겼다는 것을 알 수 있으므로, Vary 헤더를 어떻게 설정할 수 있는지 방법에 대해서 알아보겠습니다.

### Vary 헤더 값 설정

먼저 이 Vary 헤더는 어떻게 지정을 해줄 수 있을까요?

폰트에 대한 CloudFront 동작을 확인해보니, 적용되어있는 캐시정책을 살펴보니 캐시키에 Origin이 설정되어있었습니다.

![16.png](/img/content/2024-06-28-1/16.png)

이걸 Origin을 제거해보고 다른 헤더를 넣어보겠습니다.

![17.png](/img/content/2024-06-28-1/17.png)

Access-Control-Request-Method, Access-Control-Request-Headers 이 두개의 헤더를 캐시키로 설정해줬습니다.

![18.png](/img/content/2024-06-28-1/18.png)

그랬더니, Vary 헤더에 설정 된 값이 방금 설정 했던 두개의 헤더가 적용되어 있는것을 알 수 있습니다. Vary 헤더에 Origin이 설정되어있어, Origin 값 기반으로 캐시가 되어 문제가 생겼으므로 Vary 헤더에 Origin을 제거해보겠습니다.

방법은 두가지가 있습니다. 두 방법 모두 Origin 값을 캐시키로 사용하지 않는 것처럼 동작합니다.

1. 캐시 정책에서 캐시키로 설정된 Origin 을 제거하는 방법
    
    ![19.png](/img/content/2024-06-28-1/19.png)

    ![20.png](/img/content/2024-06-28-1/20.png)
    
    Vary 헤더는 응답헤더에서 사라졌습니다.
    
    그렇다면, 캐시키가 사라진 Cloudfront는 무엇을 기반으로 캐싱을 할까요? [AWS의 캐시 키 이해 문서](https://docs.aws.amazon.com/ko_kr/AmazonCloudFront/latest/DeveloperGuide/understanding-the-cache-key.html)에 따르면 CloudFront 배포 도메인과, 요청 URL이 기본캐시키로 지정되어 있다고 합니다.
    
2. CloudFront 응답헤더 정책에서 헤더 제거하기

    ![21.png](/img/content/2024-06-28-1/21.png)

    Cloudfront 응답헤더 정책에서 Vary헤더를 명시적으로 제거할 수 있습니다.

    ![22.png](/img/content/2024-06-28-1/22.png)

저는 캐시키에 설정된 헤더가 Origin 밖에 없어서, Vary 헤더를 제거하는 방식인 2번을 선택했습니다. 만약 캐시키에 설정된 다른 값들이 있다면, 캐시키에 Origin 헤더를 제거하는것이 안전하다고 생각됩니다.

### 결과

{{< raw_html >}}
<video src='/img/content/2024-06-28-1/23.mov' controls></video>
{{< /raw_html >}}

적용 한 후 폰트 캐싱이 잘 되는것을 알 수 있습니다.

## 무거운 폰트 용량

한글의 경우 조합가능한 모든 글자인 11172자가 모두 폰트에 포함되어 있어서 용량이 무겁습니다. 하지만, 대부분의 경우 이 글자들을 모두 사용하는 것은 아니기 때문에, 사용하지 않는 글자를 제거하고 폰트를 다시 만들기로 했습니다. 이렇게 사용할 글자만 남겨 둔 폰트를 서브셋 폰트라고 합니다.

### **KS X 1001**

한국어 문자집합 중 [KS X 1001](https://ko.wikipedia.org/wiki/KS_X_1001)이란 것이 있습니다. 한글을 2350자만 포함하고 있다보니 모든 한글을 표현할 수 없어 비판을 받았지만, 자주 쓰이는 글자만 포함하고 있다보니 아이러니하게 폰트 용량을 줄일 때 기준으로 삼기 좋습니다.

### 서브셋 폰트 만들기

서브셋 폰트를 만드는 도구에는 여러가지가 있는데, 처음에는 [네이버 D2](https://d2.naver.com/helloworld/4969726) 에서도 소개하고 있는 [서브셋 폰트메이커](https://opentype.jp/subsetfontmk.htm) 를 사용해서 서브셋 폰트를 적용했었습니다. 하지만 폰트가 이상하게 나오는 현상이 있다는 보고가 들어왔습니다.

![24.png](/img/content/2024-06-28-1/24.png)

동료분께서 바로 윈도우 7을 설치하셔서 확인해보니, 위 이미지 처럼 재현되는 것을 확인해주셨고,

![25.png](/img/content/2024-06-28-1/25.png)

위와 같이 생성된 폰트에 값이 누락되어서 생성 되었다는것을 알 수 있었습니다. 이런 이유로, 다른 것을 이용하여 서브셋 폰트를 생성하는 것을 추천 합니다.

- [Font Subset Generate Online](https://www.lddgo.net/en/convert/font-subset)
- [FontForge Open Source Font Editor](https://fontforge.org/en-US/)

이 중 Font Subset Generate Online를 사용해서 생성했습니다. 이 도구로 생성한 서브셋 폰트는 윈도우 7에서도 제대로 폰트가 적용되는 것을 확인 할 수 있었습니다.

### 폰트 용량 비교

일반 폰트와 서브셋 폰트의 용량을 비교해보겠습니다.

![26.png](/img/content/2024-06-28-1/26.png)

**일반 폰트**

- Woff2 : 0.76MB
- Woff: 1.1MB

**서브셋 폰트**

- Woff2: 0.16MB
- Woff: 0.21MB

**대략 80%정도 용량이 줄어든것을 확인할 수 있습니다.**

## 개선결과 비용 비교

이제 개선을 모두 완료했으니, 개선 이전과 이후의 비용을 비교해보겠습니다.

![27.png](/img/content/2024-06-28-1/27.png)

```
Tiered price for: 39,407 GB
10,240 GB x 0.12 USD = 1,228.80 USD
29,167 GB x 0.10 USD = 2,916.70 USD
Total tier cost: 1,228.80 USD + 2,916.70 USD = 4,145.50 USD (Data transfer out to internet from Asia Pacific)
Data transfer out to internet cost: 4,145.50 USD
Data transfer out to origin cost: 0 USD
250,883,581 requests x 0.0000012 USD = 301.06 USD (HTTPS requests from Asia Pacific)
Requests cost: 301.06 USD
4,145.50 USD + 301.06 USD = 4,446.56 USD (Total cost Asia Pacific)
CloudFront price Asia Pacific (monthly): 4,446.56 USD
```

비교 시점의 트래픽이 다르므로 완전히 동일한 상황은 아니지만 약 1/10로 줄어든 것을 확인할 수 있습니다. 1년으로 하면 약 46만 달러, 환율 1380원을 적용하면 6억이 넘는 돈입니다. 물론 약정할인이 있어 이 정도로 드라마틱 하지는 않겠지만 충분히 유의미한 차이가 있었습니다.

비지니스 로직의 경우 QA 프로세스도 있고, 테스트 코드를 작성해서 통과하면 별 문제 없을 것을 어느 정도 확신해도 되지만, 캐싱 같은 경우 눈에 보이는 동작이 다르지 않으므로 문제가 있음에도 모르고 넘어가기 쉬운 부분인 것 같습니다. 이런 부분은 프로덕션 환경에 배포 후 사후 검증, 모니터링을 더 철저히 해야 한다는 것을 다시 한번 확인하는 계기가 된 것 같습니다.

## 참고

- https://blog.banksalad.com/tech/font-preload-on-safari/
- https://d2.naver.com/helloworld/4969726
- https://boramyy.github.io/dev/front-end/etc/font/
- https://docs.aws.amazon.com/ko_kr/AmazonCloudFront/latest/DeveloperGuide/Introduction.html
- https://docs.aws.amazon.com/AmazonS3/latest/API/RESTCommonResponseHeaders.html
- https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS
- https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Vary
- https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Origin
- https://developer.mozilla.org/en-US/docs/Web/HTML/Attributes/rel/preload#what_types_of_content_can_be_preloaded