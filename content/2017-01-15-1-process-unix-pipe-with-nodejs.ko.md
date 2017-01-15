---
title: Node.js로 유닉스 파이프 처리하기
tags: []
date: 2017-01-15
author: Sangmin Yoon
original: http://sixmen.com/ko/tech/2017-01-15-1-process-unix-pipe-with-nodejs/
---

크로키에서는 로그를 JSON 문자열로 만들어 일자별(혹은 시간별)로 묶은 후
gzip으로 압축해서 저장하고 있습니다.
그런데 이미 만들어진 로그를 수정해야 하는 일이 생겼습니다.

<!--more-->

예를 들면

{{< highlight javascript >}}
{"date":"Fri Jan 15 2016 00:00:01 GMT+0000 (UTC)","path":"/foobar"}
{"date":"Fri Jan 15 2016 00:00:03 GMT+0000 (UTC)","path":"/croquis"}
{"date":"Fri Jan 15 2016 00:00:10 GMT+0000 (UTC)","path":"/awesome"}
{{< /highlight >}}

였던 데이터를

{{< highlight javascript >}}
{"date":"2016-01-15T00:00:01.000Z","path":"/foobar"}
{"date":"2016-01-15T00:00:03.000Z","path":"/croquis"}
{"date":"2016-01-15T00:00:10.000Z","path":"/awesome"}
{{< /highlight >}}

처럼 바꿔야 했습니다.

로그 전체를 읽어와서 줄별로 변환하고 다시 기록하면 되는 일이지만
로그가 커서 잘 동작하지 않았습니다.

그래서 유닉스의 파이프 형태로 처리하기로 했습니다.

위의 작업을 하는 Node.js 프로그램은 다음과 같습니다.

{{< highlight javascript >}}
const byline = require('byline');
const stream = byline(process.stdin);
stream.on('data', function (line) {
  const data = JSON.parse(line);
  data.date = new Date(data.date).toISOString();
  console.log(JSON.stringify(data));
});
{{< /highlight >}}

[byline](https://github.com/jahewson/node-byline)은 스트림을 줄별로 처리할 수 있게 해주는 모듈입니다.
줄별로 들어온 JSON 문자열을 파싱하고 원하는 처리를 한 후 다시 쓰기만 하는 단순한 코드입니다.
이 프로그램을 유닉스 파이프라인에 넣으면 원하는 결과를 얻을 수 있습니다.

{{< highlight bash >}}
$ gunzip -c original/01.data.gz | node convert.js | gzip > converted/01.data.gz
{{< /highlight >}}

### 보너스

이 작업을 순수히 Node.js만 가지고도 할 수 있습니다.

{{< highlight javascript >}}
const fs = require('fs');
const stream = require('stream');
const zlib = require('zlib');
const byline = require('byline');

class Convert extends stream.Transform {
  constructor(options) {
    super(options);
  }
  _transform(line, encoding, callback) {
    const data = JSON.parse(line);
    data.date = new Date(data.date).toISOString();
    callback(null, JSON.stringify(data)+'\n');
  }
}

fs.createReadStream('original/01.data.gz')
  .pipe(zlib.createGunzip())
  .pipe(byline())
  .pipe(new Convert())
  .pipe(zlib.createGzip())
  .pipe(fs.createWriteStream('converted/01.data.gz'));
{{< /highlight >}}

하지만 파이프의 특성상 하나의 프로그램이 하나의 작업만
할 수록 응용하기가 편해집니다.
예를 들어 파일이 로컬에 있는게 아니고 S3에 있다면
유닉스 파이프로는 다음과 같이 바꾸면 됩니다.

{{< highlight bash >}}
$ aws s3 cp s3://mybucket/stream.txt - | gunzip | node convert.js | gzip > converted/01.data.gz
{{< /highlight >}}

Node.js로도 작성할 수 있지만 훨씬 많은 코드를 작성해야겠죠.
