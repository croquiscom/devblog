---
title: 크로키의 스택 - AWS Batch
tags: ['Croquis','Stack','AWS','AWS Batch']
date: 2020-02-11
author: Sangmin Yoon
original: http://sixmen.com/ko/tech/2020-02-11-1-croquis-stack-aws-batch/
---

서비스를 운영하다보면 주기적으로 실행이 필요한 작업들이 생깁니다.
이런 작업들을 실행하는 방법은 여러가지가 있을 수 있습니다.
다음은 크로키에서 현재 선택해서 전환 중인 AWS Batch에 대해 설명합니다.

<!--more-->

지그재그 서비스 초기에는 서버가 EC2 인스턴스 위에서 동작하고 있었습니다.
이때는 반복 작업은 작업 전용 EC2 인스턴스에서 실행하도록 구성했습니다.
그리고 그 일정은 리눅스 cron을 통해 관리했습니다.

이후 AWS Lambda로 서비스 서버를 옮기기로 하면서 새로운 방법이 필요해졌습니다.
그래서 CloudWatch Events에 람다에 연결해서 반복 작업을 실행했습니다.
다만 EC2와 달리 실행 시간에 제한이 있고, 동시 실행을 방지할 방법이 없었습니다.

현재는 서비스 서버를 ECS Fargate로 이전한 상황입니다.
여기에 맞는 반복 작업 실행 방법을 찾아야 하는데 처음에는 Scheduled Tasks를 고려했지만,
여러가지 이유로 진도가 나가지 않고 있었습니다.

더 이상 기존 시스템을 계속 둘 수는 없기에 빠르게 전환할 수 있는 방법으로 AWS Batch를 선택하게 됐습니다.
나중에는 [Apache Airflow](https://airflow.apache.org/)나 [Kubernetes CronJob](https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/) 같은 더 기능이 풍부한 해결책이 필요해질 수도 있지만, 현재 상황에서는 충분히 만족스러운 해결책이였습니다.

다음은 저희 상황에서 AWS Batch를 적용했을 때의 장단점입니다.

1. 이미 실행할 프로그램이 Docker 이미지로 만들어져서 ECR에 올라가 있습니다. 명령(CMD)만 바꿔주면 서비스 프로세스 대신 작업이 수행됩니다.
2. 실행 결과를 보기가 편했습니다. 기존 방식은 로그를 한번에 보기가 어려웠는데 AWS Batch를 적용하면 작업만 모아서 볼 수 있어서 좋았습니다.
3. 작업 실패시 알림을 받기도 편했습니다.
4. ECS 처럼 CPU 단위를 1/4 vCPU 단위로 지정할 수 있으면 좋은데 1 vCPU 단위라서 리소스가 실제 필요보다 많이 쓰는 단점이 있습니다.

# AWS Batch 환경 구축

저희는 현재 CloudFormation으로 인프라를 구성하고 있습니다. (CDK도 고려중입니다.)

다음은 AWS Batch 인프라와 그 설명입니다.

{{< highlight yaml >}}
Resources:
  # 우선 AWS Batch가 동작할 환경(EC2)을 정의합니다.
  # 주어진 VPC의 Subnet 위에 상황에 맞는 적절한 인스턴스가 생성됩니다.
  # 관리형을 선택해 자동으로 인스턴스가 늘어나고 줄어듭니다.
  # 작업이 중단되는 것을 원하지 않아 스팟 인스턴스는 적용하지 않았습니다.
  BatchComputeEnvironment:
    Type: AWS::Batch::ComputeEnvironment
    Properties:
      ComputeResources:
        InstanceRole: ecsInstanceRole
        InstanceTypes:
          - optimal
        MaxvCpus: 16
        MinvCpus: 2
        SecurityGroupIds:
          - !ImportValue VpcSecurityGroupId
        Subnets:
          - !ImportValue SubnetId1
          - !ImportValue SubnetId2
        Type: EC2
      ServiceRole: !Sub arn:aws:iam::${AWS::AccountId}:role/AWSBatchServiceRole
      Type: MANAGED

  # 다음은 작업 대기열을 설정합니다.
  # 세부적으로 나눌 필요성을 못 느껴 대부분의 작업은 default 대기열에서 실행됩니다.
  BatchQueueDefault:
    Type: AWS::Batch::JobQueue
    Properties:
      ComputeEnvironmentOrder:
        - ComputeEnvironment: !Ref BatchComputeEnvironment
          Order: 1
      JobQueueName: default
      Priority: 5
      State: ENABLED

  # 10분 이하 간격으로 실행되는 작업이 있는데
  # default 대기열에 넣으면 화면에 작업 목록이 너무 길어져서 분리했습니다.
  # 우선순위도 조금 낮게 설정했습니다.
  BatchQueueContinuously:
    Type: AWS::Batch::JobQueue
    Properties:
      ComputeEnvironmentOrder:
        - ComputeEnvironment: !Ref BatchComputeEnvironment
          Order: 1
      JobQueueName: continuously
      Priority: 3
      State: ENABLED

  # 작업을 실행할 수 있는 역할을 미리 생성해서 각 작업 정의시 사용할 수 있도록 했습니다.
  EventsBatchSubmitJobRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Version: 2012-10-17
        Statement:
          - Effect: Allow
            Principal:
              Service:
                - events.amazonaws.com
            Action:
              - sts:AssumeRole
      Policies:
        - PolicyName: default
          PolicyDocument:
            Version: 2012-10-17
            Statement:
              - Effect: Allow
                Action:
                  - batch:SubmitJob
                Resource:
                  - '*'

  # 작업 실패시 실행할 람다 함수의 역할입니다.
  # 슬랙으로 메시지를 전송하는 SendToSlack이라는 함수를 호출할 수 있도록 권한을 부여했습니다.
  JobFailedAlertLambdaRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Version: 2012-10-17
        Statement:
          - Effect: Allow
            Principal:
              Service:
                - lambda.amazonaws.com
            Action:
              - sts:AssumeRole
      Policies:
        - PolicyName: default
          PolicyDocument:
            Version: 2012-10-17
            Statement:
              - Effect: Allow
                Action:
                  - logs:CreateLogGroup
                  - logs:CreateLogStream
                  - logs:PutLogEvents
                Resource:
                  - !Sub arn:aws:logs:ap-northeast-2:${AWS::AccountId}:*
        - PolicyName: send-to-slack
          PolicyDocument:
            Version: 2012-10-17
            Statement:
              - Effect: Allow
                Action:
                  - lambda:InvokeFunction
                Resource:
                  - !Sub arn:aws:lambda:ap-northeast-2:${AWS::AccountId}:function:SendToSlack

  # 작업 실패시 실행되는 람다 함수입니다.
  # 실패 메시지를 분석해 적절한 에러 메시지를 슬랙으로 보내줍니다.
  JobFailedAlertLambda:
    Type: AWS::Lambda::Function
    Properties:
      Code:
        ZipFile: |
          const AWS = require('aws-sdk');
          const slackChannel = '#cron-error';

          const lambda = new AWS.Lambda({ region: 'ap-northeast-2' });

          async function processEvent(event) {
            console.log(JSON.stringify(event));
            const slackMessage = {
              channel: slackChannel,
              username: 'AWS Batch Job Failed Alert',
              icon_emoji: ':cloud:',
            };

            let color = 'danger';
            slackMessage.attachments = [{
              color: color,
              text: `${event.detail.jobName} failed by ${event.detail.statusReason}`,
            }];
            await lambda.invoke({
              FunctionName: 'SendToSlack',
              Payload: JSON.stringify(slackMessage),
            }).promise();
          }

          exports.handler = async (event, context, callback) => {
            try {
              const response = await processEvent(event);
              callback(null, response);
            } catch (error) {
              callback(error);
            }
          };
      Handler: index.handler
      Role: !GetAtt JobFailedAlertLambdaRole.Arn
      Runtime: nodejs10.x

  # AWS Batch에서 작업 실패를 감지하면 람다 함수를 호출하도록 구성합니다.
  JobFailedEvent:
    Type: AWS::Events::Rule
    Properties:
      EventPattern:
        detail-type:
          - Batch Job State Change
        source:
          - aws.batch
        detail:
          status:
            - FAILED
      Targets:
        - Arn: !GetAtt JobFailedAlertLambda.Arn
          Id: lambda

  # 작업 실패 이벤트가 람다 함수를 실행할 수 있도록 권한을 부여합니다.
  JobFailedEventPermission:
    Type: AWS::Lambda::Permission
    Properties:
      Action: lambda:InvokeFunction
      FunctionName: !GetAtt JobFailedAlertLambda.Arn
      Principal: events.amazonaws.com
      SourceArn: !GetAtt JobFailedEvent.Arn

# 위에서 정의한 AWS Batch 리소스를 다른 CloudFormation에서 사용할 수 있도록 내보냅니다.
Outputs:
  BatchQueueArnDefault:
    Value: !Ref BatchQueueDefault
    Export:
      Name: BatchQueueArnDefault

  BatchQueueArnContinuously:
    Value: !Ref BatchQueueContinuously
    Export:
      Name: BatchQueueArnContinuously

  EventsBatchSubmitJobRoleArn:
    Value: !GetAtt EventsBatchSubmitJobRole.Arn
    Export:
      Name: EventsBatchSubmitJobRoleArn
{{< /highlight >}}

# AWS Batch 작업 정의

다음은 위 환경 위에서 실제 동작할 작업들에 대한 정의입니다.

{{< highlight yaml >}}
Resources:
  # 서비스 코드가 올라간 저장소입니다.
  # 서비스 구동용 ECS 작업(task) 정의에서도 같이 사용합니다.
  Repository:
    Type: AWS::ECR::Repository
    Properties:
      RepositoryName: my-service

  # 작업을 위한 역할을 정의합니다.
  Role:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Version: 2012-10-17
        Statement:
          - Effect: Allow
            Principal:
              Service:
                - ecs-tasks.amazonaws.com
            Action:
              - sts:AssumeRole

  # 첫번째 작업을 정의합니다.
  # 20분 정도 실행되는 작업으로 넉넉하게 30분의 시간 제한을 뒀습니다.
  # 재시도는 하지 않습니다.
  DoSomethingJobDefinition:
    Type: AWS::Batch::JobDefinition
    Properties:
      ContainerProperties:
        Command: ['node', 'app/jobs/do-something']
        Image: !Sub ${AWS::AccountId}.dkr.ecr.ap-northeast-2.amazonaws.com/my-service:latest
        JobRoleArn: !Ref Role
        Memory: 1024
        Vcpus: 1
      RetryStrategy:
        Attempts: 1
      Timeout:
        AttemptDurationSeconds: 1800
      Type: container

  # 매일 아침 9시 0분(UTC 기준 새벽 0시 0분) 작업 실행 하도록 CloudWatch Events를 생성합니다.
  DoSomethingEvent:
    Type: AWS::Events::Rule
    Properties:
      ScheduleExpression: cron(0 0 * * ? *)
      Targets:
        - Arn: !ImportValue BatchQueueArnDefault
          Id: task
          BatchParameters:
            JobDefinition: !Ref DoSomethingJobDefinition
            JobName: my-service-do-something
          RoleArn: !ImportValue EventsBatchSubmitJobRoleArn

  # 자주 실행하는 작업을 정의합니다.
  DoOftenJobDefinition:
    Type: AWS::Batch::JobDefinition
    Properties:
      ContainerProperties:
        Command: ['node', 'app/jobs/do-often']
        Image: !Sub ${AWS::AccountId}.dkr.ecr.ap-northeast-2.amazonaws.com/my-service:latest
        JobRoleArn: !Ref Role
        Memory: 1024
        Vcpus: 1
      RetryStrategy:
        Attempts: 1
      Timeout:
        AttemptDurationSeconds: 60
      Type: container

  # 10분마다 작업을 실행하도록 구성합니다.
  DoOftenEvent:
    Type: AWS::Events::Rule
    Properties:
      ScheduleExpression: cron(7/10 * * * ? *)
      Targets:
        - Arn: !ImportValue BatchQueueArnContinuously
          Id: task
          BatchParameters:
            JobDefinition: !Ref DoOftenJobDefinition
            JobName: my-service-do-often
          RoleArn: !ImportValue EventsBatchSubmitJobRoleArn
{{< /highlight >}}

# 기타

짧게 실행되는 작업에 대해서 중복 실행을 막고 싶은 요구사항이 있습니다. 이는 다음과 같이 현재 구동중인 작업을 검사하는 방식으로 해결했습니다.
(batch:ListJobs 권한이 필요합니다.)

{{< highlight typescript >}}
import AWS from 'aws-sdk';
import { JobStatus } from 'aws-sdk/clients/batch';

const job_name = 'do-something';

const batch = new AWS.Batch({ region: 'ap-northeast-2' });

async function checkAlreadyRunStatus(status: JobStatus) {
  const result = await batch.listJobs({
    jobQueue: process.env.AWS_BATCH_JQ_NAME,
    jobStatus: status,
  }).promise();
  const found = result.jobSummaryList.findIndex((item) => item.jobName === job_name && item.jobId !== process.env.AWS_BATCH_JOB_ID);
  if (found >= 0) {
    throw new Error(`already run ${result.jobSummaryList[found].jobId} / ${status}`);
  }
}

async function checkAlreadyRun() {
  await checkAlreadyRunStatus('SUBMITTED');
  await checkAlreadyRunStatus('PENDING');
  await checkAlreadyRunStatus('RUNNABLE');
  await checkAlreadyRunStatus('STARTING');
  await checkAlreadyRunStatus('RUNNING');
}

async function run() {
  try {
    await checkAlreadyRun();
  } catch (error) {
    process.exit(0); // 0으로 종료해야 실패로 처리되지 않습니다.
  }

  // 실제 수행할 코드
}

run();
{{< /highlight >}}

작업에 따라서는 여러 단계로 나뉘어 순차적으로 실행되야 할 수 있습니다.
작업 정의로는 그런 세세한 제어는 어렵지만, 이전 작업 마지막에서 submitJob을 수동으로 호출해주면 될 것으로 생각하고 있습니다.

AWS Batch는 노드를 여러개 띄워서 동시에 실행하는 기능도 제공하지만 저희는 아직 사용하지 않고 있습니다.

# 결론

AWS Batch는 기능이 많은 편은 아니지만, 간단하게 쓰기에는 충분했습니다.
물론 나중에 서비스 규모가 더 커지면 다른 도구를 도입할 가능성은 계속 열려있습니다.
