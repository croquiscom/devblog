---
title: 잘못된 브랜치 배포를 방지하기
tags: ['Git']
date: 2022-08-28T00:00:00
author: Simon(윤상민)
original: https://sixmen.com/ko/tech/2022-08-28-1-prevent-deploy-invalid-branch/
---

반복해서 실수가 발생해서 수많은 사람들의 시간을 낭비하는데, 사실 시스템 개선에 조금만 시간을 썼으면 발생하지 않았을, 그런 문제들이 있습니다. 이런 상황을 알면서도 바쁘다는 핑계로 넘어가곤 하는데, 이번에 1년 이상 머리 한 구석에만 뒀던 이슈를 해결해 공유해볼까 합니다.

<!--more-->

## 문제

카카오스타일 정도의 규모에서는 당연히 어떤 기능을 프로덕션에 바로 배포하지 않습니다. 먼저 테스트 서버에 배포해 어느 정도 검증을 하고 프로덕션에 반영하게 됩니다. (물론 아무리 이런 과정을 거쳐도 문제는 발생하긴 합니다.) 카카오스타일은 스테이징 서버란 용어는 사용하지 않고, 알파란 용어를 사용하고 있습니다. 알파용 환경은 프로덕션 환경과 동일한 구조를 가지고 있지만, DB는 별개로 존재하는 환경입니다. (추가로 베타는 어플리케이션은 별도이지만, DB는 프로덕션을 사용하는 환경을 의미합니다. 피쳐 플래그 대신 주로 베타 환경을 이용해 최종 검증을 합니다.)

알파 환경은 하나이기 때문에 여러 팀이 동시에 작업하는 상황에서 충돌이 발생하곤 합니다. 어떤 기능을 알파에 배포해서 확인하던 도중에 다른 팀이 작업 덮어 씌워서 혼란이 발생하는데, 이를 완전히 막기는 어렵습니다. 이 부분은 일정 시간동안 알파 환경을 점유하겠다는 의사 표현을 하거나(아직 시스템화까진 생각하고 있지 않습니다), 알파 전 단계인 팀별 개발 환경을 만들어 해결하고 있습니다.

문제는 **테스트도 끝나 정식으로 프로덕션까지 반영된 기능이 알파 환경에서 사라지는 케이스**가 꽤 높은 비율로 발생한다는 점이였습니다. 오래전의 코드에서 브랜치를 만들어 내 기능을 작업한 이후에 최신 수정 사항을 제대로 반영하지 않은 채 알파에 배포를 하는 거죠. 나는 내 기능을 배포했을 뿐인데, 무관해 보이는 기능이 갑자기 동작하지 않으면서 이를 해결하기 위해 많은 사람들이 시간을 낭비하는 일이 발생하곤 했습니다.

해결책은 단순합니다. 정식으로 반영된 기능을 되돌리는 배포를 할 수 없게 막으면 됩니다. 다만 그동안 기술적 해결책을 찾지 못해, 규칙으로 정했지만(알파 배포시에는 main 브랜치를 포함해서 주세요!) 당연히 문제는 계속 발생했습니다.

## 작업 내용

카카오스타일도 당연히 배포 시스템이 갖춰져 있습니다. 명령을 내리면 GitHub에서 소스를 가져와 도커 이미지를 빌드하게 됩니다. 이때 브랜치도 같이 지정하게 됩니다. (프로덕션 배포시에는 브랜치가 고정 - 팀에 따라 master, main, release등을 사용 - 되어 있습니다.)

모든 소스를 가져오는 것은 오래 걸리기 때문에 얕은 복제(shallow clone)을 사용합니다.

```bash
$ git clone git@github.com:croquiscom/$SERVICE -b $BRANCH --depth 1 --jobs 2
```

이런 상황에서 배포하려는 브랜치가 주 브랜치(master, main)의 내용을 포함하고 있는지를 검사하는것이 이번 문제의 기술적인 이슈였습니다.

처음에는 복제(clone) 전에 브랜치 비교하는 방법을 찾아봤습니다. 하지만 아쉽게도 git 명령 중에 원격 저장소에서 동작하는 건 [ls-remote](https://git-scm.com/docs/git-ls-remote.html) 밖에 없는 것 같습니다.

로컬 저장소에서 브랜치 비교는 가능하지만, 문제는 얕은 복제여서 브랜치간 비교가 불가능하다는 것이였습니다. 전체 복제 대신 처음 고민한 옵션은 깊이를 늘리는 것이였습니다(`--depth` 또는 `--shallow-since`). 복제시 지정한 브랜치만 받아졌기 때문에 `--no-single-branch` 옵션도 필요합니다. 다만 아무리 적당히 큰 값을 준다고해도 배포할 브랜치와 주 브랜치의 공통 조상이 복제에 포함될지 여부를 보장할 수 없는 문제가 있습니다.

그래도 얕은 복제 후 필요한 만큼 커밋을 더 받는 옵션을 찾아봤는데 deepen 옵션을 알게 됐습니다. 여기에 더해 [공통 조상이 발견될 때까지 원격에서 커밋을 가져오는 스크립트](https://stackoverflow.com/a/56113247)를 스택오버플로우에서 발견하게 됩니다.

```bash
while [ -z $( git merge-base master feature ) ]; do
  git fetch -q --deepen=1 origin master feature;
done
```

위 스크립트가 동작하려면 master 브랜치도 로컬에 존재해야 하는데 `--no-single-branch` 옵션 대신 master 브랜치만 추가로 가져오는 건 [fetch-through-merge-base](https://github.com/rmacklin/fetch-through-merge-base)라는 기능의 코드에서 찾았습니다.

```bash
git fetch --depth=1 origin "+refs/heads/$BASE_REF:refs/heads/$BASE_REF"
```

이를 조합해 이미지 빌드 서버에 최종적으로 적용된 스크립트는 다음과 같습니다. (배포할 브랜치가 주 브랜치와 같은 경우에도 동작합니다.)

```bash
git clone git@github.com:croquiscom/$SERVICE -b $BRANCH --depth 1 --jobs 2
cd $SERVICE
git fetch --depth 1 origin "+refs/heads/$BASE_BRANCH:refs/heads/$BASE_BRANCH" || echo 'same branch'
while [ -z "$( git merge-base "$BASE_BRANCH" "$BRANCH" )" ]; do
  git fetch -q --deepen=20 origin "$BASE_BRANCH" "$BRANCH"
done
if [[ "$(git rev-list --left-only --count $BASE_BRANCH...$BRANCH)" != "0" ]]; then
  echo "$BASE_BRANCH is not merged"
  exit 1
fi
```

[rev-list](https://git-scm.com/docs/git-rev-list) 명령에서 `--count` 옵션을 사용하면 브랜치가 얼마나 앞서 있는지 수치로 알 수 있습니다. 주 브랜치(left)가 0 만큼 앞서 있다면 배포하려는 브랜치가 주 브랜치의 내용을 모두 포함하고 있다는 뜻이 됩니다.

## 한편..

초기에 구축한 배포 시스템은 AWS의 [CodeBuild](https://aws.amazon.com/ko/codebuild/)를 사용하고 있습니다. 한편 근래에 작업중인 서비스에서는 [GitHub Actions](https://github.com/features/actions)를 사용중입니다. 위 방법은 GitHub Actions에도 역시 적용 가능하지만, GitHub API를 쓰면 복제전에 검사가 가능합니다. (사실 이쪽을 먼저 해결했다 보니, git만 가지고 원격에서 가능한 방식이 있나 한참 찾아봤습니다.)

```yaml
- uses: actions/github-script@v6
  with:
    script: |
      const result = await github.rest.repos.compareCommitsWithBasehead({
        owner: context.repo.owner,
        repo: context.repo.repo,
        basehead: `master...${context.sha}`,
      });
      if (result.data.behind_by === 0) {
        return;
      }
      throw new Error('master not merged');
```

## 결론

몇 줄 안 되는 코드지만, 일반적으로 겪는 문제가 아니다보니 잠깐 검색해본 것으로는 잘 나오지 않는 내용이였습니다. 그러다보니 해결책을 찾는게 많이 미뤄진 것 같습니다. 하지만 마음 먹고 작업하니 하루에 끝날 정도의 분량이였고, 이게 적용되면 많은 시간 낭비를 없앨 것으로 기대됩니다.

이번에 작업한 내용과 유사하게 실수를 방지 하기 위한 조치를 하는 것을 [포카 요케](https://ko.wikipedia.org/wiki/%ED%8F%AC%EC%B9%B4_%EC%9A%94%EC%BC%80)라고 부릅니다. 카카오스타일에서는 실수를 반복하지 않게 하기 위해 포카 요케 목록을 만들어 해결하는데 최근 많은 시간을 투자하고 있습니다.
