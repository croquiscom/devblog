---
title: 사내 npm 패키지 저장소를 구축하기 위해 겪었던 과정들
tags: ['npm']
date: 2022-03-07
author: Jason(황주성)
summary:
  회사나 팀에서 개발하다 보면 한 번쯤은 거의 필연적으로 내부에서 사용하기 위한 패키지 저장소에 대해 고민해보게 됩니다.
  오늘은 그 고민을 통해 사내에서 사용할 수 있는 NPM 패키지 저장소를 구축하기 위해 겪었던 부분들에 대해 짧게나마 공유하려고 합니다.
original: https://nabigraphics.medium.com/%EC%82%AC%EB%82%B4-npm-%ED%8C%A8%ED%82%A4%EC%A7%80-%EC%A0%80%EC%9E%A5%EC%86%8C%EB%A5%BC-%EA%B5%AC%EC%B6%95%ED%95%98%EA%B8%B0-%EC%9C%84%ED%95%B4-%EA%B2%AA%EC%97%88%EB%8D%98-%EA%B3%BC%EC%A0%95%EB%93%A4-9fa5b1e636be
---

![Photo by Mariah Krafft on Unslpash](https://images.unsplash.com/photo-1623945619536-63f2cd1bad36?ixlib=rb-1.2.1&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&auto=format&fit=crop&w=2340&q=80)

Photo by [Mariah Krafft](https://unsplash.com/@madesolobymariah) on [Unslpash](https://unsplash.com/photos/g87PtqNlqOE)

안녕하세요! 👋
카카오스타일 프론트엔드 챕터 소속 Jason(제이슨/황주성)입니다.

회사나 팀에서 개발하다 보면 한 번쯤은 거의 필연적으로 내부에서 사용하기 위한 패키지 저장소에 대해 고민해보게 됩니다.

오늘은 그 고민을 통해 사내에서 사용할 수 있는 NPM 패키지 저장소를 구축하기 위해 겪었던 부분들에 대해 짧게나마 공유하려고 합니다.

## git을 사용한 패키지 설치

기존에는 비공개 패키지를 git+ssh 방식을 사용하여 특정 저장소의 태그 내용을 받아서 사용하고 있었는데요, 이렇게 사용하다 보니 몇 가지 문제점이 있었습니다.

컴파일된 파일들뿐만 아니라 개발 환경에서 사용하는 모든 코드 및 설정들이 같이 포함되어 패키지 용량이 늘어나게 됐고, 모노레포 구조로 운영되고 있는 저장소에서는 해당 방식으로 패키지 관리를 하기에는 스크립트를 통해 패키지별로 파일 분기 작업 등 부가적인 작업이 필요했습니다.

## npm 비공개 패키지 사용

git 방식과 더불어 공개 패키지의 경우에는 npm 저장소를 사용하고 있었다 보니 처음에는 조직의 플랜을 유료 플랜으로 변경해서 사용하면 되겠지 싶었지만, 대부분의 읽기 권한 사용자를 포함하여 인당 월 7달러씩 지출이 되는 것은 꽤 큰 지출이었습니다. (그리고 관리 차원에서도 좀 더 신경을 써야 되기도 했고요.)

> 가령 비공개 패키지를 사용하는 프로젝트의 참여자가 70명이라면 7*70 = 490. 달마다 490달러씩 지출이 됩니다. 😱

## GitHub Packages

npm 외에 그 당시에 GitHub Packages에 대해서도 같이 알아보게 되었습니다.

GitHub Packages의 경우 기존에 이미 깃헙 조직(Organization)을 사용 중이기도 했고 데이터 전송과 스토리지에 대한 비용만 추가 되다 보니 꽤 나쁘지 않은 조건이었습니다.

연동 방법에 대해서도 그렇게 어렵지 않았고요.

그래서 ~~오! 이거다! 싶어서~~ 로컬 배포도 시도해 보고 깃헙 액션에도 붙여보고 조금씩 GitHub Packages를 연동하는 작업을 진행했습니다.

그러나... 이제 정말 다 끝났다 싶은 생각이 들 때쯤 예상치 못한 문제가 발생했습니다.

### 같은 scope(스코프), 서로 다른 저장소의 충돌 문제 발생

@my-project라는 스코프를 가진 패키지가 a, b, c 있다고 가정해 보겠습니다.

a는 내부에서 사용하는 비공개 패키지이며 GitHub Packages로 배포됩니다.

나머지 b와 c는 npm을 통해 공개되어있는 패키지입니다.

```
@my-project/a:registry=https://npm.pkg.github.com
```

그리고 프로젝트에서 a라는 패키지를 GitHub Packages에서 받아오기 위해 위와 같이 a 패키지에 대한 registry 설정을 해줬습니다.

하지만 알고 보니 registry 설정은 패키지 이름이 아니라 스코프(@my-project)에만 설정할 수 있었고 그로 인해 다른 저장소에서 있는 b와 c는 가져오지 못하는 문제가 생겼던 것이죠.

그래서 a라는 패키지의 스코프를 @my-project가 아닌 @my-secret-project 바꿔주고 사용하려고 했지만 GitHub Packages의 경우엔 해당 조직(Organization)과 다른 스코프의 이름은 사용할 수 없었습니다. 😭

> 다른 방안으로 스코프를 가진 기존 공개 패키지를 GitHub Packages로 옮기는 것도 생각을 해보긴 했지만 이번에는 시도해보지 않았습니다.

## Sonatype Nexus에 npm 저장소 도입

![Pasted image 20220301073804.png](/img/content/2022-03-07-1/Pasted_image_20220301073804.png)

스코프 이슈로 인해서 다시 한번 프론트엔드 챕터 채널에 내용을 공유하게 되었고, 이때 [Verdaccio](https://verdaccio.org/)와 [Sonatype의 Nexus Repository OSS](https://www.sonatype.com/products/repository-oss)가 후보군으로 올라왔습니다.

둘 다 직접 구축해서 사용하는 저장소이기에 GitHub Packages처럼 여러 스코프를 사용하지 못하는 이슈는 없었습니다.

Verdaccio의 경우 주변에서 많은 분이 들어보거나 사용해보신 경험이 있으셨고 설정도 그렇게 어렵진 않아 보였습니다. 추가로 안정성도 나름 보장된 것 같았고요.

다만, 타 팀에서 이미 Sonatype의 Nexus를 구축해서 사용하고 계셨기에 이번에는 Verdaccio 대신 Sonatype의 Nexus를 먼저 도입해보기로 결정했습니다.

> Sonatype Nexus가 이미 설치되어 있었기에, 이번 내용에서는 npm 저장소를 구축하는 방법에 대해서만 설명하도록 하겠습니다. ~~(나중에 기회가 된다면 설치 방법도...)~~
> 

### hosted npm 저장소 추가

![Pasted image 20220301054619.png](/img/content/2022-03-07-1//Pasted_image_20220301054619.png)

먼저 Repository -> Repositories에서 **Create repository**를 클릭해줍니다.

![Pasted image 20220301054638.png](/img/content/2022-03-07-1//Pasted_image_20220301054638.png)

그리고 Recipe 중에 **npm (hosted)** Recipe를 선택합니다.

![Pasted image 20220301054647.png](/img/content/2022-03-07-1//Pasted_image_20220301054647.png)

Name에 본인이 사용할 저장소 이름을 입력해주고 별다른 설정 없이 하단의 **Create repository**를 클릭해줍니다.

![Pasted image 20220301054655.png](/img/content/2022-03-07-1//Pasted_image_20220301054655.png)

생성 이후 리스트에서 본인이 만든 저장소를 클릭해서 들어간 뒤 화면과 같이 URL: 옆에 나와 있는 주소를 잘 메모해둡니다.

> 이후에 아래에서 설명할 registry 설정에서 사용될 주소입니다.
> 

### Roles 추가 및 권한 부여

생성한 저장소에 사용자가 접근할 수 있도록 읽기 권한과 패키지 작업을 위한 쓰기 권한을 만들어 줍니다.

![Pasted image 20220301054709.png](/img/content/2022-03-07-1//Pasted_image_20220301054709.png)

Security -> Roles에서 Create role(Nexus role)을 클릭해줍니다.

![Pasted image 20220307022217.png](/img/content/2022-03-07-1//Pasted_image_20220307022217.png)

Privileges에서 npm을 검색하여 `nx-repository-view-npm-{생성한 저장소 이름}-browse` 및 `nx-repository-view-npm-{생성한 저장소 이름}-read`를 추가해줍니다.

![Pasted image 20220307022250.png](/img/content/2022-03-07-1//Pasted_image_20220307022250.png)

그리고 똑같은 방식으로 쓰기(add) 및 수정(edit) 권한을 추가해주고 Roles에 방금 만든 읽기 권한(npm-read)도 같이 Contained에 추가해줍니다.

> delete도 함께 추가해줘도 되지만 보안상 이유로 패키지 작업자도 삭제는 별도의 요청을 통해 지울 수 있도록 추가하진 않았습니다.

![Pasted image 20220301054744.png](/img/content/2022-03-07-1//Pasted_image_20220301054744.png)

이제 추가해준 역할을 부여해줍니다.

Security -> Users에서 본인이 추가할 사용자에 들어가 Roles Granted에 추가해줍니다.

### npm registry login

로컬환경에서 패키지를 불러오거나 배포할 수 있게 npm login 시켜줍니다.

```bash
$ npm login --registry={{본인이 만든 hosted npm 저장소 URL}}
$ Username: 본인의 Sonatype 계정 ID
$ Password: 본인의 Sonatype 계정 Password
$ Email: 본인의 이메일
```

### package.json publishConfig registry 설정

배포할 패키지의 package.json에 registry를 설정해줍니다.

```json
{
	"publishConfig": {
		"registry": "{{본인이 만든 hosted npm 저장소 URL}}"
	}
}
```

### 로컬에서 패키지 배포

이제 npm publish(혹은 yarn publish)를 호출하면 배포가 잘..

![Pasted image 20220301054855.png](/img/content/2022-03-07-1//Pasted_image_20220301054855.png)

..?

분명 npm login도 했고... 권한도 제대로 부여한 것 같은데 배포가 되지 않았습니다... 😭

![Pasted image 20220301055152.png](/img/content/2022-03-07-1//Pasted_image_20220301055152.png)

한참을 찾던 끝에 [여기](https://productive.me/self-hosted-nexus-for-private-scoped-npm-packages/)에서 Realms 설정이 필요하다는 것을 알게 되었습니다.

![Pasted image 20220301054907.png](/img/content/2022-03-07-1//Pasted_image_20220301054907.png)

Security -> Realms에 들어가서 **npm Bearer Token Realm**을 Active로 옮겨준 뒤 Save를 누릅니다.

![Pasted image 20220301063108.png](/img/content/2022-03-07-1//Pasted_image_20220301063108.png)

이후 다시 배포를 진행하면 정상적으로 배포가 되는 것을 확인할 수 있습니다. 🎉

![(Simon에게 받은 +1)](/img/content/2022-03-07-1//Pasted_image_20220301075935.png)

(Simon에게 받은 +1)

### GitHub Actions에서 패키지 배포

GitHub Actions를 통해 패키지 배포를 하기 위해서는 workflow에서 배포 전 패키지 저장소에 권한 인증을 해줘야 합니다.

위에서 활용한 npm login 방식을 통해 인증 해줘도 되지만 이번에는 .npmrc 파일에 `_auth` 키를 추가하여 인증하는 방식을 사용했습니다.

`_auth` 키에는 Sonatype 계정의 **username:password**를 **Base64**로 인코딩된 값을 사용하고 있습니다. openssl을 사용하거나 별도 base64 인코딩 툴을 사용하여 값을 생성해 줍니다.

> *username이 user1이고 password가 1234면 `user1:1234` 를 인코딩한 `dXNlcjE6MTIzNA==` 가 `_auth` 값이 됩니다.*

```bash
$ echo -n 'user1:1234' | openssl base64
dXNlcjE6MTIzNA==
```

![Pasted image 20220301055219.png](/img/content/2022-03-07-1//Pasted_image_20220301055219.png)

생성한 값을 Actions secrets에 추가해줍니다.

이후 workflow yml 파일 중간에 .npmrc 파일을 생성하는 job을 추가해주면 정상적으로 배포가 됩니다.

```yaml
- name: Creating .npmrc
	run: |
		cat << EOF > "$HOME/.npmrc"
		{{본인이 만든 hosted npm 저장소 URL}}:_auth=$NPM_TOKEN
		EOF
	env:
		NPM_TOKEN: ${{ secrets.SONATYPE_NEXUS_NPM_PUBLISH_TOKEN }}
```

> 참고로 저장소 URL의 앞부분인 http://나 https://에서 텍스트와 : 을 빼고 `//localhost:1234/repository/npm/` 이런 식으로 추가해주셔야 합니다.
> 

### 프로젝트에서 내부 패키지 사용을 위해 .npmrc 설정

마지막으로 배포된 패키지가 npmjs 저장소가 아닌 저희가 만든 저장소에서 받도록 알려주기 위해 프로젝트 루트에 .npmrc 파일을 다음과 같이 만들어 줍니다.

```
# scope의 이름만 추가
# ex) 패키지 이름이 @my-project/library-a라면 앞에 @my-project만 입력
# .npmrc
@my-project:registry={{본인이 만든 hosted npm 저장소 URL}}
```

## 내부 패키지는 scope(스코프)를 사용해서 관리하자

@my-project와 같이 스코프를 사용할 경우 .npmrc 파일에서 특정 스코프의 패키지를 본인이 만든 hosted npm 저장소를 바라보도록 설정할 수 있지만 react나 lodash, library-a와 같이 스코프로 관리 되지 않는 내부 패키지의 경우 패키지 설치를 위해 매번 아래처럼 registry를 알려줘야 하는 번거로움이 있습니다.

```bash
$ (npm install or yarn add) library-a --registry={{본인이 만든 hosted npm 저장소 URL}}
```

그래서 가능하면 스코프를 사용해서 관리하는 것이 좋습니다.

## 이후에 해볼 만한 것들

얼핏 봤을 때 Sonatype Nexus의 Pro 버전에서만 지원하는 것 같아서 도입을 해보진 못했지만, npm hosted와 더불어 proxy 환경과 이를 묶을 수 있는 group이라는 저장소를 만들 수 있습니다.

group을 통해 잘 cd 도입해 본다면 npmjs.com에 배포된 공개 패키지의 스코프와 내부 패키지의 스코프를 통일시킬 수 있을 것 같기도 합니다. ~~(아마)~~

## 마치며

지금까지 저희가 git+ssh 방식에서부터 시작하여 GitHub Packages를 시도해보고 Sonatype Nexus 저장소로 정착하기까지의 과정들에 대해 말씀드릴 수 있었던 것 같습니다.

당분간은 이렇게 사용하겠지만 이후에 좀 더 나은 방향이 있다면 나중에 다시 개선해 볼 것 같습니다.

만약 본인이 좀 더 나은 방향에 대해 알고 있어 여기 와서 개선해보고 싶다! 하시거나, 비즈니스적인 측면과 아울러 다양한 기술적 부분에 대해 함께 고민하고 개발하고 싶으시다면 언제든 편하게 [링크](https://kakaostyle.recruiter.co.kr/app/jobnotice/view?systemKindCode=MRS2&jobnoticeSn=71180)를 통해 지원해주세요. :)

감사합니다.

---

## 참고자료

- [https://productive.me/self-hosted-nexus-for-private-scoped-npm-packages/](https://productive.me/self-hosted-nexus-for-private-scoped-npm-packages/)
- [https://ftredblog.wordpress.com/2018/03/05/nexus-3-x를-이용한-사설-npm-저장소-만들기/](https://ftredblog.wordpress.com/2018/03/05/nexus-3-x%EB%A5%BC-%EC%9D%B4%EC%9A%A9%ED%95%9C-%EC%82%AC%EC%84%A4-npm-%EC%A0%80%EC%9E%A5%EC%86%8C-%EB%A7%8C%EB%93%A4%EA%B8%B0/)
- [https://help.sonatype.com/repomanager3/nexus-repository-administration/formats/npm-registry/npm-security](https://help.sonatype.com/repomanager3/nexus-repository-administration/formats/npm-registry/npm-security)
