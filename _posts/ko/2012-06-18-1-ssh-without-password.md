---
layout: post.ko
title: 암호 없이 SSH 접속하기
category: ko
tags: [infrastructure, ssh]
author: sangmin.yoon
---

이번 글에서는 SSH 서버에 암호 입력 없이 접속하는 방법에 대해서 설명하겠습니다.
정확히 얘기하자면 암호 대신 열쇠를 이용해서 접속하는 방법이 되겠습니다.
암호를 입력하지 않는다고 해서 보안에 허술하다는 뜻은 아닙니다.

원리
====

제가 처음 유닉스를 접했을 당시에는 서버에 접속하려면 주로 Telnet을 사용했었습니다.
그때의 인식이 이어져 내려와 암호 없이 서버에 접속하는 것이 어색하게 느껴지긴 했으나,
사실 열쇠를 이용하는 것이 여러모로 편리하고 좋습니다.

두가지는 어떤 차이점이 있을까요?

암호의 경우 각 서버가 가지고 있는 것입니다.
따라서 어떠한 클라이언트에서라도 암호만 알고 있으면 서버에 접속할 수 있습니다.
외우기 위해서는 암호가 어느 정도 이상 어려워지기 힘들기 때문에, 아무리 암호가 잘 암호화되어 서버에 저장되었어도,
암호 DB가 유출되면 풀릴 가능성이 높습니다. 같은 암호를 쓴 다른 서버가 있다면 다른 서버도 덩달아 위험해지겠죠.
그리고 여러 사람이 같은 계정을 공유해야 하는 경우 암호를 한번 바꾸는 것도 쉽지 않습니다.

반면에 열쇠는 클라이언트와 서버가 나눠서 가지고 있고, 나누어진 열쇠가 맞아야지만 온전한 열쇠가 됩니다.
이 때 클라이언트가 가진 키를 개인 열쇠(private key), 서버가 가진 열쇠를 공공 열쇠(public key)라고 합니다.
서버에 공공 열쇠가 등록되어야지만 접속이 가능하기 때문에 장소를 가리지 않고 접속해야 하는 경우에는 사용하기 어렵지만,
서버에서 공공 열쇠가 유출되어도 개인 열쇠를 거의 알 수 없기 때문에 (다른 열쇠를 알기 어렵다는 것이 개인/공공 열쇠 방식의 핵심입니다)
다른 서버에 영향이 가지 않습니다.
또 한 계정에 등록할 수 있는 공공 열쇠에 제한이 없기 때문에, 여러 사람이 각자 가진 개인 열쇠들로 계정을 공유할 수 있습니다.
대신 개인 열쇠가 유출되면 문제가 생기지만 (개인 열쇠는 아무렇게나 복사해서 쓰면 안 되고
클라이언트별로 다른 열쇠를 만들어야 합니다), 열쇠를 적절히 제한해서 서버에 등록해뒀다면 영향이 최소화 될 순 있습니다.
또 개인 열쇠에 암호를 걸 수도 있습니다. 이 경우 유출되어도 비교적 안심할 수 있겠죠.

두가지 방식의 특징에 대한 논의는 많이 존재하므로 궁금하신 분은 인터넷에서 쉽게 정보를 얻으실 수 있습니다.

열쇠를 이용할 경우 자동화가 쉬워진다는 추가 장점이 있습니다.
많은 서버/클라이언트 프로토콜(Git등)이 SSH을 통하기 때문에 SSH 인증만 자동으로 된다면 많은 일들이 자동화가 됩니다.
그런데 암호를 이용한 SSH 인증 사용시 어딘가에 암호가 **평문**으로 존재해야 한다는 부담이 생깁니다.
반면 열쇠를 이용한 경우 서버에 자동 접속을 허가하려는 클라이언트의 공공 열쇠를 등록하는 것으로 충분하고,
추가적인 보안 위험은 없습니다.

방법
====

이제 실제로 암호 없이 SSH 서버에 접속하는 방법을 설명드리겠습니다.
원리를 이해하셨다면 큰 어려움이 없을 겁니다.

개인 열쇠 생성
--------------

우선 **클라이언트**에서 개인 열쇠를 생성합니다.

{% highlight bash %}
$ ssh-keygen -t rsa -C "comment to key"
Generating public/private rsa key pair.
Enter file in which to save the key (/home/user/.ssh/id_rsa):
Enter passphrase (empty for no passphrase):
Enter same passphrase again:
Your identification has been saved in /home/user/.ssh/id_rsa.
Your public key has been saved in /home/user/.ssh/id_rsa.pub.
The key fingerprint is:
50:a5:15:0b:4b:b5:2e:2e:fb:97:6d:f8:b1:c0:48:a6 comment to key
{% endhighlight %}

-C 뒤에 주는 것은 개인 열쇠에 대한 설명입니다. 보통 간단하게 이메일 형식을 사용합니다. 저의 경우 'sangmin.yoon@컴퓨터명'을 사용합니다.

첫번째로 경로를 입력하게 되어 있습니다. 대부분의 경우 기본값을 그대로 둡니다. (ssh 명령에서 따로 인자를 주지 않으면 저 경로를 참고합니다.)

두번째는 암호구를 입력하는 곳입니다. 우리의 주 목적은 암호없이 서버에 접속하는 것이기 때문에 이 부분은 빈칸으로 둡니다.
여기에 암호구를 넣으면 열쇠를 사용하기 전에 암호구를 확인합니다.
단 이 암호구는 서버로 전송되지 않는 것으로, 암호를 통한 SSH 접속과는 다른 동작을 합니다.
원하는 경우 나중에 'ssh-keygen -p' 명령으로 암호구를 변경할 수 있습니다.

위와 같이 하면 .ssh 디렉토리에 id_rsa와 id_rsa.pub 파일이 생기는데 각각 개인 열쇠와 공공 열쇠입니다.
파일 권한을 살펴보시면 id_rsa 파일이 더 한정된 권한을 갖는 것을 볼 수 있습니다.

{% highlight bash %}
$ ls -l
-rw------- 1 user user 1675 Jun 18 16:19 id_rsa
-rw-r--r-- 1 user user  396 Jun 18 16:11 id_rsa.pub
{% endhighlight %}

공공 열쇠 등록
--------------

자 이제 공공 열쇠를 **서버**에 등록하면 됩니다.

서버에 접속해서 .ssh/authorized_keys 파일에 id_rsa.pub의 내용을 추가하면 됩니다.
여려 개의 공공 열쇠를 등록할 경우 한줄에 하나씩 넣으면 됩니다.
이 파일은 본인에게만 읽기/쓰기 권한(0600)이 있어야 합니다.

제 서버 설정 예입니다.

{% highlight bash %}
$ cat .ssh/authorized_keys 
ssh-rsa AAAA....OXIj sangmin.yoon@iMac
ssh-rsa AAAA....Ew== sangmin.yoon@wiki
ssh-rsa AAAA....xgrT sangmin.yoon@git
$ ls -l .ssh/authorized_keys
-rw------- 1 user user 1585 Jun  8 09:09 .ssh/authorized_keys
{% endhighlight %}

접속 확인
---------

다시 **클라이언트**로 돌아와 SSH 접속을 시도했을 때 암호 없이 접속되었다면 성공한 것입니다.

{% highlight bash %}
$ ssh sangmin.yoon@git.croquis.com
Last login: Mon Jun 18 16:09:20 2012 from 192.168.23.7
sangmin.yoon@git:~$ 
{% endhighlight %}
