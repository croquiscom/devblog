---
title: '내가 만든 non-null 변수에서 NullPointerException이 발생할 리가 없어!'
tags: []
date: 2023-11-02T01:00:00
author: Sans(한강학)
---

안녕하세요, 카카오스타일 전시 UX팀의 샌즈입니다.

모두들 알고 계시듯 null(널)은 값이 없음을 나타냅니다. 그리고 null 값인 객체에 접근하려고 하면 그 유명한 NullPointerException(NPE)이 발생합니다. 그런데 null 값을 가지지 않는 다고 설정한 변수에서 NPE가 발생하는 현상을 겪어 그 내용을 공유해보려고 합니다.

<!--more-->

다음은  Kotlin에서 non-null 변수를 선언한 예입니다.

```kotlin
data class BoxContainer(
    val boxList: List<Box>
)

data class Box(
    val type: String, val text: String, val value: Int
)

data class NullableBoxContainer(
    val boxList: List<Box?>?
)

data class NullableBox(
    val type: String?, val text: String?, val value: Int?
)
```

`String?` 타입인 경우 null 값을 가질 수 있고, `String`으로 선언하면 null이 들어가면 안 된다는 뜻입니다. 카카오스타일에서 Kotlin 외에 사용 중인 TypeScript와 GraphQL에서도 비슷하게 설정가능합니다.

```graphql
type TitleSection {
  title: String! ### 반드시 값이 존재
  sub_title: String ### 값이 없을 수 있음
}
```

## **non-null 변수에 null이 들어가는 현상**

지그재그 특가 진입시 ad_noti_status라는 필드가 ‘disagree’이면 알림 유도 UI를 제공하도록 되어 있었습니다. 이 필드 값을 반환하는 코드는 다음과 같습니다.

```kotlin
private fun getUserAdNotification(session: Session): UserNotiStatus {
    val response = userNotificationService.getUserAdNotification(session)
    return when (response.user.ad_noti_status) {
        "AGREE" -> UserNotiStatus.AGREE
        else -> UserNotiStatus.DISAGREE
    }
}

data class UserAdNotification(
    val user: UserAdNotificationUser
)

data class UserAdNotificationUser(
    val ad_noti_status: String
)
```

일부 사용자가 알림 동의를 받지 않았음에도 UI가 노출되지 않아 분석을 해보니 위 코드에서 NPE가 발생하고 있었습니다.

문제 재현을 위해 다음과 같이 코드를 작성해봤습니다.

```kotlin
import com.google.gson.Gson
data class UserAdNotification(
    val user: UserAdNotificationUser
)
data class UserAdNotificationUser(
    val ad_noti_status: String
)
fun main() {
    val str = """{"user":{}}"""
    val parsed = Gson().fromJson(str, UserAdNotification::class.java)
    println(parsed)
    println(when(parsed.user.ad_noti_status) {
        "AGREE" -> "AGREE"
        else -> "DISAGREE"
    })
}
```

실행하면 다음과 같은 결과를 보여줍니다.

```
UserAdNotification(user=UserAdNotificationUser(ad_noti_status=null))
Exception in thread "main" java.lang.NullPointerException: Cannot invoke "String.hashCode()" because "<local2>" is null
	at MainKt.main(Main.kt:12)
	at MainKt.main(Main.kt)
```

이런 에러가 나는데는 몇가지 조건이 겹쳤습니다.

## Kotlin 버전

잠깐! NPE는 null인 객체를 접근해야 에러가 나는 건데, user는 null이 아닌데? 맞습니다. 실제 환경에서도 user가 null이면 로그를 찍게 해봤는데 로그에 찍히는게 없었습니다.

해당 서비스는 오래전에 만들어졌는데, 그 뒤로 Kotlin 버전 업그레이드를 하지 않은채 1.4.20을 사용하고 있었습니다. Kotlin을 1.5로 업그레이드 했더니 문제가 발생하지 않았습니다. (user가 null이면 당연히 NPE가 발생합니다.) when을 if로 바꿔도 문제가 발생하지 않았기 때문에 오래전 Kotlin 버전에서 when 동작에 특이한 부분이 있다고 짐작할 수 있습니다.

다음은 비슷한 상황에 enum을 추가 적용해본 것입니다.

```kotlin
import com.google.gson.Gson
data class UserAdNotification(
    val user: UserAdNotificationUser
)
data class UserAdNotificationUser(
    val ad_noti_status: Status
)
enum class Status {
    AGREE,
    DISAGREE
}
fun main() {
    val str = """{"user":{}}"""
    val parsed = Gson().fromJson(str, UserAdNotification::class.java)
    println(parsed)
    println(if(parsed.user.ad_noti_status == Status.AGREE) "AGREE" else "DISAGREE")
    println(when(parsed.user.ad_noti_status) {
        Status.AGREE -> "AGREE"
        else -> "DISAGREE"
    })
}
```

Kotlin 최신 버전(2.0.0)에서 실행해본 결과입니다.

```
UserAdNotification(user=UserAdNotificationUser(ad_noti_status=null))
DISAGREE
Exception in thread "main" java.lang.NullPointerException: Cannot invoke "Status.ordinal()" because the return value of "UserAdNotificationUser.getAd_noti_status()" is null
	at MainKt.main(Main.kt:17)
	at MainKt.main(Main.kt)
```

when를 if의 문법적 설탕 정도로 생각했는데 동작이 조금 다른 것을 확인할 수 있습니다.

## JSON 라이브러리

Kotlin 언어에는 null과 non-null 구분이 있지만, 그 기반이 되는 JVM에서는 그런 구분이 없습니다. 그렇다보니 언어의 제약과 상관없이 내부 값이 null을 가질 가능성이 존재합니다. (TypeScript도 마찬가지기 때문에 JSON 파싱 후 값의 타입을 검증해주면 좋습니다.)

위 문제를 사내에 공유했을 때 비슷한 문제가 있어서 Gson 대신 Jackson을 사용했다는 답글이 있었습니다.

테스트 코드를 Jackson으로 재작성했을 때 파싱 과정에 에러가 나는 것을 확인했습니다.

```kotlin
import com.fasterxml.jackson.databind.ObjectMapper
import com.fasterxml.jackson.module.kotlin.kotlinModule
data class UserAdNotification(
    val user: UserAdNotificationUser
)
data class UserAdNotificationUser(
    val ad_noti_status: String
)
fun main() {
    val str = """{"user":{}}"""
    val parsed = ObjectMapper().registerModule(kotlinModule()).readValue(str, UserAdNotification::class.java)
    println(parsed)
    println(when(parsed.user.ad_noti_status) {
        "AGREE" -> "AGREE"
        else -> "DISAGREE"
    })
}

// Exception in thread "main" com.fasterxml.jackson.module.kotlin.MissingKotlinParameterException: Instantiation of [simple type, class UserAdNotificationUser] value failed for JSON property ad_noti_status due to missing (therefore NULL) value for creator parameter ad_noti_status which is a non-nullable type
//  at [Source: REDACTED (`StreamReadFeature.INCLUDE_SOURCE_IN_LOCATION` disabled); line: 1, column: 10] (through reference chain: UserAdNotification["user"]->UserAdNotificationUser["ad_noti_status"])
```

Kotlinx도 마찬가지로 파싱시 에러를 발생합니다.

```kotlin
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
@Serializable
data class UserAdNotification(
    val user: UserAdNotificationUser
)
@Serializable
data class UserAdNotificationUser(
    val ad_noti_status: String
)
fun main() {
    val str = """{"user":{}}"""
    val parsed = Json.decodeFromString<UserAdNotification>(str)
    println(parsed)
    println(when(parsed.user.ad_noti_status) {
        "AGREE" -> "AGREE"
        else -> "DISAGREE"
    })
}

// Exception in thread "main" kotlinx.serialization.MissingFieldException: Field 'ad_noti_status' is required for type with serial name 'UserAdNotificationUser', but it was missing at path: $.user
```

Kotlinx는 동작이 다른 부분이 하나 더 있습니다. ad_noti_status가 nullable, 즉 String?으로 선언되었을 때, Gson, Jackson은 문제가 없었지만, Kotlinx는 에러를 반환했습니다. Kotlinx는 JSON 문자열이 `{"user":{"ad_noti_status":null}}` 일 때만 정상적으로 파싱을 했습니다.

## 타입 정의

또 다른 문제는 원래 null이 가능한 타입인데 non-null로 설정했다는 것입니다.

카카오스타일에서는 GraphQL을 사용하고 있기 때문에 다른 서비스에 요청한 값은 스키마에 따라 반환된다는 것이 보장됩니다. 그런데 스키마에서는 nullable인 필드였는데, Kotlin 클래스에서는 non-null로 설정되어 있었습니다. 이 부분은 아마 오래전 GraphQL 사용에 익숙하지 않았을 때 실수한 것으로 보입니다.

이 코드외에 근래 작성한 많은 GraphQL 처리 코드는 스키마에서 자동 생성된 클래스 정의를 사용하고 있어서 이런 문제가 없습니다.

## 마치며

이런 상황을 겪을 때마다 느끼지만 어떤 이슈나 제가 현재 인지하고 있는 범주 내에서 발생할 수 없는 일이 개발의 영역에선 자주 일어납니다. 접했을 당시에는 매우 당황스럽기도 하지만 이는 분명 저를 오만하지 않게 하며 동시에 성장의 기회이기도 하여 매우 감사한 순간입니다. 그리고 뭔가 답을 찾았단 생각에 괜히 스스로 뿌듯하기도 합니다 ^^; 거기에 더해 제가 겪었던 내용이 다른 분들에게도 도움이 된다면 큰 기쁨일 것입니다. 그런 의미에서 아티클 작성의 기회를 주신 카카오스타일과 검수에 큰 도움을 주신 사이먼께 감사를 드리며 이 글을 마칩니다.