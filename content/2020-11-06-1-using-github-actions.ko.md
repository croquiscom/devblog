---
title: GitHub Actions 활용하기
tags: ['GitHub']
date: 2020-11-06
author: Sangmin Yoon
original: http://sixmen.com/ko/tech/2020-11-06-1-using-github-actions/
---

규모가 커지면 커질 수록 자동화된 워크플로우는 필수라고 생각합니다.
하지만 부끄럽게도 크로키닷컴은 잘 구축된 편은 아닙니다.

유닛 테스트는 초기부터 있었지만 그걸 PR, 머지마다 자동으로 수행하지는 못했습니다.
그러다가 2017년 중반 겨우 Jenkins를 세팅해서 자동 테스트만은 수행했습니다. 하지만 그게 워크플로우와 잘 어우러지지 못했습니다.
2019년에는 CodeBuild로 전환을 했고 비로서 PR 생성시 자동 테스트를 수행해 실패하면 머지를 할 수 없도록 구성이 됐습니다.

그럭저럭 아쉬운 대로 쓰고는 있었지만 매 테스트마다 수십분씩 걸리고 수정도 어려웠습니다.
가장 대중적으로 널리 쓰이는 Jenkins, 저희가 만든 OSS에 연결해 둔 [Travis CI](https://travis-ci.com/), [CircleCI](https://circleci.com/)등을
계속 두드려봤지만 썩 마음에 드는게 없었습니다.

가장 방해가 되던건 저희가 마이크로서비스 아키텍처로 서비스들이 잘게 쪼개져 있는데, 저장소는 단일 저장소(monorepo)라는 점이였습니다.
그러나 사람이 늘면서 도저히 단일 저장소로는 감당이 안 되어 저장소를 분리하기 시작했고, 분리된 저장소에서
새로운 자동화 시스템을 고민하는데 그 때 눈에 띈 것이 [GitHub Actions](https://github.com/features/actions)였습니다.
작성이 쉬우면서도 확장성이 좋아서 그 뒤로 여러가지 워크플로우에 GitHub Actions를 사용하고 있습니다.

이번 글에서는 현재 저희 팀이 세팅한 GitHub Actions의 workflow 파일을 공유하려고 합니다.
이 내용이 독자분들에게 도움이 됐으면 합니다.

<!--more-->

## 테스트 자동화

PR이나 머지 완료시 테스트를 수행합니다.

```yaml
name: 테스트 실행

# PR이 만들어졌거나 master 브랜치에 머지되어 올라갈 때 수행합니다.
on:
  push:
    branches:
      - master
  pull_request:
    branches:
      - "**"

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      # MySQL 데몬을 띄웁니다.
      # service container를 쓸 수도 있습니다.
      - name: Setup MySQL
        uses: mirromutth/mysql-action@v1.1
        with:
          host port: 7777
          container port: 3306
          mysql version: '5.7'
          mysql database: testdb
          mysql user: 'croquis_test'
          mysql password: 'test_password'

      # 소스를 가져옵니다.
      - name: Checkout code
        uses: actions/checkout@v2

      # 실행 속도를 빠르게 하기 위해 설치된 Node 모듈을 캐시하도록 설정합니다.
      - name: Cache node modules
        uses: actions/cache@v2
        with:
          path: ~/.npm
          key: ${{ runner.os }}-node-${{ hashFiles('**/package-lock.json') }}
          restore-keys: |
            ${{ runner.os }}-node-

      # Node 14.x를 사용합니다.
      - name: Use Node.js
        uses: actions/setup-node@v1
        with:
          node-version: '14.x'

      # 모듈을 설치합니다.
      - name: Install packages
        run: npm ci

      # 테스트를 수행합니다.
      - name: Run unit test
        run: npm run test

      # 중간에 실패한 경우 슬랙으로 알려줍니다.
      # GitHub 저장소나 조직의 Secrets 항목에 슬랙 Webhook URL을 등록해야 합니다.
      - name: Notify failure
        uses: 8398a7/action-slack@v3
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
        with:
          status: ${{ job.status }}
          username: github-actions
          channel: '#github'
        if: failure()
```

## 문서 빌드 후 업로드

현재 [Docusaurus](https://docusaurus.io/)를 사용해 코드와 같은 저장소에서 문서를 작성하고 있습니다.
이를 자동으로 문서 공유 웹사이트에 올립니다.

PR시에도 문서를 생성해 별도 경로로 올립니다.
잘 구성하면 하나의 step으로 만들 수도 있을 것 같은데 빠르게 구현하느라 if를 써서 별도 step으로 구현했습니다.

```yaml
name: 문서 빌드

# PR이 만들어졌거나 master 브랜치에 머지되어 올라갈 때 수행합니다.
on:
  push:
    branches:
      - master
  pull_request:
    branches:
      - "**"

env:
  # 마이크로서비스 이름입니다.
  SERVICE: user
  BRANCH: ${{ github.head_ref }}
  # 문서 업로드를 위한 AWS Access Key / Secret Key를 Secrets에 등록해둡니다.
  AWS_ACCESS_KEY_ID: ${{ secrets.AWS_UPLOAD_DOC_ACCESS_KEY }}
  AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_UPLOAD_DOC_SECRET_KEY }}

jobs:
  doc:
    runs-on: ubuntu-latest

    steps:
      # 소스를 가져옵니다.
      - name: Checkout code
        uses: actions/checkout@v2

      # 실행 속도를 빠르게 하기 위해 설치된 Node 모듈을 캐시하도록 설정합니다.
      - name: Cache node modules
        uses: actions/cache@v2
        with:
          path: ~/.npm
          key: ${{ runner.os }}-node-${{ hashFiles('**/package-lock.json') }}
          restore-keys: |
            ${{ runner.os }}-node-

      # Node 14.x를 사용합니다.
      - name: Use Node.js
        uses: actions/setup-node@v1
        with:
          node-version: '14.x'

      # 모듈을 설치합니다.
      - name: Install packages
        run: npm ci

      # 문서를 빌드합니다. (PR인 경우)
      - name: Build documentation (PR)
        # Docusaurus가 문서를 절대 경로로 생성하기 때문에 경로를 알려줘야 합니다.
        run: npm run doc /branches/${SERVICE}/${BRANCH}/
        if: github.ref != 'refs/heads/master'

      # 문서를 업로드합니다. (PR인 경우)
      - name: Upload documentation (PR)
        run: |
          aws s3 sync out-doc s3://doc.mysite.com/branches/${SERVICE}/${BRANCH} --delete --cache-control max-age=0
        if: github.ref != 'refs/heads/master'

      # 생성된 주소를 커밋 상태에 설정해서 바로 열어볼 수 있도록 합니다. (PR인 경우)
      - name: Set documentation url status (PR)
        uses: actions/github-script@v3
        with:
          github-token: ${{secrets.GITHUB_TOKEN}}
          script: |
            github.repos.createCommitStatus({
              context: 'documentaion',
              owner: context.repo.owner,
              repo: context.repo.repo,
              sha: context.eventName === 'pull_request' ? context.payload.pull_request.head.sha : context.sha,
              state: 'success',
              target_url: `https://doc.mysite.com/branches/${process.env.SERVICE}/${process.env.BRANCH}/index.html`,
            });
        if: github.ref != 'refs/heads/master'

      # 문서를 빌드합니다. (주 브랜치에 푸시한 경우)
      - name: Build documentation (master)
        run: npm run doc /${SERVICE}/
        if: github.ref == 'refs/heads/master'

      # 문서를 업로드합니다. (주 브랜치에 푸시한 경우)
      - name: Upload documentation (master)
        run: |
          aws s3 sync out-doc s3://doc.mysite.com/${SERVICE} --delete --cache-control max-age=0
        if: github.ref == 'refs/heads/master'

      # 생성된 주소를 커밋 상태에 설정해서 바로 열어볼 수 있도록 합니다. (주 브랜치에 푸시한 경우)
      - name: Set documentaion url status (master)
        uses: actions/github-script@v3
        with:
          github-token: ${{secrets.GITHUB_TOKEN}}
          script: |
            github.repos.createCommitStatus({
              context: 'documentaion',
              owner: context.repo.owner,
              repo: context.repo.repo,
              sha: context.eventName === 'pull_request' ? context.payload.pull_request.head.sha : context.sha,
              state: 'success',
              target_url: `https://doc.mysite.com/${process.env.SERVICE}/index.html`,
            });
        if: github.ref == 'refs/heads/master'

      # 중간에 실패한 경우 슬랙으로 알려줍니다.
      # 저장소나 조직의 Secrets 항목에 슬랙 Webhook URL을 등록해야 합니다.
      - name: Notify failure
        uses: 8398a7/action-slack@v3
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
        with:
          status: ${{ job.status }}
          username: github-actions
          channel: '#github'
        if: failure()
```

## 웹 클라이언트 배포

현재 웹 클라이언트는 S3에 올려 운영하고 있습니다.
빌드해서 S3에 올리는 workflow입니다.

```yaml
name: '백오피스 사이트 배포'

# 배포는 GitHub Actions 화면에서 수동으로 실행시켜야 합니다.
on:
  workflow_dispatch:

jobs:
  release:
    runs-on: ubuntu-latest

    steps:
      # 소스를 가져옵니다.
      - name: Checkout code
        uses: actions/checkout@v2

      # 실행 속도를 빠르게 하기 위해 설치된 Node 모듈을 캐시하도록 설정합니다.
      - name: Cache node modules
        uses: actions/cache@v2
        with:
          path: ~/.npm
          key: ${{ runner.os }}-node-${{ hashFiles('**/package-lock.json') }}
          restore-keys: |
            ${{ runner.os }}-node-

      # Node 14.x를 사용합니다.
      - name: Use Node.js
        uses: actions/setup-node@v1
        with:
          node-version: '14.x'

      # 모듈을 설치합니다.
      - name: Install packages
        run: npm ci

      # 결과물을 만듭니다.
      - name: Build
        run: npm run build

      # S3에 결과물을 업로드합니다.
      - name: Deploy
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_DEPLOY_FRONT_ACCESS_KEY }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_DEPLOY_FRONT_SECRET_KEY }}
        run: |
          aws s3 sync dist s3://backoffice.website.mysite.com/

      # 배포가 성공한 경우 알립니다.
      # Secrets 항목에 슬랙 Webhook URL을 등록해야 합니다.
      - name: Slack notification success
        uses: Ilshidur/action-slack@2.1.0
        env:
          SLACK_WEBHOOK: ${{ secrets.SLACK_WEBHOOK_URL }}
          SLACK_USERNAME: ${{ github.actor }}
          SLACK_CHANNEL: release
        with:
          args: '{{ GITHUB_REF }}({{ GITHUB_SHA }}): 백오피스 사이트를 배포했습니다.'

      # 배포가 실패한 경우 알립니다.
      # Secrets 항목에 슬랙 Webhook URL을 등록해야 합니다.
      - name: Slack notification failure
        uses: Ilshidur/action-slack@2.1.0
        env:
          SLACK_WEBHOOK: ${{ secrets.SLACK_WEBHOOK_URL }}
          SLACK_USERNAME: ${{ github.actor }}
          SLACK_CHANNEL: release
        with:
          args: '{{ GITHUB_REF }}({{ GITHUB_SHA }}): 백오피스 사이트 배포에 실패했습니다.'
        if: failure()
```

## 출시 후보 준비

현재 저희는 개발 브랜치로 작업을 하다가 특정 시점에 출시 후보(Release Candidate)를 준비해서 최종 검증 후 출시를 하는 프로세스를 해보고 있습니다.
이를 자동으로 준비하는 workflow입니다.

이 workflow는 기본 브랜치 기준으로 실행되므로 개발 브랜치가 기본 브랜치여야 합니다.

```yaml
name: 출시 후보 준비

# 새벽에 출시를 위한 후보 브랜치를 준비합니다.
on:
  schedule:
    - cron: '0 19 * * WED' # 목요일 새벽 4시

jobs:
  create_rc:
    runs-on: ubuntu-latest

    steps:
      # RC 브랜치를 생성합니다.
      - name: Create RC branch
        uses: peterjgrainger/action-create-branch@v2.0.1
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        with:
          branch: 'rc'

      # RC 브랜치를 가지고 출시용 PR을 생성합니다.
      # JavaScript 코드로 GitHub API를 자유롭게 사용할 수 있는 github-script 모듈을 사용합니다.
      - name: Create PR
        id: cpr
        uses: actions/github-script@v3
        with:
          github-token: ${{secrets.GITHUB_TOKEN}}
          result-encoding: string
          script: |
            const target = new Date(); // UTC 기준 수요일 저녁
            const month_start = new Date(target.getFullYear(), target.getMonth(), 1);
            const month_week = Math.ceil(( ( (target - month_start) / 86400000) + 1)/7); // 주차 계산
            const title = `${target.getFullYear()}년 ${target.getMonth() + 1}월 ${month_week}주`;
            try {
              // rc에서 main으로의 PR을 생성합니다.
              const result = await github.pulls.create({
                owner: context.repo.owner,
                repo: context.repo.repo,
                title,
                head: 'rc',
                base: 'main',
              });
              return `${context.repo.repo} 저장소에 대해 ${title} RC PR을 생성했습니다. ${result.data.html_url}`;
            } catch (error) {
              return `${context.repo.repo} 저장소에 대해 변경 내용이 없어서 RC PR을 생성하지 않았습니다.`;
            }

      # 슬랙 채널에 내용을 공유합니다.
      - name: Slack notification success
        uses: Ilshidur/action-slack@2.1.0
        env:
          SLACK_WEBHOOK: ${{ secrets.SLACK_WEBHOOK_URL }}
          SLACK_USERNAME: ${{ github.actor }}
          SLACK_CHANNEL: 'release'
        with:
          args: ${{ steps.cpr.outputs.result }}
```
