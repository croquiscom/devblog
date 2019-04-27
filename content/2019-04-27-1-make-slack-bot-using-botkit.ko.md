---
title: BotKit을 이용한 슬랙 봇 만들기
tags: ['Slack','Botkit']
date: 2019-04-27
author: Sangmin Yoon
original: http://sixmen.com/ko/tech/2019-04-27-1-make-slack-bot-using-botkit/
---

크로키닷컴을 시작하고 비교적 초기부터 ChatOps를 해보고 싶었습니다.
GitHub의 글을 보고 도입하고 싶다는 생각이 들었던 거로 기억합니다.
당연하게 [Hubot](https://hubot.github.com/)을 이용해 채팅봇을 설정했습니다.

초기에는 HipChat에 Hubot을 붙였고, 2014년 중반 Slack으로 전환했습니다.
봇을 활용하려는 시도는 여러 번 했지만 대부분 장난 수준을 벗어나지 못했고(예. 점심 메뉴 보여주고 임의로 고르기),
그나마 조금 복잡했던 것이 Box, Dropbox, Evernote에서 변경된 내용을 인식해 특정 채널에 알려주는 기능이었습니다.

그렇게 방치하다가 2019년에 들어와 개발팀 인원도 늘어나서 다시 한번 제대로 채팅봇을 만들자는 얘기가 나왔습니다.
이전에 작업해서 익숙한 Hubot을 다시 사용할까 했는데 아무래도 소스 기반이 CoffeeScript인게 마음에 걸렸습니다.
여러 가지를 찾아보다가 [Botkit](https://botkit.ai/)을 사용하기로 결정했습니다.

이번 글에서는 Botkit을 이용해 슬랙 봇을 만드는 방법을 설명합니다.

<!--more-->

# 슬랙 앱 생성

Hubot은 [슬랙 앱](https://slack.com/apps/A0F7XDU93-hubot)이 있어서 설정이 편했는데,
Botkit은 슬랙 앱을 만들어야 합니다.

Botkit은 AI 봇을 만들어 여러 업체에 제공하기 위한 솔루션인 듯 여러 팀을 다룰 수 있도록 구성되어 있고,
[Botkit 슬랙 앱 설정 문서](https://botkit.ai/docs/provisioning/slack-events-api.html)도
내용이 많습니다. 하지만 내부적으로 사용하는 용도로는 그렇게까지 필요하지 않습니다.

우선 [Your Apps](https://api.slack.com/apps)에 가서 새 앱 생성을 합니다.

![Create a Slack App](/img/content/2019-04-27-1/2019-04-27-1-01.png)

그리고 Bot Users 메뉴에서 Bot User를 추가합니다.

![Add Bot User](/img/content/2019-04-27-1/2019-04-27-1-02.png)

마지막으로 Install App에서 'Install App to Workspace'를 누르고 Authorize를 선택하면 Bot User Access Token을 얻을 수 있습니다.

![Installed App Settings](/img/content/2019-04-27-1/2019-04-27-1-03.png)

# Bot 만들기

[Botkit Starter Kit for Slack Bots](https://github.com/howdyai/botkit-starter-slack)가 있지만,
이 역시 저희 용도에는 너무 복잡해서 처음부터 만들기로 했습니다.

필요한 패키지는 [botkit](https://www.npmjs.com/package/botkit), [dotenv](https://www.npmjs.com/package/dotenv) 뿐입니다.
그리고 TypeScript로 만들기 위해 typescript와 ts-node를 추가합니다.

**_package.json_**
{{< highlight json >}}
{
  "name": "bot",
  "scripts": {
    "start": "ts-node app.ts"
  },
  "dependencies": {
    "botkit": "^0.7.4",
    "dotenv": "^7.0.0",
    "ts-node": "^8.0.3",
    "typescript": "^3.4.3"
  },
  "devDependencies": {
    "@types/dotenv": "^6.1.1"
  }
}
{{< /highlight >}}

Access Token은 소스 관리가 되지 않는 .env 파일에 기록합니다.

**_.env_**
{{< highlight bash >}}
SLACK_BOT_TOKEN=xoxb-276777......
{{< /highlight >}}

TypeScript 컴파일 설정도 만들어줍니다.

**_tsconfig.json_**
{{< highlight json >}}
{
  "compilerOptions": {
    "noImplicitAny": true,
    "noImplicitThis": true,
    "strictNullChecks": true,
    "target": "es2017",
    "module": "CommonJS",
    "moduleResolution": "node",
    "esModuleInterop": true,
    "lib": [
      "es2017",
      "dom",
      "esnext.asynciterable"
    ]
  }
}
{{< /highlight >}}

마지막으로 다음과 같이 봇 코드를 작성합니다.

**_app.ts_**
{{< highlight typescript >}}
import Botkit from 'botkit';
import dotenv from 'dotenv';

dotenv.config();

const controller = Botkit.slackbot({
});

controller.startTicking();

const bot = controller.spawn({ token: process.env.SLACK_BOT_TOKEN || '' });

bot.startRTM((error) => {
  if (error) {
    console.log('구동에 실패했습니다.');
  } else {
    bot.say({ text: '봇이 배포되었습니다! 😄', channel: 'Cxxxxx' });
  }
});
{{< /highlight >}}

`npm start`를 하면 봇이 구동되고 지정한 채널에 메시지가 표시됩니다.

# 봇 스킬 추가

봇 동작을 기술할 스크립트는 Botkit Starter Kit에 맞춰 스킬이라고 부르기로 했습니다.

스킬 추가는 파일을 추가하기만 하면 되는 구조로 작성했습니다.

**_skill/index.ts_**
{{< highlight typescript >}}
import { SlackController } from 'botkit';
import fs from 'fs';

export const loadSkills = (controller: SlackController) => {
  fs.readdirSync(__dirname).forEach((filename) => {
    if (filename !== 'index.ts' && !filename.includes('.disabled.')) {
      require('./' + filename).default(controller);
    }
  });
};
{{< /highlight >}}

**_app.ts_**
{{< highlight typescript >}}
...

import { loadSkills } from './skill';

...

loadSkills(controller);
{{< /highlight >}}

다음은 Botkit Starter Kit for Slack Bots에서 가져온 스킬 샘플입니다.
봇에게 color나 question이라는 단어를 포함해 1:1 메시지(direct_message)를 보내거나 언급하면 동작합니다.

**_skill/sample-conversation.ts_**
{{< highlight typescript >}}
// copied from https://github.com/howdyai/botkit-starter-slack/blob/master/skills/sample_conversations.js
import { SlackController } from 'botkit';

export default (controller: SlackController) => {
  controller.hears(['color'], ['direct_message', 'direct_mention'], (bot, message) => {
    bot.startConversation(message, (error, convo) => {
      convo.say('This is an example of using convo.ask with a single callback.');
      convo.ask('What is your favorite color?', (response) => {
        convo.say('Cool, I like ' + response.text + ' too!');
        convo.next();
      });
    });
  });

  controller.hears(['question'], ['direct_message', 'direct_mention'], (bot, message) => {
    bot.createConversation(message, (error, convo) => {
      convo.addMessage({ text: 'How wonderful.' }, 'yes_thread');
      convo.addMessage({ text: 'Cheese! It is not for everyone.', action: 'stop' }, 'no_thread');
      convo.addMessage({ text: 'Sorry I did not understand. Say `yes` or `no`', action: 'default' }, 'bad_response');

      convo.ask('Do you like cheese?', [{
        pattern: bot.utterances.yes,
        callback: (response) => {
          convo.gotoThread('yes_thread');
        },
      }, {
        pattern: bot.utterances.no,
        callback: (response) => {
          convo.gotoThread('no_thread');
        },
      }, {
        default: true,
        callback: (response) => {
          convo.gotoThread('bad_response');
        },
      }]);

      convo.activate();

      convo.on('end', () => {
        if (convo.successful()) {
          bot.reply(message, 'Let us eat some!');
        }
      });
    });
  });
};
{{< /highlight >}}

# 마무리

원래 봇을 통해 의도했던 ChatOps는 아직 시작하지 못했지만, 회사 행정에 도움 되는 기능부터 하나씩 스킬을 늘려가고 있습니다.
다음번에는 [인터랙티브 메시지](https://api.slack.com/messaging/interactivity)를 만드는 방법을 소개하도록 하겠습니다.
