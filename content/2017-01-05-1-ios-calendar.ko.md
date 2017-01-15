---
title: iOS에서 년도를 구할 때 비정상적인 값이 나오는 문제
tags: []
date: 2017-01-05
author: Sangmin Yoon
original: http://sixmen.com/ko/tech/2016-12-16-1-ios-calendar/
---

지그재그 앱을 사용하는 사용자를 분석할 때 사용하기 위해서
최근 업데이트에 나이를 입력받는 화면이 추가되었습니다.

입력은 나이를 받지만 나이는 매년 달라지기 때문에 고정된 값인 태어난 년도로 변환하여 저장하고 있습니다.
그런데 대부분은 정상적인 년도가 들어오는데 일부 사용자의 태어난 년도가 10이하 또는 2500이상인 문제가 있었습니다.

<!--more-->

처음에는 사용자가 게임등을 위해 핸드폰의 시간을 변경해서 발생했다고 생각했습니다.
하지만 값이 너무 튀었고, 또 그렇게 값이 다양하지는 않았습니다.

그러던 중에 값이 이상한 경우는 모두 iOS라는 사실을 깨달았습니다.
그래도 짐작가는 것은 없던 차에 값이 2500~2600사이라는 것을 보고 혹시나 해서 'ios year 2500'이라는
검색어로 검색을 해봤습니다. 그랬더니 [my iPad my set year is 2558 BE?](http://forums.imore.com/general-apple-news-discussion/262432-my-ipad-my-set-year-2558-a.html)라는
문서가 딱 처음에 나왔습니다.

결론적으로 iOS는 그레고리언 달력 외에도 일본력과 불교력을 지원합니다.
올해가 일본력으로 헤이세이 28년이기 때문에 나이를 20으로 입력하면 태어난 년도가 9가 됩니다.
불기로는 올해가 2560년이고 태어난 20살은 태어난 년도가 2541이 됩니다.

이것을 깨닫고 다시 태어난 년도가 이상한 사용자의 사용언어를 살펴보니 일본력은 일본어 사용자,
불교력은 태국어등 사용자로 나왔습니다.
지극히 한국과 한국어에 특화된 지그재그 서비스라고 생각하고 있었는데 드물지만 외국어 사용자가 있다는 사실이 놀라웠습니다.

기술적으로는

{{< highlight swift >}}
let calendar = Calendar.current // <--
let components = calendar.dateComponents([.year], from: Date())
let currentYear = components.year ?? 2016
{{< /highlight >}}

로 되어 있던 것을

{{< highlight swift >}}
let calendar = Calendar(identifier: .gregorian)
{{< /highlight >}}

로 변경했더니 사용자가 설정한 캘린더와 상관없이 기대한 값이 반환되었습니다.

혹시 유사한 증상이 있을 경우 한번 의심해보시면 좋을 것 같습니다.
