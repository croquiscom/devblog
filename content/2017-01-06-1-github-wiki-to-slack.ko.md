---
title: GitHub 위키 이벤트를 슬랙으로 받기
tags: []
date: 2017-01-06
author: Sangmin Yoon
---

현재 크로키닷컴은 프로젝트 관리를 GitHub로만 하고 있습니다.
이슈도 GitHub 이슈로 관리하고, 문서도 GitHub 위키를 사용하고 있습니다.

GitHub는 슬랙과의 연동이 잘 되어 있어서 GitHub에서의 활동을
슬랙을 통해 파악하고 대응하고 있습니다.
하지만 아쉽게도 GitHub 위키 이벤트는 처리하지 않습니다.
그래서 자체적으로 GitHub 위키 이벤트를 슬랙으로 알려주는 서비스를 만들었습니다.

<!--more-->

자세한 내용은 다음 글들을 참고하시면 됩니다.

* [1. AWS Lambda 설정](http://sixmen.com/ko/tech/2017-01-05-1-github-wiki-to-slack-setting-aws-lambda/)
* [2. AWS KMS를 이용해 키 보호](http://sixmen.com/ko/tech/2017-01-06-1-github-wiki-to-slack-protect-secret-using-kms/)
* [3. AWS API Gateway 생성하기](http://sixmen.com/ko/tech/2017-01-06-2-github-wiki-to-slack-aws-api-gateway/)
* [4. GitHub 웹훅 연결하기](http://sixmen.com/ko/tech/2017-01-06-3-github-wiki-to-slack-setup-github-hook/)
