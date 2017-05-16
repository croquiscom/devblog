---
title: AWS의 Serverless #1 -  SQS, Lambda를 이용한 작업대기열 만들기
tags: ['Lambda','SQS','AWS','Serverless', 'TaskQueue','튜토리얼']
date: 2017-05-13
author: Jacob Choi
---

최근 클라우드 컴퓨팅환경이 널리 사용되면서 서버하드웨어 대한 유지보수 및 구성을 신경쓰지 않고,   
다양한 서비스들을 위한 서버를 개발할 수 있게 되었습니다.
하지만 이런 환경을 사용함에도 auto-scaling이나 서버 로그 수집, 서비스 배포 및 관리 등   
소프트웨어 스택에 관한 부분은 신경써줘야 합니다.

이러한 고민을 덜어주기 위해서 많은 클라우드 서비스에서 '서버없는 서버 Serverless' 컴퓨팅 환경을 제공하고 있습니다.  
Serverless환경에서는 코드와 몇 번의 클릭만으로 서비스 위한 REST API를 만들 수 있고,  
수 많은 request에 대한 auto-scaling걱정을 할 필요가 없으며,   
로그 및 다양한 모니터링툴 들을 추가적인 설치 없이 사용할 수 있습니다.  

AWS에서도 Serverless 컴퓨팅환경을 위해 다양한 서비스를 제공하고 있습니다.  
이번 글에서는 간단한 작업대기열(TaskQueue)을 만들어보며, Serverless를 환경을 경험해보도록 하겠습니다.

일단 작업대기열(TaskQueue)에 대해서 알아보도록 하겠습니다. 

작업대기열은 수행되어야 할 작업을 저장하고, 실행하는 구조 입니다.
작업들은 특정 Queue에 저장되고, 컴퓨팅 리소스가 허용되면 작업을 실행하고 Queue에서 제거됩니다.
이 과정에서 오류가 발생되면 작업은 계속 Queue에 유지되고, 성공적으로 실행될 때 까지 재시도 됩니다.

작업대기열을 사용하면 순서대로 실행이 필요한 작업, Long-run 작업, Cron작업 등을 안정적으로 수행시킬 수 있습니다.  
예를 들어 유저의 회원가입 후의 인증메일 보내기, 일정시간마다 페이지 크롤링, 대량 Push Notification발송 등과 같이
외부 request후에 서비스 내부적으로 처리해야하는 로직을 손쉽고 안정적으로 실행시킬 수 있습니다.

작업대기열을 만들기 위해선 컴퓨팅 리소스와 Queue가 필요합니다.  
AWS에서는 컴퓨팅환경을 위해 Lambda를, 서비스간의 메시지 전송을 위한 Queue로는 SQS라는 서비스를 제공합니다.
이 둘을 이용하면 추가적인 서버 구성없이 손쉽게 작업대기열을 만들 수 있습니다.

SQS와 Lambda는 아래와 같은 기능을 합니다.

# SQS
SQS는 Simple Queue Service의 약자로, 높은 확장성과 신뢰성을 가진 Queue를 제공서비스입니다.
SQS를 이용하면 Micro service간에 메시지들을 안정적으로 저장 및 전달할 수 있습니다.

SQS에서 메시지는 삭제명령으로 삭제 될 때까지 Queue안에서 유지됩니다.
그리고 동시에 여러 메시지반환 요청이 오더라도, 한메시지는 한 곳에만 전달됩니다.
이러한 기능을 통해 작업메시지들을 저장해 놓는 작업대기열의 Queue로 사용될 수 있습니다.

또한 다음과 같은 특징을 가지고 있습니다.
* 메시지는 최대 256KB의 텍스트를 포함할 수 있습니다.
* 메시지는 최대 14일 동안 대기열에 보관됩니다.
* 메시지는 최대 10개 메시지 또는 256KB 배치로 송수신되거나 삭제될 수 있습니다. 배치를 사용하면 SQS 비용을 좀 더 절약할 수 있습니다.

더 자세한 내용은 [AWS Guide](http://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/Welcome.html)를 참고하세요.

# Lambda
Lambda는 서버관리에 대한 고민(provisioning,managing)없이 소스 코드만으로
computing환경이 구축될 수 있게 도와줍니다.

아주 적은 수의 요청부터, 초당 수천개의 요청등 다양한 상황에 상관없이,
자동적으로 Lambda시스템에서 provisiong및 auto-scaling이 처리가 되며,
다양한 언어를 사용하여 코드를 작성할 수 있습니다.
(현재는 Node.js, Java, C#, Python를 지원)

API Gateway를 이용해서 Restful API를 작성할 수 도 있고, CloudWatch를 이용하여 Cron job을 실행 시킬 수도 있습니다.
더 자세한 내용은 [AWS Guide](http://docs.aws.amazon.com/ko_kr/lambda/latest/dg/welcome.html)를 참고하세요.

# 준비하기
작업대기열을 만들기 위해서 AWS console에서 SQS와 Lambda를 설정해보겠습니다.
SQS와 Lambda는 아래와 같이 사용됩니다.  
![서비스 구조](/img/content/2017-05-13/service-flow.png)
 1. Task들을 SQS에 Message로 보냅니다.
 2. Lambda(Consumer)는 SQS에서 메시지를 읽어드립니다. 
 3. 읽어 들인 메시지를 처리할 Lambda(Worker)를 실행시킵니다.

위와 같이 2개의 Lambda function로 구성되는 이유는 현재까진 SQS에서 Lamabda를 바로 실행시킬 수 없기 때문에(SQS는 메시지의 저장 및 전닮만을 담당하므로),  
CloudWatch 등을 이용하여 Queue를 확인하는 Lambda function(Consumer)을 주기적으로 수행시켜줘야 합니다. 
그렇게 실행된 Consumer는 Queue에서 메시지를 확인하고, 작업을 수행하는 Lambda function(Worker)를 실행합니다.

## SQS설정하기
- AWS console에서 SQS를 선택합니다.
![SQS생성하기-1단계](/img/content/2017-05-13/sqs-1.png)

그림과 같이 현재 사용중인 SQS항목이 표시됩니다.  
Create New Queue버튼을 눌러 새로운 Queue를 생성합니다.

- 아래와 같이 Queue를 생성해 줍니다.
![SQS생성하기-2단계](/img/content/2017-05-13/sqs-2.png)

이름과 Queue에 대한 설정을 완료하고 Queue를 생성해 줍니다.  
예제로 사용되는 Queue의 이름으로는 "MyFirstQueue"로 생성하였습니다.  
기타 항목들의 의미는 아래와 같습니다.
  - DefaultVisibleTimeout: SQS에서 메시지는 특정 component(여기서는 Consumer)에 전달된 뒤, 자동으로 삭제되지 않습니다. 그래서 다른 component에서 중복된 메시지를 전달받을 수 있는 문제가 있기 때문에, 한번 전달된 메시지는 visible timeout에 설정된 일정시간 동안은 다시 전달되지 않도록 하고 있습니다. 이러한 메시지들의 상태를 inflight라고 표현합니다. 이 항목은 메시지가 추가될 때 적용되는때 기본이 visible timeout을 나타냅니다.
  - MessageRetentionPeriod: 메시지의 생명주기 입니다. 1분부터 최대 14일까지 지정할 수 있습니다.
  - Maximum Message Size: 메시지의 최대 크기 입니다. 최대 256Kbytes까지 사용가능하며, SQS의 비용과 관련됩니다.
  - Delivery Delay: 새로운 메시지가 전달되는 초기 지연 시간입니다. 0초~900초(15분)까지 설정가능합니다.
  - Receive Message Wait Time: *ReceiveMessage*에서 Long Polling을 활성화 할 수 있습니다. 0초~20초 까지 설정가능합니다.
    - Long Polling: *ReceiveMessage*가 호출되었을 때, 메시지가 없으면 일정시간동안 Message가 도착할 때까지 기다린 후, 새로운 메시지가 도착하면 바로 메시지를 리턴합니다.. 메시지가 없을 때의  empty response에 대한 비용을 절약할 수 있습니다. SQS는 기본적으로 Short polling으로 설정됩니다.

하단의 Dead-letter queue를 설정은, 
메시지가 성공적으로 처리 되지 못한 조건을 설정하고, 성공적으로 처리되지 못한 메시지들을 따로 처리할 수 있도록 도와줍니다.
Dead-letter Queue로 사용되는 Queue는 원본 Queue와 동일한 형태(fifo or standard)이여야 하며, 동일한 region에 있어야 합니다.

그럼 Queue가 생성되었으니, 한번 테스트 메시지를 보내보도록 하겠습니다.
[Queue Actions]에서 sendMessage를 선택합니다.
아래 그림과 같이 Message body와 Message Attributes를 넣어줍니다.  
![SQS생성하기-3단계](/img/content/2017-05-13/sqs-3.png)
![SQS생성하기-4단계](/img/content/2017-05-13/sqs-4.png)  

메시지 전송 버튼을 눌러 작성한 메시지를 전송합니다.  
![SQS생성하기-5단계](/img/content/2017-05-13/sqs-5.png)

아래 그림과 같이 [Queue Actions]에서 View/Delete Messages를 선택해서 Queue의 message를 확인합니다.
![SQS생성하기-6단계](/img/content/2017-05-13/sqs-6.png)
![SQS생성하기-7단계](/img/content/2017-05-13/sqs-7.png)
 
이제 SQS는 준비가 완료되었습니다. 

## Lambda설정하기
이전 준비하기 단계에서 설명했듯이 우리는 2개의 Lambda function을 생성할 것입니다.
일단 Consumer function을 생성합니다.

![Lambda 생성-1단계](/img/content/2017-05-13/lambda-1.png)
그림과 같이 콘솔에서 [Create a Labmda function]을 눌러 새로운 Lambda function을 생성합니다.
그럼 아래와 같이 blueprint를 선택하는 화면이 나옵니다.

요구사항에 따라 제공되는 샘플설정을 사용할 수 있습니다.
런타임은 Node.js 6.10을 선택하고, Blank Function을 선택해서, 빈 상태로 시작합니다.
![Lambda 생성-2단계](/img/content/2017-05-13/lambda-2.png)

그림과 같이 trigger를 설정하는 화면이 나옵니다. 우리는 CloudWatch의 cron job을 trigger로 설정할 겁니다.  
CloudWatch를 설정할 때 Lambda Function이 필요하므로, 일단은 비워둔 상태로 Next를 눌러줍니다.
![Lambda 생성-3단계](/img/content/2017-05-13/lambda-3.png)

이제 Lambda function에 대한 이름을 입력해줍니다.  
![Lambda 생성-4단계](/img/content/2017-05-13/lambda-4.png)

그리고 SQS에서 메시지를 읽어들이는 코드를 작성해줍니다.  
*QueueUrl*은 이전에 생성한 SQS의 url을 넣어줍니다. AWS의 Console에서 확인할 수 있습니다.
```
const AWS = require("aws-sdk");
const sqs = new AWS.SQS();
const lambda = new AWS.Lambda();

exports.handler = (event, context, callback) => {
  const params = {
    QueueUrl: 'https://sqs.ap-northeast-2.amazonaws.com/XXXXXX/MyFirstQueue',
    MaxNumberOfMessages: 10,
    MessageAttributeNames: ['All']
  };
  sqs.receiveMessage(params).promise()
    .then((data) => {
      if (data.Messages && data.Messages.length > 0) {
        // Invoke Lambda here..
      }
    })
    .then(() => {
      callback();
    })
    .catch((err) => {
      callback(err);
    });
};
```

SQS의 receiveMessage는 queue에 포함된 message를 1~10개까지 반환합니다.  
반환되는 메시지는 아래와 같은 내용을 포함합니다.
 - Message body.
 - Message body의 MD5 digest
 - 메시지 전송시 사용된 MessageId
 - receipt handle. message삭제시 identifier로 사용됩니다.
 - Message attributes.
 - Message attributes의 MD5 digest
 
Parameter등과 같이 더 자세한 내용은 [개발 문서](http://docs.aws.amazon.com/AWSJavaScriptSDK/latest/AWS/SQS.html#receiveMessage-property)를 참고 하시기 바랍니다.

위의 코드를 동작시키기 위해서는 Labmda function에 Permission을 추가해줘야 합니다.  
아래와 같은 Policy를 가지는 Role을 생성한 뒤, [Choose an existing role]을 선택하여 생성한 Role을 선택해 줍니다.   
아래 Role은 SQS에서 message를 전달받고 삭제할 수 있으며 Lambda를 실행시킬 수 있고,   
CloudWatch에 로그를 생성할 수 있습니다.
```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "Stmt1490663845000",
            "Effect": "Allow",
            "Action": [
                "sqs:ReceiveMessage",
                "sqs:DeleteMessage"
            ],
            "Resource": [
                "*"
            ]
        },
        {
            "Sid": "Stmt1490663945000",
            "Effect": "Allow",
            "Action": [
                "lambda:InvokeFunction"
            ],
            "Resource": [
                "*"
            ]
        },
        {
            "Sid": "Stmt1490663993000",
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": [
                "arn:aws:logs:*:*:*"
            ]
        }
    ]
}
```
이제 설정을 마치고, [Create Function]을 눌러 Lambda를 생성해 줍니다.

그리고 [Test]버튼을 눌러 Lambda function을 테스트해봅니다.  
아래 화면과 같이 [Scheduled Event]를 선택한 후 [Save and test]로 테스트를 진행합니다.
![Lambda 생성-5단계](/img/content/2017-05-13/lambda-5.png)

![Lambda 생성-6단계](/img/content/2017-05-13/lambda-6.png)

상단의 [Monitorig]탭에서도 [View logs in CloudWatch]링크를 통해 로그를 확인할 수 있습니다.

이제 작업을 실행할 Worker function을 
Consumer function과 동일한 설정으로 [TaskWorker]로 생성합니다.
Worker function은 Consumer function이 읽어들인 메시지를 전달받아 처리하고,   
처리가 완료되면 SQS로 부터 해당메시지를 삭제하는 역할을 합니다.   
코드는 아래와 같습니다.
```
const AWS = require("aws-sdk");
const sqs = new AWS.SQS();
const lambda = new AWS.Lambda();

exports.handler = (event, context, callback) => {
  const queueUrl = event.QueueUrl;
  const message = event.Message;
  const params = {
    QueueUrl: queueUrl,
    ReceiptHandle: message.ReceiptHandle
  };
  sqs.deleteMessage(params).promise()
    .then(() => {
      callback();
    })
    .catch((err) => {
      callback(err);
    });
};
```
Lambda function의 생성을 완료하면, Conusmer function에서 Worker function을 실행시키도록 코드를 수정합니다.   
아래 코드를 사용해서 전달받은 메시지를 Worker function으로 전달합니다.
```
const AWS = require("aws-sdk");
const sqs = new AWS.SQS();
const lambda = new AWS.Lambda();

exports.handler = (event, context, callback) => {
  const params = {
    QueueUrl: 'https://sqs.ap-northeast-2.amazonaws.com/XXXXXX/MyFirstQueue',
    MaxNumberOfMessages: 10,
    MessageAttributeNames: ['All']
  };
  sqs.receiveMessage(params).promise()
    .then((data) => {
      if (data.Messages && data.Messages.length > 0) {
        // Invoke Lambda here
        const jobs = data.Messages.map((message) => {
          const payload = {
            QueueUrl: params.QueueUrl,
            Message: message
          }
          const lambdaInvokeParams = {
            FunctionName: 'TaskWorker',
            InvocationType: 'Event',
            Payload: JSON.stringify(payload)
          };
          return lambda.invoke(lambdaInvokeParams).promise();
        });
        return Promise.all(jobs);
      }
    })
    .then(() => {
      callback();
    })
    .catch((err) => {
      callback(err);
    });
};
```
Lambda의 invoke함수에는 실행시킬 function의 이름 혹은 ARN과 InvocationType등을 전달합니다.
InvocationType은 기본값인 'RequestResponse', 비동기 실행을 위한 'Event', test를 위한 'DryRun'값을 설정할 수 있습니다.
또한 작업에 필요한 data를 Payload를 통해 전달할 수 있습니다.

더 자세한 내용은 [개발 문서](http://docs.aws.amazon.com/AWSJavaScriptSDK/latest/AWS/Lambda.html#invoke-property)를 참고하시기 바랍니다.

이제 Consumer function을 실행시켜보면,  Worker function이 실행된것을 로그로 확인할 수 있으며,   
MyFirstQueue의 메시지가 처리되어 삭제된것을 확인할 수 있습니다.

이렇게 해서 SQS와 Lambda를 이용한 작업대기열의 구성이 완료가 되었습니다.  
이제 SQS에 원하는 작업을 AWS SDK등을 통해서 Message로 전달하고 Worker function에서 원하는 작업을 추가해주면,   
원하는 작업을 수행하는 TaskQueue를 사용할 수 있습니다.

-------

이번 글에서는 전체 웹서비스에서 일부분이라고 할 수 있는 TaskQueue를 SQS와 Labmda로 작성해보며, 
AWS에서 제공하는 Serverless에 대해서 알아보았습니다.  
위에서 경험해 보았듯이 Serveless 환경이 언어,설정 등의 자유도는 떨어지지만, 서버 운영에 대한 노력을 많이 줄일 수 있는 장점이 있습니다.  
각자의 선호도나 요구사항에 맞춰서 사용하면 좋지 않을까 생각합니다만, 저는 Serveless환경을 더 선호합니다. ^^v

다음 글에서는 API Gateway 및 Lambda, DynamoDB를 이용해서 REST API를 만들어보며, Serveless에 대해 더 Deep하게 사용해보도록 하겠습니다. 
그리고 이런 환경을 더 쉽고 편리하게 도와주는 [외부 툴](https://serverless.com/)에 대해서도 함께 알아보도록 하겠습니다.