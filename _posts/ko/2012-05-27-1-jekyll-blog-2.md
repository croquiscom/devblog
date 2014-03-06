---
layout: post.ko
title: Jekyll을 이용해서 블로그 만들기 (2)
category: ko
tags: [infrastructure, jekyll, blog, markdown, textile, liquid, yaml]
author: sangmin.yoon
---

이번 글에서는 본격적으로 Jekyll 이용법에 대해서 설명하겠습니다.

> 이 글의 내용은 [Jekyll 위키](https://github.com/mojombo/jekyll/wiki)의
> 내용을 바탕으로 만들어졌습니다.
> 그리고 Jekyll을 리눅스에서 사용한다고 가정합니다.

Jekyll 설치하기
===============

Jekyll은 Ruby 언어로 만들어졌습니다.
그리고 Ruby 언어로 만들어진 프로그램과 라이브러리는              보통
[RubyGems]를 이용해 배포됩니다.
[RubyGems]는 대부분의 리눅스 배포판에 포함되어 있으므로
따로 설치 방법을 설명드리지 않겠습니다.

[RubyGems]만 설치되면 Jekyll을 설치하는 것은 어렵지 않습니다.

{% highlight bash %}
sudo gem install jekyll
{% endhighlight %}

정상적으로 설치됐는지 확인해봅시다.
빈 디렉토리에 index.html이라는 이름을 가진 간단한 HTML 파일을 만듭니다.

{% highlight html %}
<!DOCTYPE html>
<html>
<head>
  <title>Jekyll로 만든 블로그</title>
</head>
<body>
잘 동작하네요.
</body>
</html>
{% endhighlight %}

그리고 다음과 같이 Jekyll을 실행합니다.

{% highlight bash %}
jekyll
{% endhighlight %}

명령이 종료되고 디렉토리를 살펴보면 \_site 라는 이름을 가진 디렉토리가
만들어지고, 방금 작성한 index.html이 있는 것을 확인할 수 있습니다.
이런 식으로 만들어진 \_site 디렉토리 밑의 파일들을 서버에 올려 배포하면 홈페이지가 됩니다.

> \_site 디렉토리로 복사될 때 '\_'로 시작하는 파일들은 Jekyll이 특수 처리하는 파일들로
> 무시됩니다. 그외에도 '.', '#'로 시작하거나 '~'로 끝나는 파일들도 무시됩니다.

배포 없이 결과를 미리 확인하는 것도 가능합니다.

{% highlight bash %}
jekyll --server
{% endhighlight %}

와 같은 명령을 실행하면 4000 포트로 웹 서버가 뜹니다.
http://localhost:4000/ 과 같이 접속하면 만들어진 파일을 확인할 수 있습니다.

레이아웃
========

위의 기능이 전부이면 Jekyll을 쓸 필요가 없겠죠.
본격적으로 Jekyll의 기능을 살펴보겠습니다.

가장 기본적인 기능은 레이아웃을 지정하는 기능입니다.
각 페이지들에서 공통적인 부분을 레이아웃 파일로 만들 수 있습니다.
레이아웃 파일은 \_layouts 디렉토리에 추가하면 됩니다.

예를 들어 모든 페이지에 공통이 되는 HTML 구조 부분을 다음과 같은 레이아웃 파일로 만들 수 있습니다.
이 파일을 \_layouts/default.html 이라는 파일명으로 저장합니다.

{% highlight html %}
{% raw %}
<!DOCTYPE html>
<html>
<head>
  <title>{{page.title}}</title>
</head>
<body>
{{content}}
</body>
</html>
{% endraw %}
{% endhighlight %}

여기서 중괄호 두개( {% raw %}{{ }}{% endraw %} )로 감싸진 page.title과 content는
[Liquid]라는 템플릿 엔진에 의해서 실제 내용으로 치환됩니다.

실제 페이지인 index.html은 실제 내용만으로 작성하면 됩니다.
이때 이 페이지를 구성할 레이아웃을 지정해야 하는데 이는 [YAML] 형식으로 기술합니다.
파일 내용 시작 부분에 대시 기호 세개로 감싸진 부분을 [YAML] 형식으로 해석하고,
그 결과를 파일 처리하는데 사용합니다.

여기서는 페이지의 제목과 사용할 레이아웃을 기술해 봅니다.

{% highlight html %}
---
layout: default
title: Jekyll로 만든 블로그
---
잘 동작하네요.
{% endhighlight %}

이렇게 \_layouts/default.html와 index.html 두 파일을 만들고 Jekyll을 실행하면
처음에 만들었던 index.html과 동일한 결과가 나옵니다.

파일이 하나 뿐이라면 레이아웃을 쓸 필요가 없겠지만, 두개 이상만 되도
많은 반복 작업을 줄일 수 있습니다.

레이아웃 반복
-------------

레이아웃 안에서 레이아웃을 지정하는 것도 가능합니다.

다음과 같이 \_layouts/page.html을 작성합니다.

{% highlight html %}
{% raw %}
---
layout: default
---
<h1>{{page.title}}</h1>
<div>
{{content}}
</div>
{% endraw %}
{% endhighlight %}

그리고 index.html의 레이아웃을 page로 변경합니다.

{% highlight html %}
---
layout: page
title: Jekyll로 만든 블로그
---
잘 동작하네요.
{% endhighlight %}

이경우 결과물은 다음과 같습니다.

{% highlight html %}
<!DOCTYPE html>
<html>
<head>
  <title>Jekyll로 만든 블로그</title>
</head>
<body>
<div id="content">
<h1>Jekyll로 만든 블로그</h1>
<div>
잘 동작하네요.
</div>
</div>
</body>
</html>
{% endhighlight %}

index.html을 처리한 결과가 content, page.title 변수에 들어가 \_layouts/page.html을 처리하는데 사용되고,
다시 그 결과가 \_layouts/default.html 파일의 content 변수로 들어가 처리되어 최종 \_site/index.html이 됩니다.

포스팅 하기
===========

레이아웃 기능은 페이지 자동 생성기로서 필요한 기능입니다.
다음은 Jekyll을 블로그 생성기로 만들어주는 기능을 설명드리겠습니다.

일반 페이지가 아닌 블로그 페이지는 \_posts 디렉토리에 만들면 됩니다.

파일명은 포스팅 날짜+제목의 형태를 가집니다.
2012-05-27-first-posting.html 이라는 파일명을 가진 파일을 만들어 봅시다.

{% highlight html %}
---
layout: default
title: 첫번째 포스팅
---
<b>야호</b>. 블로그를 만들었습니다.
{% endhighlight %}

Jekyll을 실행하면 \_site/2012/05/27/first-posting.html라는 파일이 다음과 같은 내용으로 생성됩니다.
(설정을 통해 경로를 다른 형태로 변경할 수 있습니다.)

{% highlight html %}
<!DOCTYPE html>
<html>
<head>
  <title>첫번째 포스팅</title>
</head>
<body>
<div id="content">
<b>야호</b>. 블로그를 만들었습니다.
</div>
</body>
</html>
{% endhighlight %}

다시 말해 경로가 달라지는 것 외에는 일반 페이지의 처리 방식과 크게 다르지 않습니다.
(그외에 포스팅에 태그, 카테고리를 기술해서 레이아웃 처리시 제공하는 등의 추가 데이터가 있긴 합니다.)
보통은 사용자가 일반 페이지와 포스팅의 레이아웃을 달리 지정해서
다른 형태의 결과를 만들어내도록 구성하게 됩니다.

다른 마크업 언어 사용
=====================

마지막으로 살펴볼 것은 HTML이 아닌 다른 마크업 언어를 사용하는 것입니다.
최종적으로 원하는 결과물은 HTML이지만, 내용을 HTML로 직접 작성하는 것은 굉장히 번거롭고 오래걸리는 작업입니다.
이를 돕기 위해 많은 마크업 언어가 있는데, 이중 Jekyll은 [Markdown]과 [Textile]을 지원합니다.
다른 마크업 언어를 사용하기 위해서는 파일명을 .md 또는 .textile로 주면 됩니다.

앞서의 포스팅의 파일명을 \_site/2012/05/27/first-posting.md로 바꾸고 다음과 같이 내용을 바꿉니다.

{% highlight html %}
---
layout: default
title: 첫번째 포스팅
---
**야호**. 블로그를 만들었습니다.
{% endhighlight %}

Jekyll 실행결과는 이전과 동일합니다.(&lt;b&gt; 태그가 &lt;strong&gt;으로 변경되긴 합니다.)

이렇게 보면 HTML과 별 다를 것 없어보이지만, 내용이 많아질 수도록 다른 마크업 언어를 이용하는게 편합니다.

결론
====

기본적으로는 여기까지가 Jekyll의 기능 전부입니다.
심지어 index.html에서 각 포스팅으로의 링크도 직접 만들어야 합니다.

물론 포스팅 목록이나 태그 목록, 카테고리 정보등의 데이터를 제공해주지만,
이런 데이터를 [Liquid]의 기능을 이용해 HTML 페이지로 만들어내는 것은 직접 해야합니다.
아무것도 없는 상태에서 이러한 결과물을 만드는 것은 쉬운일이 아니죠.

이를 도와주는 것이 [Jekyll-Bootstrap](http://jekyllbootstrap.com/)입니다.
다음 글에서는 이를 이용해 실제 블로그를 만들어 보겠습니다.

 [RubyGems]: http://rubygems.org/
 [Liquid]: http://liquidmarkup.org/
 [YAML]: http://yaml.org/
 [Markdown]: http://daringfireball.net/projects/markdown/
 [Textile]: http://textile.sitemonks.com/
